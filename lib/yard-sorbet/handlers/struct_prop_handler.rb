# typed: strict
# frozen_string_literal: true

module YARDSorbet
  module Handlers
    # Handles all `const`/`prop` calls, creating accessor methods, and compiles them for later usage at the class level
    # in creating a constructor
    class StructPropHandler < YARD::Handlers::Ruby::Base
      handles method_call(:const), method_call(:prop)
      namespace_only

      def process
        name = params.dig(0, -1, -1).source
        prop = make_prop(name)
        update_state(prop)
        object = YARD::CodeObjects::MethodObject.new(namespace, name, scope)
        decorate_object(object, prop)
        register_attrs(object, name)
      end

      private

      # Add the source and docstring to the method object
      def decorate_object(object, prop)
        object.source = prop.source
        # TODO: this should use `+` to delimit the prop name when markdown is disabled
        reader_docstring = prop.doc.empty? ? "Returns the value of prop `#{prop.prop_name}`." : prop.doc
        docstring = YARD::DocstringParser.new.parse(reader_docstring).to_docstring
        docstring.add_tag(YARD::Tags::Tag.new(:return, '', prop.types))
        object.docstring = docstring.to_raw
      end

      def immutable?
        statement.method_name(true) == :const || kw_arg('immutable:') == 'true'
      end

      # @return the value passed to the keyword argument, or nil
      def kw_arg(kwd)
        params[2]&.find { _1[0].source == kwd }&.[](1)&.source
      end

      def make_prop(name)
        TStructProp.new(
          default: kw_arg('default:'),
          doc: statement.docstring.to_s,
          prop_name: name,
          source: statement.source,
          types: SigToYARD.convert(params[1])
        )
      end

      def params
        @params ||= T.let(statement.parameters(false), T.nilable(T::Array[T.untyped]))
      end

      # Register the field explicitly as an attribute.
      def register_attrs(object, name)
        write = immutable? ? nil : object
        # Create the virtual attribute in our current scope
        namespace.attributes[scope][name] ||= SymbolHash[read: object, write: write]
      end

      # Store the prop for use in the constructor definition
      def update_state(prop)
        extra_state.prop_docs ||= Hash.new { |h, k| h[k] = [] }
        extra_state.prop_docs[namespace] << prop
      end
    end
  end
end
