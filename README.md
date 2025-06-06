# HipcallSMS

[![Hex.pm Version](https://img.shields.io/hexpm/v/hipcall_sms)](https://hex.pm/packages/hipcall_sms)
[![Hex.pm Download Total](https://img.shields.io/hexpm/dt/hipcall_sms)](https://hex.pm/packages/hipcall_sms)

Find out what the website is built with using this package.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hipcall_sms` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hipcall_sms, "~> 0.1.0"}
  ]
end
```

## Configuration

You can configure providers in your `config.exs`:

```
config :hipcall_sms,
  adapter: HipcallSMS.Adapters.Telnyx,
  telnyx_api_key: {:system, "TELNYX_API_KEY"},
  twilio_account_sid: {:system, "TWILIO_ACCOUNT_SID"},
  twilio_auth_token: {:system, "TWILIO_AUTH_TOKEN"},
  iletimerkezi_key: {:system, "ILETIMERKEZI_KEY"},
  iletimerkezi_hash: {:system, "ILETIMERKEZI_HASH"}
```

## Use

Documentation for using, please check the `HipcallSMS` module.

### Example

```elixir
# Create and send an SMS
sms =
  HipcallSMS.SMS.new()
  |> HipcallSMS.SMS.from("+15551234567")
  |> HipcallSMS.SMS.to("+15555555555")
  |> HipcallSMS.SMS.text("Hello from HipcallSMS!")

HipcallSMS.deliver(sms)

# Or with configuration override
config = [
  adapter: HipcallSMS.Adapters.Twilio,
  account_sid: "your_account_sid",
  auth_token: "your_auth_token"
]

HipcallSMS.deliver(sms, config)

# Quick send
HipcallSMS.send_sms("+15551234567", "+15555555555", "Hello!")
```

## Hipcall

All [Hipcall](https://www.hipcall.com/en/) libraries:

- [HipcallDisposableEmail](https://github.com/hipcall/hipcall_disposable_email) - Simple library checking the email's domain is disposable or not.
- [HipcallDeepgram](https://github.com/hipcall/hipcall_deepgram) - Unofficial Deepgram API Wrapper written in Elixir.
- [HipcallOpenai](https://github.com/hipcall/hipcall_openai) - Unofficial OpenAI API Wrapper written in Elixir.
- [HipcallWhichtech](https://github.com/hipcall/hipcall_whichtech) - Find out what the website is built with.

