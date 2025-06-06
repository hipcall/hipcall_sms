defmodule HipcallSMS.HTTPClient.FinchClient do
  @moduledoc """
  Finch-based implementation of the HTTPClient behavior.

  This module provides the production HTTP client implementation using Finch.
  """

  @behaviour HipcallSMS.HTTPClient

  @impl HipcallSMS.HTTPClient
  def request(method, url, headers, body, opts \\ []) do
    timeout = Keyword.get(opts, :receive_timeout, 600_000)

    Finch.build(method, url, headers, body)
    |> Finch.request(HipcallSMSFinch, receive_timeout: timeout)
    |> normalize_response()
  end

  # Normalize Finch response to match our behavior contract
  defp normalize_response({:ok, %Finch.Response{status: status, body: body, headers: headers}}) do
    {:ok, %{status: status, body: body, headers: headers}}
  end

  defp normalize_response({:error, reason}) do
    {:error, reason}
  end
end
