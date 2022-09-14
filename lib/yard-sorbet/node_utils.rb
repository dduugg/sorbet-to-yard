# typed: strict
# frozen_string_literal: true

module YARDSorbet
  # Helper methods for working with `YARD` AST Nodes
  module NodeUtils
    extend T::Sig

    # Command node types that can have type signatures
    ATTRIBUTE_METHODS = T.let(%i[attr attr_accessor attr_reader attr_writer].freeze, T::Array[Symbol])
    # Skip these method contents during BFS node traversal, they can have their own nested types via `T.Proc`
    SKIP_METHOD_CONTENTS = T.let(%i[params returns].freeze, T::Array[Symbol])
    # Node types that can have type signatures
    SigableNode = T.type_alias { T.any(YARD::Parser::Ruby::MethodDefinitionNode, YARD::Parser::Ruby::MethodCallNode) }
    private_constant :ATTRIBUTE_METHODS, :SKIP_METHOD_CONTENTS, :SigableNode

    # Traverse AST nodes in breadth-first order
    # @note This will skip over some node types.
    # @yield [YARD::Parser::Ruby::AstNode]
    sig { params(node: YARD::Parser::Ruby::AstNode, _blk: T.proc.params(n: YARD::Parser::Ruby::AstNode).void).void }
    def self.bfs_traverse(node, &_blk)
      queue = [node]
      until queue.empty?
        n = T.must(queue.shift)
        yield n
        n.children.each { queue.push(_1) }
        queue.pop if n.is_a?(YARD::Parser::Ruby::MethodCallNode) && SKIP_METHOD_CONTENTS.include?(n.method_name(true))
      end
    end

    # Gets the node that a sorbet `sig` can be attached do, bypassing visisbility modifiers and the like
    sig { params(node: YARD::Parser::Ruby::AstNode).returns(SigableNode) }
    def self.get_method_node(node)
      sigable_node?(node) ? node : node.jump(:def, :defs)
    end

    # Find and return the adjacent node (ascending)
    # @raise [IndexError] if the node does not have an adjacent sibling (ascending)
    sig { params(node: YARD::Parser::Ruby::AstNode).returns(YARD::Parser::Ruby::AstNode) }
    def self.sibling_node(node)
      siblings = node.parent.children
      node_index = siblings.find_index { _1.equal?(node) }
      siblings.fetch(node_index + 1)
    end

    sig { params(node: YARD::Parser::Ruby::AstNode).returns(T::Boolean) }
    private_class_method def self.sigable_node?(node)
      case node
      when YARD::Parser::Ruby::MethodDefinitionNode then true
      when YARD::Parser::Ruby::MethodCallNode then ATTRIBUTE_METHODS.include?(node.method_name(true))
      else false
      end
    end
  end
end
