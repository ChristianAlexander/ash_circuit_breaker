defmodule AshCircuitBreaker.Change do
  @moduledoc """
  A resource change which implements a circuit breaker.
  """
  use Ash.Resource.Change
  alias Ash.Changeset
  alias AshCircuitBreaker.CircuitBroken
  alias Spark.Options

  @option_schema Options.new!(
                   action: [
                     type: {:or, [nil, :atom]},
                     required: false,
                     default: nil,
                     doc:
                       "If provided, then only changesets matching the provided action name will run through the circuit breaker, otherwise all non-read/query actions are."
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
                     default: &AshCircuitBreaker.name_for_breaker/1,
                     doc:
                       "The name to use for the circuit breaker. This can be an atom or a function that takes a changeset and optional context object to generate an atom key."
                   ],
                   should_break?: [
                     type: {:or, [nil, {:fun, 1}]},
                     required: false,
                     doc:
                       "A function that takes the error and returns true if the circuit should break. If not provided, the circuit will break on any error."
                   ]
                 )

  @doc false
  @impl Ash.Resource.Change
  def init(options), do: Options.validate(options, @option_schema)

  @doc false
  @impl Ash.Resource.Change
  def change(changeset, opts, context) do
    if is_nil(opts[:action]) or opts[:action] == changeset.action.name do
      changeset
      |> Changeset.before_transaction(fn changeset ->
        before_transaction(changeset, opts, context)
      end)
      |> Changeset.after_transaction(fn changeset, result ->
        after_transaction(changeset, result, opts, context)
      end)
    else
      changeset
    end
  end

  defp before_transaction(changeset, opts, context) do
    case get_name(changeset, opts, context) do
      {:ok, fuse_name} ->
        case :fuse.ask(fuse_name, :sync) do
          :ok ->
            changeset

          :blown ->
            Changeset.add_error(
              changeset,
              CircuitBroken.exception(
                action: changeset.action.name,
                limit: opts[:limit],
                per: opts[:per],
                reset_after: opts[:reset_after]
              )
            )

          {:error, :not_found} ->
            :fuse.install(
              fuse_name,
              {{:standard, opts[:limit], opts[:per]}, {:reset, opts[:reset_after]}}
            )

            changeset
        end

      {:error, reason} ->
        Changeset.add_error(changeset, reason)
    end
  end

  defp after_transaction(_changeset, {:ok, _} = result, _opts, _context), do: result

  # Don't re-melt if the error is a CircuitBroken error
  defp after_transaction(
         _changeset,
         {:error, %{errors: [%CircuitBroken{}]}} = result,
         _opts,
         _context
       ),
       do: result

  defp after_transaction(input, {:error, error} = result, opts, context) do
    should_break? = opts[:should_break?]

    if is_nil(should_break?) or (is_function(should_break?, 1) and should_break?.(error)) do
      {:ok, fuse_name} = get_name(input, opts, context)
      :fuse.melt(fuse_name)
    end

    result
  end

  defp get_name(changeset, opts, context) do
    case opts[:name] do
      name when is_atom(name) ->
        name

      namefun when is_function(namefun, 1) ->
        namefun.(changeset)
        |> handle_namefun_result()

      namefun when is_function(namefun, 2) ->
        namefun.(changeset, context)
        |> handle_namefun_result()
    end
  end

  defp handle_namefun_result(name) when is_atom(name), do: {:ok, name}
  defp handle_namefun_result(name), do: {:error, "Invalid name: `#{inspect(name)}`"}
end
