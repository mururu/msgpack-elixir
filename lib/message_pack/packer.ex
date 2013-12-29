defmodule MessagePack.Packer do
  def pack(term, options // []) do
    case MessagePack.Packer.Protocol.pack(term, options) do
      { :error, _ } = error ->
        error
      packed ->
        { :ok, packed }
    end
  end

  def pack!(term, options // []) do
    case pack(term, optinos) do
      { :ok, packed } ->
        packed
      { :error, error } ->
        raise ArgumentError, message: error
    end
  end
end

defprotocol MessagePack.Packer.Protocol do
  def pack(term, options)
end

defimpl MessagePack.Packer.Protocol, for: Integer do
  def pack(i, _) when i < 0, do: pack_int(i)
  def pack(i, _), do: pack_uint(i)

  defp pack_int(i) when i >= -32,                  do: << 0b111 :: 3, i :: 5 >>
  defp pack_int(i) when i >= -128,                 do: << 0xD0  :: 8, i :: [8,  big, signed, integer, unit(1)] >>
  defp pack_int(i) when i >= -0x8000,              do: << 0xD1  :: 8, i :: [16, big, signed, integer, unit(1)] >>
  defp pack_int(i) when i >= -0x80000000,          do: << 0xD2  :: 8, i :: [32, big, signed, integer, unit(1)] >>
  defp pack_int(i) when i >= -0x8000000000000000 , do: << 0xD3  :: 8, i :: [64, big, signed, integer, unit(1)] >>
  defp pack_int(i), do: { :error, { :too_big, i } }

  defp pack_uint(i) when i < 0x80,                do: << 0    :: 1, i :: 7 >>
  defp pack_uint(i) when i < 0x100,               do: << 0xCC :: 8, i :: 8 >>
  defp pack_uint(i) when i < 0x10000,             do: << 0xCD :: 8, i :: [16, big, unsigned, integer, unit(1)] >>
  defp pack_uint(i) when i < 0x100000000,         do: << 0xCE :: 8, i :: [32, big, unsigned, integer, unit(1)] >>
  defp pack_uint(i) when i < 0x10000000000000000, do: << 0xCF :: 8, i :: [64, big, unsigned, integer, unit(1)] >>
  defp pack_uint(i), do: { :error, { :too_big, i } }
end

defimpl MessagePack.Packer.Protocol, for: Float do
  def pack(f, _), do: << 0xCB :: size(8), f :: [size(64), big, float, unit(1)]>>
end

defimpl MessagePack.Packer.Protocol, for: Atom do
  def pack(nil, _),        do: << 0xC0 :: size(8) >>
  def pack(false, _),      do: << 0xC2 :: size(8) >>
  def pack(true, _),       do: << 0xC3 :: size(8) >>
  def pack(atom, _),       do: MessagePack.Packer.pack(atom_to_binary(atom))
end

defimpl MessagePack.Packer.Protocol, for: BitString do
  def pack(binary, options) when is_binary(binary) do
    if options[:enable_string] do
      if String.valid?(binary) do
        pack_raw(binary)
      else
        pack_raw2(binary)
      end
    else
      pack_raw(binary)
    end
  end

  # for string format and old raw format
  defp pack_raw(binary) when byte_size(binary) < 32 do
    << 0b101 :: 3, byte_size(binary) :: 5, binary :: binary >>
  end
  defp pack_raw(binary) when byte_size(binary) < 0x100 do
    << 0xD9  :: 8, byte_size(binary) :: [8,  big, unsigned, integer, unit(1)], binary :: binary >>
  end
  defp pack_raw(binary) when byte_size(binary) < 0x10000 do
    << 0xDA  :: 8, byte_size(binary) :: [16, big, unsigned, integer, unit(1)], binary :: binary >>
  end
  defp pack_raw(binary) when byte_size(binary) < 0x100000000 do
    << 0xDB  :: 8, byte_size(binary) :: [32, big, unsigned, integer, unit(1)], binary :: binary >>
  end
  defp pack_raw(binary), do: { :error, { :too_big, binary } }

  # for binary format
  defp pack_raw2(binary) when byte_size(binary) < 0x100 do
    << 0xC4  :: 8, byte_size(binary) :: [8,  big, unsigned, integer, unit(1)], binary :: binary >>
  end
  defp pack_raw2(binary) when byte_size(binary) < 0x10000 do
    << 0xC5  :: 8, byte_size(binary) :: [16, big, unsigned, integer, unit(1)], binary :: binary >>
  end
  defp pack_raw2(binary) when byte_size(binary) < 0x100000000 do
    << 0xC6  :: 8, byte_size(binary) :: [32, big, unsigned, integer, unit(1)], binary :: binary >>
  end
  defp pack_raw2(binary) do
    { :error, { :too_big, binary } }
  end
end

defimpl MessagePack.Packer.Protocol, for: List do
  def pack(list, options) do
    if map?(list) do
      pack_map(list, options)
    else
      pack_array(list, options)
    end
  end

  defp pack_map([{}], options), do: pack_map([], options)
  defp pack_map(map, options) do
    case length(map) do
      len when len < 16 ->
        << 0b1000 :: 4, len :: [4, integer, unit(1)],
          (bc { k, v } inlist map, do: << MessagePack.Packer.Protocol.pack(k, options) :: binary,
                                          MessagePack.Packer.Protocol.pack(v, options) :: binary >>) :: binary >>
      len when len < 0x10000 ->
        << 0xDE :: 8, len :: [16, big, unsigned, integer, unit(1)],
          (bc { k, v } inlist map, do: << MessagePack.Packer.Protocol.pack(k, options) :: binary,
                                          MessagePack.Packer.Protocol.pack(v, options) :: binary >>) :: binary >>
      len when len < 0x100000000 ->
        << 0xDF :: 8, len :: [32, big, unsigned, integer, unit(1)],
          (bc { k, v } inlist map, do: << MessagePack.Packer.Protocol.pack(k, options) :: binary,
                                          MessagePack.Packer.Protocol.pack(v, options) :: binary >>) :: binary >>
      _ ->
        { :error, { :too_big, map } }
    end
  end

  defp pack_array(list, options) do
    case length(list) do
      len when len < 16 ->
        << 0b1001 :: 4, len :: [4, integer, unit(1)],
          (bc term inlist list, do: << MessagePack.Packer.Protocol.pack(term, options) :: binary >>) :: binary >>
      len when len < 0x10000 ->
        << 0xDC :: 8, len :: [16, big, unsigned, integer, unit(1)],
          (bc term inlist list, do: << MessagePack.Packer.Protocol.pack(term, options) :: binary >>) :: binary >>
      len when len < 0x100000000 ->
        << 0xDD :: 8, len :: [32, big, unsigned, integer, unit(1)],
          (bc term inlist list, do: << MessagePack.Packer.Protocol.pack(term, options) :: binary >>) :: binary >>
      _ ->
        { :error, { :too_big, list } }
    end
  end

  defp map?([]), do: false
  defp map?([{}]), do: true
  defp map?(list) when is_list(list), do: :lists.all(&map_tuple?/1, list)
  defp map?(_), do: false

  defp map_tuple?({ key, _ }) when is_atom(key) or is_binary(key), do: true
  defp map_tuple?(_), do: false
end
