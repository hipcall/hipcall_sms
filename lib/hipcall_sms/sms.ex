defmodule HipcallSMS.SMS do
  @moduledoc """
  Define a SMS.

  This module defines a `HipcallSMS.SMS` struct and the main functions for composing an SMS.  As it is the contract for
  the public APIs of HipcallSMS it is a good idea to make use of these functions rather than build the struct yourself.

  ## SMS fields

  * `id` - the unique identifier of the SMS, example: `"40385f64-5717-4562-b3fc-2c963f66afa6"`
  * `type` - the type of the SMS (`:sms` or `:mms`), example: `:sms`
  * `direction` - the direction of the SMS (`:outbound` or `:inbound`), example: `:outbound`
  * `from` - the sender of the SMS, example: `"+15551234567"`
  * `to` - the recipient of the SMS, example: `"+15555555555"`
  * `text` - the content of the SMS in plaintext, example: `"Hello"`

  ## Provider options

  This key allow users to make use of provider-specific functionality by passing along addition parameters.

  * `provider_options` - a map of values that are specific to adapter provider, example: `%{async: true}`

  ## Examples

      sms =
        new()
        |> from("+15551234567")
        |> to("+15555555555")
        |> text("Welcome to the Hipcall")

  The composable nature makes it very easy to continue expanding upon a given SMS.

      sms =
        sms
        |> from("+15551234567")
        |> to("+15555555555")
        |> text("Welcome to the Hipcall")

  You can also directly pass arguments to the `new/1` function.

      sms = new(from: "+15551234567", to: "+15555555555", text: "Welcome to the Hipcall!")
  """

  defstruct id: nil,
            direction: :outbound,
            from: nil,
            to: nil,
            text: nil,
            provider_options: %{}

  @type id :: String.t()
  @type direction :: atom()
  @type from :: String.t()
  @type to :: String.t()
  @type text :: String.t()
  @type provider_options :: map()

  @type t :: %__MODULE__{
    id: id,
    direction: direction,
    from: from,
    to: to,
    text: text,
    provider_options: provider_options
  }
end
