defmodule HipcallSMS.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: HipcallSMSFinch}
      # Starts a worker by calling: HipcallSMS.Worker.start_link(arg)
      # {HipcallSMS.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HipcallSMS.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Returns the list of child specifications for the application supervisor.

  Currently returns an empty list as the application has no children to supervise
  beyond the initial setup in start/2.
  """
  def children do
    []
  end
end
