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
    headers = prepare_headers()
    body = prepare_body(sms, config) |> Jason.encode!()

    Finch.build(
      :post,
      @api_endpoint,
      headers,
      body
    )
    |> Finch.request(HipcallSMSFinch, receive_timeout: 600_000)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, body |> Jason.decode!()}

      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        {:error, %{status: status, body: body |> Jason.decode!(), headers: headers}}

      {:error, reason} ->
        {:error, reason}
    end
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

    %{
      request: %{
        authentication: %{
          key: config[:key],
          hash: config[:hash]
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
end
