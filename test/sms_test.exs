defmodule HipcallSMS.SMSTest do
  use ExUnit.Case
  doctest HipcallSMS.SMS

  alias HipcallSMS.SMS

  describe "new/1" do
    test "creates empty SMS struct with defaults" do
      sms = SMS.new()

      assert %SMS{} = sms
      assert sms.id == nil
      assert sms.direction == :outbound
      assert sms.from == nil
      assert sms.to == nil
      assert sms.text == nil
      assert sms.provider_options == %{}
    end

    test "creates SMS struct with initial attributes" do
      attrs = [
        id: "msg_123",
        from: "+15551234567",
        to: "+15555555555",
        text: "Hello World",
        provider_options: %{priority: "high"}
      ]

      sms = SMS.new(attrs)

      assert sms.id == "msg_123"
      assert sms.direction == :outbound
      assert sms.from == "+15551234567"
      assert sms.to == "+15555555555"
      assert sms.text == "Hello World"
      assert sms.provider_options == %{priority: "high"}
    end

    test "creates SMS struct with partial attributes" do
      sms = SMS.new(from: "+15551234567", text: "Hello")

      assert sms.from == "+15551234567"
      assert sms.text == "Hello"
      assert sms.to == nil
      assert sms.direction == :outbound
    end
  end

  describe "from/2" do
    test "sets the from field" do
      sms = SMS.new() |> SMS.from("+15551234567")

      assert sms.from == "+15551234567"
    end

    test "updates existing from field" do
      sms =
        SMS.new(from: "+15551111111")
        |> SMS.from("+15551234567")

      assert sms.from == "+15551234567"
    end

    test "works with international numbers" do
      sms = SMS.new() |> SMS.from("+442071234567")

      assert sms.from == "+442071234567"
    end

    test "is chainable" do
      sms =
        SMS.new()
        |> SMS.from("+15551234567")
        |> SMS.to("+15555555555")
        |> SMS.text("Hello")

      assert sms.from == "+15551234567"
      assert sms.to == "+15555555555"
      assert sms.text == "Hello"
    end
  end

  describe "to/2" do
    test "sets the to field" do
      sms = SMS.new() |> SMS.to("+15555555555")

      assert sms.to == "+15555555555"
    end

    test "updates existing to field" do
      sms =
        SMS.new(to: "+15551111111")
        |> SMS.to("+15555555555")

      assert sms.to == "+15555555555"
    end

    test "works with international numbers" do
      sms = SMS.new() |> SMS.to("+33123456789")

      assert sms.to == "+33123456789"
    end

    test "is chainable" do
      sms =
        SMS.new()
        |> SMS.to("+15555555555")
        |> SMS.from("+15551234567")
        |> SMS.text("Hello")

      assert sms.to == "+15555555555"
      assert sms.from == "+15551234567"
      assert sms.text == "Hello"
    end
  end

  describe "text/2" do
    test "sets the text field" do
      sms = SMS.new() |> SMS.text("Hello World")

      assert sms.text == "Hello World"
    end

    test "updates existing text field" do
      sms =
        SMS.new(text: "Old message")
        |> SMS.text("New message")

      assert sms.text == "New message"
    end

    test "handles empty text" do
      sms = SMS.new() |> SMS.text("")

      assert sms.text == ""
    end

    test "handles long text" do
      long_text = String.duplicate("This is a long message. ", 50)
      sms = SMS.new() |> SMS.text(long_text)

      assert sms.text == long_text
    end

    test "handles text with special characters" do
      text_with_emoji = "Hello! 🎉 Welcome to our service."
      sms = SMS.new() |> SMS.text(text_with_emoji)

      assert sms.text == text_with_emoji
    end

    test "is chainable" do
      sms =
        SMS.new()
        |> SMS.text("Hello World")
        |> SMS.from("+15551234567")
        |> SMS.to("+15555555555")

      assert sms.text == "Hello World"
      assert sms.from == "+15551234567"
      assert sms.to == "+15555555555"
    end
  end

  describe "provider_options/2" do
    test "sets provider options" do
      options = %{priority: "high", async: true}
      sms = SMS.new() |> SMS.provider_options(options)

      assert sms.provider_options == options
    end

    test "replaces existing provider options" do
      sms =
        SMS.new()
        |> SMS.provider_options(%{old: "value"})
        |> SMS.provider_options(%{new: "value"})

      assert sms.provider_options == %{new: "value"}
    end

    test "handles empty options map" do
      sms = SMS.new() |> SMS.provider_options(%{})

      assert sms.provider_options == %{}
    end

    test "handles complex options" do
      options = %{
        webhook_url: "https://example.com/webhook",
        status_callback: "https://example.com/status",
        messaging_profile_id: "profile_123",
        delivery_receipt: true,
        validity_period: 3600
      }

      sms = SMS.new() |> SMS.provider_options(options)

      assert sms.provider_options == options
    end

    test "is chainable" do
      sms =
        SMS.new()
        |> SMS.provider_options(%{priority: "high"})
        |> SMS.from("+15551234567")
        |> SMS.text("Hello")

      assert sms.provider_options == %{priority: "high"}
      assert sms.from == "+15551234567"
      assert sms.text == "Hello"
    end
  end

  describe "put_provider_option/3" do
    test "adds single provider option to empty options" do
      sms = SMS.new() |> SMS.put_provider_option(:priority, "high")

      assert sms.provider_options == %{priority: "high"}
    end

    test "adds provider option to existing options" do
      sms =
        SMS.new()
        |> SMS.provider_options(%{existing: "value"})
        |> SMS.put_provider_option(:new_option, "new_value")

      assert sms.provider_options == %{existing: "value", new_option: "new_value"}
    end

    test "updates existing provider option" do
      sms =
        SMS.new()
        |> SMS.provider_options(%{priority: "low"})
        |> SMS.put_provider_option(:priority, "high")

      assert sms.provider_options == %{priority: "high"}
    end

    test "works with string keys" do
      sms = SMS.new() |> SMS.put_provider_option("webhook_url", "https://example.com")

      assert sms.provider_options == %{"webhook_url" => "https://example.com"}
    end

    test "works with atom keys" do
      sms = SMS.new() |> SMS.put_provider_option(:async, true)

      assert sms.provider_options == %{async: true}
    end

    test "handles various value types" do
      sms =
        SMS.new()
        |> SMS.put_provider_option(:string_val, "text")
        |> SMS.put_provider_option(:boolean_val, true)
        |> SMS.put_provider_option(:integer_val, 42)
        |> SMS.put_provider_option(:list_val, [1, 2, 3])
        |> SMS.put_provider_option(:map_val, %{nested: "value"})

      expected = %{
        string_val: "text",
        boolean_val: true,
        integer_val: 42,
        list_val: [1, 2, 3],
        map_val: %{nested: "value"}
      }

      assert sms.provider_options == expected
    end

    test "is chainable" do
      sms =
        SMS.new()
        |> SMS.put_provider_option(:priority, "high")
        |> SMS.put_provider_option(:async, true)
        |> SMS.from("+15551234567")
        |> SMS.text("Hello")

      assert sms.provider_options == %{priority: "high", async: true}
      assert sms.from == "+15551234567"
      assert sms.text == "Hello"
    end
  end

  describe "complete SMS building" do
    test "builds complete SMS with all methods" do
      sms =
        SMS.new()
        |> SMS.from("+15551234567")
        |> SMS.to("+15555555555")
        |> SMS.text("Welcome to our service!")
        |> SMS.provider_options(%{priority: "high"})
        |> SMS.put_provider_option(:delivery_receipt, true)
        |> SMS.put_provider_option(:webhook_url, "https://example.com/webhook")

      assert sms.from == "+15551234567"
      assert sms.to == "+15555555555"
      assert sms.text == "Welcome to our service!"
      assert sms.direction == :outbound

      assert sms.provider_options == %{
               priority: "high",
               delivery_receipt: true,
               webhook_url: "https://example.com/webhook"
             }
    end

    test "builds SMS with constructor and chaining" do
      sms =
        SMS.new(id: "msg_123", from: "+15551234567")
        |> SMS.to("+15555555555")
        |> SMS.text("Hello from constructor!")
        |> SMS.put_provider_option(:async, true)

      assert sms.id == "msg_123"
      assert sms.from == "+15551234567"
      assert sms.to == "+15555555555"
      assert sms.text == "Hello from constructor!"
      assert sms.provider_options == %{async: true}
    end
  end
end
