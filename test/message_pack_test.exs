Code.require_file "../test_helper.exs", __FILE__

defmodule MessagePackTest do
  use ExUnit.Case

  def check(term) do
    assert term |> MessagePack.pack |> MessagePack.unpack == term
  end

  test "integer" do
     [0, 1, 127, 128, 255, 256, 65535, 65536, 8388608, 0xFFFFFFFFFF, -1, -32, -33, -128, -129, -32768, -32769, 0xFFFFFFFFFF] |> Enum.each check(&1)
  end

  test "float" do
    [0.0, 1.0, -1.0] |> Enum.each check(&1)
  end

  test "binary" do
    ["", "hoge", "ほげ", <<"hoge">>, << "hoge", 2, 255, 1>>] |> Enum.each check(&1)
  end

  test "array" do
    [[], :lists.seq(0, 16), :lists.seq(0, 0x10000), [[], nil]] |> Enum.each check(&1)
  end

  test "map" do
    [{[]}, { :lists.seq(0, 0x10000) |> Enum.map(fn(i)-> {i, i*2} end) }] |> Enum.each check(&1)
  end

  test "boolean" do
    [true, false] |> Enum.each check(&1)
  end

  test "nil" do
    check(nil)
  end

  test "atom" do
    Enum.each [:a, :"-111"], fn(term)->
      assert term |> MessagePack.pack |> MessagePack.unpack == to_binary(term)
    end
  end

  test "unpack_all" do
    assert MessagePack.unpack(<<1, 2>>, all: true) == [1, 2]
  end

  test "unpack_rest" do
    assert MessagePack.unpack(<<1, 2>>, rest: true) == { 1, <<2>>}
  end
end
