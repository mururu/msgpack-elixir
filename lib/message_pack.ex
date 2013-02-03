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

  defexception IncompleteDataError, data: nil do
    def message(exception) do
      "Incomplete data: #{inspect exception.data}"
    end
  end

  defexception InvalidPrefixError, prefix: nil do
    def message(exception) do
      "Invalid prefix: #{inspect exception.prefix}"
    end
  end

  defexception ExtraBytesError, bytes: nil do
    def message(exception) do
      "Extra bytes follow after a deserialized object.\nExtra bytes: #{inspect exception.bytes}"
    end
  end
end
