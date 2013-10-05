Code.require_file "../test_helper.exs", __FILE__

defmodule MessagePackTest do
  use ExUnit.Case

  def check(term) do
    assert term |> MessagePack.pack |> MessagePack.unpack == term
  end

  test "integer" do
     [0, 1, 127, 128, 255, 256, 65535, 65536, 8388608, 0xFFFFFFFFFF, -1, -32, -33, -128, -129, -32768, -32769, 0xFFFFFFFFFF] |> Enum.each &check(&1)
  end

  test "float" do
    [0.0, 1.0, -1.0] |> Enum.each &check(&1)
  end

  test "binary" do
    ["", "hoge", "ほげ", <<"hoge">>, << "hoge", 2, 255, 1>>] |> Enum.each &check(&1)
  end

  test "array" do
    [[], :lists.seq(0, 16), :lists.seq(0, 0x10000), [[], nil]] |> Enum.each &check(&1)
  end

  test "map" do
    [{[]}, { :lists.seq(0, 0x10000) |> Enum.map(fn(i)-> {i, i*2} end) }] |> Enum.each &check(&1)
  end

  test "boolean" do
    [true, false] |> Enum.each &check(&1)
  end

  test "nil" do
    check(nil)
  end

  test "atom" do
    Enum.each [:a, :"-111"], fn(term)->
      assert term |> MessagePack.pack |> MessagePack.unpack == to_string(term)
    end
  end

  test "extra bytes error" do
    assert_raise MessagePack.ExtraBytesError, "Extra bytes follow after a deserialized object.\nExtra bytes: #{inspect << 2 >>}", fn->
      MessagePack.unpack(<< 1, 2 >>)
    end
  end

  test "incomplete data error" do
    assert_raise MessagePack.IncompleteDataError, "Incomplete data: #{ inspect <<>> }", fn->
      MessagePack.unpack(<<>>)
    end
  end

  def check_invalid_prefix(prefix) do
    assert_raise MessagePack.InvalidPrefixError, "Invalid prefix: #{inspect prefix}", fn->
      MessagePack.unpack(<< prefix >>)
    end
  end

  test "invalid prefix" do
    [0xC1, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
     0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9] |> Enum.each &check_invalid_prefix(&1)
  end

  test "unpack_stream" do
    assert MessagePack.unpack_stream(<<1, 2>>) == { 1, <<2>> }
  end


  def unpack_all(binary) do
    do_unpack_all(binary, []) |> Enum.reverse
  end

  def do_unpack_all(<<>>, acc) do
    acc
  end
  def do_unpack_all(binary, acc) do
    {term, rest} = MessagePack.unpack_stream(binary)
    do_unpack_all(rest, [term|acc])
  end

  def nillify(term) do
    case term do
      :null -> nil
      other -> other
    end
  end

  test "compare with json" do
    from_msg  = Path.expand("../cases.msg", __FILE__)  |> File.read! |> unpack_all
    from_json = Path.expand("../cases.json", __FILE__) |> File.read! |> :jiffy.decode |> Enum.map &nillify(&1)

    Enum.zip(from_msg, from_json) |> Enum.each fn({term1, term2})->
      assert term1 == term2
    end
  end
end
