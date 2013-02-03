defmodule MessagePack.Unpacker do
  def unpack(binary) when is_binary(binary) do
    case do_unpack(binary) do
      { result, <<>> } ->
        result
      { result, rest } when is_binary(rest) ->
        raise MessagePack.ExtraBytesError, bytes: rest
    end
  end

  def unpack_rest(binary) when is_binary(binary) do
    do_unpack(binary)
  end

  def unpack_all(binary) when is_binary(binary) do
    do_unpack_all(binary, []) |> Enum.reverse
  end

  def do_unpack_all(binary, acc) do
    case do_unpack(binary) do
      { term, <<>> } ->
        [term|acc]
      { term, rest } when is_binary(binary) ->
        do_unpack_all(rest, [term|acc])
    end
  end

  # positive fixnum
  defp do_unpack(<< 0 :: size(1), v :: size(7), rest :: binary >>), do: { v, rest }

  #negative fixnum
  defp do_unpack(<< 0b111 :: size(3), v :: size(5), rest :: binary >>), do: { v - 0b100000, rest }

  # uint
  defp do_unpack(<< 0xCC, uint :: [size(8), unsigned, integer], rest :: binary >>), do: { uint, rest }
  defp do_unpack(<< 0xCD, uint :: [size(16), big, unsigned, integer, unit(1)], rest :: binary >>), do: { uint, rest }
  defp do_unpack(<< 0xCE, uint :: [size(32), big, unsigned, integer, unit(1)], rest :: binary >>), do: { uint, rest }
  defp do_unpack(<< 0xCF, uint :: [size(64), big, unsigned, integer, unit(1)], rest :: binary >>), do: { uint, rest }

  # int
  defp do_unpack(<< 0xD0, int :: [size(8), signed, integer], rest :: binary >>), do: { int, rest }
  defp do_unpack(<< 0xD1, int :: [size(16), big, signed, integer, unit(1)], rest :: binary >>), do: { int, rest }
  defp do_unpack(<< 0xD2, int :: [size(32), big, signed, integer, unit(1)], rest :: binary >>), do: { int, rest }
  defp do_unpack(<< 0xD3, int :: [size(64), big, signed, integer, unit(1)], rest :: binary >>), do: { int, rest }

  # nil
  defp do_unpack(<< 0xC0, rest :: binary >>), do: { nil, rest }

  # boolean
  defp do_unpack(<< 0xC3, rest :: binary >>), do: { true, rest }
  defp do_unpack(<< 0xC2, rest :: binary >>), do: { false, rest }

  # float & double (same in Elixir)
  defp do_unpack(<< 0xCA, float  :: [size(32), float, unit(1)], rest :: binary >>), do: { float, rest }
  defp do_unpack(<< 0xCB, double :: [size(64), float, unit(1)], rest :: binary >>), do: { double, rest }

  # raw bytes
  defp do_unpack(<< 0b101 :: size(3), len :: size(5), v :: [size(len), binary], rest :: binary >>), do: { v, rest }
  defp do_unpack(<< 0xDA, binary :: [size(16), unsigned, integer, unit(1)], rest :: binary >>), do: { binary, rest }
  defp do_unpack(<< 0xDB, binary :: [size(32), unsigned, integer, unit(1)], rest :: binary >>), do: { binary, rest }

  # array
  defp do_unpack(<< 0b1001 :: size(4), len :: size(4), rest :: binary >>), do: unpack_array(rest, len)
  defp do_unpack(<< 0xDC, len :: [size(16), big, unsigned, integer, unit(1)], rest :: binary >>), do: unpack_array(rest, len)
  defp do_unpack(<< 0xDD, len :: [size(32), big, unsigned, integer, unit(1)], rest :: binary >>), do: unpack_array(rest, len)

  # map
  defp do_unpack(<< 0b1000 :: size(4), len :: size(4), rest :: binary >>), do: unpack_map(rest, len)
  defp do_unpack(<< 0xDE, len :: [size(16), big, unsigned, integer, unit(1)], rest :: binary >>), do: unpack_map(rest, len)
  defp do_unpack(<< 0xDF, len :: [size(32), big, unsigned, integer, unit(1)], rest :: binary >>), do: unpack_map(rest, len)

  @invalid_prefixes [0xC1, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9]
  defp do_unpack(<< prefix, _ :: binary>>) when prefix in @invalid_prefixes do
    raise MessagePack.InvalidPrefixError, prefix: prefix
  end

  defp do_unpack(data) do
    raise MessagePack.IncompleteDataError, data: data
  end

  defp unpack_array(binary, len) do
    do_unpack_array(binary, len, [])
  end

  defp do_unpack_array(rest, 0, acc) do
    { :lists.reverse(acc), rest }
  end

  defp do_unpack_array(binary, len, acc) do
    { term, rest } = do_unpack(binary)
    { term, rest } = do_unpack_array(rest, len - 1, [term|acc])
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
