## `dump` hooks for stdlib types

import ./[common, dumper_common, dumper_basic, dump_helpers], std/[options, sets, tables, json]

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: JsonNode) =
  ## Dumps a regular json node.
  if v == nil:
    writer.write "null"
  else:
    case v.kind:
    of JObject:
      writer.write '{'
      var i = 0
      for k, e in v.pairs:
        if i != 0:
          writer.write ","
        format.dump(writer, k)
        writer.write ':'
        format.dump(writer, e)
        inc i
      writer.write '}'
    of JArray:
      writer.write '['
      var i = 0
      for e in v:
        if i != 0:
          writer.write ","
        format.dump(writer, e)
        inc i
      writer.write ']'
    of JNull:
      writer.write "null"
    of JInt:
      format.dump(writer, v.getInt)
    of JFloat:
      format.dump(writer, v.getFloat)
    of JString:
      format.dump(writer, v.getStr)
    of JBool:
      format.dump(writer, v.getBool)

proc dump*[T](format: JsonDumpFormat, writer: JsonWriterArg, v: Option[T]) {.inline.} =
  mixin dump
  if v.isNone:
    writer.write "null"
  else:
    format.dump(writer, v.get())

proc dump*[T](format: JsonDumpFormat, writer: JsonWriterArg, v: HashSet[T]) =
  mixin dump
  var arr: ArrayDump
  format.withArrayDump(writer, arr):
    for e in v:
      format.withArrayItem(writer, arr):
        format.dump(writer, e)

proc dump*[T](format: JsonDumpFormat, writer: JsonWriterArg, v: OrderedSet[T]) =
  mixin dump
  var arr: ArrayDump
  format.withArrayDump(writer, arr):
    for e in v:
      format.withArrayItem(writer, arr):
        format.dump(writer, e)

proc dump*[T](format: JsonDumpFormat, writer: JsonWriterArg, v: set[T]) =
  mixin dump
  var arr: ArrayDump
  format.withArrayDump(writer, arr):
    for e in v:
      format.withArrayItem(writer, arr):
        format.dump(writer, e)

template stringTableImpl(format, writer, tab, K, V) =
  mixin dump
  # not in original jsony
  when tab is ref:
    if isNil(v):
      writer.write "null"
      return
  var obj: ObjectDump
  format.withObjectDump(writer, obj):
    for k, v in tab:
      format.withObjectField(writer, obj, $k):
        format.dump writer, v

proc dump*[K: string | enum, V](format: JsonDumpFormat, writer: JsonWriterArg, tab: Table[K, V]) =
  ## Dump an object.
  stringTableImpl(format, writer, tab, K, V)

proc dump*[K: string | enum, V](format: JsonDumpFormat, writer: JsonWriterArg, tab: OrderedTable[K, V]) =
  ## Dump an object.
  stringTableImpl(format, writer, tab, K, V)

proc dump*[K: string | enum](format: JsonDumpFormat, writer: JsonWriterArg, tab: CountTable[K]) =
  ## Dump an object.
  stringTableImpl(format, writer, tab, K, int)

template anyTableImpl(format, writer, tab, K, V) =
  mixin dump
  # not in original jsony
  when tab is ref:
    if isNil(v):
      writer.write "null"
      return
  var arr: ArrayDump
  format.withArrayDump(writer, arr):
    for k, v in tab:
      format.withArrayItem(writer, arr):
        var pair: ArrayDump
        format.withArrayDump(writer, pair):
          format.withArrayItem(writer, pair):
            format.dump writer, k
          format.withArrayItem(writer, pair):
            format.dump writer, v

proc dump*[K: not (string | enum), V](format: JsonDumpFormat, writer: JsonWriterArg, tab: Table[K, V]) =
  ## Dump a normal table.
  anyTableImpl(format, writer, tab, K, V)

proc dump*[K: not (string | enum), V](format: JsonDumpFormat, writer: JsonWriterArg, tab: OrderedTable[K, V]) =
  ## Dump a normal table.
  anyTableImpl(format, writer, tab, K, V)

proc dump*[K: not (string | enum)](format: JsonDumpFormat, writer: JsonWriterArg, tab: CountTable[K]) =
  ## Dump a normal table.
  anyTableImpl(format, writer, tab, K, int)

when false: # should not need anymore with the `ref object` overload disabled
  proc dump*[K: string | enum, V](format: JsonDumpFormat, writer: JsonWriterArg, tab: TableRef[K, V]) =
    ## Dump an object.
    tableImpl(format, writer, tab, K, V)

  proc dump*[K: string | enum, V](format: JsonDumpFormat, writer: JsonWriterArg, tab: OrderedTableRef[K, V]) =
    ## Dump an object.
    tableImpl(format, writer, tab, K, V)

  proc dump*[K: string | enum](format: JsonDumpFormat, writer: JsonWriterArg, tab: CountTableRef[K]) =
    ## Dump an object.
    tableImpl(format, writer, tab, K, int)
