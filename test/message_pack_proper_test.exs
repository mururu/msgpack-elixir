defmodule MessagePackProperTest do
  use ExUnit.Case
  use Proper.Properties

  test "pack -> unpack" do
    fun = fn ->
      forall term in msgpack do
        { :ok, bin } = MessagePack.pack(term)
        { :ok, { term2, <<>> } } = MessagePack.unpack(bin)
        term == term2
      end
    end
    ExUnit.CaptureIO.capture_io fn ->
      assert Proper.quickcheck(fun.(), numtests: 100) == true
    end
  end

  test "pack -> unpack with str" do
    fun = fn ->
      forall term in msgpack do
        { :ok, bin } = MessagePack.pack(term, enable_string: true)
        { :ok, { term2, <<>> } } = MessagePack.unpack(bin, enable_string: true)
        term == term2
      end
    end
    ExUnit.CaptureIO.capture_io fn ->
      assert Proper.quickcheck(fun.(), numtests: 100) == true
    end
  end

  defp msgpack do
    oneof([
      nil,
      boolean,
      float,
      positive_fixint,
      uint8,
      uint16,
      uint32,
      uint64,
      negative_fixint,
      int8,
      int16,
      int32,
      int64,
      fixraw,
      raw16,
      raw32,
      fixarray,
      fixmap
    ])
  end

  defp positive_fixint, do: choose(0, 127)
  defp uint8, do: choose(128, 0xFF)
  defp uint16, do: choose(0x100, 0xFFFF)
  defp uint32, do: choose(0x10000, 0xFFFFFFFF)
  defp uint64, do: choose(0x100000000, 0xFFFFFFFFFFFFFFFF)

  defp negative_fixint, do: choose(-32, -1)
  defp int8, do: choose(-0x80, -33)
  defp int16, do: choose(-0x8000, -0x81)
  defp int32, do: choose(-0x80000000, -0x8001)
  defp int64, do: choose(-0x8000000000000000, -0x80000001)

  defp fixraw do
    let size = choose(0, 31) do
      let bin = binary(size), do: bin
    end
  end
  defp raw16 do
    let size = choose(32, 0xFFFF) do
      let bin = binary(size), do: bin
    end
  end
  defp raw32 do
    let size = uint32 do
      let bin = binary(size), do: bin
    end
  end

  defp fixarray do
    let size = choose(0, 15) do
      :proper_gen.list_gen(size, msgpack())
    end
  end
  #defp array16
  #defp array32

  defp fixmap do
    let size = choose(0, 15) do
      :proper_gen.list_gen(size, {msgpack(), msgpack()})
    end
  end
  #defp map16
  #defp map32
end
