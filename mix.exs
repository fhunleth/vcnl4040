defmodule Vcnl4040.MixProject do
  use Mix.Project

  def project do
    [
      app: :vcnl4040,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_i2c, "~> 2.0"},
      {:circuits_gpio, "~> 2.0"},
      {:circular_buffer, "~> 0.4.1"}
    ]
  end
end