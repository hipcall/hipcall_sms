defmodule HipcallSMS.Adapters.TestTest do
  use ExUnit.Case
  doctest HipcallSMS.Adapters.Test

  alias HipcallSMS.{SMS, Adapters.Test}

  describe "deliver/2" do
    test "sends SMS as message to current process" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")

      assert {:ok, %{}} = Test.deliver(sms, [])

      assert_received {:sms, received_sms}
      assert received_sms == sms
    end

    test "sends SMS with all fields populated" do
      sms =
        SMS.new(
          id: "msg_123",
          from: "+15551234567",
          to: "+15555555555",
          text: "Complete test message",
          provider_options: %{priority: "high", async: true}
        )

      assert {:ok, %{}} = Test.deliver(sms, [])

      assert_received {:sms, received_sms}
      assert received_sms.id == "msg_123"
      assert received_sms.from == "+15551234567"
      assert received_sms.to == "+15555555555"
      assert received_sms.text == "Complete test message"
      assert received_sms.provider_options == %{priority: "high", async: true}
    end

    test "ignores config parameter" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test")
      config = [some: "config", that: "is_ignored"]

      assert {:ok, %{}} = Test.deliver(sms, config)

      assert_received {:sms, received_sms}
      assert received_sms.text == "Test"
    end

    test "sends multiple SMS messages" do
      sms1 = SMS.new(from: "+15551234567", to: "+15555555555", text: "First message")
      sms2 = SMS.new(from: "+15551234567", to: "+15555555556", text: "Second message")

      assert {:ok, %{}} = Test.deliver(sms1, [])
      assert {:ok, %{}} = Test.deliver(sms2, [])

      assert_received {:sms, received_sms1}
      assert_received {:sms, received_sms2}

      assert received_sms1.text == "First message"
      assert received_sms2.text == "Second message"
    end

    test "works with shared test process" do
      # Start a separate process to act as shared test process
      {:ok, shared_pid} =
        Task.start_link(fn ->
          receive do
            {:sms, _sms} -> :ok
          end
        end)

      # Configure shared test process
      Application.put_env(:hipcall_sms, :shared_test_process, shared_pid)

      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Shared process test")

      assert {:ok, %{}} = Test.deliver(sms, [])

      # The message should go to the shared process, not the current process
      refute_received {:sms, _}

      # Clean up
      Application.delete_env(:hipcall_sms, :shared_test_process)
      Process.exit(shared_pid, :normal)
    end

    test "handles empty SMS text" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "")

      assert {:ok, %{}} = Test.deliver(sms, [])

      assert_received {:sms, received_sms}
      assert received_sms.text == ""
    end

    test "handles SMS with special characters" do
      text_with_emoji = "Hello! 🎉 Welcome to our service."
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: text_with_emoji)

      assert {:ok, %{}} = Test.deliver(sms, [])

      assert_received {:sms, received_sms}
      assert received_sms.text == text_with_emoji
    end

    test "handles long SMS messages" do
      long_text = String.duplicate("This is a long message. ", 50)
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: long_text)

      assert {:ok, %{}} = Test.deliver(sms, [])

      assert_received {:sms, received_sms}
      assert received_sms.text == long_text
    end

    test "preserves SMS struct integrity" do
      original_sms =
        SMS.new(
          id: "preserve_test",
          from: "+15551234567",
          to: "+15555555555",
          text: "Integrity test",
          provider_options: %{test: "value"}
        )

      assert {:ok, %{}} = Test.deliver(original_sms, [])

      assert_received {:sms, received_sms}

      # Verify the received SMS is identical to the original
      assert received_sms == original_sms
      assert received_sms.id == original_sms.id
      assert received_sms.direction == original_sms.direction
      assert received_sms.from == original_sms.from
      assert received_sms.to == original_sms.to
      assert received_sms.text == original_sms.text
      assert received_sms.provider_options == original_sms.provider_options
    end
  end

  describe "integration with HipcallSMS.deliver/2" do
    setup do
      Application.put_env(:hipcall_sms, :adapter, HipcallSMS.Adapters.Test)
      :ok
    end

    test "works through main HipcallSMS interface" do
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Integration test")

      assert {:ok, %{}} = HipcallSMS.deliver(sms)

      assert_received {:sms, received_sms}
      assert received_sms.text == "Integration test"
    end

    test "works with HipcallSMS.send_sms/4" do
      assert {:ok, %{}} = HipcallSMS.send_sms("+15551234567", "+15555555555", "Quick send test")

      assert_received {:sms, received_sms}
      assert received_sms.from == "+15551234567"
      assert received_sms.to == "+15555555555"
      assert received_sms.text == "Quick send test"
    end
  end
end
