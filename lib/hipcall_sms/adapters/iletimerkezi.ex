defmodule HipcallSMS.Adapters.Iletimerkezi do
  @moduledoc """
  An adapter for Iletimerkezi SMS API.

  This adapter provides SMS delivery through Iletimerkezi's REST API, which is a
  popular SMS service provider in Turkey. It supports scheduled messaging and
  IYS (İzinli Yollama Sistemi) compliance for Turkish regulations.

  For reference: [Iletimerkezi API docs](https://www.toplusmsapi.com/sms/gonder/json)

  ## Configuration

  The Iletimerkezi adapter requires the following configuration:

  - `:key` - Your Iletimerkezi API key
  - `:hash` - Your Iletimerkezi API hash

  ## Configuration Examples

      # In config/config.exs
      config :hipcall_sms,
        adapter: HipcallSMS.Adapters.Iletimerkezi,
        iletimerkezi_key: {:system, "ILETIMERKEZI_KEY"},
        iletimerkezi_hash: {:system, "ILETIMERKEZI_HASH"}

      # Runtime configuration override
      config = [
        adapter: HipcallSMS.Adapters.Iletimerkezi,
        key: "your_api_key",
        hash: "your_api_hash"
      ]

  ## Provider Options

  The Iletimerkezi adapter supports the following provider-specific options via `provider_options`:

  - `:send_date_time` - Schedule message for future delivery (array format)
  - `:iys` - IYS compliance setting (default: "1")
  - `:iys_list` - IYS list type (default: "BIREYSEL")

  ## Examples

      # Basic SMS
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Merhaba!")
      {:ok, response} = HipcallSMS.deliver(sms)

      # Scheduled SMS
      sms =
        SMS.new(from: "SENDER", to: "+905551234567", text: "Hatırlatma!")
        |> SMS.put_provider_option(:send_date_time, ["2024", "12", "25", "10", "30"])

      # SMS with custom IYS settings
      sms =
        SMS.new(from: "SENDER", to: "+905551234567", text: "Bilgilendirme")
        |> SMS.put_provider_option(:iys, "1")
        |> SMS.put_provider_option(:iys_list, "TACIR")

  """

  @api_endpoint "https://api.iletimerkezi.com/v1/send-sms/json"
  @balance_endpoint "https://api.iletimerkezi.com/v1/get-balance/json"

  # @provider_options_body_fields [
  #   :iys,
  #   :iys_list,
  #   :send_date_time
  # ]

  @default_iys_list "BIREYSEL"
  @default_iys "1"

  use HipcallSMS.Adapter, required_config: [:key, :hash]

  alias HipcallSMS.SMS

  @doc """
  Delivers an SMS through Iletimerkezi's REST API.

  This function sends an SMS message using Iletimerkezi's JSON API. It handles
  authentication, request formatting, and response parsing with IYS compliance.

  ## Parameters

  - `sms` - The SMS struct containing message details
  - `config` - Configuration keyword list (optional, defaults to application config)

  ## Returns

  - `{:ok, response}` - Success with Iletimerkezi API response
  - `{:error, reason}` - Failure with error details including HTTP status and body

  ## Response Format

  Success responses contain the raw Iletimerkezi API response:

      {:ok, %{
        "response" => %{
          "status" => %{
            "code" => "200",
            "message" => "OK"
          },
          "order" => %{
            "id" => "order_id"
          }
        }
      }}

  ## Examples

      # Basic delivery
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Merhaba!")
      {:ok, response} = deliver(sms)

      # Delivery with custom config
      config = [key: "custom_key", hash: "custom_hash"]
      {:ok, response} = deliver(sms, config)

  """
  @impl HipcallSMS.Adapter
  @spec deliver(SMS.t(), Keyword.t()) :: {:ok, map()} | {:error, map()}
  def deliver(%SMS{} = sms, config \\ []) do
    validate_iletimerkezi_config(config)

    headers = prepare_headers()
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
  Gets the account balance from Iletimerkezi's REST API.

  This function retrieves the current account balance using Iletimerkezi's Balance API.
  It handles authentication and response parsing.

  ## Parameters

  - `config` - Configuration keyword list (optional, defaults to application config)

  ## Returns

  - `{:ok, balance_info}` - Success with balance information
  - `{:error, reason}` - Failure with error details including HTTP status and body

  ## Response Format

  Success responses contain normalized balance information:

      %{
        balance: "300.00",           # Current account balance (TL)
        sms_balance: "18343",        # SMS credit balance
        currency: "TRY",             # Currency (Turkish Lira)
        provider: "iletimerkezi",    # Provider identifier
        provider_response: %{}       # Full Iletimerkezi API response
      }

  ## Examples

      # Get balance with application config
      {:ok, balance} = get_balance()

      # Get balance with custom config
      config = [key: "custom_key", hash: "custom_hash"]
      {:ok, balance} = get_balance(config)

  """
  @impl HipcallSMS.Adapter
  @spec get_balance(Keyword.t()) :: {:ok, map()} | {:error, map()}
  def get_balance(config \\ []) do
    validate_iletimerkezi_config(config)

    headers = prepare_headers()
    body = prepare_balance_body(config) |> Jason.encode!()

    http_client().request(
      :post,
      @balance_endpoint,
      headers,
      body,
      receive_timeout: 600_000
    )
    |> handle_balance_response()
  end

  # Prepares HTTP headers for Iletimerkezi API request
  @spec prepare_headers() :: [{String.t(), String.t()}]
  defp prepare_headers() do
    [
      {"User-Agent", "hipcall_sms/#{HipcallSMS.version()}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  # Prepares the request body with SMS data and provider options
  @spec prepare_body(SMS.t(), Keyword.t()) :: map()
  defp prepare_body(%SMS{provider_options: provider_options} = sms, config) do
    send_date_time = provider_options[:send_date_time] || []
    iys = provider_options[:iys] || @default_iys
    iys_list = provider_options[:iys_list] || @default_iys_list

    key = config[:key] || get_config_value(:iletimerkezi_key, nil)
    hash = config[:hash] || get_config_value(:iletimerkezi_hash, nil)

    %{
      request: %{
        authentication: %{
          key: key,
          hash: hash
        },
        order: %{
          sender: sms.from,
          sendDateTime: send_date_time,
          iys: iys,
          iysList: iys_list,
          message: %{
            text: sms.text,
            receipents: %{
              number: [sms.to]
            }
          }
        }
      }
    }
  end

  # Prepares the request body for balance API call
  @spec prepare_balance_body(Keyword.t()) :: map()
  defp prepare_balance_body(config) do
    key = config[:key] || get_config_value(:iletimerkezi_key, nil)
    hash = config[:hash] || get_config_value(:iletimerkezi_hash, nil)

    %{
      request: %{
        authentication: %{
          key: key,
          hash: hash
        }
      }
    }
  end

  # Handles HTTP response from Iletimerkezi API
  @spec handle_response({:ok, map()} | {:error, any()}) :: {:ok, map()} | {:error, map()}
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
    {:error, %{error: reason, provider: "iletimerkezi"}}
  end

  # Handles HTTP response from Iletimerkezi Balance API
  @spec handle_balance_response({:ok, map()} | {:error, any()}) :: {:ok, map()} | {:error, map()}
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
    {:error, %{error: reason, provider: "iletimerkezi"}}
  end

  # Normalizes Iletimerkezi API response to standard format
  @spec normalize_response(map()) :: map()
  defp normalize_response(response) do
    %{
      id: get_in(response, ["response", "order", "id"]),
      status: get_response_status(response),
      provider: "iletimerkezi",
      provider_response: response
    }
  end

  # Extracts status from Iletimerkezi response
  defp get_response_status(response) do
    case get_in(response, ["response", "status", "code"]) do
      "200" -> "queued"
      _ -> "failed"
    end
  end

  # Normalizes Iletimerkezi Balance API response to standard format
  @spec normalize_balance_response(map()) :: map()
  defp normalize_balance_response(response) do
    balance_data = get_in(response, ["response", "balance"])

    %{
      balance: balance_data["amount"],
      sms_balance: balance_data["sms"],
      currency: "TRY",
      provider: "iletimerkezi",
      provider_response: response
    }
  end

  # Returns the configured HTTP client module
  defp http_client do
    Application.get_env(:hipcall_sms, :http_client, HipcallSMS.HTTPClient.FinchClient)
  end

  # Validates Iletimerkezi-specific configuration
  defp validate_iletimerkezi_config(config) do
    key = config[:key] || get_config_value(:iletimerkezi_key, nil)
    hash = config[:hash] || get_config_value(:iletimerkezi_hash, nil)

    if key in [nil, ""] do
      raise "key is required for Iletimerkezi adapter"
    end

    if hash in [nil, ""] do
      raise "hash is required for Iletimerkezi adapter"
    end

    :ok
  end
end
