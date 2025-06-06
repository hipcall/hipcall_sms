defmodule HipcallSMS.Adapters.TelnyxTest do
  use ExUnit.Case, async: true
  doctest HipcallSMS.Adapters.Telnyx

  import Mox

  alias HipcallSMS.{SMS, Adapters.Telnyx}
  alias HipcallSMS.HTTPClient.Mock, as: HTTPClientMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "deliver/2" do
    test "requires api_key configuration" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      assert_raise ArgumentError, ~r/api_key is required/, fn ->
        Telnyx.deliver(sms, [])
      end
    end

    test "successfully delivers SMS with valid configuration" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      config = [api_key: "KEY_test123"]

      # Mock successful API response
      expect(HTTPClientMock, :request, fn :post, url, headers, body, _opts ->
        assert url == "https://api.telnyx.com/v2/messages"
        assert {"Authorization", "Bearer KEY_test123"} in headers
        assert {"Content-Type", "application/json"} in headers

        # Verify request body
        decoded_body = Jason.decode!(body)
        assert decoded_body["from"] == "+15551234567"
        assert decoded_body["to"] == "+15555555555"
        assert decoded_body["text"] == "Test message"
        assert decoded_body["type"] == "SMS"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_123456789",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_123456789"
      assert response.status == "queued"
      assert response.provider == "telnyx"
    end

    test "uses config from application environment" do
      # Set up application config
      Application.put_env(:hipcall_sms, :telnyx_api_key, "KEY_from_env")

      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      expect(HTTPClientMock, :request, fn :post, _url, headers, _body, _opts ->
        assert {"Authorization", "Bearer KEY_from_env"} in headers

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_env_test",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, [])
      assert response.id == "msg_env_test"

      # Clean up
      Application.delete_env(:hipcall_sms, :telnyx_api_key)
    end

    test "handles SMS with messaging profile ID" do
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
        |> SMS.put_provider_option(:messaging_profile_id, "profile_123")

      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["messaging_profile_id"] == "profile_123"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_with_profile",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_with_profile"
    end

    test "handles SMS with webhook URL" do
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
        |> SMS.put_provider_option(:webhook_url, "https://example.com/webhook")

      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["webhook_url"] == "https://example.com/webhook"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_with_webhook",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_with_webhook"
    end

    test "handles MMS with media URLs" do
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Check this out!")
        |> SMS.put_provider_option(:type, "MMS")
        |> SMS.put_provider_option(:media_urls, [
          "https://example.com/image1.jpg",
          "https://example.com/image2.jpg"
        ])

      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["type"] == "MMS"

        assert decoded_body["media_urls"] == [
                 "https://example.com/image1.jpg",
                 "https://example.com/image2.jpg"
               ]

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_mms_test",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_mms_test"
    end

    test "handles all supported provider options" do
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
        |> SMS.put_provider_option(:messaging_profile_id, "profile_123")
        |> SMS.put_provider_option(:webhook_url, "https://example.com/webhook")
        |> SMS.put_provider_option(:webhook_failover_url, "https://example.com/failover")
        |> SMS.put_provider_option(:use_profile_webhooks, false)
        |> SMS.put_provider_option(:type, "MMS")
        |> SMS.put_provider_option(:auto_detect, true)
        |> SMS.put_provider_option(:media_urls, ["https://example.com/image1.jpg"])

      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["messaging_profile_id"] == "profile_123"
        assert decoded_body["webhook_url"] == "https://example.com/webhook"
        assert decoded_body["webhook_failover_url"] == "https://example.com/failover"
        assert decoded_body["use_profile_webhooks"] == false
        assert decoded_body["type"] == "MMS"
        assert decoded_body["auto_detect"] == true
        assert decoded_body["media_urls"] == ["https://example.com/image1.jpg"]

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_all_options",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_all_options"
    end

    test "handles config fallback when provider options not set" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      config = [
        api_key: "KEY_test456",
        messaging_profile_id: "config_profile_123",
        webhook_url: "https://config.example.com/webhook",
        auto_detect: true
      ]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["messaging_profile_id"] == "config_profile_123"
        assert decoded_body["webhook_url"] == "https://config.example.com/webhook"
        assert decoded_body["auto_detect"] == true

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_config_fallback",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_config_fallback"
    end

    test "handles API error responses" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      config = [api_key: "KEY_invalid"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 401,
           body:
             Jason.encode!(%{
               "errors" => [
                 %{
                   "code" => "unauthorized",
                   "title" => "Unauthorized",
                   "detail" => "Invalid API key"
                 }
               ]
             }),
           headers: []
         }}
      end)

      assert {:error, error} = Telnyx.deliver(sms, config)
      assert error.status == 401
      assert is_map(error.body)
    end

    test "handles network errors" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert {:error, error} = Telnyx.deliver(sms, config)
      assert error.error == :timeout
      assert error.provider == "telnyx"
    end

    test "handles invalid JSON response" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: "invalid json response",
           headers: []
         }}
      end)

      assert {:error, error} = Telnyx.deliver(sms, config)
      assert error.status == 200
      assert error.error == "Invalid JSON response"
    end

    test "handles empty text message" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "")
      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["text"] == ""

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_empty_text",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_empty_text"
    end

    test "handles long text message" do
      long_text = String.duplicate("This is a long message. ", 50)
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: long_text)
      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["text"] == long_text

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_long_text",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_long_text"
    end

    test "handles special characters in message" do
      special_text = "Hello! 🎉 Welcome to our service. Special chars: @#$%^&*()"
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: special_text)
      config = [api_key: "KEY_test456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["text"] == special_text

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "data" => %{
                 "id" => "msg_special_chars",
                 "to" => [%{"status" => "queued"}]
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Telnyx.deliver(sms, config)
      assert response.id == "msg_special_chars"
    end
  end
end
