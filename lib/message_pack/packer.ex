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
        << 0xDC :: size(8), len :: [size(16), big, unsigned, integer, unit(1)], (pack_array(list)) :: binary >>
      len ->
        << 0xDD :: size(8), len :: [size(32), big, unsigned, integer, unit(1)], (pack_array(list)) :: binary >>
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
