defmodule MessagePackCasesTest do
  use ExUnit.Case

  defp unpack_all(binary) do
    do_unpack_all(binary, []) |> Enum.reverse
  end

  defp do_unpack_all("", acc), do: acc
  defp do_unpack_all(binary, acc) do
    { term, rest } = MessagePack.unpack_once!(binary)
    do_unpack_all(rest, [term|acc])
  end

  defp nillify(:null), do: nil
  defp nillify(other), do: other

  test "compare with json" do
    from_msg  = Path.expand("cases.msg", __DIR__)
                |> File.read!
                |> unpack_all

    from_json = Path.expand("cases.json", __DIR__)
                |> File.read!
                |> :jsx.decode
                |> Enum.map &nillify(&1)

    Enum.zip(from_msg, from_json) |> Enum.map fn({term1, term2})->
      assert term1 == term2
    end
  end
end
