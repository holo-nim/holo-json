## `read` hooks for stdlib types

import ./[common, readerbasic], holo_flow/holo_reader, std/[options, tables, sets]

proc read*[T](format: JsonReadFormat, reader: var HoloReader, v: var Option[T]) =
  ## Parse an Option.
  mixin read
  eatSpace(reader)
  if reader.nextMatch("null"):
    # v = none(T)?
    return
  var e: T
  read(format, reader, e)
  v = some(e)

template tableImpl(format, reader, v, K, V) =
  mixin read
  when v is ref:
    if reader.nextMatch("null"):
      # this is added this time
      return
    new(v)
  eatChar(reader, '{')
  while reader.hasNext():
    eatSpace(reader)
    if reader.peekMatch('}'):
      break
    var key: K
    read(format, reader, key)
    eatChar(reader, ':')
    var element: V
    read(format, reader, element)
    v[key] = element
    if reader.nextMatch(','):
      discard
    else:
      break
  eatChar(reader, '}')

proc read*[K: string | enum, V](format: JsonReadFormat, reader: var HoloReader, v: var Table[K, V]) =
  ## Parse an object.
  tableImpl(format, reader, v, K, V)

proc read*[K: string | enum, V](format: JsonReadFormat, reader: var HoloReader, v: var OrderedTable[K, V]) =
  ## Parse an object.
  tableImpl(format, reader, v, K, V)

proc read*[K: string | enum, V](format: JsonReadFormat, reader: var HoloReader, v: var TableRef[K, V]) =
  ## Parse an object.
  tableImpl(format, reader, v, K, V)

proc read*[K: string | enum, V](format: JsonReadFormat, reader: var HoloReader, v: var OrderedTableRef[K, V]) =
  ## Parse an object.
  tableImpl(format, reader, v, K, V)

proc read*[K: string | enum](format: JsonReadFormat, reader: var HoloReader, v: var CountTable[K]) =
  ## Parse an object.
  tableImpl(format, reader, v, K, int)

proc read*[K: string | enum](format: JsonReadFormat, reader: var HoloReader, v: var CountTableRef[K]) =
  ## Parse an object.
  tableImpl(format, reader, v, K, int)

proc read*[T](format: JsonReadFormat, reader: var HoloReader, v: var HashSet[T]) =
  ## Parses `HashSet`.
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    v.incl(e)

proc read*[T](format: JsonReadFormat, reader: var HoloReader, v: var OrderedSet[T]) =
  ## Parses `OrderedSet`.
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    v.incl(e)

proc read*[T](format: JsonReadFormat, reader: var HoloReader, v: var set[T]) =
  ## Parses the built-in `set` type.
  # separate overload for bitflags or something
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    v.incl(e)
