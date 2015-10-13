module GraphQL
  class Query
    class Executor
      class OperationNameMissingError < StandardError
        def initialize(names)
          msg = "You must provide an operation name from: #{names.join(", ")}"
          super(msg)
        end
      end

      # @return [GraphQL::Query] the query being executed
      attr_reader :query

      # @return [String] the operation to run in {query}
      attr_reader :operation_name


      def initialize(query, operation_name)
        @query = query
        @operation_name = operation_name
      end

      # Evalute {operation_name} on {query}. Handle errors by putting them in the "errors" key.
      # (Or, if `query.debug`, by re-raising them.)
      # @return [Hash] A GraphQL response, with either a "data" key or an "errors" key
      def result
        execute
      rescue OperationNameMissingError => err
        {"errors" => [{"message" => err.message}]}
      rescue StandardError => err
        query.debug && raise(err)
        message = "Something went wrong during query execution: #{err}" # \n  #{err.backtrace.join("\n  ")}"
        {"errors" => [{"message" => message}]}
      end

      private

      def execute
        return {} if query.operations.none?
        operation = find_operation(operation_name, query.operations)
        coerce_variables(operation, query)
        if operation.operation_type == "query"
          root_type = query.schema.query
          execution_strategy_class = query.schema.query_execution_strategy
        elsif operation.operation_type == "mutation"
          root_type = query.schema.mutation
          execution_strategy_class = query.schema.mutation_execution_strategy
        end
        execution_strategy = execution_strategy_class.new
        query.context.execution_strategy = execution_strategy
        data_result = execution_strategy.execute(operation, root_type, query)
        result = { "data" => data_result }
        error_result = query.context.errors.map(&:to_h)

        if error_result.any?
          result["errors"] = error_result
        end

        result
      end

      def find_operation(operation_name, operations)
        if operations.length == 1
          operations.values.first
        elsif !operations.key?(operation_name)
          raise OperationNameMissingError, operations.keys
        else
          operations[operation_name]
        end
      end

      def coerce_variables(operation, query)
        values = {}
        operation.variables.each do |variable_definition|
          name = variable_definition.name
          raw_value = query.raw_variables[name]
          values[name] = coerce_variable(variable_definition, raw_value)
        end
        query.variables = GraphQL::Query::Arguments.new(values)
      end

      def coerce_variable(variable_definition, input)
        type = type_from_ast(variable_definition.type)

        unless type.valid_input?(input)
          exc = GraphQL::ExecutionError.new("Value #{JSON.dump(input)} for variable #{variable_definition.name} wasn't of type #{type}")
          exc.ast_node = variable_definition
          raise exc
        end
        if input.nil?
          GraphQL::Query::Literal.to_value(variable_definition.default_value, type)
        else
          type.coerce_input(input)
        end
      end

      WRAPPER_TYPES = {
        GraphQL::Language::Nodes::NonNullType => GraphQL::NonNullType,
        GraphQL::Language::Nodes::ListType => GraphQL::ListType,
      }
      private_constant :WRAPPER_TYPES

      def type_from_ast(type_ast)
        if wrapper_type = WRAPPER_TYPES[type_ast.class]
          wrapper_type.new(of_type: type_from_ast(type_ast.of_type))
        else
          query.schema.types[type_ast.name]
        end
      end
    end
  end
end
