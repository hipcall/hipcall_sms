defmodule HipcallSMS.SMS do
  @moduledoc """
  Define a SMS.

  This module defines a `HipcallSMS.SMS` struct and the main functions for composing an SMS.  As it is the contract for
  the public APIs of HipcallSMS it is a good idea to make use of these functions rather than build the struct yourself.

  ## SMS fields

  * `id` - the unique identifier of the SMS, example: `"40385f64-5717-4562-b3fc-2c963f66afa6"`
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

  @doc """
  Creates a new SMS struct.

  This function creates a new SMS struct with default values. You can optionally
  pass a keyword list to set initial values for the struct fields.

  ## Parameters

  - `attrs` - Optional keyword list of attributes to set on the SMS struct

  ## Returns

  A new `HipcallSMS.SMS` struct with the specified attributes set.

  ## Examples

      # Create an empty SMS struct
      iex> HipcallSMS.SMS.new()
      %HipcallSMS.SMS{direction: :outbound}

      # Create an SMS struct with initial values
      iex> HipcallSMS.SMS.new(from: "+15551234567", to: "+15555555555", text: "Hello")
      %HipcallSMS.SMS{
        direction: :outbound,
        from: "+15551234567",
        to: "+15555555555",
        text: "Hello"
      }

      # Create an SMS struct with all fields
      iex> HipcallSMS.SMS.new(
      ...>   id: "msg_123",
      ...>   from: "+15551234567",
      ...>   to: "+15555555555",
      ...>   text: "Hello World",
      ...>   provider_options: %{priority: "high"}
      ...> )
      %HipcallSMS.SMS{
        id: "msg_123",
        direction: :outbound,
        from: "+15551234567",
        to: "+15555555555",
        text: "Hello World",
        provider_options: %{priority: "high"}
      }

  """
  @spec new(Keyword.t()) :: t()
  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Sets the sender of the SMS.

  This function sets the `from` field of the SMS struct to the specified phone number.
  The phone number should be in E.164 format for best compatibility across providers.

  ## Parameters

  - `sms` - The SMS struct to modify
  - `from` - The sender phone number (E.164 format recommended)

  ## Returns

  The updated SMS struct with the `from` field set.

  ## Examples

      # Set sender with E.164 format
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.from("+15551234567")
      %HipcallSMS.SMS{direction: :outbound, from: "+15551234567"}

      # Set sender with international format
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.from("+442071234567")
      %HipcallSMS.SMS{direction: :outbound, from: "+442071234567"}

      # Chain with other functions
      iex> HipcallSMS.SMS.new()
      ...> |> HipcallSMS.SMS.from("+15551234567")
      ...> |> HipcallSMS.SMS.to("+15555555555")
      ...> |> HipcallSMS.SMS.text("Hello!")
      %HipcallSMS.SMS{
        direction: :outbound,
        from: "+15551234567",
        to: "+15555555555",
        text: "Hello!"
      }

  """
  @spec from(t(), String.t()) :: t()
  def from(%__MODULE__{} = sms, from) do
    %{sms | from: from}
  end

  @doc """
  Sets the recipient of the SMS.

  This function sets the `to` field of the SMS struct to the specified phone number.
  The phone number should be in E.164 format for best compatibility across providers.

  ## Parameters

  - `sms` - The SMS struct to modify
  - `to` - The recipient phone number (E.164 format recommended)

  ## Returns

  The updated SMS struct with the `to` field set.

  ## Examples

      # Set recipient with E.164 format
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.to("+15555555555")
      %HipcallSMS.SMS{direction: :outbound, to: "+15555555555"}

      # Set recipient with international format
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.to("+33123456789")
      %HipcallSMS.SMS{direction: :outbound, to: "+33123456789"}

      # Chain with other functions
      iex> HipcallSMS.SMS.new()
      ...> |> HipcallSMS.SMS.from("+15551234567")
      ...> |> HipcallSMS.SMS.to("+15555555555")
      %HipcallSMS.SMS{
        direction: :outbound,
        from: "+15551234567",
        to: "+15555555555"
      }

  """
  @spec to(t(), String.t()) :: t()
  def to(%__MODULE__{} = sms, to) do
    %{sms | to: to}
  end

  @doc """
  Sets the text content of the SMS.

  This function sets the `text` field of the SMS struct to the specified message content.
  The text should be plain text. Different providers have different limits for SMS length,
  typically 160 characters for single SMS or up to 1600 characters for concatenated SMS.

  ## Parameters

  - `sms` - The SMS struct to modify
  - `text` - The message content as plain text

  ## Returns

  The updated SMS struct with the `text` field set.

  ## Examples

      # Set simple message
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.text("Hello World")
      %HipcallSMS.SMS{direction: :outbound, text: "Hello World"}

      # Set longer message
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.text("This is a longer message that demonstrates multi-part SMS capability.")
      %HipcallSMS.SMS{direction: :outbound, text: "This is a longer message that demonstrates multi-part SMS capability."}

      # Set message with special characters
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.text("Hello! 🎉 Welcome to our service.")
      %HipcallSMS.SMS{direction: :outbound, text: "Hello! 🎉 Welcome to our service."}

      # Chain with other functions
      iex> HipcallSMS.SMS.new()
      ...> |> HipcallSMS.SMS.from("+15551234567")
      ...> |> HipcallSMS.SMS.to("+15555555555")
      ...> |> HipcallSMS.SMS.text("Welcome to our service!")
      %HipcallSMS.SMS{
        direction: :outbound,
        from: "+15551234567",
        to: "+15555555555",
        text: "Welcome to our service!"
      }

  """
  @spec text(t(), String.t()) :: t()
  def text(%__MODULE__{} = sms, text) do
    %{sms | text: text}
  end

  @doc """
  Sets provider-specific options for the SMS.

  This function replaces the entire `provider_options` map with the provided options.
  Provider options allow you to use provider-specific features that are not part
  of the standard SMS fields.

  ## Parameters

  - `sms` - The SMS struct to modify
  - `options` - A map of provider-specific options

  ## Returns

  The updated SMS struct with the `provider_options` field set.

  ## Examples

      # Set Twilio-specific options
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.provider_options(%{status_callback: "https://example.com/webhook"})
      %HipcallSMS.SMS{direction: :outbound, provider_options: %{status_callback: "https://example.com/webhook"}}

      # Set Telnyx-specific options
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.provider_options(%{messaging_profile_id: "profile_123", webhook_url: "https://example.com/webhook"})
      %HipcallSMS.SMS{direction: :outbound, provider_options: %{messaging_profile_id: "profile_123", webhook_url: "https://example.com/webhook"}}

      # Set multiple options
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.provider_options(%{
      ...>   priority: "high",
      ...>   delivery_receipt: true,
      ...>   validity_period: 3600
      ...> })
      %HipcallSMS.SMS{
        direction: :outbound,
        provider_options: %{
          priority: "high",
          delivery_receipt: true,
          validity_period: 3600
        }
      }

  """
  @spec provider_options(t(), map()) :: t()
  def provider_options(%__MODULE__{} = sms, options) when is_map(options) do
    %{sms | provider_options: options}
  end

  @doc """
  Puts a single provider-specific option for the SMS.

  This function adds or updates a single key-value pair in the `provider_options` map
  without affecting other existing options. This is useful when you want to add
  provider-specific options incrementally.

  ## Parameters

  - `sms` - The SMS struct to modify
  - `key` - The option key (atom or string)
  - `value` - The option value

  ## Returns

  The updated SMS struct with the new option added to `provider_options`.

  ## Examples

      # Add a single option
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.put_provider_option(:async, true)
      %HipcallSMS.SMS{direction: :outbound, provider_options: %{async: true}}

      # Add multiple options incrementally
      iex> HipcallSMS.SMS.new()
      ...> |> HipcallSMS.SMS.put_provider_option(:priority, "high")
      ...> |> HipcallSMS.SMS.put_provider_option(:delivery_receipt, true)
      %HipcallSMS.SMS{
        direction: :outbound,
        provider_options: %{priority: "high", delivery_receipt: true}
      }

      # Add to existing options
      iex> sms = HipcallSMS.SMS.new() |> HipcallSMS.SMS.provider_options(%{existing: "value"})
      iex> sms |> HipcallSMS.SMS.put_provider_option(:new_option, "new_value")
      %HipcallSMS.SMS{
        direction: :outbound,
        provider_options: %{existing: "value", new_option: "new_value"}
      }

      # Use with string keys
      iex> HipcallSMS.SMS.new() |> HipcallSMS.SMS.put_provider_option("webhook_url", "https://example.com/webhook")
      %HipcallSMS.SMS{direction: :outbound, provider_options: %{"webhook_url" => "https://example.com/webhook"}}

  """
  @spec put_provider_option(t(), atom() | String.t(), any()) :: t()
  def put_provider_option(%__MODULE__{} = sms, key, value) do
    %{sms | provider_options: Map.put(sms.provider_options, key, value)}
  end
end
