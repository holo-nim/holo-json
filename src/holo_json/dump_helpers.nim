import ./[common, dumper_common]

# don't dogfood these yet if they add to compile times:
type
  ArrayDump* = object
    needsComma*: bool
  ObjectDump* = object
    needsComma*: bool

proc startArrayDump*(format: JsonDumpFormat, writer: JsonWriterArg): ArrayDump {.inline.} =
  result = ArrayDump(needsComma: false)
  writer.write '['

proc finishArrayDump*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ArrayDump) {.inline.} =
  writer.write ']'

proc startArrayItem*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ArrayDump) {.inline.} =
  if arr.needsComma: writer.write ','
  else: arr.needsComma = true

proc finishArrayItem*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ArrayDump) {.inline.} =
  discard

template withArrayDump*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ArrayDump, body: typed) =
  arr = startArrayDump(format, writer)
  body
  finishArrayDump(format, writer, arr)

template withArrayItem*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ArrayDump, body: typed) =
  startArrayItem(format, writer, arr)
  body
  finishArrayItem(format, writer, arr)

proc startObjectDump*(format: JsonDumpFormat, writer: JsonWriterArg): ObjectDump {.inline.} =
  result = ObjectDump(needsComma: false)
  writer.write '{'

proc finishObjectDump*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump) {.inline.} =
  writer.write '}'

proc startObjectField*[T](format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump, name: T, raw = false) {.inline.} =
  mixin dump
  if arr.needsComma: writer.write ','
  else: arr.needsComma = true
  if raw:
    writer.write name
  else:
    format.dump writer, name
  writer.write ':'

proc finishObjectField*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump) {.inline.} =
  discard

template withObjectDump*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump, body: typed) =
  arr = startObjectDump(format, writer)
  body
  finishObjectDump(format, writer, arr)

template withObjectField*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump, name: string, body: typed) =
  startObjectField(format, writer, arr, name)
  body
  finishObjectField(format, writer, arr)

template withRawObjectField*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump, name: string, body: typed) =
  startObjectField(format, writer, arr, name, raw = true)
  body
  finishObjectField(format, writer, arr)
