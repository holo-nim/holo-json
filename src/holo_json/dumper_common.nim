import holo_flow/flush_writer
export flush_writer

type
  JsonWriter* = FlushWriter
  JsonWriterArg* = var JsonWriter

proc initJsonWriter*(): JsonWriter {.inline.} =
  result = initFlushWriter()
