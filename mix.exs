defmodule HipcallSMS.MixProject do
  use Mix.Project

  @source_url "https://github.com/hipcall/hipcall_sms"
  @version "0.2.0"

  def project do
    [
      app: :hipcall_sms,
      name: "HipcallSMS",
      description: "SMS SDK for different providers",
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {HipcallSMS.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.19"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  def package do
    [
      maintainers: ["Onur Ozgur OZKAN"],
      licenses: ["MIT"],
      links: %{
        "Website" => "https://www.hipcall.com/en/",
        "GitHub" => @source_url
      }
    ]
  end

  def docs do
    [
      main: "readme",
      name: "HipcallSMS",
      canonical: "https://hex.pm/packages/hipcall_sms",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"]
    ]
  end
end
