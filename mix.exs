defmodule MessagePack.Mixfile do
  use Mix.Project

  def project do
    [ app: :message_pack,
      version: "0.0.1",
      elixir: "~> 0.12.1-dev",
      deps: deps(Mix.env) ]
  end

  def application do
    []
  end

  defp deps(:test) do
    [{ :properex, github: "yrashk/properex" }]
  end

  defp deps(_) do
    []
  end
end
