## `read` hooks for stdlib types

import ./[common, read_common, read_basic, parser, read_helpers], std/[options, tables, sets, json, parseutils]

proc read*(format: JsonRead, reader: JsonReaderArg, value: var JsonNode) =
  ## Parses a regular json node.
  skipSpace(format, reader)
  let kind = peekRawKind(format, reader)
  case kind
  of JsonInvalid:
    reader.unexpectedError(format, "json value")
  of JsonObject:
    value = newJObject()
    for k in readObject[string](format, reader):
      var e: JsonNode
      read(format, reader, e)
      value[k] = e
  of JsonArray:
    value = newJArray()
    for i in readArray(format, reader):
      var e: JsonNode
      read(format, reader, e)
      value.add(e)
  of JsonString:
    var str: string
    read(format, reader, str)
    value = newJString(str)
  of JsonNull:
    unsafeNextBy(reader, "null".len)
    value = newJNull()
  of JsonTrue:
    unsafeNextBy(reader, "true".len)
    value = newJBool(true)
  of JsonFalse:
    unsafeNextBy(reader, "false".len)
    value = newJBool(false)
  of JsonRawNan:
    unsafeNextBy(reader, "NaN".len)
    value = newJFloat(NaN)
  of JsonRawInf:
    unsafeNextBy(reader, "Infinity".len)
    value = newJFloat(Inf)
  of JsonRawNegInf:
    unsafeNextBy(reader, "-Infinity".len)
    value = newJFloat(NegInf)
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
        value = newJFloat(f)
      else:
        assert firstPos + chars == reader.bufferPos + 1
        value = newJInt(integer)
    finally:
      reader.unlockBuffer()

proc fromJson*(s: string): JsonNode {.inline.} =
  ## Takes json parses it into `JsonNode`s.
  result = fromJson(JsonNode, s)

proc read*[T](format: JsonRead, reader: JsonReaderArg, value: var Option[T]) =
  ## Parse an Option.
  mixin read
  skipSpace(format, reader)
  if reader.nextMatch("null"):
    # value = none(T)?
    return
  var e: T
  read(format, reader, e)
  value = some(e)

template anyTableImpl(format, reader, tab, K, V) =
  mixin read, jsonUseStringKey
  when tab is ref:
    if reader.nextMatch("null"):
      # this is added this time
      return
    new(tab)
  when jsonUseStringKey(K):
    for key in readObject[K](format, reader):
      var element: V
      read(format, reader, element)
      tab[key] = element
  else:
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

proc read*[K, V](format: JsonRead, reader: JsonReaderArg, tab: var Table[K, V]) =
  ## Parse a normal table.
  anyTableImpl(format, reader, tab, K, V)

proc read*[K, V](format: JsonRead, reader: JsonReaderArg, tab: var OrderedTable[K, V]) =
  ## Parse a normal table.
  anyTableImpl(format, reader, tab, K, V)

proc read*[K](format: JsonRead, reader: JsonReaderArg, tab: var CountTable[K]) =
  ## Parse a normal table.
  anyTableImpl(format, reader, tab, K, int)

when false: # should not need anymore with the `ref object` overload disabled
  proc read*[K, V](format: JsonRead, reader: JsonReaderArg, value: var TableRef[K, V]) =
    ## Parse an object.
    anyTableImpl(format, reader, value, K, V)

  proc read*[K, V](format: JsonRead, reader: JsonReaderArg, value: var OrderedTableRef[K, V]) =
    ## Parse an object.
    anyTableImpl(format, reader, value, K, V)

  proc read*[K](format: JsonRead, reader: JsonReaderArg, value: var CountTableRef[K]) =
    ## Parse an object.
    anyTableImpl(format, reader, value, K, int)

proc read*[T](format: JsonRead, reader: JsonReaderArg, value: var HashSet[T]) =
  ## Parses `HashSet`.
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    value.incl(e)

proc read*[T](format: JsonRead, reader: JsonReaderArg, value: var OrderedSet[T]) =
  ## Parses `OrderedSet`.
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    value.incl(e)

proc read*[T](format: JsonRead, reader: JsonReaderArg, value: var set[T]) =
  ## Parses the built-in `set` type.
  # separate overload for bitflags or something
  mixin read
  for i in readArray(format, reader):
    var e: T
    read(format, reader, e)
    value.incl(e)
