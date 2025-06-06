defmodule HipcallSMSTest do
  use ExUnit.Case
  doctest HipcallSMS

  alias HipcallSMS.SMS

  setup do
    # Configure test adapter for all tests
    Application.put_env(:hipcall_sms, :adapter, HipcallSMS.Adapters.Test)
    :ok
  end

  describe "version/0" do
    test "returns the current version" do
      version = HipcallSMS.version()
      assert is_binary(version)
      assert version =~ ~r/^\d+\.\d+\.\d+/
    end
  end

  describe "deliver/2" do
    test "delivers SMS with test adapter" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello World!")

      assert {:ok, %{}} = HipcallSMS.deliver(sms)
      assert_received {:sms, received_sms}
      assert received_sms.from == "+15551234567"
      assert received_sms.to == "+15555555555"
      assert received_sms.text == "Hello World!"
    end

    test "delivers SMS with config override" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
      config = [adapter: HipcallSMS.Adapters.Test]

      assert {:ok, %{}} = HipcallSMS.deliver(sms, config)
      assert_received {:sms, received_sms}
      assert received_sms.text == "Hello!"
    end

    test "raises error when no adapter configured" do
      Application.delete_env(:hipcall_sms, :adapter)
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")

      assert_raise ArgumentError,
                   "No adapter configured. Please set :adapter in your config.",
                   fn ->
                     HipcallSMS.deliver(sms)
                   end

      # Restore adapter for other tests
      Application.put_env(:hipcall_sms, :adapter, HipcallSMS.Adapters.Test)
    end

    test "delivers SMS with provider options" do
      sms =
        SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
        |> SMS.provider_options(%{priority: "high", async: true})

      assert {:ok, %{}} = HipcallSMS.deliver(sms)
      assert_received {:sms, received_sms}
      assert received_sms.provider_options == %{priority: "high", async: true}
    end
  end

  describe "send_sms/4" do
    test "sends SMS with basic parameters" do
      assert {:ok, %{}} = HipcallSMS.send_sms("+15551234567", "+15555555555", "Quick message")

      assert_received {:sms, received_sms}
      assert received_sms.from == "+15551234567"
      assert received_sms.to == "+15555555555"
      assert received_sms.text == "Quick message"
      assert received_sms.direction == :outbound
    end

    test "sends SMS with config override" do
      config = [adapter: HipcallSMS.Adapters.Test]

      assert {:ok, %{}} =
               HipcallSMS.send_sms("+15551234567", "+15555555555", "Quick message", config)

      assert_received {:sms, received_sms}
      assert received_sms.text == "Quick message"
    end

    test "sends SMS with international numbers" do
      assert {:ok, %{}} =
               HipcallSMS.send_sms("+442071234567", "+33123456789", "International message")

      assert_received {:sms, received_sms}
      assert received_sms.from == "+442071234567"
      assert received_sms.to == "+33123456789"
      assert received_sms.text == "International message"
    end

    test "sends long SMS message" do
      long_message = String.duplicate("This is a long message. ", 20)

      assert {:ok, %{}} = HipcallSMS.send_sms("+15551234567", "+15555555555", long_message)

      assert_received {:sms, received_sms}
      assert received_sms.text == long_message
    end
  end

  describe "configuration merging" do
    test "merges base config with override config" do
      # Set up base config for Twilio
      Application.put_env(:hipcall_sms, :twilio_account_sid, "base_sid")
      Application.put_env(:hipcall_sms, :twilio_auth_token, "base_token")

      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test")

      # Override with different values
      config = [
        adapter: HipcallSMS.Adapters.Test,
        account_sid: "override_sid",
        auth_token: "override_token"
      ]

      assert {:ok, %{}} = HipcallSMS.deliver(sms, config)
      assert_received {:sms, _received_sms}

      # Clean up
      Application.delete_env(:hipcall_sms, :twilio_account_sid)
      Application.delete_env(:hipcall_sms, :twilio_auth_token)
    end
  end

  describe "get_balance/1" do
    test "gets balance with test adapter" do
      assert {:ok, balance} = HipcallSMS.get_balance()

      assert balance.balance == "100.00"
      assert balance.currency == "USD"
      assert balance.provider == "test"
      assert balance.provider_response.mock == true
    end

    test "gets balance with config override" do
      config = [adapter: HipcallSMS.Adapters.Test]

      assert {:ok, balance} = HipcallSMS.get_balance(config)

      assert balance.balance == "100.00"
      assert balance.currency == "USD"
      assert balance.provider == "test"
    end

    test "raises error when no adapter configured" do
      Application.delete_env(:hipcall_sms, :adapter)

      assert_raise ArgumentError,
                   "No adapter configured. Please set :adapter in your config.",
                   fn ->
                     HipcallSMS.get_balance()
                   end

      # Restore adapter for other tests
      Application.put_env(:hipcall_sms, :adapter, HipcallSMS.Adapters.Test)
    end

    test "gets balance with Twilio adapter returns not supported error" do
      config = [
        adapter: HipcallSMS.Adapters.Twilio,
        account_sid: "test_sid",
        auth_token: "test_token"
      ]

      assert {:error, error} = HipcallSMS.get_balance(config)

      assert error.error == "Balance checking not supported"
      assert error.provider == "twilio"
      assert error.message =~ "Twilio does not provide a simple balance endpoint"
    end
  end

  describe "error handling" do
    test "handles invalid SMS struct gracefully" do
      # This should raise a FunctionClauseError due to pattern matching
      assert_raise FunctionClauseError, fn ->
        HipcallSMS.deliver(%{not: "an_sms_struct"})
      end
    end
  end
end
