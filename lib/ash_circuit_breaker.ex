defmodule AshCircuitBreaker do
  @moduledoc """
  An extension for `Ash.Resource` which adds the ability to wrap actions in circuit breakers to allow for graceful handling of and recovery from failures.
  """

  @circuit %Spark.Dsl.Section{
    name: :circuit,
    describe: """
    Configure a circuit breaker for actions.

    _Note that this extension does not support circuit breaking for read/query actions._

    ## Fuse

    This library uses the [fuse](https://hex.pm/packages/fuse) package to provide
    circuit breaker features. See [fuse's documentation](https://hexdocs.pm/fuse) for more information.

    ## Names

    Fuse uses an atom "name" value as a reference to a specific circuit breaker. By default, the name is derived from the action name and resource name. You can provide a custom name using the `name` option.
    """,
    entities: [
      %Spark.Dsl.Entity{
        name: :action,
        describe: """
        Configure a circuit breaker for a single action.

        It does this by adding a global change or preparation to the resource with the provided configuration.
        """,
        target: __MODULE__,
        identifier: :action,
        args: [:action],
        schema: [
          action: [
            type: :atom,
            required: true,
            doc: "The name of the action to wrap in a circuit breaker"
          ],
          limit: [
            type: :pos_integer,
            required: true,
            doc: "The maximum number of failures allowed before the circuit opens"
          ],
          per: [
            type: :pos_integer,
            required: true,
            doc: "The time period (in milliseconds) for which failures are counted"
          ],
          reset_after: [
            type: :pos_integer,
            required: true,
            doc:
              "The time period (in milliseconds) after which the circuit will attempt to close again"
          ],
          name: [
            type: {:or, [:atom, {:fun, 1}, {:fun, 2}]},
            required: false,
            default: &__MODULE__.name_for_breaker/1,
            doc:
              "The name to use for the circuit breaker. This can be an atom or a function that takes a query/changeset and optional context object to generate an atom key."
          ],
          should_break?: [
            type: {:or, [nil, {:fun, 1}]},
            required: false,
            doc:
              "A function that takes the error and returns true if the circuit should break. If not provided, the circuit will break on any error."
          ]
        ]
      }
    ]
  }

  defstruct [:action, :limit, :per, :reset_after, :name, :should_break?, :__identifier__]

  @type namefun ::
          (Ash.Changeset.t() | Ash.ActionInput.t() -> atom())
          | (Ash.Changeset.t() | Ash.ActionInput.t(), map -> atom())

  @type error_matcher :: (any -> boolean())

  @type t :: %__MODULE__{
          __identifier__: any,
          action: atom(),
          limit: pos_integer(),
          per: pos_integer(),
          reset_after: pos_integer(),
          name: atom() | namefun(),
          should_break?: error_matcher() | nil
        }

  use Spark.Dsl.Extension, sections: [@circuit], transformers: [__MODULE__.Transformer]

  @doc """
  Generates a name for the circuit breaker based on the action input or changeset.
  """
  def name_for_breaker(action_input_or_changeset) do
    domain = Ash.Domain.Info.short_name(action_input_or_changeset.domain)
    resource = Ash.Resource.Info.short_name(action_input_or_changeset.resource)
    action_name = action_input_or_changeset.action.name

    [domain, resource, action_name]
    |> Enum.map(&to_string/1)
    |> Path.join()
    |> String.to_atom()
  end
end
