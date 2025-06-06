defmodule HipcallSMS.Adapter do
  @moduledoc """
  Specification of the SMS delivery adapter.

  This module defines the behavior that all SMS adapters must implement and provides
  utility functions for configuration validation and dependency checking.

  ## Creating an Adapter

  To create a new SMS adapter, you need to implement the `HipcallSMS.Adapter` behavior
  and use the `__using__/1` macro to get default implementations of common functions.

  ## Example

      defmodule MyApp.Adapters.CustomProvider do
        use HipcallSMS.Adapter, required_config: [:api_key, :secret]

        @impl HipcallSMS.Adapter
        def deliver(%HipcallSMS.SMS{} = sms, config) do
          # Implementation for sending SMS through your provider
          {:ok, %{id: "msg_123", status: "sent"}}
        end
      end

  ## Configuration

  Adapters can specify required configuration keys that must be present when
  delivering an SMS. The `validate_config/1` callback will automatically check
  for these keys.

  ## Dependencies

  Adapters can also specify required dependencies that must be available at runtime.
  This is useful for HTTP clients or other external libraries.

  """

  @doc """
  Macro for implementing SMS adapters.

  This macro provides default implementations for common adapter functions and
  sets up the required configuration and dependencies.

  ## Options

  - `:required_config` - List of atoms representing required configuration keys
  - `:required_deps` - List of modules or `{library, module}` tuples for required dependencies

  ## Examples

      # Basic adapter with API key requirement
      use HipcallSMS.Adapter, required_config: [:api_key]

      # Adapter with multiple config requirements
      use HipcallSMS.Adapter, required_config: [:account_sid, :auth_token]

      # Adapter with dependencies
      use HipcallSMS.Adapter,
        required_config: [:api_key],
        required_deps: [Finch, Jason]

  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @required_config opts[:required_config] || []
      @required_deps opts[:required_deps] || []

      @behaviour HipcallSMS.Adapter

      def validate_config(config) do
        HipcallSMS.Adapter.validate_config(@required_config, config)
      end

      def validate_dependency do
        HipcallSMS.Adapter.validate_dependency(@required_deps)
      end

      def get_config_value(key, default) do
        HipcallSMS.Adapter.get_config_value(key, default)
      end
    end
  end

  @type t :: module
  @type sms :: HipcallSMS.SMS.t()
  @type config :: Keyword.t()
  @type delivery_result :: {:ok, map()} | {:error, map()}

  @doc """
  Delivers a SMS with the given config.

  This callback must be implemented by all adapters to handle the actual SMS delivery
  through the provider's API.

  ## Parameters

  - `sms` - The SMS struct containing message details
  - `config` - Configuration keyword list with provider-specific settings

  ## Returns

  - `{:ok, response}` - Success with provider response map
  - `{:error, reason}` - Failure with error details

  ## Configuration Override

  Client library configuration can be overwritten at runtime by passing
  a configuration map as the last argument. This is useful for multi-tenant
  applications or when you need to use different credentials per request.

  ## Examples

      # Basic delivery with application config
      {:ok, response} = MyAdapter.deliver(sms, [])

      # Delivery with runtime config override
      config_override = [
        adapter: HipcallSMS.Adapters.Twilio,
        account_sid: "ACxxxxx",
        auth_token: "runtime_token"
      ]
      {:ok, response} = MyAdapter.deliver(sms, config_override)

  """
  @callback deliver(sms(), config()) :: delivery_result()

  @doc """
  Validates the adapter configuration.

  This callback validates that all required configuration keys are present
  and have valid values.

  ## Parameters

  - `config` - Configuration keyword list to validate

  ## Returns

  - `:ok` - Configuration is valid
  - Raises `ArgumentError` - If required configuration is missing

  """
  @callback validate_config(config()) :: :ok | no_return

  @doc """
  Validates that required dependencies are available.

  This callback checks that all required dependencies are loaded and available
  at runtime.

  ## Returns

  - `:ok` - All dependencies are available
  - `{:error, missing_deps}` - List of missing dependencies

  """
  @callback validate_dependency() :: :ok | {:error, [module | {atom, module}]}

  @doc """
  Gets a configuration value with a default fallback.

  This callback retrieves configuration values from the application environment,
  with support for system environment variables and default values.

  ## Parameters

  - `key` - The configuration key to retrieve
  - `default` - Default value if the key is not found

  ## Returns

  The configuration value or the default if not found.

  """
  @callback get_config_value(atom(), any()) :: any()

  @doc """
  Validates that all required configuration keys are present.

  This function checks that all keys in the `required_config` list are present
  in the provided configuration and have non-nil, non-empty values.

  ## Parameters

  - `required_config` - List of required configuration keys (atoms)
  - `config` - Configuration keyword list to validate

  ## Returns

  - `:ok` - All required configuration is present
  - Raises `ArgumentError` - If any required configuration is missing

  ## Examples

      # Valid configuration
      iex> HipcallSMS.Adapter.validate_config([:api_key], [api_key: "secret123"])
      :ok

      # Missing required key
      iex> HipcallSMS.Adapter.validate_config([:api_key, :secret], [api_key: "secret123"])
      ** (ArgumentError) Missing required configuration: [:secret], got: [api_key: "secret123"]

      # Empty value treated as missing
      iex> HipcallSMS.Adapter.validate_config([:api_key], [api_key: ""])
      ** (ArgumentError) Missing required configuration: [:api_key], got: [api_key: ""]

  """
  @spec validate_config([atom], Keyword.t()) :: :ok | no_return
  def validate_config(required_config, config) do
    missing_keys =
      Enum.reduce(required_config, [], fn key, missing_keys ->
        if config[key] in [nil, ""],
          do: [key | missing_keys],
          else: missing_keys
      end)

    raise_on_missing_config(missing_keys, config)
  end

  defp raise_on_missing_config([], _config), do: :ok

  defp raise_on_missing_config(key, config) do
    raise ArgumentError,
          "Missing required configuration: #{inspect(key)}, got: #{inspect(config)}"
  end

  @doc """
  Validates that all required dependencies are available.

  This function checks that all modules in the `required_deps` list are loaded
  and available at runtime. Dependencies can be specified as module names or
  as `{library_name, module}` tuples.

  ## Parameters

  - `required_deps` - List of required dependencies

  ## Returns

  - `:ok` - All dependencies are available
  - `{:error, missing_deps}` - List of missing dependencies

  ## Examples

      # All dependencies available
      iex> HipcallSMS.Adapter.validate_dependency([Jason, Finch])
      :ok

      # Missing dependency
      iex> HipcallSMS.Adapter.validate_dependency([NonExistentModule])
      {:error, [NonExistentModule]}

      # Mixed dependency specification
      iex> HipcallSMS.Adapter.validate_dependency([Jason, {:finch, Finch}])
      :ok

  """
  @spec validate_dependency([module | {atom, module}]) ::
          :ok | {:error, [module | {atom, module}]}
  def validate_dependency(required_deps) do
    missing_deps =
      Enum.reject(required_deps, fn
        {_lib, module} -> Code.ensure_loaded?(module)
        module -> Code.ensure_loaded?(module)
      end)

    case missing_deps do
      [] -> :ok
      deps -> {:error, deps}
    end
  end

  @doc """
  Gets a configuration value from the application environment.

  This function retrieves configuration values with support for system environment
  variables and default fallbacks. It supports several configuration formats:

  - Direct values: `"api_key_value"`
  - System environment variables: `{:system, "ENV_VAR_NAME"}`
  - System environment integers: `{:system, :integer, "ENV_VAR_NAME"}`

  ## Parameters

  - `key` - The configuration key to retrieve
  - `default` - Default value if the key is not found or is nil

  ## Returns

  The configuration value or the default if not found.

  ## Examples

      # Direct configuration value
      # config :hipcall_sms, api_key: "secret123"
      iex> HipcallSMS.Adapter.get_config_value(:api_key, nil)
      "secret123"

      # System environment variable
      # config :hipcall_sms, api_key: {:system, "SMS_API_KEY"}
      # Environment: SMS_API_KEY=secret123
      iex> HipcallSMS.Adapter.get_config_value(:api_key, nil)
      "secret123"

      # System environment integer
      # config :hipcall_sms, timeout: {:system, :integer, "SMS_TIMEOUT"}
      # Environment: SMS_TIMEOUT=5000
      iex> HipcallSMS.Adapter.get_config_value(:timeout, 3000)
      5000

      # Default value when not configured
      iex> HipcallSMS.Adapter.get_config_value(:missing_key, "default_value")
      "default_value"

      # Nil value returns default
      # config :hipcall_sms, some_key: nil
      iex> HipcallSMS.Adapter.get_config_value(:some_key, "default")
      "default"

  """
  @spec get_config_value(atom(), any()) :: any()
  def get_config_value(key, default) do
    value =
      :hipcall_sms
      |> Application.get_env(key)
      |> parse_config_value()

    if is_nil(value), do: default, else: value
  end

  defp parse_config_value({:system, env_name}), do: System.get_env(env_name)

  defp parse_config_value({:system, :integer, env_name}) do
    case System.get_env(env_name) do
      nil -> nil
      value -> String.to_integer(value)
    end
  end

  defp parse_config_value(value), do: value
end
