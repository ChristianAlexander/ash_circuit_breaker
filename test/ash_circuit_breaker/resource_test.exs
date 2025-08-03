defmodule AshCircuitBreaker.ResourceTest do
  use ExUnit.Case, async: true
  alias Example.SampleResource

  describe "fallible_create" do
    test "Creates a resource successfully", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:fallible_create, %{
          description: "Test Resource",
          should_fail: false
        })

      opts = [context: %{circuit_name: test}]

      assert {:ok, _} = Ash.create(changeset, opts)
    end

    test "Fails to create a resource as expected", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:fallible_create, %{
          description: "Test Resource",
          should_fail: true
        })

      opts = [context: %{circuit_name: test}]

      assert {:error, error} = Ash.create(changeset, opts)
      assert %Ash.Error.Invalid{errors: [error]} = error
      assert %{field: :should_fail, message: "This action is configured to fail"} = error
    end

    test "Returns a circuit broken error when maximum failures are exceeded", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:fallible_create, %{
          description: "Test Resource",
          should_fail: true
        })

      opts = [context: %{circuit_name: test}]

      # First failure
      assert {:error, error} = Ash.create(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Second failure
      assert {:error, error} = Ash.create(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Third failure should trigger circuit breaker
      assert {:error, error} = Ash.create(changeset, opts)
      assert %Ash.Error.Unknown{errors: [error]} = error
      assert %AshCircuitBreaker.CircuitBroken{} = error
    end

    test "Returns a successful response after the circuit is reset", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:fallible_create, %{
          description: "Test Resource",
          should_fail: true
        })

      opts = [context: %{circuit_name: test}]

      # First failure
      assert {:error, error} = Ash.create(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Second failure
      assert {:error, error} = Ash.create(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      :fuse.reset(test)

      # After resetting the circuit, we should be able to try again
      assert {:error, error} = Ash.create(changeset, opts)
      assert %Ash.Error.Invalid{} = error
    end
  end

  describe "always_fail_create_ignore_errors" do
    test "Executes a create action that always fails but ignores errors", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:always_fail_create_ignore_errors, %{
          description: "Test"
        })

      opts = [context: %{circuit_name: test}]
      {:error, _error} = Ash.create(changeset, opts)
      {:error, _error} = Ash.create(changeset, opts)

      assert :ok = :fuse.ask(test, :sync)
    end
  end

  describe "always_fail_create_all_errors" do
    test "breaks the circuit", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:always_fail_create_all_errors, %{
          description: "Test"
        })

      opts = [context: %{circuit_name: test}]
      {:error, _error} = Ash.create(changeset, opts)
      {:error, _error} = Ash.create(changeset, opts)

      assert :blown = :fuse.ask(test, :sync)
    end
  end

  describe "fallible_update" do
    test "Updates a resource successfully", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:create, %{
          description: "Test Resource",
          should_fail: false
        })

      {:ok, resource} = Ash.create(changeset)

      changeset =
        resource
        |> Ash.Changeset.for_update(:fallible_update, %{
          description: "Updated Test Resource"
        })

      opts = [context: %{circuit_name: test}]

      assert {:ok, updated_resource} = Ash.update(changeset, opts)
      assert updated_resource.description == "Updated Test Resource"
    end

    test "Fails to update a resource as expected", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:create, %{
          description: "Test Resource",
          should_fail: true
        })

      {:ok, resource} = Ash.create(changeset)

      changeset =
        resource
        |> Ash.Changeset.for_update(:fallible_update, %{
          description: "Updated Test Resource"
        })

      opts = [context: %{circuit_name: test}]

      assert {:error, error} = Ash.update(changeset, opts)
      assert %Ash.Error.Invalid{errors: [error]} = error
      assert %{field: :should_fail, message: "This action is configured to fail"} = error
    end

    test "Returns a circuit broken error when maximum failures are exceeded", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:create, %{
          description: "Test Resource",
          should_fail: true
        })

      {:ok, resource} = Ash.create(changeset)

      changeset =
        resource
        |> Ash.Changeset.for_update(:fallible_update, %{
          description: "Updated Test Resource"
        })

      opts = [context: %{circuit_name: test}]

      # First failure
      assert {:error, error} = Ash.update(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Second failure
      assert {:error, error} = Ash.update(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Third failure should trigger circuit breaker
      assert {:error, error} = Ash.update(changeset, opts)
      assert %Ash.Error.Unknown{errors: [error]} = error
      assert %AshCircuitBreaker.CircuitBroken{} = error
    end

    test "Returns a successful response after the circuit is reset", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:create, %{
          description: "Test Resource",
          should_fail: true
        })

      {:ok, resource} = Ash.create(changeset)

      changeset =
        resource
        |> Ash.Changeset.for_update(:fallible_update, %{
          description: "Updated Test Resource"
        })

      opts = [context: %{circuit_name: test}]

      # First failure
      assert {:error, error} = Ash.update(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Second failure
      assert {:error, error} = Ash.update(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      :fuse.reset(test)

      # After resetting the circuit, we should be able to try again
      assert {:error, error} = Ash.update(changeset, opts)
      assert %Ash.Error.Invalid{} = error
    end
  end

  describe "fallible_destroy" do
    test "Destroys a resource successfully", %{test: test} do
      # First create a resource
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:create, %{
          description: "Test Resource",
          should_fail: false
        })

      {:ok, resource} = Ash.create(changeset)

      # Now destroy it
      changeset =
        resource
        |> Ash.Changeset.for_destroy(:fallible_destroy)

      opts = [context: %{circuit_name: test}]

      assert :ok = Ash.destroy(changeset, opts)
    end

    test "Fails to destroy a resource as expected", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:create, %{
          description: "Test Resource",
          should_fail: true
        })

      {:ok, resource} = Ash.create(changeset)

      changeset =
        resource
        |> Ash.Changeset.for_destroy(:fallible_destroy)

      opts = [context: %{circuit_name: test}]

      assert {:error, error} = Ash.destroy(changeset, opts)
      assert %Ash.Error.Invalid{errors: [error]} = error
      assert %{field: :should_fail, message: "This action is configured to fail"} = error
    end

    test "Returns a circuit broken error when maximum failures are exceeded", %{test: test} do
      # First create a resource with should_fail: true
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:create, %{
          description: "Test Resource",
          should_fail: true
        })

      {:ok, resource} = Ash.create(changeset)

      changeset =
        resource
        |> Ash.Changeset.for_destroy(:fallible_destroy)

      opts = [context: %{circuit_name: test}]

      # First failure
      assert {:error, error} = Ash.destroy(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Second failure
      assert {:error, error} = Ash.destroy(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Third failure should trigger circuit breaker
      assert {:error, error} = Ash.destroy(changeset, opts)
      assert %Ash.Error.Unknown{errors: [error]} = error
      assert %AshCircuitBreaker.CircuitBroken{} = error
    end

    test "Returns a successful response after the circuit is reset", %{test: test} do
      changeset =
        SampleResource
        |> Ash.Changeset.for_create(:create, %{
          description: "Test Resource",
          should_fail: true
        })

      {:ok, resource} = Ash.create(changeset)

      changeset =
        resource
        |> Ash.Changeset.for_destroy(:fallible_destroy)

      opts = [context: %{circuit_name: test}]

      # First failure
      assert {:error, error} = Ash.destroy(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      # Second failure
      assert {:error, error} = Ash.destroy(changeset, opts)
      assert %Ash.Error.Invalid{} = error

      :fuse.reset(test)

      # After resetting the circuit, we should be able to try again
      assert {:error, error} = Ash.destroy(changeset, opts)
      assert %Ash.Error.Invalid{} = error
    end
  end

  describe "fallible_action" do
    test "Executes a fallible action successfully", %{test: test} do
      action_input =
        SampleResource
        |> Ash.ActionInput.for_action(:fallible_action, %{
          should_fail: false,
          input_data: "Test Input"
        })

      opts = [context: %{circuit_name: test}]

      assert {:ok, result} = Ash.run_action(action_input, opts)
      assert result == "Processed: Test Input"
    end

    test "Fails to execute a fallible action as expected", %{test: test} do
      action_input =
        SampleResource
        |> Ash.ActionInput.for_action(:fallible_action, %{
          should_fail: true,
          input_data: "Test Input"
        })

      opts = [context: %{circuit_name: test}]

      assert {:error, error} = Ash.run_action(action_input, opts)
      assert %Ash.Error.Invalid{errors: [error]} = error
      assert %{field: :should_fail, message: "This action is configured to fail"} = error
    end

    test "Returns a circuit broken error when maximum failures are exceeded", %{test: test} do
      action_input =
        SampleResource
        |> Ash.ActionInput.for_action(:fallible_action, %{
          should_fail: true,
          input_data: "Test Input"
        })

      opts = [context: %{circuit_name: test}]

      # First failure
      assert {:error, error} = Ash.run_action(action_input, opts)
      assert %Ash.Error.Invalid{} = error

      # Second failure
      assert {:error, error} = Ash.run_action(action_input, opts)
      assert %Ash.Error.Invalid{} = error

      # Third failure should trigger circuit breaker
      assert {:error, error} = Ash.run_action(action_input, opts)
      assert %Ash.Error.Unknown{errors: [error]} = error
      assert %AshCircuitBreaker.CircuitBroken{} = error
    end
  end

  describe "always_fail_action_ignore_errors" do
    test "Executes an action that always fails but ignores errors", %{test: test} do
      action_input =
        SampleResource
        |> Ash.ActionInput.for_action(:always_fail_action_ignore_errors, %{})

      opts = [context: %{circuit_name: test}]
      {:error, _error} = Ash.run_action(action_input, opts)
      {:error, _error} = Ash.run_action(action_input, opts)

      assert :ok = :fuse.ask(test, :sync)
    end
  end

  describe "always_fail_action_all_errors" do
    test "breaks the circuit", %{test: test} do
      action_input =
        SampleResource
        |> Ash.ActionInput.for_action(:always_fail_action_all_errors, %{})

      opts = [context: %{circuit_name: test}]
      {:error, _error} = Ash.run_action(action_input, opts)
      {:error, _error} = Ash.run_action(action_input, opts)

      assert :blown = :fuse.ask(test, :sync)
    end
  end
end
