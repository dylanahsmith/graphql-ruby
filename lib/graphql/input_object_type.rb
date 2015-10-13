# A complex input type for a field argument.
#
# @example An input type with name and number
#   PlayerInput = GraphQL::InputObjectType.define do
#     name("Player")
#     input_field :name, !types.String
#     input_field :number, !types.Int
#   end
#
class GraphQL::InputObjectType < GraphQL::BaseType
  attr_accessor :name, :description, :input_fields
  defined_by_config :name, :description, :input_fields

  def input_fields=(new_fields)
    @input_fields = GraphQL::DefinitionHelpers::StringNamedHash.new(new_fields).to_h
  end

  def kind
    GraphQL::TypeKinds::INPUT_OBJECT
  end

  def valid_non_null_input?(input)
    return false unless input.is_a?(Hash) || value.is_a?(GraphQL::Query::Arguments)
    input.all? do |name, value|
      field = input_fields[name]
      !field.nil? && field.type.valid_input?(value)
    end
  end

  def coerce_non_null_input(input)
    result = {}
    input.each do |name, value|
      field = input_fields[name]
      field_value = field.type.coerce_input(value)
      if field_value.nil?
        field_value = field.default_value
      end
      result[name] = field_value unless field_value.nil?
    end
    GraphQL::Query::Arguments.new(result)
  end
end
