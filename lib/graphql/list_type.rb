# A list type wraps another type.
#
# Get the underlying type with {#unwrap}
class GraphQL::ListType < GraphQL::BaseType
  include GraphQL::BaseType::ModifiesAnotherType
  attr_reader :of_type, :name
  def initialize(of_type:)
    @name = "List"
    @of_type = of_type
  end

  def kind
    GraphQL::TypeKinds::LIST
  end

  def to_s
    "[#{of_type.to_s}]"
  end

  def valid_non_null_input?(value)
    return true if value.nil?
    list = value.is_a?(Array) ? value : [value]
    list.all?{ |element| of_type.valid_input?(element) }
  end

  def coerce_non_null_input(value)
    return nil if value.nil?
    list = value.is_a?(Array) ? value : [value]
    list.map{ |element| of_type.coerce_input(element) }
  end
end
