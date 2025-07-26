defmodule Example do
  @moduledoc false
  use Ash.Domain, otp_app: :ash_circuit_breaker

  resources do
    resource __MODULE__.SampleResource
  end
end
