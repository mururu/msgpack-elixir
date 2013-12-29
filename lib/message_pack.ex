defmodule MessagePack do
  defdelegate pack(term), to: MessagePack.Packer
  defdelegate pack(term, options), to: MessagePack.Packer
  defdelegate pack!(term), to: MessagePack.Packer
  defdelegate pack!(term, options), to: MessagePack.Packer
end
