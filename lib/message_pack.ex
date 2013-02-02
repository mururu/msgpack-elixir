defmodule MessagePack do
  defdelegate pack(term),     to: MessagePack.Packer

  def unpack(binary, options // []) do
    if options[:all] do
      MessagePack.Unpacker.unpack_all(binary)
    else
      MessagePack.Unpacker.unpack(binary)
    end
  end
end

#pack
defprotocol MessagePack.Packer do
  def pack(term)
end

defimpl MessagePack.Packer, for: Number do
  def pack(i) when is_integer(i) and i < 0, do: pack_int(i)
  def pack(i) when is_integer(i),           do: pack_uint(i)
  def pack(f) when is_float(f),             do: pack_double(f)

  defp pack_uint(i) when i < 128,        do: << 0b0  :: size(1), i :: size(7) >>
  defp pack_uint(i) when i < 256,        do: << 0xCC :: size(8), i :: size(8) >>
  defp pack_uint(i) when i < 0x10000,    do: << 0xCD :: size(8), i :: [size(16), big, unsigned, integer, unit(1)] >>
  defp pack_uint(i) when i < 0xFFFFFFFF, do: << 0xCE :: size(8), i :: [size(32), big, unsigned, integer, unit(1)] >>
  defp pack_uint(i),                     do: << 0xCF :: size(8), i :: [size(64), big, unsigned, integer, unit(1)] >>

  defp pack_int(i) when i >= -32,        do: << 0b111 :: size(3), i :: size(5)>>
  defp pack_int(i) when i > -128,        do: << 0xD0  :: size(8), i :: [size(8),  big, signed, integer, unit(1)] >>
  defp pack_int(i) when i > -0x8000,     do: << 0xD1  :: size(8), i :: [size(16), big, signed, integer, unit(1)] >>
  defp pack_int(i) when i > -0x80000000, do: << 0xD2  :: size(8), i :: [size(32), big, signed, integer, unit(1)] >>
  defp pack_int(i),                      do: << 0xD3  :: size(8), i :: [size(64), big, signed, integer, unit(1)] >>

  defp pack_double(f), do: << 0xCB :: size(8), f :: [size(64), big, float, unit(1)]>>
end

defimpl MessagePack.Packer, for: BitString do
  def pack(binary) when byte_size(binary) < 32,      do: << 0b101 :: size(3),  byte_size(binary) :: size(5),                                binary :: binary >>
  def pack(binary) when byte_size(binary) < 0x10000, do: << 0xDA  :: size(16), byte_size(binary) :: [size(16), unsigned, integer, unit(1)], binary :: binary >>
  def pack(binary),                                  do: << 0xDA  :: size(32), byte_size(binary) :: [size(16), unsigned, integer, unit(1)], binary :: binary >>
end

defimpl MessagePack.Packer, for: List do
  def pack(list) do
    case length(list) do
      len when len < 16 ->
        << 0b1001 :: size(4), len :: [size(4), integer, unit(1)], (pack_array(list)) :: binary >>
      len when len < 0x10000 ->
        << 0xDC :: size(8),   len :: [size(16), big, unsigned, integer, unit(1)], (pack_array(list)) :: binary >>
      len ->
        << 0xDD :: size(8),   len :: [size(32), big, unsigned, integer, unit(1)], (pack_array(list)) :: binary >>
    end
  end

  defp pack_array(list) do
    do_pack_array(list, []) |> Enum.reverse |> list_to_binary
  end

  defp do_pack_array([], acc), do: acc
  defp do_pack_array([term|rest], acc) do
    do_pack_array(rest, [MessagePack.Packer.pack(term)|acc])
  end
end

defimpl MessagePack.Packer, for: Tuple do
  def pack({map}) when is_list(map) do
    case length(map) do
      len when len < 16 ->
        << 0b1000 :: size(4), len :: [size(4), integer, unit(1)], (pack_map(map)) :: binary >>
      len when len < 0x10000 ->
        << 0xDE :: size(8), len :: [size(16), big, unsigned, integer, unit(1)], (pack_map(map)) :: binary >>
      len ->
        << 0xDF :: size(8), len :: [size(32), big, unsigned, integer, unit(1)], (pack_map(map)) :: binary >>
    end
  end

  defp pack_map(map) do
    do_pack_map(map, []) |> Enum.reverse |> list_to_binary
  end

  defp do_pack_map([], acc), do: acc
  defp do_pack_map([{key, value}|rest], acc) do
    do_pack_map(rest, [MessagePack.Packer.pack(value), MessagePack.Packer.pack(key)|acc])
  end
end

defimpl MessagePack.Packer, for: Atom do
  def pack(nil),        do: << 0xC0 :: size(8) >>
  def pack(false),      do: << 0xC2 :: size(8) >>
  def pack(true),       do: << 0xC3 :: size(8) >>
  def pack(other_atom), do: MessagePack.Packer.pack(atom_to_binary(other_atom))
end

#unpack
defmodule MessagePack.Unpacker do
  def unpack(binary) when is_binary(binary) do
    case do_unpack(binary) do
      { result, <<>> } ->
        result
      { result, rest } when is_binary(rest) ->
        raise "extra bytes follow after a deserialized object"
      _ ->
        raise "unpack error"
    end
  end

  def unpack_all(binary) when is_binary(binary) do
    do_unpack_all(binary, []) |> Enum.reverse
  end

  def do_unpack_all(binary, acc) do
    case do_unpack(binary) do
      { term, <<>> } ->
        [term|acc]
      { _, rest } when byte_size(binary) == byte_size(rest) ->
        raise "unpack failed"
      { term, rest } when is_binary(binary) ->
        do_unpack_all(rest, [term|acc])
    end
  end

  #atom
  defp do_unpack(<< 0xC0, rest :: binary >>), do: { nil, rest }
  defp do_unpack(<< 0xC2, rest :: binary >>), do: { false, rest }
  defp do_unpack(<< 0xC3, rest :: binary >>), do: { true, rest }

  #float
  defp do_unpack(<< 0xCA, float :: [size(32), float, unit(1)], rest :: binary >>), do: { float, rest }
  defp do_unpack(<< 0xCB, float :: [size(64), float, unit(1)], rest :: binary >>), do: { float, rest }

  # unsigned integer
  defp do_unpack(<< 0xCC, uint :: [size(8), unsigned, integer], rest :: binary >>), do: { uint, rest }
  defp do_unpack(<< 0xCD, uint :: [size(16), big, unsigned, integer, unit(1)], rest :: binary >>), do: { uint, rest }
  defp do_unpack(<< 0xCE, uint :: [size(32), big, unsigned, integer, unit(1)], rest :: binary >>), do: { uint, rest }
  defp do_unpack(<< 0xCF, uint :: [size(64), big, unsigned, integer, unit(1)], rest :: binary >>), do: { uint, rest }

  # signed integer
  defp do_unpack(<< 0xD0, int :: [size(8), signed, integer], rest :: binary >>), do: { int, rest }
  defp do_unpack(<< 0xD1, int :: [size(16), big, signed, integer, unit(1)], rest :: binary >>), do: { int, rest }
  defp do_unpack(<< 0xD2, int :: [size(32), big, signed, integer, unit(1)], rest :: binary >>), do: { int, rest }
  defp do_unpack(<< 0xD3, int :: [size(64), big, signed, integer, unit(1)], rest :: binary >>), do: { int, rest }

  # binary
  defp do_unpack(<< 0xDA, binary :: [size(16), unsigned, integer, unit(1)], rest :: binary >>), do: { binary, rest }
  defp do_unpack(<< 0xDB, binary :: [size(32), unsigned, integer, unit(1)], rest :: binary >>), do: { binary, rest }

  # array
  defp do_unpack(<< 0xDC, len :: [size(16), big, unsigned, integer, unit(1)], rest :: binary >>), do: unpack_array(rest, len)
  defp do_unpack(<< 0xDD, len :: [size(32), big, unsigned, integer, unit(1)], rest :: binary >>), do: unpack_array(rest, len)

  # map
  defp do_unpack(<< 0xDE, len :: [size(16), big, unsigned, integer, unit(1)], rest :: binary >>), do: unpack_map(rest, len)
  defp do_unpack(<< 0xDF, len :: [size(32), big, unsigned, integer, unit(1)], rest :: binary >>), do: unpack_map(rest, len)

  defp do_unpack(<< 0 :: size(1), v :: size(7), rest :: binary >>), do: { v, rest }
  defp do_unpack(<< 0b111 :: size(3), v :: size(5), rest :: binary >>), do: { v - 0b100000, rest }
  defp do_unpack(<< 0b101 :: size(3), len :: size(5), v :: [size(len), binary], rest :: binary >>), do: { v, rest }
  defp do_unpack(<< 0b1001 :: size(4), len :: size(4), rest :: binary >>), do: unpack_array(rest, len)
  defp do_unpack(<< 0b1000 :: size(4), len :: size(4), rest :: binary >>), do: unpack_map(rest, len)

  defp unpack_array(binary, len) do
    do_unpack_array(binary, len, [])
  end

  defp do_unpack_array(rest, 0, acc) do
    { :lists.reverse(acc), rest }
  end
  defp do_unpack_array(binary, len, acc) do
    case do_unpack(binary) do
      { term, rest } ->
        do_unpack_array(rest, len - 1, [term|acc])
      _ ->
        raise "do_unpack_array error"
    end
  end

  defp unpack_map(binary, len) do
    do_unpack_map(binary, len, [])
  end

  defp do_unpack_map(rest, 0, acc) do
    { {:lists.reverse(acc)}, rest }
  end
  defp do_unpack_map(binary, len, acc) do
    { key, rest } = do_unpack(binary)
    { value, rest } = do_unpack(rest)
    do_unpack_map(rest, len - 1, [{key, value}|acc])
  end
end
