defmodule HipcallSMS.Adapters.Test do
  @moduledoc """
  An adapter that sends SMS as messages to the current process.

  This is meant to be used during tests and works with the assertions found in
  the [HipcallSMS.TestAssertions](HipcallSMS.TestAssertions.html) module.

  ## Example

      # config/test.exs
      config :hipcall_sms, HipcallSMS.Adapter.Test,
        adapter: HipcallSMS.Adapters.Test

      # lib/hipcall_sms/adapter.ex
      defmodule HipcallSMS.Adapter do
        use HipcallSMS.Adapter, otp_app: :hipcall_sms
      end
  """

  use HipcallSMS.Adapter

  def deliver(sms, _config) do
    for pid <- pids() do
      send(pid, {:sms, sms})
    end

    {:ok, %{}}
  end

  defp pids do
    if pid = Application.get_env(:hipcall_sms, :shared_test_process) do
      [pid]
    else
      Enum.uniq([self() | List.wrap(Process.get(:"$callers"))])
    end
  end
end
