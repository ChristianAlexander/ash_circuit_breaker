defmodule AshCircuitBreaker.Transformer do
  @moduledoc """
  A Spark DSL transformer for circuit breaking.
  """
  use Spark.Dsl.Transformer
  import Spark.Dsl.Transformer
  alias Ash.Resource.{Dsl, Info}
  alias Spark.Error.DslError

  @doc false
  @impl Spark.Dsl.Transformer
  def after?(_), do: true

  @doc false
  @impl Spark.Dsl.Transformer
  def transform(dsl) do
    dsl
    |> get_entities([:circuit])
    |> Enum.reduce_while({:ok, dsl}, fn entity, {:ok, dsl} ->
      case transform_entity(entity, dsl) do
        {:ok, dsl} -> {:cont, {:ok, dsl}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp transform_entity(entity, dsl) do
    with {:ok, action} <- validate_action(entity, dsl) do
      add_change_or_preparation(entity, action, dsl)
    end
  end

  defp validate_action(entity, dsl) do
    case Info.action(dsl, entity.action) do
      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:circuit, :action, entity.action, :action],
           message: """
           Action #{entity.action} not found.
           """
         )}

      action when action.type in [:create, :update, :destroy, :action] ->
        {:ok, action}

      action when action.type == :read ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:circuit, :action, entity.action, :action],
           message: """
           Read actions are not supported by the circuit breaker DSL
           """
         )}
    end
  end

  defp add_change_or_preparation(entity, action, dsl) when action.type == :action,
    do: add_preparation_to_action(entity, action, dsl)

  defp add_change_or_preparation(entity, action, dsl),
    do: add_change_to_action(entity, action, dsl)

  defp add_preparation_to_action(entity, action, dsl) do
    with {:ok, preparation} <-
           build_entity(Dsl, [:preparations], :prepare,
             preparation:
               {AshCircuitBreaker.Preparation,
                action: entity.action,
                limit: entity.limit,
                per: entity.per,
                reset_after: entity.reset_after,
                name: entity.name,
                should_break?: entity.should_break?},
             only_when_valid?: true
           ) do
      updated_action = %{action | preparations: [preparation | action.preparations]}
      {:ok, replace_entity(dsl, [:actions], updated_action, &(&1.name == action.name))}
    end
  end

  defp add_change_to_action(entity, action, dsl) do
    with {:ok, change} <-
           build_entity(Dsl, [:changes], :change,
             change:
               {AshCircuitBreaker.Change,
                action: entity.action,
                limit: entity.limit,
                per: entity.per,
                reset_after: entity.reset_after,
                name: entity.name,
                should_break?: entity.should_break?}
           ) do
      updated_action = %{action | changes: [change | action.changes]}
      {:ok, replace_entity(dsl, [:actions], updated_action, &(&1.name == action.name))}
    end
  end
end
