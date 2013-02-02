# MessagePack Elixir

[![Build Status](https://travis-ci.org/mururu/msgpack-elixir.png?branch=master)](https://travis-ci.org/mururu/msgpack-elixir)

## Usage

```elixir
msg = MessagePack.pack([1,2,3]) #=> <<147,1,2,3>>
MessagePack.unpack(msg)         #=> [1,2,3] 
```
