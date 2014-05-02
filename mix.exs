defmodule MessagePack.Mixfile do
  use Mix.Project

  def project do
    [ app: :message_pack,
      version: "0.1.0",
      elixir: "~> 0.12",
      deps: deps(Mix.env) ]
  end

  def application do
    []
  end

  defp deps(:test) do
    [{ :properex, github: "reset/properex", branch: "elixir-13" },
     { :jsx, github: "talentdeficit/jsx" }]
  end

  defp deps(_) do
    []
  end
end
