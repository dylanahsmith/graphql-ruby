require 'spec_helper'

describe GraphQL::Query::Executor do
  let(:debug) { false }
  let(:operation_name) { nil }
  let(:schema) { DummySchema }
  let(:variables) { {"cheeseId" => 2} }
  let(:result) { schema.execute(
    query_string,
    variables: variables,
    debug: debug,
    operation_name: operation_name,
  )}

  describe "multiple operations" do
    let(:query_string) { %|
      query getCheese1 { cheese(id: 1) { flavor } }
      query getCheese2 { cheese(id: 2) { flavor } }
    |}

    describe "when an operation is named" do
      let(:operation_name) { "getCheese2" }

      it "runs the named one" do
        expected = {
          "data" => {
            "cheese" => {
              "flavor" => "Gouda"
            }
          }
        }
        assert_equal(expected, result)
      end
    end

    describe "when one is NOT named" do
      it "returns an error" do
        expected = {
          "errors" => [
            {"message" => "You must provide an operation name from: getCheese1, getCheese2"}
          ]
        }
        assert_equal(expected, result)
      end
    end
  end


  describe 'execution order' do
    let(:query_string) {%|
      mutation setInOrder {
        first:  pushValue(value: 1)
        second: pushValue(value: 5)
        third:  pushValue(value: 2)
        fourth: replaceValues(input: {values: [6,5,4]})
      }
    |}

    it 'executes mutations in order' do
      expected = {"data"=>{
          "first"=> [1],
          "second"=>[1, 5],
          "third"=> [1, 5, 2],
          "fourth"=> [6, 5 ,4],
      }}
      assert_equal(expected, result)
    end
  end


  describe 'fragment resolution' do
    let(:schema) {
      # we will raise if the dairy field is resolved more than one time
      resolved = false

      DummyQueryType = GraphQL::ObjectType.define do
        name "Query"
        field :dairy do
          type DairyType
          resolve -> (t, a, c) {
            raise if resolved
            resolved = true
            DAIRY
          }
        end
      end

      GraphQL::Schema.new(query: DummyQueryType, mutation: MutationType)
    }
    let(:variables) { nil }
    let(:query_string) { %|
      query getDairy {
        dairy {
          id
          ... on Dairy {
            id
          }
          ...repetitiveFragment
        }
      }
      fragment repetitiveFragment on Dairy {
        id
      }
    |}

    it 'resolves each field only one time, even when present in multiple fragments' do
      expected = {"data" => {
        "dairy" => { "id" => "1" }
      }}
      assert_equal(expected, result)
    end

  end


  describe 'runtime errors' do
    let(:query_string) {%| query noMilk { error }|}
    describe 'if debug: false' do
      let(:debug) { false }
      it 'turns into error messages' do
        expected = {"errors"=>[
          {"message"=>"Something went wrong during query execution: This error was raised on purpose"}
        ]}
        assert_equal(expected, result)
      end
    end

    describe 'if debug: true' do
      let(:debug) { true }
      it 'raises error' do
        assert_raises(RuntimeError) { result }
      end
    end
  end
end
