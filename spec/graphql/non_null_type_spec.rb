require "spec_helper"

describe GraphQL::NonNullType do
  describe "when a non-null field raises an execution error" do
    it "nulls out the parent selection" do
      query_string = %|{ cow { name cantBeNullButRaisesExecutionError } }|
      result = DummySchema.execute(query_string)
      assert_equal({"cow" => nil }, result["data"])
      assert_equal([{
        "message"=>"BOOM",
        "locations"=>[{"line"=>1, "column"=>14}],
        "path"=>["cow", "cantBeNullButRaisesExecutionError"],
      }], result["errors"])
    end

    it "propagates the null up to the next nullable field" do
      query_string = %|
      {
        nn1: deepNonNull {
          nni1: nonNullInt(returning: 1)
          nn2: deepNonNull {
            nni2: nonNullInt(returning: 2)
            nn3: deepNonNull {
              nni3: nonNullError
            }
          }
        }
      }
      |
      result = DummySchema.execute(query_string)
      assert_equal(nil, result["data"])
      assert_equal([{
        "message"=>"error on non-null field",
        "locations"=>[{"line"=>8, "column"=>15}],
        "path"=>["nn1", "nn2", "nn3", "nni3"],
      }], result["errors"])
    end
  end

  describe "when a non-null field returns null" do
    it "raises an invalid null error" do
      query_string = %|{ cow { name cantBeNullButIs } }|
      err = assert_raises(GraphQL::InvalidNullError) do
        DummySchema.execute(query_string)
      end
      assert_equal "Cannot return null for non-nullable field Cow.cantBeNullButIs", err.message
    end
  end
end
