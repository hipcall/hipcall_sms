defmodule HipcallSMS.Adapters.IletimerkeziTest do
  use ExUnit.Case, async: true
  doctest HipcallSMS.Adapters.Iletimerkezi

  import Mox

  alias HipcallSMS.{SMS, Adapters.Iletimerkezi}
  alias HipcallSMS.HTTPClient.Mock, as: HTTPClientMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "deliver/2" do
    test "requires key configuration" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")

      # No HTTP expectation since validation happens before HTTP call
      assert_raise RuntimeError, ~r/key is required/, fn ->
        Iletimerkezi.deliver(sms, [])
      end
    end

    test "requires hash configuration" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")

      # No HTTP expectation since validation happens before HTTP call
      assert_raise RuntimeError, ~r/hash is required/, fn ->
        Iletimerkezi.deliver(sms, key: "test_key")
      end
    end

    test "successfully delivers SMS with valid configuration" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
      config = [key: "test_key123", hash: "test_hash123"]

      # Mock successful API response
      expect(HTTPClientMock, :request, fn :post, url, headers, body, _opts ->
        assert url == "https://api.iletimerkezi.com/v1/send-sms/json"
        assert {"Content-Type", "application/json"} in headers
        assert {"Accept", "application/json"} in headers

        # Verify request body
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["authentication"]["key"] == "test_key123"
        assert decoded_body["request"]["authentication"]["hash"] == "test_hash123"
        assert decoded_body["request"]["order"]["sender"] == "SENDER"
        assert decoded_body["request"]["order"]["message"]["text"] == "Test message"

        assert decoded_body["request"]["order"]["message"]["receipents"]["number"] == [
                 "+905551234567"
               ]

        assert decoded_body["request"]["order"]["iys"] == "1"
        assert decoded_body["request"]["order"]["iysList"] == "BIREYSEL"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_123456789"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_123456789"
      assert response.status == "queued"
      assert response.provider == "iletimerkezi"
    end

    test "uses config from application environment" do
      # Set up application config
      Application.put_env(:hipcall_sms, :iletimerkezi_key, "test_key_env")
      Application.put_env(:hipcall_sms, :iletimerkezi_hash, "test_hash_env")

      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["authentication"]["key"] == "test_key_env"
        assert decoded_body["request"]["authentication"]["hash"] == "test_hash_env"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_env_test"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, [])
      assert response.id == "order_env_test"

      # Clean up
      Application.delete_env(:hipcall_sms, :iletimerkezi_key)
      Application.delete_env(:hipcall_sms, :iletimerkezi_hash)
    end

    test "handles SMS with scheduled delivery" do
      sms =
        SMS.new(from: "SENDER", to: "+905551234567", text: "Scheduled message")
        |> SMS.put_provider_option(:send_date_time, ["2024", "12", "25", "10", "30"])

      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)

        assert decoded_body["request"]["order"]["sendDateTime"] == [
                 "2024",
                 "12",
                 "25",
                 "10",
                 "30"
               ]

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_scheduled"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_scheduled"
    end

    test "handles SMS with custom IYS settings" do
      sms =
        SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
        |> SMS.put_provider_option(:iys, "0")
        |> SMS.put_provider_option(:iys_list, "TACIR")

      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["order"]["iys"] == "0"
        assert decoded_body["request"]["order"]["iysList"] == "TACIR"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_custom_iys"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_custom_iys"
    end

    test "handles SMS with all provider options" do
      sms =
        SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
        |> SMS.put_provider_option(:send_date_time, ["2025", "01", "15", "14", "30"])
        |> SMS.put_provider_option(:iys, "1")
        |> SMS.put_provider_option(:iys_list, "BIREYSEL")

      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)

        assert decoded_body["request"]["order"]["sendDateTime"] == [
                 "2025",
                 "01",
                 "15",
                 "14",
                 "30"
               ]

        assert decoded_body["request"]["order"]["iys"] == "1"
        assert decoded_body["request"]["order"]["iysList"] == "BIREYSEL"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_all_options"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_all_options"
    end

    test "handles SMS with empty send_date_time" do
      sms =
        SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
        |> SMS.put_provider_option(:send_date_time, [])

      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["order"]["sendDateTime"] == []

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_empty_date"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_empty_date"
    end

    test "handles API error responses" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
      config = [key: "invalid_key", hash: "invalid_hash"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 401,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "401",
                   "message" => "Unauthorized"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:error, error} = Iletimerkezi.deliver(sms, config)
      assert error.status == 401
      assert is_map(error.body)
    end

    test "handles network errors" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert {:error, error} = Iletimerkezi.deliver(sms, config)
      assert error.error == :timeout
      assert error.provider == "iletimerkezi"
    end

    test "handles invalid JSON response" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: "invalid json response",
           headers: []
         }}
      end)

      assert {:error, error} = Iletimerkezi.deliver(sms, config)
      assert error.status == 200
      assert error.error == "Invalid JSON response"
    end

    test "handles empty text message" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "")
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["order"]["message"]["text"] == ""

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_empty_text"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_empty_text"
    end

    test "handles long text message" do
      long_text = String.duplicate("Bu uzun bir mesajdır. ", 50)
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: long_text)
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["order"]["message"]["text"] == long_text

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_long_text"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_long_text"
    end

    test "handles Turkish characters in message" do
      turkish_text = "Merhaba! Türkçe karakterler: ğüşıöç ĞÜŞIÖÇ"
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: turkish_text)
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["order"]["message"]["text"] == turkish_text

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_turkish_chars"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_turkish_chars"
    end

    test "handles SMS with nil provider options" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        # Should use default values when provider options are nil
        assert decoded_body["request"]["order"]["sendDateTime"] == []
        assert decoded_body["request"]["order"]["iys"] == "1"
        assert decoded_body["request"]["order"]["iysList"] == "BIREYSEL"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "order" => %{
                   "id" => "order_nil_options"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_nil_options"
    end

    test "handles failed response status" do
      sms = SMS.new(from: "SENDER", to: "+905551234567", text: "Test message")
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "400",
                   "message" => "Bad Request"
                 },
                 "order" => %{
                   "id" => "order_failed"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, response} = Iletimerkezi.deliver(sms, config)
      assert response.id == "order_failed"
      assert response.status == "failed"
    end
  end

  describe "get_balance/1" do
    test "requires key and hash configuration" do
      assert_raise RuntimeError, ~r/key is required/, fn ->
        Iletimerkezi.get_balance([])
      end

      assert_raise RuntimeError, ~r/hash is required/, fn ->
        Iletimerkezi.get_balance(key: "test_key")
      end
    end

    test "successfully gets balance with valid configuration" do
      config = [key: "test_key123", hash: "test_hash123"]

      # Mock successful balance API response
      expect(HTTPClientMock, :request, fn :post, url, headers, body, _opts ->
        assert url == "https://api.iletimerkezi.com/v1/get-balance/json"
        assert {"Content-Type", "application/json"} in headers

        # Verify request body
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["authentication"]["key"] == "test_key123"
        assert decoded_body["request"]["authentication"]["hash"] == "test_hash123"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "balance" => %{
                   "amount" => "300.00",
                   "sms" => "18343"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, balance} = Iletimerkezi.get_balance(config)
      assert balance.balance == "300.00"
      assert balance.sms_balance == "18343"
      assert balance.currency == "TRY"
      assert balance.provider == "iletimerkezi"
      assert is_map(balance.provider_response)
    end

    test "uses config from application environment" do
      # Set up application config
      Application.put_env(:hipcall_sms, :iletimerkezi_key, "key_from_env")
      Application.put_env(:hipcall_sms, :iletimerkezi_hash, "hash_from_env")

      expect(HTTPClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["request"]["authentication"]["key"] == "key_from_env"
        assert decoded_body["request"]["authentication"]["hash"] == "hash_from_env"

        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "balance" => %{
                   "amount" => "250.00",
                   "sms" => "15000"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, balance} = Iletimerkezi.get_balance([])
      assert balance.balance == "250.00"
      assert balance.sms_balance == "15000"

      # Clean up
      Application.delete_env(:hipcall_sms, :iletimerkezi_key)
      Application.delete_env(:hipcall_sms, :iletimerkezi_hash)
    end

    test "handles API error responses" do
      config = [key: "invalid_key", hash: "invalid_hash"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 401,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "401",
                   "message" => "Unauthorized"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:error, error} = Iletimerkezi.get_balance(config)
      assert error.status == 401
      assert is_map(error.body)
    end

    test "handles network errors" do
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert {:error, error} = Iletimerkezi.get_balance(config)
      assert error.error == :timeout
      assert error.provider == "iletimerkezi"
    end

    test "handles invalid JSON response" do
      config = [key: "test_key456", hash: "test_hash456"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: "invalid json response",
           headers: []
         }}
      end)

      assert {:error, error} = Iletimerkezi.get_balance(config)
      assert error.status == 200
      assert error.error == "Invalid JSON response"
    end

    test "handles zero balance" do
      config = [key: "test_key123", hash: "test_hash123"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "balance" => %{
                   "amount" => "0.00",
                   "sms" => "0"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, balance} = Iletimerkezi.get_balance(config)
      assert balance.balance == "0.00"
      assert balance.sms_balance == "0"
      assert balance.currency == "TRY"
    end

    test "handles missing balance data in response" do
      config = [key: "test_key123", hash: "test_hash123"]

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 }
                 # Missing balance data
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, balance} = Iletimerkezi.get_balance(config)
      assert balance.balance == nil
      assert balance.sms_balance == nil
      assert balance.currency == "TRY"
      assert balance.provider == "iletimerkezi"
    end

    test "works without config parameter" do
      # Set up application config
      Application.put_env(:hipcall_sms, :iletimerkezi_key, "default_key")
      Application.put_env(:hipcall_sms, :iletimerkezi_hash, "default_hash")

      expect(HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "status" => %{
                   "code" => "200",
                   "message" => "OK"
                 },
                 "balance" => %{
                   "amount" => "150.00",
                   "sms" => "10000"
                 }
               }
             }),
           headers: []
         }}
      end)

      assert {:ok, balance} = Iletimerkezi.get_balance()
      assert balance.balance == "150.00"
      assert balance.sms_balance == "10000"

      # Clean up
      Application.delete_env(:hipcall_sms, :iletimerkezi_key)
      Application.delete_env(:hipcall_sms, :iletimerkezi_hash)
    end
  end
end
