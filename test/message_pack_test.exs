defmodule MessagePackTest do
  use ExUnit.Case

  defmacrop check(term, len, options // []) do
    quote location: :keep, bind_quoted: [term: term, len: len, options: options] do
      assert { :ok, bin } = MessagePack.pack(term, options)
      assert byte_size(bin) == len
      assert { :ok, term2 } = MessagePack.unpack(bin, options)
      assert term == term2
    end
  end

  defmacrop check_raw(num, overhead) do
    quote location: :keep, bind_quoted: [num: num, overhead: overhead] do
      check(:binary.copy(<<255>>, num), num + overhead)
    end
  end

  defmacrop check_str(num, overhead) do
    quote location: :keep, bind_quoted: [num: num, overhead: overhead] do
      check(String.duplicate(" ", num), num + overhead, enable_string: true)
    end
  end

  defmacrop check_bin(num, overhead) do
    quote location: :keep, bind_quoted: [num: num, overhead: overhead] do
      check(:binary.copy(<<255>>, num), num + overhead, enable_string: true)
    end
  end

  defmacrop check_array(num, overhead) do
    quote location: :keep, bind_quoted: [num: num, overhead: overhead] do
      check(:lists.duplicate(num, nil), num + overhead)
    end
  end

  defmacrop check_map(0, overhead) do
    quote location: :keep, bind_quoted: [overhead: overhead] do
      check([{}], overhead)
    end
  end

  defmacrop check_map(num, overhead) do
    quote location: :keep, bind_quoted: [num: num, overhead: overhead] do
      check(:lists.duplicate(num, { nil, nil }), 2 * num + overhead)
    end
  end

  test "nil" do
    check nil, 1
  end

  test "true" do
    check true, 1
  end

  test "false" do
    check false, 1
  end

  test "zero" do
    check 0, 1
  end

  test "positive fixnum" do
    check 1, 1
    check 64, 1
    check 127, 1
  end

  test "negative fixnum" do
    check -1, 1
    check -32, 1
  end

  test "uint 8" do
    check 128, 2
    check 0xFF, 2
  end

  test "uint 16" do
    check 0x100, 3
    check 0xFFFF, 3
  end

  test "uint 32" do
    check 0x10000, 5
    check 0xFFFFFFFF, 5
  end

  test "unit 64" do
    check 0x100000000, 9
    check 0xFFFFFFFFFFFFFFFF, 9
  end

  test "int 8" do
    check -33, 2
    check -128, 2
  end

  test "int 16" do
    check -129, 3
    check 0x8000, 3
  end

  test "int 32" do
    check -0x8001, 5
    check -0x80000000, 5
  end

  test "int 64" do
    check -0x80000001, 9
    check -0x8000000000000000, 9
  end

  test "float" do
    check 1.0, 9
    check 0.1, 9
    check -0.1, 9
    check -1.0, 9
  end

  test "fixraw" do
    check_raw 0, 1
    check_raw 31, 1
  end

  test "raw 16" do
    check_raw 32, 3
    check_raw 0xFFFF, 3
  end

  test "raw 32" do
    check_raw 0x10000, 5
    #check_raw 0xFFFFFFFF, 5
  end

  test "fixstr" do
    check_str 0, 1
    check_str 31, 1
  end

  test "str 8" do
    check_str 32, 2
    check_str 0xFF, 2
  end

  test "str 16" do
    check_str 0x100, 3
    check_str 0xFFFF, 3
  end

  test "str 32" do
    check_str 0x10000, 5
    #check_str 0xFFFFFFFF, 5
  end

  test "bin 8" do
    check_bin 1, 2
    check_bin 0xFF, 2
  end

  test "bin 16" do
    check_bin 0x100, 3
    check_bin 0xFFFF, 3
  end

  test "bin 32" do
    check_bin 0x10000, 5
    #check_bin 0xFFFFFFFF, 5
  end

  test "fixarray" do
    check_array 0, 1
    check_array 15, 1
  end

  test "array 16" do
    check_array 16, 3
    check_array 0xFFFF, 3
  end

  test "array 32" do
    check_array 0x10000, 5
    #check_array 0xFFFFFFFF, 5
  end

  test "fixmap" do
    check_map 0, 1
    check_map 15, 1
  end

  test "map 16" do
    check_map 16, 3
    check_map 0xFFFF, 3
  end

  test "map 32" do
    check_map 0x10000, 5
    #check_map 0xFFFFFFFF, 5
  end

  test "pack too big error" do
    assert MessagePack.pack(-0x8000000000000001) == { :error, { :too_big, -0x8000000000000001 } }
    assert_raise ArgumentError, fn -> MessagePack.pack!(-0x8000000000000001) end

    assert MessagePack.pack(0x10000000000000000) == { :error, { :too_big, 0x10000000000000000 } }
    assert_raise ArgumentError, fn -> MessagePack.pack!(0x10000000000000000) end
  end

  test "pack badarg error" do
    assert { :error, { :badarg, ref } } = MessagePack.pack(self)
    assert is_pid(ref)

    assert_raise ArgumentError, fn -> MessagePack.pack!(self) end
  end

  test "pack error nested" do
    assert MessagePack.pack([0x10000000000000000]) == { :error, { :too_big, 0x10000000000000000 } }
    assert_raise ArgumentError, fn -> MessagePack.pack!([0x10000000000000000]) end

    assert MessagePack.pack([{0x10000000000000000, 1}]) == { :error, { :too_big, 0x10000000000000000 } }
    assert_raise ArgumentError, fn -> MessagePack.pack!([{0x10000000000000000, 1}]) end

    assert MessagePack.pack([{1, 0x10000000000000000}]) == { :error, { :too_big, 0x10000000000000000 } }
    assert_raise ArgumentError, fn -> MessagePack.pack!([{0x10000000000000000, 1}]) end
  end

  test "upack invalid string error" do
    bin = MessagePack.pack!(<<255>>)
    assert MessagePack.unpack(bin, enable_string: true) == { :error, { :invalid_string, << 255 >> } }
    assert_raise ArgumentError, fn -> MessagePack.unpack!(bin, enable_string: true) end
  end

  test "unpack invalid prefix error" do
    bin = << 0xC1, 1 >>
    assert MessagePack.unpack(bin) == { :error, { :invalid_prefix, 0xC1 } }
    assert_raise ArgumentError, fn -> MessagePack.unpack!(bin) end
  end

  test "unpack incomlete error" do
    bin = << 147, 1, 2 >>
    assert MessagePack.unpack(bin) == { :error, :incomplete }
    assert_raise ArgumentError, fn -> MessagePack.unpack!(bin) end
  end
end
