## `read` hooks for stdlib types

import ./[common, read_common, read_basic, parser, read_helpers], std/[options, tables, sets, json, parseutils]

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var JsonNode) =
  ## Parses a regular json node.
  skipSpace(reader)
  let kind = peekRawKind(format, reader)
  case kind
  of JsonInvalid:
    reader.unexpectedError(format, "json value")
  of JsonObject:
    v = newJObject()
    for k in readObject[string](format, reader):
      var e: JsonNode
      read(format, reader, e)
      v[k] = e
  of JsonArray:
    v = newJArray()
    for i in readArray(format, reader):
      var e: JsonNode
      read(format, reader, e)
      v.add(e)
  of JsonString:
    var str: string
    read(format, reader, str)
    v = newJString(str)
  of JsonNull:
    unsafeNextBy(reader, "null".len)
    v = newJNull()
  of JsonTrue:
    unsafeNextBy(reader, "true".len)
    v = newJBool(true)
  of JsonFalse:
    unsafeNextBy(reader, "false".len)
    v = newJBool(false)
  of JsonRawNan:
    unsafeNextBy(reader, "NaN".len)
    v = newJFloat(NaN)
  of JsonRawInf:
    unsafeNextBy(reader, "Infinity".len)
    v = newJFloat(Inf)
  of JsonRawNegInf:
    unsafeNextBy(reader, "-Infinity".len)
    v = newJFloat(NegInf)
  of JsonNumber:
    reader.lockBuffer()
    try:
      let firstPos = skipNumber(format, reader)
      if firstPos < 0:
        reader.unexpectedError(format, "number value")
      var i = firstPos
      var integer: BiggestInt
      var chars = 
        when reader.currentBuffer is string:
          parseutils.parseBiggestInt(reader.currentBuffer, integer, i)
        else:
          parseutils.parseBiggestInt(reader.currentBuffer.toOpenArray(i, reader.currentBuffer.len - 1), integer)
      if firstPos + chars <= reader.bufferPos:
        i = firstPos
        var f: float
        chars =
          when reader.currentBuffer is string:
            parseutils.parseFloat(reader.currentBuffer, f, i)
          else:
            parseutils.parseFloat(reader.currentBuffer.toOpenArray(i, reader.currentBuffer.len - 1), f)
        assert firstPos + chars == reader.bufferPos + 1
        v = newJFloat(f)
      else:
        assert firstPos + chars == reader.bufferPos + 1
        v = newJInt(integer)
    finally:
      reader.unlockBuffer()

proc fromJson*(s: string): JsonNode {.inline.} =
  ## Takes json parses it into `JsonNode`s.
  result = fromJson(s, JsonNode)

proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var Option[T]) =
  ## Parse an Option.
  mixin read
  skipSpace(reader)
  if reader.nextMatch("null"):
    # v = none(T)?
    return
  var e: T
  read(format, reader, e)
  v = some(e)

template stringTableImpl(format, reader, v, K, V) =
  mixin read
  when v is ref:
    if reader.nextMatch("null"):
      # this is added this time
      return
    new(v)
  expectChar(format, reader, '{')
  while reader.hasNext():
    skipSpace(reader)
    if reader.peekMatch('}'):
      break
    var key: K
    read(format, reader, key)
    skipChar(reader, ':')
    var element: V
    read(format, reader, element)
    v[key] = element
    if reader.nextMatch(','):
      discard
    else:
      break
  skipChar(reader, '}')

proc read*[K: string | enum, V](format: JsonReadFormat, reader: JsonReaderArg, v: var Table[K, V]) =
  ## Parse an object.
  stringTableImpl(format, reader, v, K, V)

proc read*[K: string | enum, V](format: JsonReadFormat, reader: JsonReaderArg, v: var OrderedTable[K, V]) =
  ## Parse an object.
  stringTableImpl(format, reader, v, K, V)

proc read*[K: string | enum](format: JsonReadFormat, reader: JsonReaderArg, v: var CountTable[K]) =
  ## Parse an object.
  stringTableImpl(format, reader, v, K, int)

template anyTableImpl(format, reader, tab, K, V) =
  mixin read
  when tab is ref:
    if reader.nextMatch("null"):
      # this is added this time
      return
    new(tab)
  for _ in readArray(format, reader):
    var k: K
    var v: V
    for pairI in readArray(format, reader):
      if pairI == 0:
        read(format, reader, k)
      elif pairI == 1:
        read(format, reader, v)
      else:
        reader.error("expected table key/value pair, but extra element found")
    tab[k] = v

proc read*[K: not (string | enum), V](format: JsonReadFormat, reader: JsonReaderArg, tab: var Table[K, V]) =
  ## Parse a normal table.
  anyTableImpl(format, reader, tab, K, V)

proc read*[K: not (string | enum), V](format: JsonReadFormat, reader: JsonReaderArg, tab: var OrderedTable[K, V]) =
  ## Parse a normal table.
  anyTableImpl(format, reader, tab, K, V)

proc read*[K: not (string | enum)](format: JsonReadFormat, reader: JsonReaderArg, tab: var CountTable[K]) =
  ## Parse a normal table.
  anyTableImpl(format, reader, tab, K, int)

when false: # should not need anymore with the `ref object` overload disabled
  proc read*[K: string | enum, V](format: JsonReadFormat, reader: JsonReaderArg, v: var TableRef[K, V]) =
    ## Parse an object.
    tableImpl(format, reader, v, K, V)

  proc read*[K: string | enum, V](format: JsonReadFormat, reader: JsonReaderArg, v: var OrderedTableRef[K, V]) =
    ## Parse an object.
    tableImpl(format, reader, v, K, V)

  proc read*[K: string | enum](format: JsonReadFormat, reader: JsonReaderArg, v: var CountTableRef[K]) =
    ## Parse an object.
    tableImpl(format, reader, v, K, int)

proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var HashSet[T]) =
  ## Parses `HashSet`.
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    v.incl(e)

proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var OrderedSet[T]) =
  ## Parses `OrderedSet`.
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    v.incl(e)

proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var set[T]) =
  ## Parses the built-in `set` type.
  # separate overload for bitflags or something
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    v.incl(e)
