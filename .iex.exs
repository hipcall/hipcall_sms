# .iex.exs - IEx configuration file
# This file is automatically loaded when starting IEx with `iex -S mix`

# Import main modules
import HipcallSMS
import HipcallSMS.SMS
import HipcallSMS.Adapter

# Create convenient aliases
alias HipcallSMS.SMS
alias HipcallSMS.Adapter
alias HipcallSMS.Adapters.Twilio
alias HipcallSMS.Adapters.Telnyx
alias HipcallSMS.Adapters.Iletimerkezi
alias HipcallSMS.Adapters.Test

# Print welcome message
IO.puts """

🚀 HipcallSMS modules loaded!

Available modules:
  • HipcallSMS - Main module
  • SMS - SMS functionality
  • Adapter - Base adapter
  • Twilio - Twilio adapter
  • Telnyx - Telnyx adapter
  • Iletimerkezi - Iletimerkezi adapter
  • Test - Test adapter

Example usage:
  iex> SMS.send(%{to: "+1234567890", body: "Hello!"}, Twilio)

"""
