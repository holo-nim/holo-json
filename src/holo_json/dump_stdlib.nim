## `dump` hooks for stdlib types

import ./[common, dump_common, dump_basic, dump_helpers], std/[options, sets, tables, json]

proc dump*(format: JsonDump, writer: JsonWriterArg, value: JsonNode) =
  ## Dumps a regular json node.
  if value == nil:
    writer.write "null"
  else:
    case value.kind:
    of JObject:
      var obj: ObjectDump
      obj.dumpTo format, writer:
        for k, e in value.pairs:
          obj.withField format, writer, k:
            format.dump(writer, e)
    of JArray:
      var arr: ArrayDump
      arr.dumpTo format, writer:
        for e in value:
          arr.withItem format, writer:
            format.dump(writer, e)
    of JNull:
      writer.write "null"
    of JInt:
      format.dump(writer, value.getBiggestInt)
    of JFloat:
      format.dump(writer, value.getFloat)
    of JString:
      format.dump(writer, value.getStr)
    of JBool:
      format.dump(writer, value.getBool)

proc dump*[T](format: JsonDump, writer: JsonWriterArg, value: Option[T]) {.inline.} =
  mixin dump
  if value.isNone:
    writer.write "null"
  else:
    format.dump(writer, value.get())

proc dump*[T](format: JsonDump, writer: JsonWriterArg, value: HashSet[T]) =
  mixin dump, items
  var arr: ArrayDump
  arr.dumpTo format, writer:
    for e in value.items:
      arr.withItem format, writer:
        format.dump(writer, e)

proc dump*[T](format: JsonDump, writer: JsonWriterArg, value: OrderedSet[T]) =
  mixin dump, items
  var arr: ArrayDump
  arr.dumpTo format, writer:
    for e in value.items:
      arr.withItem format, writer:
        format.dump(writer, e)

proc dump*[T](format: JsonDump, writer: JsonWriterArg, value: set[T]) =
  mixin dump, items
  var arr: ArrayDump
  arr.dumpTo format, writer:
    for e in value.items:
      arr.withItem format, writer:
        format.dump(writer, e)

template stringTableImpl(format, writer, tab, K, V) =
  mixin dump, pairs
  # not in original jsony
  when tab is ref:
    if isNil(value):
      writer.write "null"
      return
  var obj: ObjectDump
  obj.dumpTo format, writer:
    for k, value in tab.pairs:
      obj.withField format, writer, $k:
        format.dump writer, value

proc dump*[K: string | enum, V](format: JsonDump, writer: JsonWriterArg, tab: Table[K, V]) =
  ## Dump an object.
  stringTableImpl(format, writer, tab, K, V)

proc dump*[K: string | enum, V](format: JsonDump, writer: JsonWriterArg, tab: OrderedTable[K, V]) =
  ## Dump an object.
  stringTableImpl(format, writer, tab, K, V)

proc dump*[K: string | enum](format: JsonDump, writer: JsonWriterArg, tab: CountTable[K]) =
  ## Dump an object.
  stringTableImpl(format, writer, tab, K, int)

template anyTableImpl(format, writer, tab, K, V) =
  mixin dump, pairs
  # not in original jsony
  when tab is ref:
    if isNil(value):
      writer.write "null"
      return
  var arr: ArrayDump
  arr.dumpTo format, writer:
    for k, value in tab.pairs:
      arr.withItem format, writer:
        var pair: ArrayDump
        pair.dumpTo format, writer:
          pair.withItem format, writer:
            format.dump writer, k
          pair.withItem format, writer:
            format.dump writer, value

proc dump*[K: not (string | enum), V](format: JsonDump, writer: JsonWriterArg, tab: Table[K, V]) =
  ## Dump a normal table.
  anyTableImpl(format, writer, tab, K, V)

proc dump*[K: not (string | enum), V](format: JsonDump, writer: JsonWriterArg, tab: OrderedTable[K, V]) =
  ## Dump a normal table.
  anyTableImpl(format, writer, tab, K, V)

proc dump*[K: not (string | enum)](format: JsonDump, writer: JsonWriterArg, tab: CountTable[K]) =
  ## Dump a normal table.
  anyTableImpl(format, writer, tab, K, int)

when false: # should not need anymore with the `ref object` overload disabled
  proc dump*[K: string | enum, V](format: JsonDump, writer: JsonWriterArg, tab: TableRef[K, V]) =
    ## Dump an object.
    tableImpl(format, writer, tab, K, V)

  proc dump*[K: string | enum, V](format: JsonDump, writer: JsonWriterArg, tab: OrderedTableRef[K, V]) =
    ## Dump an object.
    tableImpl(format, writer, tab, K, V)

  proc dump*[K: string | enum](format: JsonDump, writer: JsonWriterArg, tab: CountTableRef[K]) =
    ## Dump an object.
    tableImpl(format, writer, tab, K, int)
