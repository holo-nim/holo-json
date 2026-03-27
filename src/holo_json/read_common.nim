import ./common

const holoJsonUseViewReader* {.booldefine.} = true

when holoJsonUseViewReader:
  import holo_flow/[view_reader, load_reader]
  export view_reader

  type
    JsonReader* = ViewReader
    JsonReaderArg* = JsonReader

  template initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader =
    ## warning: cannot escape stack
    var readerImpl = initLoadReader(doLineColumn)
    initViewReader(readerImpl)
else:
  import holo_flow/load_reader
  export load_reader

  type
    JsonReader* = LoadReader
    JsonReaderArg* = var JsonReader

  proc initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader {.inline.} =
    result = initLoadReader(doLineColumn = doLineColumn)
