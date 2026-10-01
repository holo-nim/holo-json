## implements dumping behavior for basic types 

# helpers imported mostly for relevant types:
import ./[common, dump_common, dump_helpers], std/[typetraits, unicode], cosm/field_map
import std/math # for classify

export JsonWriter, JsonWriterArg, initJsonWriter, startWrite, finishWrite, write

proc dump*(format: JsonDump, writer: JsonWriterArg, value: string) {.gcsafe.}
proc dump*[N, T](format: JsonDump, writer: JsonWriterArg, value: array[N, tuple[a: string, b: T]]) {.gcsafe.}
proc dump*[N, T](format: JsonDump, writer: JsonWriterArg, value: array[N, T]) {.gcsafe.}
proc dump*[T](format: JsonDump, writer: JsonWriterArg, value: seq[T]) {.gcsafe.}
proc dump*[T: object](format: JsonDump, writer: JsonWriterArg, value: T) {.inline, gcsafe.}
proc dump*[T: distinct](format: JsonDump, writer: JsonWriterArg, value: T) {.inline, gcsafe.}

proc dump*[T: distinct](format: JsonDump, writer: JsonWriterArg, value: T) {.inline.} =
  mixin dump
  format.dump(writer, distinctBase(T)(value))

proc dump*(format: JsonDump, writer: JsonWriterArg, value: bool) {.inline.} =
  if value:
    writer.write "true"
  else:
    writer.write "false"

proc dumpNumberSlow(writer: JsonWriterArg, value: uint|uint8|uint16|uint32|uint64) {.inline.} =
  writer.write $value.uint64

const twoDigitLookup = block:
  ## Generate 00, 01, 02 ... 99 pairs.
  var s = ""
  for i in 0 ..< 100:
    if i < 10:
      s.add("0")
    s.add($i)
  s

proc dumpNumberFast(writer: JsonWriterArg, value: uint|uint8|uint16|uint32|uint64) =
  # Its faster to not allocate a string for a number,
  # but to write it out the digits directly.
  if value == 0:
    writer.write '0'
    return
  # Max size of a uin64 number is 20 digits.
  var digits: array[20, char]
  var v = value
  var p = 0
  while v != 0:
    # Its faster to look up 2 digits at a time, less int divisions.
    let idx = v mod 100
    digits[p] = twoDigitLookup[idx*2+1]
    inc p
    digits[p] = twoDigitLookup[idx*2]
    inc p
    v = v div 100
  if digits[p-1] == '0':
    dec p
  when supportsIndent(writer):
    writer.maybeInsertIndent()
  var at = writer.currentBuffer.len
  writer.currentBuffer.setLen(at + p)
  dec p
  while p >= 0:
    writer.currentBuffer[at] = digits[p]
    dec p
    inc at
  writer.consumeBuffer()

template uintImpl() =
  when jsonyIntOutput:
    when nimvm:
      writer.dumpNumberSlow(value)
    else:
      when defined(js):
        writer.dumpNumberSlow(value)
      else:
        writer.dumpNumberFast(value)
  else:
    when supportsIndent(writer):
      writer.maybeInsertIndent()
    writer.currentBuffer.addInt value
    writer.consumeBuffer()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: uint) {.inline.} =
  uintImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: uint8) {.inline.} =
  uintImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: uint16) {.inline.} =
  uintImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: uint32) {.inline.} =
  uintImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: uint64) {.inline.} =
  uintImpl()

template intImpl() =
  when jsonyIntOutput:
    if value < 0:
      writer.write '-'
      dump(format, writer, 0.uint64 - value.uint64)
    else:
      dump(format, writer, value.uint64)
  else:
    when supportsIndent(writer):
      writer.maybeInsertIndent()
    writer.currentBuffer.addInt value
    writer.consumeBuffer()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: int) {.inline.} =
  intImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: int8) {.inline.} =
  intImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: int16) {.inline.} =
  intImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: int32) {.inline.} =
  intImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: int64) {.inline.} =
  intImpl()

template floatImpl() =
  #writer.write $value # original jsony
  let cls = classify(value)
  case cls
  of fcNan:
    if format.rawJsNanInf:
      writer.write "NaN"
    else:
      # copy nim json
      writer.write "\"nan\""
  of fcInf:
    if format.rawJsNanInf:
      writer.write "Infinity"
    else:
      # copy nim json
      writer.write "\"inf\""
  of fcNegInf:
    if format.rawJsNanInf:
      writer.write "-Infinity"
    else:
      # copy nim json
      writer.write "\"-inf\""
  else:
    when supportsIndent(writer):
      writer.maybeInsertIndent()
    writer.currentBuffer.addFloat(value)
    writer.consumeBuffer()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: float) =
  floatImpl()

proc dump*(format: JsonDump, writer: JsonWriterArg, value: float32) =
  floatImpl()

proc validRuneAt(s: string, i: int, rune: var Rune): int =
  # returns number of skipped bytes
  # Based on fastRuneAt from std/unicode
  result = 0

  template ones(n: untyped): untyped = static((1 shl n)-1)

  if uint8(s[i]) <= 127:
    result = 1
    rune = Rune(s[i].byte)
  elif uint8(s[i]) shr 5 == 0b110:
    if i <= s.len - 2:
      let valid = (uint8(s[i+1]) shr 6 == 0b10)
      if valid:
        result = 2
        rune = Rune(
          (uint8(s[i]) and (ones(5))) shl 6 or
          (uint8(s[i+1]) and ones(6))
        )
  elif uint8(s[i]) shr 4 == 0b1110:
    if i <= s.len - 3:
      let valid =
        (uint8(s[i+1]) shr 6 == 0b10) and
        (uint8(s[i+2]) shr 6 == 0b10)
      if valid:
        result = 3
        rune = Rune(
          (uint8(s[i]) and ones(4)) shl 12 or
          (uint8(s[i+1]) and ones(6)) shl 6 or
          (uint8(s[i+2]) and ones(6))
        )
  elif uint8(s[i]) shr 3 == 0b11110:
    if i <= s.len - 4:
      let valid =
        (uint8(s[i+1]) shr 6 == 0b10) and
        (uint8(s[i+2]) shr 6 == 0b10) and
        (uint8(s[i+3]) shr 6 == 0b10)
      if valid:
        result = 4
        rune = Rune(
          (uint8(s[i]) and ones(3)) shl 18 or
          (uint8(s[i+1]) and ones(6)) shl 12 or
          (uint8(s[i+2]) and ones(6)) shl 6 or
          (uint8(s[i+3]) and ones(6))
        )

const hex = [
  '0', '1', '2', '3', '4', '5', '6', '7',
  '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']

template escapeByte(writer: JsonWriterArg, c: char) =
  if format.useXEscape:
    let chars = ['\\', 'x', hex[c.int shr 4], hex[c.int and 0xF]]
    writer.write chars
  else:
    let chars = ['\\', 'u', '0', '0', hex[c.int shr 4], hex[c.int and 0xF]]
    writer.write chars

proc dump*(format: JsonDump, writer: JsonWriterArg, value: string) =
  writer.write '"'

  var i = 0

  const doCopy = holoJsonBatchStringAdd

  when doCopy:
    var
      copyStart = 0
      inCopy = false
    template enterCopy() =
      if not inCopy:
        copyStart = i
        inCopy = true
    template finishCopy() =
      if inCopy:
        if i >= copyStart:
          let numBytes = i - copyStart
          let sLen = writer.currentBuffer.len
          writer.currentBuffer.setLen(sLen + numBytes)
          when nimvm:
            for p in 0 ..< numBytes:
              writer.currentBuffer[sLen + p] = value[copyStart + p]
          else:
            when not holoJsonStringCopyMem or defined(js) or defined(nimscript):
              for p in 0 ..< numBytes:
                writer.currentBuffer[sLen + p] = value[copyStart + p]
            else:
              copyMem(writer.currentBuffer[sLen].addr, value[copyStart].unsafeAddr, numBytes)
          writer.consumeBuffer()
        inCopy = false

  try:
    while i < value.len:
      let c = value[i]
      if (cast[uint8](c) and 0b10000000) == 0:
        # When the high bit is not set this is a single-byte character (ASCII)
        # Does this character need escaping?
        if c < 32.char or c == '\\' or c == '"':
          when doCopy:
            finishCopy()
          case c
          of '\\': writer.write r"\\"
          of '\b': writer.write r"\b"
          of '\f': writer.write r"\f"
          of '\n': writer.write r"\n"
          of '\r': writer.write r"\r"
          of '\t': writer.write r"\t"
          of '\v':
            writer.escapeByte('\v')
          of '"': writer.write r"\"""
          else:
            writer.escapeByte(c)
        else:
          when doCopy:
            enterCopy()
          else:
            writer.write c
        inc i
      elif not format.keepUtf8:
        when doCopy:
          finishCopy()
        # XXX maybe encode full utf16?
        writer.escapeByte(c)
        inc i
      else: # Multi-byte characters
        var rune: Rune
        let r = value.validRuneAt(i, rune)
        if r == 0:
          # invalid rune
          case format.invalidUtf8
          of EscapeInvalidUtf8:
            when doCopy:
              finishCopy()
            writer.escapeByte(c)
          of ReplaceInvalidUtf8:
            when doCopy:
              finishCopy()
            writer.write Rune(0xfffd)
          of KeepInvalidUtf8:
            when doCopy:
              enterCopy()
            else:
              writer.write c
          inc i
        else:
          when doCopy:
            enterCopy()
          else:
            writer.write value.toOpenArray(i, i + r - 1)
          i += r
  finally:
    when doCopy:
      finishCopy()

  writer.write '"'

proc dump*(format: JsonDump, writer: JsonWriterArg, value: char) =
  writer.write '"'
  if value < 32.char or value > 127.char or value == '\\' or value == '"':
    case value
    of '\\': writer.write r"\\"
    of '\b': writer.write r"\b"
    of '\f': writer.write r"\f"
    of '\n': writer.write r"\n"
    of '\r': writer.write r"\r"
    of '\t': writer.write r"\t"
    of '\v':
      writer.escapeByte('\v')
    of '"': writer.write r"\"""
    else:
      writer.escapeByte(value)
  else:
    writer.write value
  writer.write '"'

proc dumpItems*[T: tuple](format: JsonDump, writer: JsonWriterArg, arr: var ArrayDump, value: T) =
  mixin dump
  for _, e in value.fieldPairs:
    arr.withItem format, writer:
      format.dump(writer, e)

proc dumpStr(s: string): string =
  var writer = initJsonWriter()
  writer.startWrite()
  dump(JsonDump(), writer, s)
  result = writer.finishWrite()

template dumpKey(writer: JsonWriterArg, value: static string) =
  const v2 = dumpStr(value) & ":"
  writer.write v2

proc dumpFields*[T: tuple](format: JsonDump, writer: JsonWriterArg, obj: var ObjectDump, value: T) =
  mixin dump
  for k, e in value.fieldPairs:
    maybeAddComma(format, writer, obj.needsComma)
    format.dumpKey(writer, k)
    if format.pretty: writer.write ' '
    format.dump(writer, e)

proc dump*[T: tuple](format: JsonDump, writer: JsonWriterArg, value: T) =
  # XXX different for named tuple?
  var arr: ArrayDump
  arr.dumpTo format, writer:
    dumpItems(format, writer, arr, value)

template dumpStaticStr(writer: JsonWriterArg, s: static string) =
  const s2 = dumpStr(s)
  writer.write s2

type HasEnumOutputHook* = concept
  ## implement to determine which output kind an enum type uses
  proc enumOutput(format: JsonDump, _: typedesc[Self]): EnumOutput

template getEnumOutputKind*(format: JsonDump, T: typedesc): EnumOutput =
  mixin enumOutput
  when T is HasEnumOutputHook:
    enumOutput(format, T)
  else:
    format.defaultEnumOutput

proc dump*[T: enum](format: JsonDump, writer: JsonWriterArg, value: T) {.inline.} =
  let outputKind = getEnumOutputKind(format, T)
  case outputKind
  of EnumName:
    template onEnumOutput(s: string) =
      writer.dumpStaticStr(s)
    when T is HasFieldMappings:
      const mappings = getActualFieldMappings(T, HoloJson)
    else:
      const mappings = default(FieldMappingPairs)
    # can always use it here, however will not work with custom `$` XXX
    # XXX no normalizer support
    mapEnumFieldOutput(T, value, mappings, nil, onEnumOutput)
    when false:
      format.dump(writer, $value)
  of EnumOrd:
    format.dump(writer, ord(value))

proc dumpItems*[T](format: JsonDump, writer: JsonWriterArg, arr: var ArrayDump, value: openArray[T]) =
  mixin dump
  for i, e in value:
    arr.withItem format, writer:
      format.dump(writer, e)

proc dump*[N, T](format: JsonDump, writer: JsonWriterArg, value: array[N, T]) =
  mixin dump
  var arr: ArrayDump
  arr.dumpTo format, writer:
    for e in value:
      arr.withItem format, writer:
        format.dump(writer, e)

proc dump*[T](format: JsonDump, writer: JsonWriterArg, value: seq[T]) =
  mixin dump
  var arr: ArrayDump
  arr.dumpTo format, writer:
    for i, e in value:
      arr.withItem format, writer:
        #if i != 0: writer.write ','
        format.dump(writer, e)

proc dumpFields*[T: object](format: JsonDump, writer: JsonWriterArg, obj: var ObjectDump, value: T) =
  mixin dump
  when jsonyPairsObject and compiles(for k, e in value.pairs: discard):
    # Tables and table like objects.
    for k, e in value.pairs:
      maybeAddComma(format, writer, obj.needsComma)
      format.dump(writer, k)
      writer.write ':'
      if format.pretty: writer.write ' '
      format.dump(writer, e)
  else:
    # Normal objects.
    when jsonyHookCompatibility and (compiles do:
        for k, e in value.fieldPairs:
          discard skipHook(type(value), k)):
      for k, e in value.fieldPairs:
        when skipHook(type(value), k):
          discard
        else:
          # original jsony does not have rename hook here
          maybeAddComma(format, writer, obj.needsComma)
          writer.dumpKey(k)
          if format.pretty: writer.write ' '
          format.dump(writer, e)
    else:
      template onFieldOutput(f, fName) =
        maybeAddComma(format, writer, obj.needsComma)
        writer.dumpKey(fName)
        if format.pretty: writer.write ' '
        format.dump(writer, f)
      const mappings = getActualFieldMappings(T, HoloJson)
      # XXX no normalizer support
      mapFieldOutput(value, mappings, nil, jsonDefaultOutputName, onFieldOutput)

proc dump*[T: object](format: JsonDump, writer: JsonWriterArg, value: T) {.inline.} =
  when false: # refs disabled
    when T is ref:
      if value.isNil:
        writer.write "null"
        return
  var obj: ObjectDump
  obj.dumpTo format, writer:
    dumpFields(format, writer, obj, value)

proc dump*[N, T](format: JsonDump, writer: JsonWriterArg, value: array[N, tuple[a: string, b: T]]) =
  mixin dump
  var obj: ObjectDump
  obj.dumpTo format, writer:
    # Normal objects.
    for (k, e) in value.items:
      obj.withField format, writer, k:
        format.dump(writer, e)

proc dump*[T](format: JsonDump, writer: JsonWriterArg, value: ref T) {.inline, gcsafe.} =
  mixin dump
  if value == nil:
    writer.write "null"
  else:
    format.dump(writer, value[])

proc dump*(format: JsonDump, writer: JsonWriterArg, value: RawJson) {.inline.} =
  writer.write value.string

proc dump*[T](format: JsonDump, s: var string, value: T) {.inline.} =
  mixin dump
  var writer = initJsonWriter()
  writer.startWrite()
  dump(format, writer, value)
  s = writer.finishWrite()

proc dumpJson*[T](writer: JsonWriterArg, value: T) {.inline.} =
  dump(JsonDump(), writer, value)

proc dumpJson*[T](s: var string, value: T) {.inline.} =
  dump(JsonDump(), s, value)

proc toJson*[T](value: T, format = JsonDump()): string {.inline.} =
  dump(format, result, value)

template toStaticJson*(value: untyped, format = JsonDump()): static[string] =
  ## This will turn `value` into json at compile time and return the json string.
  const s = value.toJson(format)
  s
