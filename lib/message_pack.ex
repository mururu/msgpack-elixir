defmodule MessagePack do
  defdelegate pack(term), to: MessagePack.Packer

  defdelegate unpack(binary), to: MessagePack.Unpacker
  defdelegate unpack_stream(binary), to: MessagePack.Unpacker

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
