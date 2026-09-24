type JsonWriterImplementation* = enum
  JsonFlushWriter = "flush"
  JsonIndentFlushWriter = "indent-flush"
    ## tracks indent for optional pretty printing
  JsonGenericWriter = "generic"

when defined(nimHasGenericDefine):
  const holoJsonWriterImpl* {.define.}: JsonWriterImplementation = JsonFlushWriter
  const impl = holoJsonWriterImpl
else:
  import std/strutils
  const holoJsonWriterImpl* {.strdefine.} = $JsonFlushWriter
  const impl = parseEnum[JsonWriterImplementation](holoJsonWriterImpl)

when impl == JsonFlushWriter:
  import fleu/flush_writer
  export flush_writer

  type
    JsonWriter* = FlushWriter
      ## writer implementation used in the default `dump` hook implementations
    JsonWriterArg* = var JsonWriter
      ## writer implementation used in the default `dump` hook implementation signatures
      ## 
      ## implementing type has to match API in https://holo-nim.github.io/fleu/docs/writer_api

  proc initJsonWriter*(): JsonWriter {.inline.} =
    result = initFlushWriter()
  
  template supportsIndent*(writer: JsonWriterArg): bool =
    ## whether or not the writer supports indent tracking for pretty printing
    false
elif impl == JsonIndentFlushWriter:
  import fleu/flush_writer
  export flush_writer

  type
    JsonWriter* = IndentFlushWriter
    JsonWriterArg* = var JsonWriter

  proc initJsonWriter*(): JsonWriter {.inline.} =
    result = initIndentFlushWriter()
  
  template supportsIndent*(writer: JsonWriterArg): bool =
    ## whether or not the writer supports indent tracking for pretty printing
    true
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
  
  template supportsIndent*(writer: JsonWriterArg): bool =
    ## override for writers that support indent tracking
    false
else:
  {.error: "unimplemented writer implementation " & $impl.}
