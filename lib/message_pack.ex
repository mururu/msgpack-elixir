defmodule MessagePack do
  defdelegate pack(term), to: MessagePack.Packer

  def unpack(binary, options // []) do
    if options[:all] do
      MessagePack.Unpacker.unpack_all(binary)
    else
      if options[:rest] do
        MessagePack.Unpacker.unpack_rest(binary)
      else
        MessagePack.Unpacker.unpack(binary)
      end
    end
  end
end
