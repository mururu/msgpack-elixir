defmodule TestExt do
  use MessagePack.Ext.Behaviour

  def pack({ :ref, term }), do: { :ok, { 1, :erlang.term_to_binary(term) } }
  def pack({ :pid, term }), do: { :ok, { 2, :erlang.term_to_binary(term) } }

  def unpack(1, bin), do: { :ok, { :ref, :erlang.binary_to_term(bin) } }
  def unpack(2, bin), do: { :ok, { :pid, :erlang.binary_to_term(bin) } }
end

defmodule MessagePackExtTest do
  use ExUnit.Case

  test "ext mod" do
    options = [ext: TestExt]

    oref = make_ref
    assert { :ok, { :ref, ref } } = MessagePack.pack!({ :ref, oref }, options) |> MessagePack.unpack(options)
    assert is_reference(ref)
    assert ref == oref

    opid = self
    assert { :ok, { :pid, pid } } = MessagePack.pack!({ :pid, opid }, options) |> MessagePack.unpack(options)
    assert is_pid(pid)
    assert pid == opid
  end

  test "ext fun" do
    packer = fn
      ({ :ref, ref }) -> { :ok, { 1, :erlang.term_to_binary(ref) } }
      ({ :pid, pid }) -> { :ok, { 2, :erlang.term_to_binary(pid) } }
    end

    unpacker = fn
      (1, bin) -> { :ok, { :ref, :erlang.binary_to_term(bin) } }
      (2, bin) -> { :ok, { :pid, :erlang.binary_to_term(bin) } }
    end

    options = [ext: [packer: packer, unpacker: unpacker]]

    oref = make_ref
    assert { :ok, { :ref, ref } } = MessagePack.pack!({ :ref, oref }, options) |> MessagePack.unpack(options)
    assert is_reference(ref)
    assert ref == oref

    opid = self
    assert { :ok, { :pid, pid } } = MessagePack.pack!({ :pid, opid }, options) |> MessagePack.unpack(options)
    assert is_pid(pid)
    assert pid == opid
  end
end
