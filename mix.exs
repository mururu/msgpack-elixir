defmodule MessagePack.Mixfile do
  use Mix.Project

  def project do
    [ app: :message_pack,
      version: "0.1.0",
      elixir: "~> 0.12.1-dev",
      deps: deps(Mix.env) ]
  end

  def application do
    []
  end

  defp deps(:test) do
    [{ :properex, github: "mururu/properex", branch: "build" }, # temporary
     { :jsx, github: "talentdeficit/jsx" }]
  end

  defp deps(_) do
    []
  end
end
