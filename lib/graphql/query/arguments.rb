# Provide read-only access to arguments by string or symbol names.
class GraphQL::Query::Arguments
  extend Forwardable

  def self.from_ast(ast_arguments, argument_hash, variables)
    new(ast_arguments.reduce({}) { |memo, arg|
      arg_defn = argument_hash[arg.name]
      value = GraphQL::Query::Literal.to_value(arg.value, arg_defn.type, variables)
      memo[arg.name] = value
      memo
    })
  end

  def initialize(hash)
    @hash = hash
  end

  def_delegators :@hash, :keys, :values, :inspect, :to_h, :key?, :has_key?, :each

  # Find an argument by name.
  # (Coerce to strings because we use strings internally.)
  # @param [String, Symbol] Argument name to access
  def [](key)
    @hash[key.to_s]
  end
end
