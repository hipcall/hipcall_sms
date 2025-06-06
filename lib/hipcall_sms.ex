defmodule HipcallSMS do
  @moduledoc """
  HipcallSMS is a unified SMS library for sending SMS messages through multiple providers.

  Supported providers:
  - Telnyx
  - Twilio
  - Iletimerkezi

  ## Configuration

  You can configure providers in your `config.exs`:

      config :hipcall_sms,
        adapter: HipcallSMS.Adapters.Telnyx,
        telnyx_api_key: {:system, "TELNYX_API_KEY"},
        twilio_account_sid: {:system, "TWILIO_ACCOUNT_SID"},
        twilio_auth_token: {:system, "TWILIO_AUTH_TOKEN"},
        iletimerkezi_key: {:system, "ILETIMERKEZI_KEY"},
        iletimerkezi_hash: {:system, "ILETIMERKEZI_HASH"}

  ## Usage

      # Create and send an SMS
      sms =
        HipcallSMS.SMS.new()
        |> HipcallSMS.SMS.from("+15551234567")
        |> HipcallSMS.SMS.to("+15555555555")
        |> HipcallSMS.SMS.text("Hello from HipcallSMS!")

      HipcallSMS.deliver(sms)

      # Or with configuration override
      config = [
        adapter: HipcallSMS.Adapters.Twilio,
        account_sid: "your_account_sid",
        auth_token: "your_auth_token"
      ]

      HipcallSMS.deliver(sms, config)

      # Quick send
      HipcallSMS.send_sms("+15551234567", "+15555555555", "Hello!")
  """

  alias HipcallSMS.{SMS, Adapter}

  @version Mix.Project.config()[:version]

  @type config :: Keyword.t()
  @type delivery_result :: {:ok, map()} | {:error, map()}

  @doc """
  Returns the current version of HipcallSMS.

  ## Examples

      iex> HipcallSMS.version()
      "0.2.0"

  """
  @spec version() :: String.t()
  def version, do: @version

  @doc """
  Delivers an SMS using the configured adapter.

  This function takes an SMS struct and optional configuration to send the message
  through the specified provider. If no configuration is provided, it uses the
  application configuration.

  ## Parameters

  - `sms` - A `HipcallSMS.SMS` struct containing the message details
  - `config` - Optional keyword list to override adapter configuration

  ## Returns

  - `{:ok, response}` - Success with provider response containing message ID and status
  - `{:error, reason}` - Failure with error details

  ## Examples

      # Basic usage with application config
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
      {:ok, response} = HipcallSMS.deliver(sms)
      # => {:ok, %{id: "msg_123", status: "queued", provider: "twilio"}}

      # With configuration override for Twilio
      config = [
        adapter: HipcallSMS.Adapters.Twilio,
        account_sid: "ACxxxxx",
        auth_token: "your_auth_token"
      ]
      {:ok, response} = HipcallSMS.deliver(sms, config)

      # With configuration override for Telnyx
      config = [
        adapter: HipcallSMS.Adapters.Telnyx,
        api_key: "your_api_key"
      ]
      {:ok, response} = HipcallSMS.deliver(sms, config)

      # With configuration override for Iletimerkezi
      config = [
        adapter: HipcallSMS.Adapters.Iletimerkezi,
        key: "your_key",
        hash: "your_hash"
      ]
      {:ok, response} = HipcallSMS.deliver(sms, config)

  ## Error Handling

      case HipcallSMS.deliver(sms) do
        {:ok, response} ->
          IO.puts("Message sent with ID: " <> response.id)
        {:error, %{status: 401}} ->
          IO.puts("Authentication failed")
        {:error, %{status: 400, body: body}} ->
          IO.puts("Bad request: " <> inspect(body))
        {:error, reason} ->
          IO.puts("Failed to send: " <> inspect(reason))
      end

  """
  @spec deliver(SMS.t(), config()) :: delivery_result()
  def deliver(%SMS{} = sms, config \\ []) do
    adapter = config[:adapter] || get_adapter()
    merged_config = merge_config(adapter, config)

    adapter.validate_config(merged_config)
    adapter.deliver(sms, merged_config)
  end

  @doc """
  Quick function to send an SMS without creating an SMS struct first.

  This is a convenience function that creates an SMS struct internally and
  delivers it using the specified or configured adapter.

  ## Parameters

  - `from` - The sender phone number (E.164 format recommended)
  - `to` - The recipient phone number (E.164 format recommended)
  - `text` - The message content
  - `config` - Optional keyword list to override adapter configuration

  ## Returns

  - `{:ok, response}` - Success with provider response
  - `{:error, reason}` - Failure with error details

  ## Examples

      # Basic usage
      {:ok, response} = HipcallSMS.send_sms("+15551234567", "+15555555555", "Hello!")

      # With Twilio configuration override
      config = [
        adapter: HipcallSMS.Adapters.Twilio,
        account_sid: "ACxxxxx",
        auth_token: "your_auth_token"
      ]
      {:ok, response} = HipcallSMS.send_sms("+15551234567", "+15555555555", "Hello!", config)

      # Sending a longer message
      message = "This is a longer SMS message that demonstrates sending multi-part messages through HipcallSMS."
      {:ok, response} = HipcallSMS.send_sms("+15551234567", "+15555555555", message)

      # International numbers
      {:ok, response} = HipcallSMS.send_sms("+442071234567", "+33123456789", "Hello from UK to France!")

  ## Error Handling

      case HipcallSMS.send_sms("+15551234567", "+15555555555", "Hello!") do
        {:ok, response} ->
          IO.puts("SMS sent successfully")
        {:error, reason} ->
          IO.puts("Failed to send SMS")
      end

  """
  @spec send_sms(String.t(), String.t(), String.t(), config()) :: delivery_result()
  def send_sms(from, to, text, config \\ []) do
    sms =
      SMS.new()
      |> SMS.from(from)
      |> SMS.to(to)
      |> SMS.text(text)

    deliver(sms, config)
  end

  defp get_adapter do
    Application.get_env(:hipcall_sms, :adapter) ||
      raise ArgumentError, "No adapter configured. Please set :adapter in your config."
  end

  defp merge_config(adapter, override_config) do
    base_config = get_base_config(adapter)
    Keyword.merge(base_config, override_config)
  end

  defp get_base_config(HipcallSMS.Adapters.Telnyx) do
    [
      api_key: Adapter.get_config_value(:telnyx_api_key, nil)
    ]
  end

  defp get_base_config(HipcallSMS.Adapters.Twilio) do
    [
      account_sid: Adapter.get_config_value(:twilio_account_sid, nil),
      auth_token: Adapter.get_config_value(:twilio_auth_token, nil)
    ]
  end

  defp get_base_config(HipcallSMS.Adapters.Iletimerkezi) do
    [
      key: Adapter.get_config_value(:iletimerkezi_key, nil),
      hash: Adapter.get_config_value(:iletimerkezi_hash, nil)
    ]
  end

  defp get_base_config(_adapter), do: []
end
