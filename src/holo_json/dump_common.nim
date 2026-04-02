type JsonWriterImplementation* = enum
  JsonFlushWriter = "flush"
  JsonGenericWriter = "generic"

when defined(nimHasGenericDefine):
  const holoJsonWriterImpl* {.define.}: JsonWriterImplementation = JsonFlushWriter
  const impl = holoJsonWriterImpl
else:
  import std/strutils
  const holoJsonWriterImpl* {.strdefine.} = $JsonFlushWriter
  const impl = parseEnum[JsonWriterImplementation](holoJsonWriterImpl)

when impl == JsonFlushWriter:
  import flue/flush_writer
  export flush_writer

  type
    JsonWriter* = FlushWriter
      ## writer implementation used in the default `dump` hook implementations
    JsonWriterArg* = var JsonWriter
      ## writer implementation used in the default `dump` hook implementation signatures
      ## 
      ## implementing type has to match API in https://holo-nim.github.io/flue/docs/writer_api

  proc initJsonWriter*(): JsonWriter {.inline.} =
    result = initFlushWriter()
elif impl == JsonGenericWriter:
  template getArgType*[T](_: typedesc[T]): untyped =
    ## hook to override to turn `T` into an argument type
    T

  template toArgType(T: untyped): untyped =
    mixin getArgType
    getArgType(T)
  type
    JsonWriter*[T] = T
    JsonWriterArg*[T] = toArgType(T)

  template initJsonWriter*[T](impl: T): JsonWriter[T] =
    impl
else:
  {.error: "unimplemented writer implementation " & $impl.}
