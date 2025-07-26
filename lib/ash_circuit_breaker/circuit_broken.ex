defmodule AshCircuitBreaker.CircuitBroken do
  @moduledoc """
  An exception which is raised or returned when an action invocation is blocked by a circuit breaker.
  """
  use Splode.Error, fields: [:action, :limit, :per, :reset_after], class: :unknown

  def message(_) do
    "Circuit breaker is open, action cannot be executed"
  end

  if Code.loaded?(Plug.Exception) do
    defimpl Plug.Exception do
      @doc false
      @impl Plug.Exception
      def actions(_), do: []

      @doc false
      @impl Plug.Exception
      def status(_), do: 503
    end
  end
end
