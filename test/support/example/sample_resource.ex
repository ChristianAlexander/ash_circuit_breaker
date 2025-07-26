defmodule Example.SampleResource do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    domain: Example,
    extensions: [AshCircuitBreaker]

  alias Ash.Error.Changes.InvalidAttribute
  alias Ash.Error.Invalid

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :fallible_create do
      accept :*

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          if Ash.Changeset.get_attribute(changeset, :should_fail) do
            Ash.Changeset.add_error(changeset,
              field: :should_fail,
              message: "This action is configured to fail"
            )
          else
            changeset
          end
        end)
      end
    end

    update :fallible_update do
      accept :*
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          if Ash.Changeset.get_argument_or_attribute(changeset, :should_fail) do
            Ash.Changeset.add_error(changeset,
              field: :should_fail,
              message: "This action is configured to fail"
            )
          else
            changeset
          end
        end)
      end
    end

    destroy :fallible_destroy do
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          if Ash.Changeset.get_data(changeset, :should_fail) do
            Ash.Changeset.add_error(changeset,
              field: :should_fail,
              message: "This action is configured to fail"
            )
          else
            changeset
          end
        end)
      end
    end

    action :fallible_action, :string do
      argument :should_fail, :boolean, default: false
      argument :input_data, :string

      run fn input, _context ->
        if input.arguments.should_fail do
          {:error,
           Invalid.exception(
             errors: [
               %InvalidAttribute{
                 field: :should_fail,
                 message: "This action is configured to fail"
               }
             ]
           )}
        else
          {:ok, "Processed: #{input.arguments.input_data}"}
        end
      end
    end

    action :regular_action, :string do
      argument :input_data, :string

      run fn input, _context ->
        {:ok, "Processed: #{input.arguments.input_data}"}
      end
    end
  end

  circuit do
    action :fallible_create,
      limit: 1,
      per: :timer.seconds(1),
      reset_after: :timer.seconds(2),
      name: &name_fun/1

    action :fallible_update,
      limit: 1,
      per: :timer.seconds(1),
      reset_after: :timer.seconds(2),
      name: &name_fun/1

    action :fallible_destroy,
      limit: 1,
      per: :timer.seconds(1),
      reset_after: :timer.seconds(2),
      name: &name_fun/1

    action :fallible_action,
      limit: 1,
      per: :timer.seconds(1),
      reset_after: :timer.seconds(2),
      name: &name_fun/1
  end

  attributes do
    uuid_v7_primary_key :id, writable?: true
    attribute :description, :string, allow_nil?: false, public?: true
    attribute :should_fail, :boolean, default: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  ets do
    table :sample_resources
    private? true
  end

  defp name_fun(changeset_or_action),
    do: changeset_or_action.context.circuit_name
end
