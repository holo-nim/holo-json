import ./common

type JsonReaderImplementation* = enum
  JsonLoadReader = "load"
  JsonViewReader = "view"
  JsonGenericReader = "generic"

when defined(nimHasGenericDefine):
  const holoJsonReaderImpl* {.define.}: JsonReaderImplementation = JsonLoadReader
  const impl = holoJsonReaderImpl
else:
  import std/strutils
  const holoJsonReaderImpl* {.strdefine.} = $JsonLoadReader
  const impl = parseEnum[JsonReaderImplementation](holoJsonReaderImpl)

when impl == JsonLoadReader:
  import holo_flow/load_reader
  from holo_flow/reader_common import holoReaderDisableLineColumn
  export load_reader

  type
    JsonReader* = LoadReader
    JsonReaderArg* = var JsonReader

  proc initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader {.inline.} =
    result = initLoadReader(doLineColumn = doLineColumn)
  
  template supportsLineColumn*(reader: JsonReaderArg): bool =
    not holoReaderDisableLineColumn
elif impl == JsonViewReader:
  import holo_flow/[view_reader, reader_common]
  export view_reader

  type
    JsonReader* = ViewReader
    JsonReaderArg* = JsonReader

  template initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader =
    ## warning: cannot escape stack
    var stateImpl = initReadState(doLineColumn)
    initViewReader(stateImpl)
  
  template supportsLineColumn*(reader: JsonReaderArg): bool =
    not holoReaderDisableLineColumn
elif impl == JsonGenericReader:
  template getArgType*[T](_: typedesc[T]): untyped =
    ## hook to override to turn `T` into an argument type
    T

  template toArgType(T: untyped): untyped =
    mixin getArgType
    getArgType(T)
  type
    JsonReader*[T] = T
    JsonReaderArg*[T] = toArgType(T)

  template initJsonReader*[T](impl: T): JsonReader[T] =
    impl
  
  template supportsLineColumn*[T](reader: T): bool =
    ## override for reader types that support line/column
    false
else:
  {.error: "unimplemented reader implementation " & $impl.}
