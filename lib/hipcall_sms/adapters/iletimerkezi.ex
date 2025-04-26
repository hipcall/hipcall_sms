defmodule HipcallSMS.Adapters.Iletimerkezi do
  @moduledoc """
  An adapter for Iletimerkezi.

  For reference: [Iletimerkezi API docs](https://www.toplusmsapi.com/sms/gonder/json)
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

  @impl HipcallSMS.Adapter
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

  defp prepare_headers() do
    [
      {"User-Agent", "hipcall_sms/#{HipcallSMS.version()}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

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
