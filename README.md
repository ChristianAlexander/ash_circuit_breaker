[![Ash CI](https://github.com/christianalexander/ash_circuit_breaker/actions/workflows/elixir.yml/badge.svg)](https://github.com/christianalexander/ash_circuit_breaker/actions/workflows/elixir.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_circuit_breaker.svg)](https://hex.pm/packages/ash_circuit_breaker)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_circuit_breaker)

# AshCircuitBreaker

Welcome! This is an extension for the [Ash framework](https://hexdocs.pm/ash)
which protects your application from cascading failures by adding circuit breaker functionality to [actions](https://hexdocs.pm/ash/actions.html).

Uses the excellent [fuse](https://hex.pm/packages/fuse) library to provide robust circuit breaker features that help your application gracefully handle and recover from failures.

## Installation

Add `ash_circuit_breaker` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_circuit_breaker, "~> 0.0.1"}
  ]
end
```

## Quick Start

1. **Add to your resource**: Use the `circuit` DSL section in your Ash resource:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    domain: MyApp,
    extensions: [AshCircuitBreaker]

  circuit do
    # Protect create action - open circuit after 5 failures in 30 seconds
    action :create,
      limit: 5,
      per: :timer.seconds(30),
      reset_after: :timer.minutes(5)

    # Protect update action with different thresholds
    action :update,
      limit: 10,
      per: :timer.minutes(1),
      reset_after: :timer.minutes(2)
  end

  # ... rest of your resource definition
end
```

2. **That's it!** Your actions are now protected by circuit breakers. When failures exceed the threshold, subsequent calls will be blocked with an `AshCircuitBreaker.CircuitBroken` error until the circuit resets.

## Basic Usage

### Simple Circuit Breaker

```elixir
circuit do
  # Open circuit after 5 failures in 30 seconds, reset after 5 minutes
  action :create,
    limit: 5,
    per: :timer.seconds(30),
    reset_after: :timer.minutes(5)
end
```

### Multiple Actions

```elixir
circuit do
  action :create, limit: 5, per: :timer.seconds(30), reset_after: :timer.minutes(5)
  action :update, limit: 10, per: :timer.minutes(1), reset_after: :timer.minutes(2)
  action :delete, limit: 3, per: :timer.seconds(15), reset_after: :timer.minutes(10)
end
```

### Custom Circuit Names

```elixir
circuit do
  # Use a custom static name
  action :create,
    limit: 5,
    per: :timer.seconds(30),
    reset_after: :timer.minutes(5),
    name: :my_custom_circuit

  # Use a function to generate dynamic names
  action :update,
    limit: 10,
    per: :timer.minutes(1),
    reset_after: :timer.minutes(2),
    name: fn changeset ->
      :"update_circuit_#{changeset.data.id}"
    end
end
```

## Advanced Usage

### Manual Integration

For more control, you can add circuit breaker protection directly to specific actions:

```elixir
defmodule MyApp.Post do
  use Ash.Resource, domain: MyApp

  actions do
    create :create do
      change {AshCircuitBreaker.Change,
        limit: 5,
        per: :timer.seconds(30),
        reset_after: :timer.minutes(5)}
    end

    update :update do
      change {AshCircuitBreaker.Change,
        limit: 10,
        per: :timer.minutes(1),
        reset_after: :timer.minutes(2)}
    end
  end
end
```

### Custom Name Functions

The name function determines how circuit breakers are identified and shared:

```elixir
# Per-user circuit breakers
name: fn changeset, context ->
  :"user_#{context.actor.id}_create"
end

# Per-tenant circuit breakers
name: fn changeset ->
  :"tenant_#{changeset.data.tenant_id}_action"
end

# Use the built-in name function (default)
name: &AshCircuitBreaker.name_for_breaker/1
```

## Circuit Breaker States

A circuit breaker can be in one of two states:

1. **OK** (normal operation): Requests flow through normally. Failures are counted until the limit is reached.
2. **Blown** (failing fast): All requests are immediately rejected with `CircuitBroken` error until the reset period expires.

## Error Handling

When a circuit is open, an `AshCircuitBreaker.CircuitBroken` exception is raised:

```elixir
case MyApp.create_post(attrs) do
  {:ok, post} ->
    # Success
    {:ok, post}

  {:error, %AshCircuitBreaker.CircuitBroken{} = error} ->
    # Circuit breaker is open
    {:error, "Service temporarily unavailable, please try again later"}

  {:error, other_error} ->
    # Handle other errors (these may trigger the circuit breaker)
    {:error, other_error}
end
```

In web applications, the exception includes `Plug.Exception` behaviour for automatic HTTP 503 responses.

## Configuration

### Parameters

- **`limit`**: Maximum number of failures allowed before opening the circuit
- **`per`**: Time window (in milliseconds) for counting failures
- **`reset_after`**: Time (in milliseconds) before attempting to close an open circuit
- **`name`**: Identifier for the circuit breaker (atom or function)

### Example Configurations

```elixir
# High-traffic endpoint with tight failure tolerance
action :api_call, limit: 3, per: :timer.seconds(10), reset_after: :timer.seconds(30)

# Background job with more lenient settings
action :process_data, limit: 20, per: :timer.minutes(5), reset_after: :timer.minutes(10)

# Critical operation with long recovery time
action :payment, limit: 1, per: :timer.seconds(5), reset_after: :timer.minutes(30)
```

## Monitoring

Circuit breaker state can be monitored using fuse's built-in functions:

```elixir
# Check circuit state
:fuse.ask(:my_circuit_name, :sync)
# Returns: :ok | :blown | {:error, :not_found}

# Reset a blown circuit manually
:fuse.reset(:my_circuit_name)

# Melt (blow) a circuit manually
:fuse.melt(:my_circuit_name)
```

## Testing

In test environments, you may want to disable circuit breakers or use test-friendly configurations:

```elixir
# Use very high limits in tests
circuit do
  action :create, limit: 999, per: :timer.hours(1), reset_after: :timer.seconds(1)
end

# Or conditionally apply circuit breakers
if Mix.env() != :test do
  circuit do
    action :create, limit: 5, per: :timer.seconds(30), reset_after: :timer.minutes(5)
  end
end
```

## Limitations

- Circuit breakers are **not supported for read/query actions** - they only work with create, update, and delete actions
- Circuit breaker state is not persisted across application restarts
- Fuse circuits are local and don't share state across nodes in a distributed system

## Reference

- [AshCircuitBreaker DSL](documentation/dsls/DSL-AshCircuitBreaker.md)
- [Fuse Documentation](https://hexdocs.pm/fuse)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
