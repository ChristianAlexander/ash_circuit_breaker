defmodule AshCircuitBreaker.TransformerTest do
  use ExUnit.Case, async: true
  alias Ash.Resource.Info
  alias AshCircuitBreaker.Change
  alias AshCircuitBreaker.Preparation
  alias Example.SampleResource

  describe "transformer behavior" do
    test "changes are added to specific actions only" do
      # Circuit breaker create action should have its normal change and the circuit breaker change
      fallible_create_action = Info.action(SampleResource, :fallible_create)
      assert length(fallible_create_action.changes) == 2

      change = hd(fallible_create_action.changes)
      assert elem(change.change, 0) == Change

      # Non-circuit create action should have no changes
      create_action = Info.action(SampleResource, :create)
      assert create_action.changes == []
    end

    test "preparations are added to specific actions only" do
      # Circuit breaker update action should have a preparation
      fallible_action = Info.action(SampleResource, :fallible_action)
      assert length(fallible_action.preparations) == 1

      preparation = hd(fallible_action.preparations)
      assert elem(preparation.preparation, 0) == Preparation

      # Non-circuit breaker update action should have no preparations
      regular_action = Info.action(SampleResource, :regular_action)
      assert regular_action.preparations == []
    end
  end
end
