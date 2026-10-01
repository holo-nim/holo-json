import ./[common, dump_common]

type
  ArrayDump* = object
    needsComma*: bool
  ObjectDump* = object
    needsComma*: bool

proc maybeAddComma*(format: JsonDump, writer: JsonWriterArg, needsComma: var bool) {.inline.} =
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

proc startArrayDump*(format: JsonDump, writer: JsonWriterArg): ArrayDump {.inline.} =
  result = ArrayDump(needsComma: false)
  writer.write '['
  # do this in comma for better empty arrays:
  #if format.pretty:
  #  when supportsIndent(writer):
  #    writer.addIndent()
  #  writer.write '\n'

proc finishArrayDump*(arr: var ArrayDump, format: JsonDump, writer: JsonWriterArg) {.inline.} =
  if format.pretty and arr.needsComma:
    when supportsIndent(writer):
      writer.removeIndent()
    case format.prettyClosingBrace
    of SeparateLine:
      writer.write '\n'
    of InlineSpace:
      writer.write ' '
    of NoSpacing: discard
  writer.write ']'

proc startArrayItem*(arr: var ArrayDump, format: JsonDump, writer: JsonWriterArg) {.inline.} =
  maybeAddComma(format, writer, arr.needsComma)

proc finishArrayItem*(arr: var ArrayDump, format: JsonDump, writer: JsonWriterArg) {.inline.} =
  discard

template dumpTo*(arr: var ArrayDump, format: JsonDump, writer: JsonWriterArg, body: typed) =
  arr = startArrayDump(format, writer)
  body
  finishArrayDump(arr, format, writer)

template withItem*(arr: var ArrayDump, format: JsonDump, writer: JsonWriterArg, body: typed) =
  startArrayItem(arr, format, writer)
  body
  finishArrayItem(arr, format, writer)

proc startObjectDump*(format: JsonDump, writer: JsonWriterArg): ObjectDump {.inline.} =
  result = ObjectDump(needsComma: false)
  writer.write '{'
  # do this in comma for better empty objects:
  #if format.pretty:
  #  when supportsIndent(writer):
  #    writer.addIndent()
  #  writer.write '\n'

proc finishObjectDump*(arr: var ObjectDump, format: JsonDump, writer: JsonWriterArg) {.inline.} =
  if format.pretty and arr.needsComma:
    when supportsIndent(writer):
      writer.removeIndent()
    case format.prettyClosingBrace
    of SeparateLine:
      writer.write '\n'
    of InlineSpace:
      writer.write ' '
    of NoSpacing: discard
  writer.write '}'

proc startObjectField*[T](arr: var ObjectDump, format: JsonDump, writer: JsonWriterArg, name: T, raw = false) {.inline.} =
  mixin dump
  maybeAddComma(format, writer, arr.needsComma)
  if raw:
    writer.write name
  else:
    format.dump writer, name
  writer.write ':'
  if format.pretty: writer.write ' '

proc finishObjectField*(arr: var ObjectDump, format: JsonDump, writer: JsonWriterArg) {.inline.} =
  discard

template dumpTo*(arr: var ObjectDump, format: JsonDump, writer: JsonWriterArg, body: typed) =
  arr = startObjectDump(format, writer)
  body
  finishObjectDump(arr, format, writer)

template withField*[T](arr: var ObjectDump, format: JsonDump, writer: JsonWriterArg, name: T, body: typed) =
  startObjectField(arr, format, writer, name)
  body
  finishObjectField(arr, format, writer)

template withRawField*(arr: var ObjectDump, format: JsonDump, writer: JsonWriterArg, name: string, body: typed) =
  startObjectField(arr, format, writer, name, raw = true)
  body
  finishObjectField(arr, format, writer)
