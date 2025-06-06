defmodule HipcallSMS.Adapters.Telnyx do
  @moduledoc """
  An adapter for Telnyx SMS API.

  This adapter provides SMS delivery through Telnyx's REST API. It supports messaging
  profiles, webhooks, auto-detection, and media attachments for MMS.

  For reference: [Telnyx API docs](https://developers.telnyx.com/api/messaging/send-message)

  ## Configuration

  The Telnyx adapter requires the following configuration:

  - `:api_key` - Your Telnyx API key

  ## Configuration Examples

      # In config/config.exs
      config :hipcall_sms,
        adapter: HipcallSMS.Adapters.Telnyx,
        telnyx_api_key: {:system, "TELNYX_API_KEY"}

      # Runtime configuration override
      config = [
        adapter: HipcallSMS.Adapters.Telnyx,
        api_key: "your_api_key"
      ]

  ## Provider Options

  The Telnyx adapter supports the following provider-specific options via `provider_options`:

  - `:messaging_profile_id` - Messaging profile ID to use for sending
  - `:webhook_url` - URL for delivery status webhooks
  - `:webhook_failover_url` - Failover URL for webhooks
  - `:use_profile_webhooks` - Whether to use messaging profile webhooks (default: true)
  - `:type` - Message type, "SMS" or "MMS" (default: "SMS")
  - `:auto_detect` - Enable auto-detection of message type
  - `:media_urls` - Array of media URLs for MMS

  ## Examples

      # Basic SMS
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
      {:ok, response} = HipcallSMS.deliver(sms)

      # SMS with messaging profile
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
        |> SMS.put_provider_option(:messaging_profile_id, "profile_123")

      # SMS with webhook
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
        |> SMS.put_provider_option(:webhook_url, "https://example.com/webhook")

      # MMS with media
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Check this out!")
        |> SMS.put_provider_option(:type, "MMS")
        |> SMS.put_provider_option(:media_urls, ["https://example.com/image.jpg"])

  """

  @api_endpoint "https://api.telnyx.com/v2/messages"
  @balance_endpoint "https://api.telnyx.com/v2/balance"

  use HipcallSMS.Adapter, required_config: [:api_key]

  alias HipcallSMS.SMS

  @doc """
  Delivers an SMS through Telnyx's REST API.

  This function sends an SMS message using Telnyx's Messages API. It handles
  authentication, request formatting, and response parsing.

  ## Parameters

  - `sms` - The SMS struct containing message details
  - `config` - Configuration keyword list (optional, defaults to application config)

  ## Returns

  - `{:ok, response}` - Success with normalized response containing message ID and status
  - `{:error, reason}` - Failure with error details including HTTP status and body

  ## Response Format

  Success responses are normalized to:

      %{
        id: "msg_123",           # Telnyx message ID
        status: "queued",        # Message status
        provider: "telnyx",      # Provider identifier
        provider_response: %{}   # Full Telnyx API response
      }

  ## Examples

      # Basic delivery
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
      {:ok, response} = deliver(sms)
      # => {:ok, %{id: "msg_123", status: "queued", provider: "telnyx"}}

      # Delivery with custom config
      config = [api_key: "custom_api_key"]
      {:ok, response} = deliver(sms, config)

  """
  @impl HipcallSMS.Adapter
  @spec deliver(SMS.t(), Keyword.t()) :: {:ok, map()} | {:error, map()}
  def deliver(%SMS{} = sms, config \\ []) do
    validate_telnyx_config(config)

    headers = prepare_headers(config)
    body = prepare_body(sms, config) |> Jason.encode!()

    http_client().request(
      :post,
      @api_endpoint,
      headers,
      body,
      receive_timeout: 600_000
    )
    |> handle_response()
  end

  @doc """
  Gets the account balance from Telnyx's REST API.

  This function retrieves the current account balance using Telnyx's Balance API.
  It handles authentication and response parsing.

  ## Parameters

  - `config` - Configuration keyword list (optional, defaults to application config)

  ## Returns

  - `{:ok, balance_info}` - Success with balance information
  - `{:error, reason}` - Failure with error details including HTTP status and body

  ## Response Format

  Success responses contain normalized balance information:

      %{
        balance: "300.00",           # Current account balance
        currency: "USD",             # Currency code
        credit_limit: "100.00",      # Credit limit
        available_credit: "400.00",  # Available credit (balance + credit limit)
        pending: "10.00",            # Pending amount
        provider: "telnyx",          # Provider identifier
        provider_response: %{}       # Full Telnyx API response
      }

  ## Examples

      # Get balance with application config
      {:ok, balance} = get_balance()

      # Get balance with custom config
      config = [api_key: "custom_api_key"]
      {:ok, balance} = get_balance(config)

  """
  @impl HipcallSMS.Adapter
  @spec get_balance(Keyword.t()) :: {:ok, map()} | {:error, map()}
  def get_balance(config \\ []) do
    validate_telnyx_config(config)

    headers = prepare_headers(config)

    http_client().request(
      :get,
      @balance_endpoint,
      headers,
      "",
      receive_timeout: 600_000
    )
    |> handle_balance_response()
  end

  # Prepares HTTP headers for Telnyx API request
  @spec prepare_headers(Keyword.t()) :: [{String.t(), String.t()}]
  defp prepare_headers(config) do
    api_key = config[:api_key] || get_config_value(:telnyx_api_key, nil)

    [
      {"User-Agent", "hipcall_sms/#{HipcallSMS.version()}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]
  end

  # Prepares the request body with SMS data and provider options
  @spec prepare_body(SMS.t(), Keyword.t()) :: map()
  defp prepare_body(%SMS{provider_options: provider_options} = sms, config) do
    messaging_profile_id =
      provider_options[:messaging_profile_id] || config[:messaging_profile_id]

    webhook_url = provider_options[:webhook_url] || config[:webhook_url]

    webhook_failover_url =
      provider_options[:webhook_failover_url] || config[:webhook_failover_url]

    use_profile_webhooks =
      case provider_options[:use_profile_webhooks] do
        nil -> config[:use_profile_webhooks] || true
        value -> value
      end

    type = provider_options[:type] || "SMS"
    auto_detect = provider_options[:auto_detect] || config[:auto_detect]
    media_urls = provider_options[:media_urls] || config[:media_urls]

    body = %{
      from: sms.from,
      to: sms.to,
      text: sms.text,
      type: type,
      use_profile_webhooks: use_profile_webhooks
    }

    body
    |> maybe_add_field(:messaging_profile_id, messaging_profile_id)
    |> maybe_add_field(:webhook_url, webhook_url)
    |> maybe_add_field(:webhook_failover_url, webhook_failover_url)
    |> maybe_add_field(:auto_detect, auto_detect)
    |> maybe_add_field(:media_urls, media_urls)
  end

  # Handles HTTP response from Telnyx API
  @spec handle_response({:ok, map()} | {:error, any()}) ::
          {:ok, map()} | {:error, map()}
  defp handle_response({:ok, %{status: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, decoded_body} ->
        {:ok, normalize_response(decoded_body)}

      {:error, _} ->
        {:error, %{status: 200, body: body, error: "Invalid JSON response"}}
    end
  end

  defp handle_response({:ok, %{status: status, body: body, headers: headers}}) do
    case Jason.decode(body) do
      {:ok, decoded_body} ->
        {:error, %{status: status, body: decoded_body, headers: headers}}

      {:error, _} ->
        {:error, %{status: status, body: body, headers: headers, error: "Invalid JSON response"}}
    end
  end

  defp handle_response({:error, reason}) do
    {:error, %{error: reason, provider: "telnyx"}}
  end

  # Handles HTTP response from Telnyx Balance API
  @spec handle_balance_response({:ok, map()} | {:error, any()}) ::
          {:ok, map()} | {:error, map()}
  defp handle_balance_response({:ok, %{status: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, decoded_body} ->
        {:ok, normalize_balance_response(decoded_body)}

      {:error, _} ->
        {:error, %{status: 200, body: body, error: "Invalid JSON response"}}
    end
  end

  defp handle_balance_response({:ok, %{status: status, body: body, headers: headers}}) do
    case Jason.decode(body) do
      {:ok, decoded_body} ->
        {:error, %{status: status, body: decoded_body, headers: headers}}

      {:error, _} ->
        {:error, %{status: status, body: body, headers: headers, error: "Invalid JSON response"}}
    end
  end

  defp handle_balance_response({:error, reason}) do
    {:error, %{error: reason, provider: "telnyx"}}
  end

  # Normalizes Telnyx API response to standard format
  @spec normalize_response(map()) :: map()
  defp normalize_response(%{"data" => data}) do
    %{
      id: data["id"],
      status: data["to"] |> List.first() |> Map.get("status", "unknown"),
      provider: "telnyx",
      provider_response: data
    }
  end

  defp normalize_response(response), do: response

  # Normalizes Telnyx Balance API response to standard format
  @spec normalize_balance_response(map()) :: map()
  defp normalize_balance_response(%{"data" => data}) do
    %{
      balance: data["balance"],
      currency: data["currency"],
      credit_limit: data["credit_limit"],
      available_credit: data["available_credit"],
      pending: data["pending"],
      provider: "telnyx",
      provider_response: data
    }
  end

  defp normalize_balance_response(response), do: response

  # Helper function to conditionally add fields to the request body
  @spec maybe_add_field(map(), atom(), any()) :: map()
  defp maybe_add_field(body, _key, nil), do: body
  defp maybe_add_field(body, key, value), do: Map.put(body, key, value)

  # Returns the configured HTTP client module
  defp http_client do
    Application.get_env(:hipcall_sms, :http_client, HipcallSMS.HTTPClient.FinchClient)
  end

  # Validates Telnyx-specific configuration
  defp validate_telnyx_config(config) do
    api_key = config[:api_key] || get_config_value(:telnyx_api_key, nil)

    if api_key in [nil, ""] do
      raise ArgumentError, "api_key is required for Telnyx adapter"
    end

    :ok
  end
end
