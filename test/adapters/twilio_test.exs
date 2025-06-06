defmodule HipcallSMS.Adapters.TwilioTest do
  use ExUnit.Case, async: true
  doctest HipcallSMS.Adapters.Twilio

  import Mox

  alias HipcallSMS.{SMS, Adapters.Twilio}
  alias HipcallSMS.HTTPClient.Mock, as: HTTPClientMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "deliver/2" do
    test "requires account_sid configuration" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      # No HTTP expectation since validation happens before HTTP call
      assert_raise RuntimeError, ~r/account_sid is required/, fn ->
        Twilio.deliver(sms, [])
      end
    end

    test "requires auth_token configuration" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      # No HTTP expectation since validation happens before HTTP call
      assert_raise RuntimeError, ~r/auth_token is required/, fn ->
        Twilio.deliver(sms, account_sid: "ACtest")
      end
    end

    test "successfully delivers SMS with valid configuration" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      config = [account_sid: "ACtest123", auth_token: "token123"]

      # Mock successful API response
      expect(HTTPClientMock, :request, fn :post, url, headers, body, _opts ->
        assert url == "https://api.twilio.com/2010-04-01/Accounts/ACtest123/Messages.json"
        assert {"Content-Type", "application/x-www-form-urlencoded"} in headers
        assert {"Accept", "application/json"} in headers

        # Check for Basic auth header
        auth_header = Enum.find(headers, fn {key, _} -> key == "Authorization" end)
        assert auth_header != nil
        {"Authorization", auth_value} = auth_header
        assert String.starts_with?(auth_value, "Basic ")

        # Verify request body (URL encoded)
        assert String.contains?(body, "To=%2B15555555555")
        assert String.contains?(body, "From=%2B15551234567")
        assert String.contains?(body, "Body=Test+message")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM123456789",
               "status" => "queued",
               "to" => "+15555555555",
               "from" => "+15551234567",
               "body" => "Test message"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM123456789"
      assert response.status == "queued"
      assert response.provider == "twilio"
    end

    test "uses config from application environment" do
      # Set up application config
      Application.put_env(:hipcall_sms, :twilio_account_sid, "ACtest_env")
      Application.put_env(:hipcall_sms, :twilio_auth_token, "token_env")

      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      expect(HTTPClientMock, :request, fn :post, url, headers, _body, _opts ->
        assert url == "https://api.twilio.com/2010-04-01/Accounts/ACtest_env/Messages.json"

        # Check for Basic auth header with env credentials
        auth_header = Enum.find(headers, fn {key, _} -> key == "Authorization" end)
        assert auth_header != nil

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_env_test",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, [])
      assert response.id == "SM_env_test"

      # Clean up
      Application.delete_env(:hipcall_sms, :twilio_account_sid)
      Application.delete_env(:hipcall_sms, :twilio_auth_token)
    end

    test "handles SMS with messaging service" do
      sms =
        SMS.new(to: "+15555555555", text: "Test message")
        |> SMS.put_provider_option(:messaging_service_sid, "MGtest123")

      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        assert String.contains?(body, "MessagingServiceSid=MGtest123")
        # Should not contain From parameter when using messaging service
        refute String.contains?(body, "From=")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_with_service",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM_with_service"
    end

    test "handles SMS with status callback" do
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
        |> SMS.put_provider_option(:status_callback, "https://example.com/webhook")

      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        assert String.contains?(body, "StatusCallback=https%3A%2F%2Fexample.com%2Fwebhook")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_with_callback",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM_with_callback"
    end

    test "handles SMS with media URL (MMS)" do
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Check this out!")
        |> SMS.put_provider_option(:media_url, "https://example.com/image.jpg")

      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        assert String.contains?(body, "MediaUrl=https%3A%2F%2Fexample.com%2Fimage.jpg")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "MM_with_media",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "MM_with_media"
    end

    test "handles SMS with all supported provider options" do
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
        |> SMS.put_provider_option(:messaging_service_sid, "MGtest123")
        |> SMS.put_provider_option(:status_callback, "https://example.com/webhook")
        |> SMS.put_provider_option(:application_sid, "APtest123")
        |> SMS.put_provider_option(:max_price, "0.05")
        |> SMS.put_provider_option(:provide_feedback, true)
        |> SMS.put_provider_option(:attempt, 1)
        |> SMS.put_provider_option(:validity_period, 3600)
        |> SMS.put_provider_option(:force_delivery, true)
        |> SMS.put_provider_option(:smart_encoded, true)
        |> SMS.put_provider_option(:send_at, "2024-12-25T10:00:00Z")

      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        assert String.contains?(body, "MessagingServiceSid=MGtest123")
        assert String.contains?(body, "StatusCallback=https%3A%2F%2Fexample.com%2Fwebhook")
        assert String.contains?(body, "ApplicationSid=APtest123")
        assert String.contains?(body, "MaxPrice=0.05")
        assert String.contains?(body, "ProvideFeedback=true")
        assert String.contains?(body, "Attempt=1")
        assert String.contains?(body, "ValidityPeriod=3600")
        assert String.contains?(body, "ForceDelivery=true")
        assert String.contains?(body, "SmartEncoded=true")
        assert String.contains?(body, "SendAt=2024-12-25T10%3A00%3A00Z")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_all_options",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM_all_options"
    end

    test "handles config fallback when provider options not set" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      config = [
        account_sid: "ACtest456",
        auth_token: "token456",
        messaging_service_sid: "MGconfig123",
        status_callback: "https://config.example.com/webhook",
        max_price: "0.10"
      ]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        assert String.contains?(body, "MessagingServiceSid=MGconfig123")
        assert String.contains?(body, "StatusCallback=https%3A%2F%2Fconfig.example.com%2Fwebhook")
        assert String.contains?(body, "MaxPrice=0.10")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_config_fallback",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM_config_fallback"
    end

    test "handles API error responses" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      config = [account_sid: "ACinvalid", auth_token: "invalid_token"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 401,
           body:
             Jason.encode!(%{
               "code" => 20003,
               "message" => "Authenticate",
               "more_info" => "https://www.twilio.com/docs/errors/20003",
               "status" => 401
             }),
           headers: []
         }}
      end)

      assert {:error, error} = Twilio.deliver(sms, config)
      assert error.status == 401
      assert is_map(error.body)
    end

    test "handles network errors" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert {:error, error} = Twilio.deliver(sms, config)
      assert error.error == :timeout
      assert error.provider == "twilio"
    end

    test "handles invalid JSON response" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 201,
           body: "invalid json response",
           headers: []
         }}
      end)

      assert {:error, error} = Twilio.deliver(sms, config)
      assert error.status == 201
      assert error.error == "Invalid JSON response"
    end

    test "handles empty text message" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "")
      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        assert String.contains?(body, "Body=")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_empty_text",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM_empty_text"
    end

    test "handles long text message" do
      long_text = String.duplicate("This is a long message. ", 50)
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: long_text)
      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        # The long text should be URL encoded in the body
        assert String.contains?(body, "Body=")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_long_text",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM_long_text"
    end

    test "handles special characters in message" do
      special_text = "Hello! 🎉 Welcome to our service. Special chars: @#$%^&*()"
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: special_text)
      config = [account_sid: "ACtest456", auth_token: "token456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        # Special characters should be URL encoded
        assert String.contains?(body, "Body=")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_special_chars",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM_special_chars"
    end

    test "handles nil provider options" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      config = [
        account_sid: "ACtest456",
        auth_token: "token456",
        max_price: nil,
        validity_period: nil
      ]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        # Nil values should not appear in the body
        refute String.contains?(body, "MaxPrice=")
        refute String.contains?(body, "ValidityPeriod=")

        {:ok,
         %{
           status: 201,
           body:
             Jason.encode!(%{
               "sid" => "SM_nil_options",
               "status" => "queued"
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Twilio.deliver(sms, config)
      assert response.id == "SM_nil_options"
    end
  end

  describe "get_balance/1" do
    test "returns not supported error" do
      assert {:error, error} = Twilio.get_balance([])

      assert error.error == "Balance checking not supported"
      assert error.provider == "twilio"
      assert error.message =~ "Twilio does not provide a simple balance endpoint"
    end

    test "returns not supported error with config" do
      config = [account_sid: "ACtest123", auth_token: "test_token"]

      assert {:error, error} = Twilio.get_balance(config)

      assert error.error == "Balance checking not supported"
      assert error.provider == "twilio"
      assert error.message =~ "Please check your Twilio Console"
    end

    test "ignores all configuration parameters" do
      config = [
        account_sid: "ACtest123",
        auth_token: "test_token",
        some_other: "parameter"
      ]

      assert {:error, error} = Twilio.get_balance(config)

      assert error.error == "Balance checking not supported"
      assert error.provider == "twilio"
    end

    test "works without config parameter" do
      assert {:error, error} = Twilio.get_balance()

      assert error.error == "Balance checking not supported"
      assert error.provider == "twilio"
    end

    test "consistent error message format" do
      assert {:error, error} = Twilio.get_balance([])

      assert is_binary(error.error)
      assert is_binary(error.message)
      assert is_binary(error.provider)
      assert error.provider == "twilio"
    end
  end
end
