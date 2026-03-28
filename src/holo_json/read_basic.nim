## implements reading behavior for basic types

import ./[common, read_common, parser, read_helpers], holo_map/[caseutils, variants]
import std/[unicode, parseutils, typetraits, importutils, strbasics]

export JsonReader, JsonReaderArg, initJsonReader, startRead

proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var seq[T])
proc read*[T: enum](format: JsonReadFormat, reader: JsonReaderArg, v: var T) {.inline.}
proc read*[T: object](format: JsonReadFormat, reader: JsonReaderArg, v: var T)
proc read*[T: tuple](format: JsonReadFormat, reader: JsonReaderArg, v: var T)
proc read*[T: array](format: JsonReadFormat, reader: JsonReaderArg, v: var T)
proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var ref T) {.inline.}
proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var string) {.inline.}
proc read*[T: distinct](format: JsonReadFormat, reader: JsonReaderArg, v: var T) {.inline.}

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var RawJson) {.inline.} =
  reader.lockBuffer()
  try:
    let start = skipValue(format, reader)
    v = reader.currentBuffer[start .. reader.bufferPos].RawJson
  finally:
    reader.unlockBuffer()

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var RawJsonValue) {.inline.} =
  v = readRawValue(format, reader)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var bool) {.inline.} =
  ## Will parse boolean true or false.
  skipSpace(reader)
  var c: char
  if not peek(reader, c):
    reader.endError("bool value")
  case c
  of 'f':
    if reader.nextMatch("false"):
      v = false
    else:
      reader.valueError(format, "false")
  of 't':
    if reader.nextMatch("true"):
      v = true
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

proc readUnsignedInt*[T](format: JsonReadFormat, reader: JsonReaderArg, _: typedesc[T]): UintImpl[T] =
  #when nimvm: v = type(v)(parseBiggestUInt(parseSymbol(reader)))
  result = 0
  var gotChar = false
  for c in reader.chars():
    case c
    of '0'..'9':
      gotChar = true
      # XXX handle overflow
      #let prev = v2
      #if prev >= (high(typeof(v)) div 10 - digit):
      #  reader.error("uint overflow: got " & $prev & $c & "... > " & $high(typeof(v)))
      result = result * 10 + (typeof(result)(c) - typeof(result)('0'))
      #if v2 < prev:
      #  reader.error("uint overflow: got " & $prev & $c & "... > " & $high(typeof(v)))
    else:
      break
  if not gotChar:
    reader.unexpectedError(format, "number of type " & $T)

template uintImpl(T: typedesc) =
  skipSpace(reader)
  if reader.nextMatch('+'):
    discard
  let v2 = readUnsignedInt(format, reader, T)
  when sizeof(T) != sizeof(uint64):
    type Impl = UintImpl[T]
    if v2 > Impl(high(T)):
      reader.error("got uint value: " & $v2 & " > max unsigned of " & $T & ": " & $high(T))
  v = T(v2)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var uint) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var uint8) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint8)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var uint16) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint16)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var uint32) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint32)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var uint64) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl(uint64)

template intImpl(T: typedesc) =
  #when nimvm: v = type(v)(parseBiggestInt(parseSymbol(reader)))
  skipSpace(reader)
  if reader.nextMatch('+'):
    discard
  if reader.nextMatch('-'):
    let v2 = readUnsignedInt(format, reader, T)
    type Impl = UintImpl[T]
    if v2 > Impl(high(T)):
      if v2 == Impl(high(T)) + 1:
        v = low(T)
      else:
        reader.error("got int value: -" & $v2 & " > min of " & $T & ": -" & $high(T))
    else:
      v = -T(v2)
  else:
    let v2 = readUnsignedInt(format, reader, T)
    type Impl = UintImpl[T]
    if v2 > Impl(high(T)):
      reader.error("got int value: " & $v2 & " < max of " & $T & ": " & $high(T))
    else:
      v = T(v2)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var int) {.inline.} =
  ## Will parse signed integers.
  intImpl(int)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var int8) {.inline.} =
  ## Will parse signed integers.
  intImpl(int8)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var int16) {.inline.} =
  ## Will parse signed integers.
  intImpl(int16)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var int32) {.inline.} =
  ## Will parse signed integers.
  intImpl(int32)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var int64) {.inline.} =
  ## Will parse signed integers.
  intImpl(int64)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var float) =
  ## Will parse floats.
  skipSpace(reader)
  if reader.peekMatch('"'):
    # string, check for nim json nan and inf strings:
    if reader.nextMatch("\"nan\""):
      v = NaN
    elif reader.nextMatch("\"inf\""):
      v = Inf
    elif reader.nextMatch("\"-inf\""):
      v = NegInf
    else:
      reader.unexpectedError(format, "float string")
    return
  if format.rawJsNanInf:
    if reader.nextMatch("NaN"):
      v = NaN
      return
    elif reader.nextMatch("Infinity"):
      v = Inf
      return
    elif reader.nextMatch("-Infinity"):
      v = NegInf
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
    v = f
  finally:
    reader.unlockBuffer()

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var float32) {.inline.} =
  ## Will parse floats.
  var f: float
  read(format, reader, f)
  v = float32(f)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var string) {.inline.} =
  ## Parse string.
  if false:
    # XXX disabled for now maybe config option
    if reader.nextMatch("null"):
      return
  expectChar(format, reader, '"')
  v = parseString(format, reader, quoteSkipped = true)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var cstring) {.inline.} =
  ## Parse cstring.
  ## 
  ## on native backends, deallocating it is the user's responsibility
  if reader.nextMatch("null"):
    v = nil
    return
  expectChar(format, reader, '"')
  var s = parseString(format, reader, quoteSkipped = true)
  when nimvm:
    v = cstring(s)
  else:
    when defined(nimscript) or defined(js):
      v = cstring(s)
    else:
      v = cast[cstring](alloc(s.len))
      copyMem(addr v[0], addr s[0], s.len)

proc read*(format: JsonReadFormat, reader: JsonReaderArg, v: var char) {.inline.} =
  var str: string
  format.read(reader, str)
  if str.len != 1:
    reader.error("String can't fit into a char.")
  v = str[0]

proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var seq[T]) =
  ## Parse seq.
  mixin read
  for i in readArray(format, reader):
    var element: T
    read(format, reader, element)
    v.add element

proc read*[T: array](format: JsonReadFormat, reader: JsonReaderArg, v: var T) =
  mixin read
  skipSpace(reader)
  expectChar(format, reader, '[')
  var i = 0
  for value in v.mitems:
    inc i
    skipSpace(reader)
    if reader.peekMatch(']'):
      # XXX special parse is just for this error which i added could just remove
      reader.error("expected " & $i & "th element in array of len " & $len(v))
    read(format, reader, value)
    skipSpace(reader)
    if reader.nextMatch(','):
      discard
    elif reader.peekMatch(']'):
      # if it has a next element it will fail above
      discard
    else:
      # maybe improve error message wasnt in original
      reader.parseError("expected comma")
  skipChar(reader, ']')

proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var ref T) {.inline.} =
  mixin read
  skipSpace(reader)
  if reader.nextMatch("null"):
    v = nil # changed from original jsony which did nothing, pretty unambiguous here
    return
  new(v)
  read(format, reader, v[])

proc finishObjectRead*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var T) {.inline.} =
  ## hook called into when an object or named tuple has finished reading all fields
  ##
  ## does not work for ref objects, define it for their deref types,
  ## see `derefType` in `test_objects` for an easy way to do this
  discard

type HasNormalizer* = concept
  ## implement to normalize field names when reading in json, i.e. for style insensitivity
  proc normalizeField(_: typedesc[Self], format: type JsonReadFormat, name: string): string

when holoJsonObjectStyleInsensitivity:
  from std/strutils import nimIdentNormalize
  proc normalizeField*[T: object](_: typedesc[T], format: type JsonReadFormat, name: string): string =
    nimIdentNormalize(name)

when holoJsonEnumStyleInsensitivity:
  when not declared(nimIdentNormalize):
    from std/strutils import nimIdentNormalize
  proc normalizeField*[T: enum](_: typedesc[T], format: type JsonReadFormat, name: string): string =
    nimIdentNormalize(name)

template implNormalizer[T: HasNormalizer](_: typedesc[T]): untyped =
  mixin normalizeField
  template normalizerImpl(s: string): string {.inject.} =
    normalizeField(`T`, JsonReadFormat, s)

template implNormalizer[T: not HasNormalizer](_: typedesc[T]): untyped =
  when (ref T) is HasNormalizer:
    implNormalizer(ref T)
  else:
    const normalizerImpl {.inject.} = nil

proc parseObjectInner[T](format: JsonReadFormat, reader: JsonReaderArg, obj: var T) {.inline.} =
  mixin read
  privateAccess(T) # important
  while reader.hasNext():
    skipSpace(reader)
    if reader.peekMatch('}'):
      break
    var key: string
    read(format, reader, key)
    skipChar(reader, ':')
    {.cast(uncheckedAssign).}:
      when jsonyHookCompatibility and compiles(renameHook(obj, key)):
        renameHook(obj, key)
        block all:
          for k, v in fieldPairs(when obj is ref: obj[] else: obj):
            if k == key or static(toSnakeCase(k)) == key:
              read(format, reader, v)
              break all
          discard skipValue(format, reader)
      else:
        template onFieldInput(f) =
          read(format, reader, f)
        const mappings = getActualFieldMappings(T, HoloJson)
        implNormalizer(T)
        mapFieldInput(obj, key, mappings, normalizerImpl, jsonDefaultInputNames, onFieldInput):
          discard skipValue(format, reader)
    skipSpace(reader)
    if reader.nextMatch(','):
      discard
    else:
      break
  mixin finishObjectRead
  finishObjectRead(format, reader, obj)

proc read*[T: tuple](format: JsonReadFormat, reader: JsonReaderArg, v: var T) =
  mixin read
  skipSpace(reader)
  when isNamedTuple(T):
    if reader.nextMatch('{'):
      parseObjectInner(format, reader, v)
      skipChar(reader, '}')
      return
  expectChar(format, reader, '[')
  for name, value in v.fieldPairs:
    skipSpace(reader)
    read(format, reader, value)
    skipSpace(reader)
    if reader.nextMatch(','):
      discard
  skipChar(reader, ']')

proc readEnumString*[T: enum](format: JsonReadFormat, reader: JsonReaderArg, _: typedesc[T]): T =
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

proc read*[T: enum](format: JsonReadFormat, reader: JsonReaderArg, v: var T) {.inline.} =
  skipSpace(reader)
  if reader.peekMatch('"'):
    v = readEnumString(format, reader, T)
  elif reader.peekMatch({'-', '+', '0'..'9'}):
    # XXX custom low/high using readUnsignedInt?
    var integer: int
    read(format, reader, integer)
    v = T(integer) # XXX maybe case statement here #17
  else:
    reader.unexpectedError(format, "enum value of type " & $T)

proc startObjectRead*[T](format: JsonReadFormat, reader: JsonReaderArg, v: var T) {.inline.} =
  ## hook called into when an object or named tuple are about to read their fields
  ##
  ## does not work for ref objects, define it for their deref types,
  ## see `derefType` in `test_objects` for an easy way to do this
  discard

template initObj[T](v: var T) =
  mixin startObjectRead
  when false: # refs disabled
    when v is ref:
      new(v)
  startObjectRead(format, reader, v)

template initObjVariant[T](v: var T, discrimField, discrimValue) =
  mixin startObjectRead
  v = T(`discrimField`: `discrimValue`)
  startObjectRead(format, reader, v)

proc read*[T: object](format: JsonReadFormat, reader: JsonReaderArg, v: var T) =
  ## Parse an object.
  privateAccess(T) # important
  mixin read
  skipSpace(reader)
  when false: # refs disabled
    when T is ref: # changed from original jsony, which allows object
      # XXX maybe config option? has test
      if reader.nextMatch("null"):
        v = nil # changed from original jsony, where it does nothing
        return
  expectChar(format, reader, '{')
  when not hasVariants(T):
    initObj(v)
  else:
    # scan for field names belonging to a variant branch, or the variant field itself
    skipSpace(reader)
    reader.lockBuffer()
    var savedState = reader.state # XXX using `let` makes VM not copy here
    try:
      while reader.hasNext():
        var key: string
        read(format, reader, key)
        skipChar(reader, ':')
        when jsonyHookCompatibility and compiles(renameHook(v, key)):
          renameHook(v, key)
          template onVariantField(f) =
            if key == astToStr(f):
              var discrimValue: typeof(v.`f`)
              read(format, reader, discrimValue)
              initObjVariant(v, `f`, discrimValue)
              break
          withFirstVariantFieldName(T, onVariantField)
        else:
          template onVariantField(f) =
            var v2: typeof(v.`f`)
            read(format, reader, v2)
            initObjVariant(v, `f`, v2)
            break
          template onInnerField(f, vf, discrim) =
            initObjVariant(v, `vf`, `discrim`)
            break
          const mappings = getActualFieldMappings(T, HoloJson)
          implNormalizer(T)
          mapInputVariantFieldName(T, key,
            mappings, normalizerImpl, jsonDefaultInputNames,
            onInnerField, onVariantField): discard
        discard skipValue(format, reader)
        if not reader.peekMatch('}'):
          # needs space skipped above?
          skipChar(reader, ',')
        else:
          initObj(v)
          break
    finally:
      reader.state = savedState
      reader.unlockBuffer()
  parseObjectInner(format, reader, v)
  skipChar(reader, '}')

proc read*[T: distinct](format: JsonReadFormat, reader: JsonReaderArg, v: var T) {.inline.} =
  mixin read
  read(format, reader, distinctBase(T)(v))

proc read*[T](format: JsonReadFormat, reader: JsonReaderArg, _: typedesc[T]): T =
  mixin read
  read(format, reader, result)

proc readJson*[T](reader: JsonReaderArg, v: var T) {.inline.} =
  mixin read
  read(JsonReadFormat(), reader, v)

proc readJson*[T](reader: JsonReaderArg, _: typedesc[T]): T {.inline.} =
  mixin read
  read(JsonReadFormat(), reader, result)

proc fromJson*[T](s: string, x: typedesc[T], format = JsonReadFormat()): T {.inline.} =
  ## Takes json and outputs the object it represents.
  ## * Extra json fields are ignored.
  ## * Missing json fields keep their default values.
  ## * `proc startObjectRead(format: JsonReadFormat, reader: JsonReaderArg, foo: var ...)` Can be used to populate default values.
  mixin read
  result = default(T)
  var reader = initJsonReader()
  reader.startRead(s)
  read(format, reader, result)
  skipSpace(reader)
  if reader.hasNext():
    var msg = "Found non-whitespace character after JSON data: "
    msg.addQuoted(reader.peekOrZero())
    reader.parseError(msg)
