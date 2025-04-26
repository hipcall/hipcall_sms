defmodule HipcallSMS.Adapter do
  @moduledoc """
  Specification of the SMS delivery adapter.
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

  @doc """
  Delivers a SMS with the given config.

  Client library configuration can be overwritten in runtime by passing
  a %{} map as last argument of the function you need to use. For
  instance if you need to use a different api_key you can simply do:

  config_override = %{
    adapter: HipcallSMS.Adapters.Iletimerkezi,
    key: "mTRwVrbZ4aoHTyjMepleT3BlbkFJ7zZYazuN7F16XuY3WErl",
    hash: "awesome-company"
  }
  # pass the overriden configuration as last argument of the function
  HipcallSMS.deliver(sms, config_override)
  """
  @callback deliver(sms(), config()) :: {:ok, term} | {:error, term}

  @callback validate_config(config()) :: :ok | no_return
  @callback validate_dependency() :: :ok | [module | {atom, module}]
  @callback get_config_value(atom(), any()) :: any()

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
    raise ArgumentError, """
    expected #{inspect(key)} to be set, got: #{inspect(config)}
    """
  end

  @spec validate_dependency([module | {atom, module}]) ::
          :ok | {:error, [module | {:atom | module}]}
  def validate_dependency(required_deps) do
    if Enum.all?(required_deps, fn
         {_lib, module} -> Code.ensure_loaded?(module)
         module -> Code.ensure_loaded?(module)
       end),
       do: :ok,
       else: {:error, required_deps}
  end

  @spec get_config_value(atom(), any()) :: any()
  def get_config_value(key, default) do
    value =
      :hipcall_sms
      |> Application.get_env(key)
      |> parse_config_value()

    if is_nil(value), do: default, else: value
  end

  defp parse_config_value({:system, env_name}), do: fetch_env!(env_name)

  defp parse_config_value({:system, :integer, env_name}) do
    env_name
    |> fetch_env!()
    |> String.to_integer()
  end

  defp parse_config_value(value), do: value

  defp fetch_env!(env_name) do
    case System.get_env(env_name) do
      nil ->
        raise ArgumentError,
          message: "could not fetch environment variable \"#{env_name}\" because it is not set"

      value ->
        value
    end
  end
end
