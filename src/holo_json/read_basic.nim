## implements reading behavior for basic types

import ./[common, read_common, parser, read_helpers], cosm/[caseutils, variants, field_map]
import std/[unicode, parseutils, typetraits, importutils, strbasics]

export JsonReader, JsonReaderArg, initJsonReader, startRead

proc read*[T](format: JsonRead, reader: JsonReaderArg, value: var seq[T]) {.inline, gcsafe.}
proc read*[T: enum](format: JsonRead, reader: JsonReaderArg, value: var T) {.inline, gcsafe.}
proc read*[T: object](format: JsonRead, reader: JsonReaderArg, value: var T) {.gcsafe.}
proc read*[T: tuple](format: JsonRead, reader: JsonReaderArg, value: var T) {.gcsafe.}
proc read*[T: array](format: JsonRead, reader: JsonReaderArg, value: var T) {.gcsafe.}
proc read*[T](format: JsonRead, reader: JsonReaderArg, value: var ref T) {.inline, gcsafe.}
proc read*(format: JsonRead, reader: JsonReaderArg, value: var string) {.inline, gcsafe.}
proc read*[T: distinct](format: JsonRead, reader: JsonReaderArg, value: var T) {.inline, gcsafe.}

proc read*(format: JsonRead, reader: JsonReaderArg, value: var RawJson) {.inline.} =
  reader.lockBuffer()
  try:
    let start = skipValue(format, reader)
    value = reader.currentBuffer[start .. reader.bufferPos].RawJson
  finally:
    reader.unlockBuffer()

proc read*(format: JsonRead, reader: JsonReaderArg, value: var RawJsonValue) {.inline.} =
  value = readRawValue(format, reader)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var bool) {.inline.} =
  ## Will parse boolean true or false.
  skipSpace(format, reader)
  var c: char
  if not peek(reader, c):
    reader.endError("bool value")
  case c
  of 'f':
    if reader.nextMatch("false"):
      value = false
    else:
      reader.valueError(format, "false")
  of 't':
    if reader.nextMatch("true"):
      value = true
    else:
      reader.valueError(format, "true")
  else:
    reader.valueError(format, "bool value")

type UintImpl[T] = (
  #when sizeof(uint) == sizeof(uint64) or sizeof(uint) < sizeof(T):
  when sizeof(T) == sizeof(uint64):
    uint64
  else: # for JS etc
    uint32
)

proc readUnsignedInt*[T](format: JsonRead, reader: JsonReaderArg, _: typedesc[T]): UintImpl[T] =
  #when nimvm: value = type(value)(parseBiggestUInt(parseSymbol(reader)))
  result = 0
  var gotChar = false
  for c in reader.chars():
    case c
    of '0'..'9':
      gotChar = true
      # XXX handle overflow
      #let prev = v2
      #if prev >= (high(typeof(value)) div 10 - digit):
      #  reader.error("uint overflow: got " & $prev & $c & "... > " & $high(typeof(value)))
      result = result * 10 + (typeof(result)(c) - typeof(result)('0'))
      #if v2 < prev:
      #  reader.error("uint overflow: got " & $prev & $c & "... > " & $high(typeof(value)))
    else:
      break
  if not gotChar:
    reader.unexpectedError(format, "number of type " & $T)

template uintImpl(T: typedesc) =
  skipSpace(format, reader)
  if reader.nextMatch('+'):
    discard
  let v2 = readUnsignedInt(format, reader, T)
  when sizeof(T) != sizeof(uint64):
    type Impl = UintImpl[T]
    if v2 > Impl(high(T)):
      reader.error("got uint value: " & $v2 & " > max unsigned of " & $T & ": " & $high(T))
  value = T(v2)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var uint) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var uint8) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint8)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var uint16) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint16)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var uint32) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint32)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var uint64) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint64)

template intImpl(T: typedesc) =
  #when nimvm: value = type(value)(parseBiggestInt(parseSymbol(reader)))
  skipSpace(format, reader)
  if reader.nextMatch('+'):
    discard
  if reader.nextMatch('-'):
    let v2 = readUnsignedInt(format, reader, T)
    type Impl = UintImpl[T]
    if v2 > Impl(high(T)):
      if v2 == Impl(high(T)) + 1:
        value = low(T)
      else:
        reader.error("got int value: -" & $v2 & " > min of " & $T & ": -" & $high(T))
    else:
      value = -T(v2)
  else:
    let v2 = readUnsignedInt(format, reader, T)
    type Impl = UintImpl[T]
    if v2 > Impl(high(T)):
      reader.error("got int value: " & $v2 & " < max of " & $T & ": " & $high(T))
    else:
      value = T(v2)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var int) {.inline.} =
  ## Will parse signed integers.
  intImpl(int)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var int8) {.inline.} =
  ## Will parse signed integers.
  intImpl(int8)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var int16) {.inline.} =
  ## Will parse signed integers.
  intImpl(int16)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var int32) {.inline.} =
  ## Will parse signed integers.
  intImpl(int32)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var int64) {.inline.} =
  ## Will parse signed integers.
  intImpl(int64)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var float) =
  ## Will parse floats.
  skipSpace(format, reader)
  if reader.peekMatch('"'):
    # string, check for nim json nan and inf strings:
    if reader.nextMatch("\"nan\""):
      value = NaN
    elif reader.nextMatch("\"inf\""):
      value = Inf
    elif reader.nextMatch("\"-inf\""):
      value = NegInf
    else:
      reader.unexpectedError(format, "float string")
    return
  if format.rawJsNanInf:
    if reader.nextMatch("NaN"):
      value = NaN
      return
    elif reader.nextMatch("Infinity"):
      value = Inf
      return
    elif reader.nextMatch("-Infinity"):
      value = NegInf
      return
  # build float string based on acceptable characters:
  reader.lockBuffer()
  try:
    let firstPos = skipNumber(format, reader)
    if firstPos < 0:
      reader.unexpectedError(format, "float")
    var i = firstPos
    var f: float
    let chars =
      when reader.currentBuffer is string:
        parseutils.parseFloat(reader.currentBuffer, f, i)
      else:
        parseutils.parseFloat(reader.currentBuffer.toOpenArray(i, reader.currentBuffer.len - 1), f)
    assert firstPos + chars == reader.bufferPos + 1
    value = f
  finally:
    reader.unlockBuffer()

proc read*(format: JsonRead, reader: JsonReaderArg, value: var float32) {.inline.} =
  ## Will parse floats.
  var f: float
  read(format, reader, f)
  value = float32(f)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var string) {.inline.} =
  ## Parse string.
  if false:
    # XXX disabled for now maybe config option
    if reader.nextMatch("null"):
      return
  expectChar(format, reader, '"')
  value = parseString(format, reader, quoteSkipped = true)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var cstring) {.inline.} =
  ## Parse cstring.
  ## 
  ## on native backends, deallocating it is the user's responsibility
  if reader.nextMatch("null"):
    value = nil
    return
  expectChar(format, reader, '"')
  var s = parseString(format, reader, quoteSkipped = true)
  when nimvm:
    value = cstring(s)
  else:
    when defined(nimscript) or defined(js):
      value = cstring(s)
    else:
      value = cast[cstring](alloc(s.len))
      copyMem(addr value[0], addr s[0], s.len)

proc read*(format: JsonRead, reader: JsonReaderArg, value: var char) {.inline.} =
  var str: string
  format.read(reader, str)
  if str.len != 1:
    reader.error("String can't fit into a char.")
  value = str[0]

proc readSeq*[T](format: JsonRead, reader: JsonReaderArg): seq[T] =
  ## reads a JSON array as a seq of T
  mixin read
  result = @[]
  for i in readArray(format, reader):
    var element: T
    read(format, reader, element)
    result.add element

proc read*[T](format: JsonRead, reader: JsonReaderArg, value: var seq[T]) {.inline.} =
  ## Parse seq.
  value = readSeq[T](format, reader)

proc read*[T: array](format: JsonRead, reader: JsonReaderArg, value: var T) =
  mixin read
  skipSpace(format, reader)
  expectChar(format, reader, '[')
  var i = 0
  for value in value.mitems:
    inc i
    skipSpace(format, reader)
    if reader.peekMatch(']'):
      # XXX special parse is just for this error which i added could just remove
      reader.error("expected " & $i & "th element in array of len " & $len(value))
    read(format, reader, value)
    skipSpace(format, reader)
    if reader.nextMatch(','):
      discard
    elif reader.peekMatch(']'):
      # if it has a next element it will fail above
      discard
    else:
      # maybe improve error message wasnt in original
      reader.parseError("expected comma")
  skipChar(format, reader, ']')

proc read*[T](format: JsonRead, reader: JsonReaderArg, value: var ref T) {.inline.} =
  mixin read
  skipSpace(format, reader)
  if reader.nextMatch("null"):
    value = nil # changed from original jsony which did nothing, pretty unambiguous here
    return
  new(value)
  read(format, reader, value[])

proc finishObjectRead*[T](format: JsonRead, reader: JsonReaderArg, value: var T) {.inline.} =
  ## hook called into when an object or named tuple has finished reading all fields
  ##
  ## does not work for ref objects, define it for their deref types,
  ## see `derefType` in `test_objects` for an easy way to do this
  discard

type HasNormalizer* = concept
  ## implement to normalize field names when reading in json, i.e. for style insensitivity
  proc normalizeField(_: typedesc[Self], format: type JsonRead, name: string): string

when holoJsonObjectStyleInsensitivity:
  from std/strutils import nimIdentNormalize
  proc normalizeField*[T: object](_: typedesc[T], format: type JsonRead, name: string): string =
    nimIdentNormalize(name)

when holoJsonEnumStyleInsensitivity:
  when not declared(nimIdentNormalize):
    from std/strutils import nimIdentNormalize
  proc normalizeField*[T: enum](_: typedesc[T], format: type JsonRead, name: string): string =
    nimIdentNormalize(name)

template implNormalizer[T: HasNormalizer](_: typedesc[T]): untyped =
  mixin normalizeField
  template normalizerImpl(s: string): string {.inject.} =
    normalizeField(`T`, JsonRead, s)

template implNormalizer[T: not HasNormalizer](_: typedesc[T]): untyped =
  when (ref T) is HasNormalizer:
    implNormalizer(ref T)
  else:
    const normalizerImpl {.inject.} = nil

proc parseObjectInner[T](format: JsonRead, reader: JsonReaderArg, obj: var T) {.inline.} =
  mixin read
  privateAccess(T) # XXX https://github.com/holo-nim/cosm/issues/8
  while reader.hasNext():
    skipSpace(format, reader)
    if reader.peekMatch('}'):
      break
    var key: string
    read(format, reader, key)
    skipChar(format, reader, ':')
    {.cast(uncheckedAssign).}:
      when jsonyHookCompatibility and compiles(renameHook(obj, key)):
        renameHook(obj, key)
        block all:
          for k, value in fieldPairs(when obj is ref: obj[] else: obj):
            if k == key or static(toSnakeCase(k)) == key:
              read(format, reader, value)
              break all
          discard skipValue(format, reader)
      else:
        template onFieldInput(f) {.used.} =
          read(format, reader, f)
        const mappings = getActualFieldMappings(T, HoloJson)
        implNormalizer(T)
        mapFieldInput(obj, key, mappings, normalizerImpl, jsonDefaultInputNames, onFieldInput):
          discard skipValue(format, reader)
    skipSpace(format, reader)
    if reader.nextMatch(','):
      discard
    else:
      break
  mixin finishObjectRead
  finishObjectRead(format, reader, obj)

proc read*[T: tuple](format: JsonRead, reader: JsonReaderArg, value: var T) =
  mixin read
  skipSpace(format, reader)
  when isNamedTuple(T):
    if reader.nextMatch('{'):
      parseObjectInner(format, reader, value)
      skipChar(format, reader, '}')
      return
  expectChar(format, reader, '[')
  for name, value in value.fieldPairs:
    skipSpace(format, reader)
    read(format, reader, value)
    skipSpace(format, reader)
    if reader.nextMatch(','):
      discard
  skipChar(format, reader, ']')

proc readEnumString*[T: enum](format: JsonRead, reader: JsonReaderArg, _: typedesc[T]): T =
  var strV: string
  read(format, reader, strV)
  when jsonyHookCompatibility and compiles(enumHook(strV, result)):
    enumHook(strV, result)
  else:
    template onEnumInput(e: T) =
      result = e
    when T is HasFieldMappings:
      const mappings = getActualFieldMappings(T, HoloJson)
    else:
      const mappings = default(FieldMappingPairs)
    implNormalizer(T)
    mapEnumFieldInput(T, strV, mappings, normalizerImpl, onEnumInput):
      reader.error("could not parse enum of type " & $T & " from string: " & $strV)

proc read*[T: enum](format: JsonRead, reader: JsonReaderArg, value: var T) {.inline.} =
  skipSpace(format, reader)
  if reader.peekMatch('"'):
    value = readEnumString(format, reader, T)
  elif reader.peekMatch({'-', '+', '0'..'9'}):
    # XXX custom low/high using readUnsignedInt?
    var integer: int
    read(format, reader, integer)
    value = T(integer) # XXX maybe case statement here #17
  else:
    reader.unexpectedError(format, "enum value of type " & $T)

proc startObjectRead*[T](format: JsonRead, reader: JsonReaderArg, value: var T) {.inline.} =
  ## hook called into when an object or named tuple are about to read their fields
  ##
  ## does not work for ref objects, define it for their deref types,
  ## see `derefType` in `test_objects` for an easy way to do this
  discard

template initObj[T](value: var T) =
  mixin startObjectRead
  when false: # refs disabled
    when value is ref:
      new(value)
  startObjectRead(format, reader, value)

template initObjVariant[T](value: var T, discrimField, discrimValue) =
  mixin startObjectRead
  value = T(`discrimField`: `discrimValue`)
  startObjectRead(format, reader, value)

proc read*[T: object](format: JsonRead, reader: JsonReaderArg, value: var T) =
  ## Takes json and outputs the object it represents.
  ## * Extra json fields are ignored.
  ## * Missing json fields keep their default values.
  ## * `proc startObjectRead(format: JsonRead, reader: JsonReaderArg, foo: var ...)` can be used to populate default values.
  privateAccess(T) # XXX https://github.com/holo-nim/cosm/issues/8
  mixin read
  skipSpace(format, reader)
  when false: # refs disabled
    when T is ref: # changed from original jsony, which allows object
      # XXX maybe config option? has test
      if reader.nextMatch("null"):
        value = nil # changed from original jsony, where it does nothing
        return
  expectChar(format, reader, '{')
  when not hasVariants(T):
    initObj(value)
  else:
    # scan for field names belonging to a variant branch, or the variant field itself
    skipSpace(format, reader)
    reader.lockBuffer()
    var savedState = reader.state # XXX using `let` makes VM not copy here
    try:
      while reader.hasNext():
        var key: string
        read(format, reader, key)
        skipChar(format, reader, ':')
        when jsonyHookCompatibility and compiles(renameHook(value, key)):
          renameHook(value, key)
          template onVariantField(f) =
            if key == astToStr(f):
              var discrimValue: typeof(value.`f`)
              read(format, reader, discrimValue)
              initObjVariant(value, `f`, discrimValue)
              break
          withFirstVariantFieldName(T, onVariantField)
        else:
          template onVariantField(f) {.used.} =
            var v2: typeof(value.`f`)
            read(format, reader, v2)
            initObjVariant(value, `f`, v2)
            break
          template onInnerField(f, vf, discrim) {.used.} =
            initObjVariant(value, `vf`, `discrim`)
            break
          const mappings = getActualFieldMappings(T, HoloJson)
          implNormalizer(T)
          mapInputVariantFieldName(T, key,
            mappings, normalizerImpl, jsonDefaultInputNames,
            onInnerField, onVariantField): discard
        discard skipValue(format, reader)
        if not reader.peekMatch('}'):
          # needs space skipped above?
          skipChar(format, reader, ',')
        else:
          initObj(value)
          break
    finally:
      reader.state = savedState
      reader.unlockBuffer()
  parseObjectInner(format, reader, value)
  skipChar(format, reader, '}')

proc read*[T: distinct](format: JsonRead, reader: JsonReaderArg, value: var T) {.inline.} =
  mixin read
  read(format, reader, distinctBase(T)(value))

proc read*[T](format: JsonRead, reader: JsonReaderArg, _: typedesc[T]): T =
  mixin read
  read(format, reader, result)

proc readJson*[T](reader: JsonReaderArg, value: var T) {.inline.} =
  mixin read
  read(JsonRead(), reader, value)

proc readJson*[T](reader: JsonReaderArg, _: typedesc[T]): T {.inline.} =
  mixin read
  read(JsonRead(), reader, result)

proc fromJson*[T](x: typedesc[T], s: string, format = JsonRead()): T {.inline.} =
  mixin read
  result = default(T)
  var reader = initJsonReader()
  reader.startRead(s)
  read(format, reader, result)
  skipSpace(format, reader)
  if reader.hasNext():
    var msg = "Found non-whitespace character after JSON data: "
    msg.addQuoted(reader.peekOrZero())
    reader.parseError(msg)

proc fromJsonAs*[T](s: string, x: typedesc[T], format = JsonRead()): T {.inline.} =
  fromJson(T, s, format)
