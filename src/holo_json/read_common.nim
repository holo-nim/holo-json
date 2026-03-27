import ./common, holo_flow/load_reader
export load_reader

type
  JsonReader* = LoadReader
  JsonReaderArg* = var JsonReader

proc initJsonReader*(doLineColumn = holoJsonLineColumn): JsonReader {.inline.} =
  result = initLoadReader(doLineColumn = doLineColumn)
