import ./common

type JsonReaderImplementation* = enum
  JsonLoadReader = "load"
    ## default, allows streaming
  JsonTrackedLoadReader = "tracked-load"
    ## same as load reader but allows line/column tracking
  JsonViewReader = "view"
    ## only allows reading from constant strings
  JsonTrackedViewReader = "tracked-view"
    ## same as view reader but allows line/column tracking
  JsonGenericReader = "generic"
    ## defines hooks on generic wildcard type

when defined(nimHasGenericDefine):
  const holoJsonReaderImpl* {.define.}: JsonReaderImplementation = JsonLoadReader
  const impl = holoJsonReaderImpl
else:
  import std/strutils
  const holoJsonReaderImpl* {.strdefine.} = $JsonLoadReader
  const impl = parseEnum[JsonReaderImplementation](holoJsonReaderImpl)

when impl in {JsonLoadReader, JsonTrackedLoadReader}:
  import fleu/load_reader
  export load_reader

  when impl == JsonTrackedLoadReader:
    type
      JsonReader* = TrackedLoadReader
      JsonReaderArg* = var JsonReader

    proc initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader {.inline.} =
      result = initTrackedLoadReader(doLineColumn = doLineColumn)
    
    template supportsLineColumn*(reader: JsonReaderArg): bool =
      true
  else:
    type
      JsonReader* = LoadReader
        ## reader implementation used in the default `read` hook implementations
      JsonReaderArg* = var JsonReader
        ## reader implementation used in the default `read` hook implementation signatures
        ## 
        ## implementing type has to match API in https://holo-nim.github.io/fleu/docs/reader_api

    proc initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader {.inline.} =
      result = initLoadReader()
    
    template supportsLineColumn*(reader: JsonReaderArg): bool =
      false
elif impl in {JsonViewReader, JsonTrackedViewReader}:
  import fleu/[view_reader, reader_common]
  export view_reader

  when impl == JsonTrackedViewReader:
    type
      JsonReader* = TrackedViewReader
      JsonReaderArg* = JsonReader

    template initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader =
      ## warning: cannot escape stack, enforced if `--experimental:views` is enabled
      var stateImpl = initTrackedReadState(doLineColumn)
      initTrackedViewReader(stateImpl)
    
    template supportsLineColumn*(reader: JsonReaderArg): bool =
      true
  else:
    type
      JsonReader* = ViewReader
      JsonReaderArg* = JsonReader

    template initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader =
      ## warning: cannot escape stack, enforced if `--experimental:views` is enabled
      var stateImpl = initReadState()
      initViewReader(stateImpl)
    
    template supportsLineColumn*(reader: JsonReaderArg): bool =
      false
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

  template initJsonReader*[T](doLineColumn = holoJsonLineColumn): JsonReader[T] {.
      error: "default json reader implementation unavailable".}
  
  template supportsLineColumn*[T](reader: T): bool =
    ## override for reader types that support line/column
    false
else:
  {.error: "unimplemented reader implementation " & $impl.}
