defmodule HipcallSMS.Adapters.Test do
  @moduledoc """
  An adapter that sends SMS as messages to the current process.

  This adapter is designed for testing purposes and does not actually send SMS messages
  through any external service. Instead, it sends the SMS struct as a message to the
  current process, allowing you to assert that SMS messages were sent in your tests.

  This is meant to be used during tests and works with the assertions found in
  the [HipcallSMS.TestAssertions](HipcallSMS.TestAssertions.html) module.

  ## Configuration

  The Test adapter does not require any configuration keys, but you can optionally
  configure a shared test process to receive all SMS messages.

  ## Configuration Examples

      # In config/test.exs
      config :hipcall_sms,
        adapter: HipcallSMS.Adapters.Test

      # With shared test process
      config :hipcall_sms,
        adapter: HipcallSMS.Adapters.Test,
        shared_test_process: self()

  ## Usage in Tests

      # Basic test
      test "sends welcome SMS" do
        sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Welcome!")
        {:ok, _response} = HipcallSMS.deliver(sms)

        assert_received {:sms, %SMS{text: "Welcome!"}}
      end

      # With pattern matching
      test "sends SMS with correct details" do
        sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello!")
        {:ok, _response} = HipcallSMS.deliver(sms)

        assert_received {:sms, %SMS{
          from: "+15551234567",
          to: "+15555555555",
          text: "Hello!"
        }}
      end

  ## Process Selection

  The adapter sends messages to processes in the following order of preference:

  1. The process configured in `:shared_test_process` application environment
  2. The current process (`self()`)
  3. Any processes in the `$callers` process dictionary (for GenServer calls)

  """

  use HipcallSMS.Adapter

  alias HipcallSMS.SMS

  @doc """
  Delivers an SMS by sending it as a message to test processes.

  This function does not actually send an SMS through any external service.
  Instead, it sends the SMS struct as a `{:sms, sms}` message to the appropriate
  test processes, allowing you to assert that the SMS was sent in your tests.

  ## Parameters

  - `sms` - The SMS struct containing message details
  - `config` - Configuration (ignored for the test adapter)

  ## Returns

  Always returns `{:ok, %{}}` to simulate successful delivery.

  ## Examples

      # In a test
      sms = SMS.new(from: "+15551234567", to: "+15555555555", text: "Test message")
      {:ok, response} = deliver(sms, [])
      # => {:ok, %{}}

      # Then assert the message was received
      assert_received {:sms, %SMS{text: "Test message"}}

  """
  @impl HipcallSMS.Adapter
  @spec deliver(SMS.t(), Keyword.t()) :: {:ok, map()}
  def deliver(sms, _config) do
    for pid <- pids() do
      send(pid, {:sms, sms})
    end

    {:ok, %{}}
  end

  # Gets the list of processes that should receive SMS messages
  @spec pids() :: [pid()]
  defp pids do
    if pid = Application.get_env(:hipcall_sms, :shared_test_process) do
      [pid]
    else
      Enum.uniq([self() | List.wrap(Process.get(:"$callers"))])
    end
  end
end
