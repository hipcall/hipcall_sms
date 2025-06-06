ExUnit.start()

# Set up configuration for doctests
# This doctest expects api_key to be "secret123"
Application.put_env(:hipcall_sms, :api_key, "secret123")

# This doctest expects timeout to resolve to 5000 from environment
Application.put_env(:hipcall_sms, :timeout, {:system, :integer, "SMS_TIMEOUT"})

# Set up environment variables for doctests
System.put_env("SMS_TIMEOUT", "5000")
System.put_env("SMS_API_KEY", "secret123")

# Clean up function to reset config for tests that need defaults
defmodule TestHelper do
  def reset_config do
    Application.delete_env(:hipcall_sms, :api_key)
    Application.delete_env(:hipcall_sms, :timeout)
  end

  def setup_doctest_config do
    Application.put_env(:hipcall_sms, :api_key, "secret123")
    Application.put_env(:hipcall_sms, :timeout, {:system, :integer, "SMS_TIMEOUT"})
  end
end
