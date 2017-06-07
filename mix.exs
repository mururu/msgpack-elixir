defmodule MessagePack.Mixfile do
  use Mix.Project

  def project do
    [ app: :message_pack,
      version: "0.2.0",
      elixir: "~> 1.0 or ~> 0.15.1",
      deps: deps,
      build_per_environment: false,

      name: "MessagePack",
      source_url: "https://github.com/mururu/msgpack-elixir",
      description: "MessagePack Implementation for Elixir",
      package: package ]
  end

  def application do
    []
  end

  defp deps do
    [{ :excheck, "~> 0.2.0", only: :test },
     {:triq, github: "krestenkrab/triq", only: :test},
     { :poison, "~> 1.2.0", only: :test },]
  end

  defp package do
    [ contributors: ["Yuki Ito"],
      licenses: ["MIT"],
      links: %{ "GitHub" => "https://github.com/mururu/msgpack-elixir"} ]
  end
end
