defmodule Nvjorn.Mixfile do
  use Mix.Project

  def project do
    [app: :nvjorn,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :yaml_elixir, :httpoison, :poolboy, :ssh, :crypto, :gproc],
     mod: {Nvjorn, []}]
  end

  defp deps do
    [
      {:socket, "~> 0.3"},
      {:httpoison, "~> 0.8"},
      {:poolboy, "~> 1.5"},
      {:yaml_elixir, "~> 1.2"},
      {:gen_icmp, github: "msantos/gen_icmp"},
      {:gproc, "~> 0.5"},

    ]
  end
end
