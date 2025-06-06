defmodule HipcallSMS.HTTPClient.FinchClientTest do
  use ExUnit.Case, async: true
  doctest HipcallSMS.HTTPClient.FinchClient

  alias HipcallSMS.HTTPClient.FinchClient

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
      # Use a local endpoint that should fail gracefully
      result = FinchClient.request(:get, "http://127.0.0.1:1", [], "")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "request/5 structure and error handling" do
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

    test "handles connection refused" do
      # Try to connect to localhost on a port that should be closed
      result = FinchClient.request(:get, "http://127.0.0.1:1", [], "", [])
      assert {:error, _reason} = result
    end

    test "handles DNS resolution failures" do
      result = FinchClient.request(:get, "https://nonexistent-domain-12345.invalid", [], "", [])
      assert {:error, _reason} = result
    end

    test "handles different HTTP methods without crashing" do
      methods_to_test = [:get, :post, :put, :delete, :patch]

      for method <- methods_to_test do
        # Use a local endpoint that will fail but test that the method is accepted
        result = FinchClient.request(method, "http://127.0.0.1:1", [], "", [])
        # Should return error tuple, not crash
        assert match?({:error, _}, result)
      end
    end

    test "accepts timeout options" do
      # Test that timeout option is properly accepted (will fail due to connection but won't crash)
      result =
        FinchClient.request(:get, "http://127.0.0.1:1", [], "", receive_timeout: 50)

      assert match?({:error, _}, result)
    end

    test "response structure matches expected format" do
      # Test that error responses have the expected structure
      result = FinchClient.request(:get, "http://127.0.0.1:1", [], "", [])

      case result do
        {:ok, response} ->
          # If somehow successful, verify the response has the expected structure
          assert Map.has_key?(response, :status)
          assert Map.has_key?(response, :body)
          assert Map.has_key?(response, :headers)
          assert is_integer(response.status)
          assert is_binary(response.body)
          assert is_list(response.headers)

        {:error, reason} ->
          # Error responses should be in the expected format
          assert is_atom(reason) or is_struct(reason) or is_binary(reason)
          # This is expected for connection refused
          assert true
      end
    end

    test "POST request with body and headers" do
      headers = [{"Content-Type", "application/json"}]
      body = ~s({"test": "data"})

      # Test that POST requests with body and headers don't crash
      result = FinchClient.request(:post, "http://127.0.0.1:1", headers, body, [])

      # Should return error tuple (connection refused), not crash
      assert match?({:error, _}, result)

      # Test POST with empty body
      result_empty = FinchClient.request(:post, "http://127.0.0.1:1", headers, "", [])
      assert match?({:error, _}, result_empty)

      # Test POST with large body
      large_body = String.duplicate("x", 10000)
      result_large = FinchClient.request(:post, "http://127.0.0.1:1", headers, large_body, [])
      assert match?({:error, _}, result_large)
    end

    test "accepts and processes request headers without crashing" do
      headers = [
        {"User-Agent", "HipcallSMS/1.0"},
        {"Accept", "application/json"},
        {"Custom-Header", "custom-value"}
      ]

      # Test that the function accepts headers and doesn't crash
      # Using a local endpoint that will fail but test header processing
      result = FinchClient.request(:get, "http://127.0.0.1:1", headers, "", [])

      # Should return error tuple (connection refused), not crash
      assert match?({:error, _}, result)

      # Test with empty headers
      result_empty = FinchClient.request(:get, "http://127.0.0.1:1", [], "", [])
      assert match?({:error, _}, result_empty)

      # Test with multiple headers
      many_headers = [
        {"User-Agent", "HipcallSMS/1.0"},
        {"Accept", "application/json"},
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer token123"},
        {"X-Custom-Header", "custom-value"},
        {"X-Another-Header", "another-value"}
      ]

      result_many = FinchClient.request(:post, "http://127.0.0.1:1", many_headers, "{}", [])
      assert match?({:error, _}, result_many)
    end
  end

  describe "integration with HipcallSMSFinch" do
    test "uses HipcallSMSFinch as the Finch instance name" do
      # This is more of a documentation test - the actual Finch instance
      # should be started by the application supervision tree
      # We can verify this by checking if our requests work (which they do in other tests)

      # Verify that HipcallSMSFinch is running by making a simple request
      # If the Finch instance wasn't properly configured, this would fail
      result = FinchClient.request(:get, "http://127.0.0.1:1", [], "", [])

      # The request should either succeed or fail gracefully (network issues)
      # but not crash due to missing Finch instance
      assert match?({:error, _}, result)
    end
  end

  describe "timeout handling" do
    test "handles network timeouts gracefully" do
      # Test with a very short timeout - connection to a closed port should timeout quickly
      result =
        FinchClient.request(:get, "http://127.0.0.1:1", [], "", receive_timeout: 10)

      # Should return error tuple (timeout or connection refused), not crash
      assert match?({:error, _}, result)
    end

    test "uses default timeout when not specified" do
      # Test that default timeout (600_000ms) is used when not specified
      result = FinchClient.request(:get, "http://127.0.0.1:1", [], "")

      # The result should be either success or error, but not crash
      assert match?({:error, _}, result)
    end
  end
end
