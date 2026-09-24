import ./[common, dump_common]

type
  ArrayDump* = object
    needsComma*: bool
  ObjectDump* = object
    needsComma*: bool

proc maybeAddComma*(format: JsonDumpFormat, writer: JsonWriterArg, needsComma: var bool) {.inline.} =
  if needsComma:
    writer.write ','
    if format.pretty:
      writer.write '\n'
  else:
    needsComma = true
    if format.pretty:
      when supportsIndent(writer):
        writer.addIndent()
      writer.write '\n'

proc startArrayDump*(format: JsonDumpFormat, writer: JsonWriterArg): ArrayDump {.inline.} =
  result = ArrayDump(needsComma: false)
  writer.write '['
  # do this in comma for better empty arrays:
  #if format.pretty:
  #  when supportsIndent(writer):
  #    writer.addIndent()
  #  writer.write '\n'

proc finishArrayDump*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ArrayDump) {.inline.} =
  if format.pretty and arr.needsComma:
    when supportsIndent(writer):
      writer.removeIndent()
    writer.write '\n'
  writer.write ']'

proc startArrayItem*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ArrayDump) {.inline.} =
  maybeAddComma(format, writer, arr.needsComma)

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
  # do this in comma for better empty objects:
  #if format.pretty:
  #  when supportsIndent(writer):
  #    writer.addIndent()
  #  writer.write '\n'

proc finishObjectDump*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump) {.inline.} =
  if format.pretty and arr.needsComma:
    when supportsIndent(writer):
      writer.removeIndent()
    writer.write '\n'
  writer.write '}'

proc startObjectField*[T](format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump, name: T, raw = false) {.inline.} =
  mixin dump
  maybeAddComma(format, writer, arr.needsComma)
  if raw:
    writer.write name
  else:
    format.dump writer, name
  writer.write ':'
  if format.pretty: writer.write ' '

proc finishObjectField*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump) {.inline.} =
  discard

template withObjectDump*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump, body: typed) =
  arr = startObjectDump(format, writer)
  body
  finishObjectDump(format, writer, arr)

template withObjectField*[T](format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump, name: T, body: typed) =
  startObjectField(format, writer, arr, name)
  body
  finishObjectField(format, writer, arr)

template withRawObjectField*(format: JsonDumpFormat, writer: JsonWriterArg, arr: var ObjectDump, name: string, body: typed) =
  startObjectField(format, writer, arr, name, raw = true)
  body
  finishObjectField(format, writer, arr)
