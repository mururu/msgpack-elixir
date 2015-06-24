defmodule MessagePackProperTest do
  use ExUnit.Case, async: false
  use ExCheck

  property :bijective_packing do
    for_all term in msgpack do
      { :ok, bin } = MessagePack.pack(term)
      { :ok, term2 } = MessagePack.unpack(bin)
      term == term2
    end
  end

  property :bijective_str_packing do
    for_all term in msgpack do
      { :ok, bin } = MessagePack.pack(term, enable_string: true)
      { :ok, term2 } = MessagePack.unpack(bin, enable_string: true)
      term == term2
    end
  end

  defp msgpack do
    oneof([
      nil,
      bool,
      real,
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
      # raw32, # do not work, too big binary and to long test
      fixarray,
      fixmap
    ])
  end
  defp msgpack_atomic do
    oneof([nil,bool,real,positive_fixint,uint8,uint16,uint32,uint64,
           negative_fixint,int8,int16,int32,int64,fixraw,raw16])
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
    bind choose(0,31),&binary(&1)
  end
  defp raw16 do
    bind choose(32, 0xFFFF),&binary(&1)
  end
  #defp raw32 do
  #  bind uint32,&binary(&1)
  #end

  defp fixarray do
    bind choose(0, 15), &vector(&1,msgpack_atomic)
  end
  #defp array16
  #defp array32

  defp fixmap do
    bind choose(0, 15), fn size->
      bind vector(size,{msgpack_atomic,msgpack_atomic}), fn kv_vector->
        Enum.into(kv_vector,%{})
      end
    end
  end
  #defp map16
  #defp map32
end
