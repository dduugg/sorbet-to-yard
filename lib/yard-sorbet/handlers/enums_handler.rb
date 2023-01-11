# typed: strict
# frozen_string_literal: true

module YARDSorbet
  module Handlers
    # Handle `enums` calls, registering enum values as constants
    class EnumsHandler < YARD::Handlers::Ruby::Base
      handles method_call(:enums)
      namespace_only

      def process
        statement.traverse do |node|
          if const_assign_node?(node)
            register YARD::CodeObjects::ConstantObject.new(namespace, node.first.source) do |obj|
              obj.docstring = node.docstring
              obj.source = node
              obj.value = node.last.source
            end
          end
        end
      end

      private

      def const_assign_node?(node)
        node.type == :assign && node.dig(0, 0).type == :const
      end
    end
  end
end
