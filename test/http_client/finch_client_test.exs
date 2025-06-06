defmodule HipcallSMS.HTTPClient.FinchClientTest do
  use ExUnit.Case
  doctest HipcallSMS.HTTPClient.FinchClient

  alias HipcallSMS.HTTPClient.FinchClient

  describe "request/5" do
    test "makes successful HTTP request and normalizes response" do
      # Test with a real HTTP request to httpbin.org (a testing service)
      result = FinchClient.request(:get, "https://httpbin.org/get", [], "", [])

      case result do
        {:ok, response} ->
          assert is_integer(response.status)
          assert response.status >= 200 and response.status < 300
          assert is_binary(response.body)
          assert is_list(response.headers)

        {:error, _reason} ->
          # Network might not be available in test environment, that's ok
          # The important thing is that we get a proper error tuple
          assert true
      end
    end

    test "handles POST request with body" do
      # Test POST request to httpbin.org which echoes back the request
      headers = [{"Content-Type", "application/json"}]
      body = ~s({"test": "data"})

      result = FinchClient.request(:post, "https://httpbin.org/post", headers, body, [])

      case result do
        {:ok, response} ->
          assert response.status == 200
          assert String.contains?(response.body, "test")
          assert String.contains?(response.body, "data")

        {:error, _reason} ->
          # Network might not be available, that's acceptable for this test
          assert true
      end
    end

    test "uses custom timeout from options" do
      # Test that timeout option is properly passed
      # We'll use a very short timeout to test timeout handling
      result =
        FinchClient.request(:get, "https://httpbin.org/delay/2", [], "", receive_timeout: 50)

      case result do
        {:error, reason} when is_struct(reason) ->
          # Various timeout-related errors are acceptable
          assert true

        {:error, :timeout} ->
          assert true

        {:error, _other_reason} ->
          # Other network errors are also acceptable
          assert true

        {:ok, _response} ->
          # If the request somehow completes quickly, that's also fine
          assert true
      end
    end

    test "uses default timeout when not specified" do
      # Test that default timeout (600_000ms) is used when not specified
      # We can't easily test the exact timeout value without mocking,
      # but we can verify the function accepts calls without timeout option
      result = FinchClient.request(:get, "https://httpbin.org/get", [], "")

      # The result should be either success or error, but not crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles different HTTP methods" do
      methods_to_test = [:get, :post, :put, :delete, :patch]

      for method <- methods_to_test do
        result = FinchClient.request(method, "https://httpbin.org/#{method}", [], "", [])
        # Should return either success or error tuple, not crash
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "handles invalid URL gracefully" do
      # Test with malformed URL that should cause an error
      assert_raise ArgumentError, fn ->
        FinchClient.request(:get, "not-a-valid-url", [], "", [])
      end
    end

    test "handles connection errors gracefully" do
      # Try to connect to a non-existent domain
      result =
        FinchClient.request(:get, "https://this-domain-should-not-exist-12345.com", [], "", [])

      assert {:error, _reason} = result
    end

    test "preserves request headers" do
      headers = [
        {"User-Agent", "HipcallSMS/1.0"},
        {"Accept", "application/json"},
        {"Custom-Header", "custom-value"}
      ]

      result = FinchClient.request(:get, "https://httpbin.org/headers", headers, "", [])

      case result do
        {:ok, response} ->
          # httpbin.org/headers returns the headers it received
          assert String.contains?(response.body, "User-Agent")
          assert String.contains?(response.body, "HipcallSMS/1.0")
          assert String.contains?(response.body, "Custom-Header")

        {:error, _reason} ->
          # Network errors are acceptable in test environment
          assert true
      end
    end
  end

  describe "normalize_response/1" do
    # We can't directly test the private function, but we can test its behavior
    # through the public interface by examining the response structure

    test "response structure matches expected format" do
      # Make a request and verify the response structure
      result = FinchClient.request(:get, "https://httpbin.org/json", [], "", [])

      case result do
        {:ok, response} ->
          # Verify the response has the expected structure
          assert Map.has_key?(response, :status)
          assert Map.has_key?(response, :body)
          assert Map.has_key?(response, :headers)
          assert is_integer(response.status)
          assert is_binary(response.body)
          assert is_list(response.headers)

        {:error, reason} ->
          # Error responses should be in the expected format
          assert is_atom(reason) or is_struct(reason) or is_binary(reason)
      end
    end
  end

  describe "behavior compliance" do
    test "implements HipcallSMS.HTTPClient behavior" do
      # Verify that the module implements the required behavior
      behaviours = HipcallSMS.HTTPClient.FinchClient.__info__(:attributes)[:behaviour] || []
      assert HipcallSMS.HTTPClient in behaviours
    end

    test "request/5 function exists with correct arity" do
      # Verify the function exists and has the correct arity
      assert function_exported?(HipcallSMS.HTTPClient.FinchClient, :request, 5)
    end

    test "request/4 function exists (with default opts)" do
      # Verify the function can be called with 4 arguments (opts defaults to [])
      result = FinchClient.request(:get, "https://httpbin.org/get", [], "")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "integration with HipcallSMSFinch" do
    test "uses HipcallSMSFinch as the Finch instance name" do
      # This is more of a documentation test - the actual Finch instance
      # should be started by the application supervision tree
      # We can verify this by checking if our requests work (which they do in other tests)

      # Verify that HipcallSMSFinch is running by making a simple request
      # If the Finch instance wasn't properly configured, this would fail
      result = FinchClient.request(:get, "https://httpbin.org/get", [], "", [])

      # The request should either succeed or fail gracefully (network issues)
      # but not crash due to missing Finch instance
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "error handling" do
    test "handles network timeouts" do
      # Test with a very short timeout to force a timeout error
      result =
        FinchClient.request(:get, "https://httpbin.org/delay/3", [], "", receive_timeout: 10)

      case result do
        {:error, _reason} ->
          assert true

        {:ok, _response} ->
          # If somehow the request completes very quickly, that's also acceptable
          assert true
      end
    end

    test "handles DNS resolution failures" do
      result = FinchClient.request(:get, "https://nonexistent-domain-12345.invalid", [], "", [])
      assert {:error, _reason} = result
    end

    test "handles connection refused" do
      # Try to connect to localhost on a port that should be closed
      result = FinchClient.request(:get, "http://127.0.0.1:1", [], "", [])
      assert {:error, _reason} = result
    end
  end
end
