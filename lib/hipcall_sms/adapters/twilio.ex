defmodule HipcallSMS.Adapters.Twilio do
  @moduledoc """
  An adapter for Twilio SMS API.

  This adapter provides SMS delivery through Twilio's REST API. It supports all major
  Twilio SMS features including messaging services, status callbacks, scheduling,
  and media attachments.

  For reference: [Twilio API docs](https://www.twilio.com/docs/sms/api/message-resource#create-a-message-resource)

  ## Configuration

  The Twilio adapter requires the following configuration:

  - `:account_sid` - Your Twilio Account SID
  - `:auth_token` - Your Twilio Auth Token

  ## Configuration Examples

      # In config/config.exs
      config :hipcall_sms,
        adapter: HipcallSMS.Adapters.Twilio,
        twilio_account_sid: {:system, "TWILIO_ACCOUNT_SID"},
        twilio_auth_token: {:system, "TWILIO_AUTH_TOKEN"}

      # Runtime configuration override
      config = [
        adapter: HipcallSMS.Adapters.Twilio,
        account_sid: "ACxxxxx",
        auth_token: "your_auth_token"
      ]

  ## Provider Options

  The Twilio adapter supports the following provider-specific options via `provider_options`:

  - `:messaging_service_sid` - Use a Twilio Messaging Service
  - `:status_callback` - URL for delivery status webhooks
  - `:media_url` - URL for MMS media attachments
  - `:max_price` - Maximum price per message
  - `:validity_period` - Message validity period in seconds
  - `:send_at` - Schedule message for future delivery
  - `:smart_encoded` - Enable smart encoding
  - `:shorten_urls` - Enable URL shortening

  ## Examples

      # Basic SMS
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
      {:ok, response} = HipcallSMS.deliver(sms)

      # SMS with messaging service
      sms =
        SMS.new(to: "+15555555555", text: "Hello!")
        |> SMS.put_provider_option(:messaging_service_sid, "MGxxxxx")

      # SMS with status callback
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
        |> SMS.put_provider_option(:status_callback, "https://example.com/webhook")

      # Scheduled SMS
      send_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Reminder!")
        |> SMS.put_provider_option(:send_at, send_at)

  """

  @api_endpoint "https://api.twilio.com/2010-04-01/Accounts"

  use HipcallSMS.Adapter, required_config: [:account_sid, :auth_token]

  alias HipcallSMS.SMS

  @doc """
  Delivers an SMS through Twilio's REST API.

  This function sends an SMS message using Twilio's Messages API. It handles
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
        id: "SMxxxxx",           # Twilio message SID
        status: "queued",        # Message status
        provider: "twilio",      # Provider identifier
        provider_response: %{}   # Full Twilio API response
      }

  ## Examples

      # Basic delivery
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
      {:ok, response} = deliver(sms)
      # => {:ok, %{id: "SMxxxxx", status: "queued", provider: "twilio"}}

      # Delivery with custom config
      config = [account_sid: "ACxxxxx", auth_token: "custom_token"]
      {:ok, response} = deliver(sms, config)

  """
  @impl HipcallSMS.Adapter
  @spec deliver(SMS.t(), Keyword.t()) :: {:ok, map()} | {:error, map()}
  def deliver(%SMS{} = sms, config \\ []) do
    validate_twilio_config(config)

    account_sid = config[:account_sid] || get_config_value(:twilio_account_sid, nil)
    headers = prepare_headers(config)
    body = prepare_body(sms, config)

    url = "#{@api_endpoint}/#{account_sid}/Messages.json"

    http_client().request(
      :post,
      url,
      headers,
      body,
      receive_timeout: 600_000
    )
    |> handle_response()
  end

  @doc """
  Gets the account balance from Twilio.

  Note: Twilio does not provide a simple balance endpoint like other providers.
  This function returns an error indicating that balance checking is not supported
  for Twilio through this adapter.

  For Twilio balance information, you would need to use their Account API
  or check your Twilio Console.

  ## Parameters

  - `config` - Configuration keyword list (ignored)

  ## Returns

  - `{:error, reason}` - Always returns an error as this feature is not supported

  """
  @impl HipcallSMS.Adapter
  @spec get_balance(Keyword.t()) :: {:error, map()}
  def get_balance(_config \\ []) do
    {:error,
     %{
       error: "Balance checking not supported",
       message:
         "Twilio does not provide a simple balance endpoint. Please check your Twilio Console for account balance information.",
       provider: "twilio"
     }}
  end

  # Prepares HTTP headers for Twilio API request
  @spec prepare_headers(Keyword.t()) :: [{String.t(), String.t()}]
  defp prepare_headers(config) do
    account_sid = config[:account_sid] || get_config_value(:twilio_account_sid, nil)
    auth_token = config[:auth_token] || get_config_value(:twilio_auth_token, nil)

    credentials = Base.encode64("#{account_sid}:#{auth_token}")

    [
      {"User-Agent", "hipcall_sms/#{HipcallSMS.version()}"},
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Accept", "application/json"},
      {"Authorization", "Basic #{credentials}"}
    ]
  end

  # Prepares the request body with SMS data and provider options
  @spec prepare_body(SMS.t(), Keyword.t()) :: String.t()
  defp prepare_body(%SMS{provider_options: provider_options} = sms, config) do
    messaging_service_sid =
      provider_options[:messaging_service_sid] || config[:messaging_service_sid]

    status_callback = provider_options[:status_callback] || config[:status_callback]
    application_sid = provider_options[:application_sid] || config[:application_sid]
    max_price = provider_options[:max_price] || config[:max_price]
    provide_feedback = provider_options[:provide_feedback] || config[:provide_feedback]
    attempt = provider_options[:attempt] || config[:attempt]
    validity_period = provider_options[:validity_period] || config[:validity_period]
    force_delivery = provider_options[:force_delivery] || config[:force_delivery]
    content_retention = provider_options[:content_retention] || config[:content_retention]
    address_retention = provider_options[:address_retention] || config[:address_retention]
    smart_encoded = provider_options[:smart_encoded] || config[:smart_encoded]
    persistent_action = provider_options[:persistent_action] || config[:persistent_action]
    shorten_urls = provider_options[:shorten_urls] || config[:shorten_urls]
    schedule_type = provider_options[:schedule_type] || config[:schedule_type]
    send_at = provider_options[:send_at] || config[:send_at]
    send_as_mms = provider_options[:send_as_mms] || config[:send_as_mms]
    content_variables = provider_options[:content_variables] || config[:content_variables]
    risk_check = provider_options[:risk_check] || config[:risk_check]
    media_url = provider_options[:media_url] || config[:media_url]

    params = [
      {"To", sms.to},
      {"Body", sms.text}
    ]

    params
    |> maybe_add_param("From", sms.from)
    |> maybe_add_param("MessagingServiceSid", messaging_service_sid)
    |> maybe_add_param("StatusCallback", status_callback)
    |> maybe_add_param("ApplicationSid", application_sid)
    |> maybe_add_param("MaxPrice", max_price)
    |> maybe_add_param("ProvideFeedback", provide_feedback)
    |> maybe_add_param("Attempt", attempt)
    |> maybe_add_param("ValidityPeriod", validity_period)
    |> maybe_add_param("ForceDelivery", force_delivery)
    |> maybe_add_param("ContentRetention", content_retention)
    |> maybe_add_param("AddressRetention", address_retention)
    |> maybe_add_param("SmartEncoded", smart_encoded)
    |> maybe_add_param("PersistentAction", persistent_action)
    |> maybe_add_param("ShortenUrls", shorten_urls)
    |> maybe_add_param("ScheduleType", schedule_type)
    |> maybe_add_param("SendAt", send_at)
    |> maybe_add_param("SendAsMms", send_as_mms)
    |> maybe_add_param("ContentVariables", content_variables)
    |> maybe_add_param("RiskCheck", risk_check)
    |> maybe_add_param("MediaUrl", media_url)
    |> URI.encode_query()
  end

  # Handles HTTP response from Twilio API
  @spec handle_response({:ok, map()} | {:error, any()}) ::
          {:ok, map()} | {:error, map()}
  defp handle_response({:ok, %{status: status, body: body, headers: headers}})
       when status in 200..299 do
    case Jason.decode(body) do
      {:ok, decoded_body} ->
        {:ok, normalize_response(decoded_body)}

      {:error, _} ->
        {:error, %{status: status, body: body, headers: headers, error: "Invalid JSON response"}}
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
    {:error, %{error: reason, provider: "twilio"}}
  end

  # Normalizes Twilio API response to standard format
  @spec normalize_response(map()) :: map()
  defp normalize_response(response) do
    %{
      id: response["sid"],
      status: response["status"],
      provider: "twilio",
      provider_response: response
    }
  end

  # Helper function to conditionally add parameters to the request
  @spec maybe_add_param([{String.t(), String.t()}], String.t(), any()) :: [
          {String.t(), String.t()}
        ]
  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: [{key, to_string(value)} | params]

  # Returns the configured HTTP client module
  defp http_client do
    Application.get_env(:hipcall_sms, :http_client, HipcallSMS.HTTPClient.FinchClient)
  end

  # Validates Twilio-specific configuration
  defp validate_twilio_config(config) do
    account_sid = config[:account_sid] || get_config_value(:twilio_account_sid, nil)
    auth_token = config[:auth_token] || get_config_value(:twilio_auth_token, nil)

    if account_sid in [nil, ""] do
      raise "account_sid is required for Twilio adapter"
    end

    if auth_token in [nil, ""] do
      raise "auth_token is required for Twilio adapter"
    end

    :ok
  end
end
