defmodule HipcallSMS.HTTPClient do
  @moduledoc """
  Behavior for HTTP client operations.

  This behavior defines the contract for making HTTP requests, allowing for
  easy mocking in tests while using Finch in production.
  """

  @doc """
  Makes an HTTP request.

  ## Parameters

  - `method` - HTTP method (:get, :post, :put, :delete, etc.)
  - `url` - Request URL
  - `headers` - List of header tuples
  - `body` - Request body (optional)
  - `opts` - Additional options (optional)

  ## Returns

  - `{:ok, %{status: integer(), body: binary(), headers: list()}}` - Success response
  - `{:error, reason}` - Error response
  """
  @callback request(
              method :: atom(),
              url :: String.t(),
              headers :: [{String.t(), String.t()}],
              body :: binary(),
              opts :: Keyword.t()
            ) :: {:ok, %{status: integer(), body: binary(), headers: list()}} | {:error, any()}
end
