module GraphQL
  class Query
    module Literal
      extend self

      def to_value(value_ast, type, variables=nil)
        if value_ast.is_a?(Language::Nodes::VariableIdentifier)
          variables[value_ast.name]
        elsif value_ast.nil?
          nil
        else
          STRATEGIES.fetch(type.kind).to_value(value_ast, type, variables)
        end
      end

      module NonNullLiteral
        def self.to_value(value_ast, type, variables)
          Literal.to_value(value_ast, type.of_type, variables)
        end
      end

      module ListLiteral
        def self.to_value(value_ast, type, variables)
          if value_ast.is_a?(Array)
            value_ast.map{ |element_ast| Literal.to_value(element_ast, type.of_type, variables) }
          else
            [Literal.to_value(value_ast, type.of_type, variables)]
          end
        end
      end

      module InputObjectLiteral
        def self.to_value(value_ast, type, variables)
          unless value_ast.is_a?(Language::Nodes::InputObject)
            return nil
          end
          hash = {}
          value_ast.pairs.each do |arg|
            field_type = type.input_fields[arg.name].type
            hash[arg.name] = Literal.to_value(arg.value, field_type, variables)
          end
          Arguments.new(hash)
        end
      end

      module EnumLiteral
        def self.to_value(value_ast, type, variables)
          type.coerce_input(value_ast.name)
        end
      end

      module ScalarLiteral
        def self.to_value(value_ast, type, variables)
          type.coerce_input(value_ast)
        end
      end

      STRATEGIES = {
        TypeKinds::NON_NULL =>     NonNullLiteral,
        TypeKinds::LIST =>         ListLiteral,
        TypeKinds::INPUT_OBJECT => InputObjectLiteral,
        TypeKinds::ENUM =>         EnumLiteral,
        TypeKinds::SCALAR =>       ScalarLiteral,
      }
      private_constant :STRATEGIES
    end
  end
end
