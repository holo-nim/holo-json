## `dump` hooks for stdlib types

import ./[common, dumperbasic], holo_flow/holo_writer, std/[options, sets, tables]

proc dump*[T](format: JsonDumpFormat, writer: var HoloWriter, v: Option[T]) {.inline.} =
  mixin dump
  if v.isNone:
    writer.write "null"
  else:
    format.dump(writer, v.get())

proc dump*[T](format: JsonDumpFormat, writer: var HoloWriter, v: HashSet[T]) =
  mixin dump
  var arr: ArrayDump
  format.withArrayDump(writer, arr):
    for e in v:
      format.withArrayItem(writer, arr):
        format.dump(writer, e)

proc dump*[T](format: JsonDumpFormat, writer: var HoloWriter, v: OrderedSet[T]) =
  mixin dump
  var arr: ArrayDump
  format.withArrayDump(writer, arr):
    for e in v:
      format.withArrayItem(writer, arr):
        format.dump(writer, e)

proc dump*[T](format: JsonDumpFormat, writer: var HoloWriter, v: set[T]) =
  mixin dump
  var arr: ArrayDump
  format.withArrayDump(writer, arr):
    for e in v:
      format.withArrayItem(writer, arr):
        format.dump(writer, e)

template tableImpl(format, writer, tab, K, V) =
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

proc dump*[K: string | enum, V](format: JsonDumpFormat, writer: var HoloWriter, tab: Table[K, V]) =
  ## Dump an object.
  tableImpl(format, writer, tab, K, V)

proc dump*[K: string | enum, V](format: JsonDumpFormat, writer: var HoloWriter, tab: TableRef[K, V]) =
  ## Dump an object.
  tableImpl(format, writer, tab, K, V)

proc dump*[K: string | enum, V](format: JsonDumpFormat, writer: var HoloWriter, tab: OrderedTable[K, V]) =
  ## Dump an object.
  tableImpl(format, writer, tab, K, V)

proc dump*[K: string | enum, V](format: JsonDumpFormat, writer: var HoloWriter, tab: OrderedTableRef[K, V]) =
  ## Dump an object.
  tableImpl(format, writer, tab, K, V)

proc dump*[K: string | enum](format: JsonDumpFormat, writer: var HoloWriter, tab: CountTable[K]) =
  ## Dump an object.
  tableImpl(format, writer, tab, K, int)

proc dump*[K: string | enum](format: JsonDumpFormat, writer: var HoloWriter, tab: CountTableRef[K]) =
  ## Dump an object.
  tableImpl(format, writer, tab, K, int)
