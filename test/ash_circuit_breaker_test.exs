defmodule AshCircuitBreakerTest do
  use ExUnit.Case
  doctest AshCircuitBreaker

  alias Example.SampleResource

  describe "name_for_breaker/1" do
    test "returns a reasonable name for an action" do
      action_input =
        SampleResource
        |> Ash.ActionInput.for_action(:fallible_action, %{
          input_data: "Test Input"
        })

      assert AshCircuitBreaker.name_for_breaker(action_input) ==
               :"example/sample_resource/fallible_action"
    end

    test "returns a reasonable name for a changeset" do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:fallible_create, %{
          description: "Test Description"
        })

      assert AshCircuitBreaker.name_for_breaker(changeset) ==
               :"example/sample_resource/fallible_create"
    end
  end
end
