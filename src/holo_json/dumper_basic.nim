## implements dumping behavior for basic types 

import ./[common, dumper_common], std/[typetraits, unicode]
import std/math # for classify

export JsonWriter, JsonWriterArg, initJsonWriter, startWrite, finishWrite, write

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: string)
type t[T] = tuple[a: string, b: T]
proc dump*[N, T](format: JsonDumpFormat, writer: JsonWriterArg, v: array[N, t[T]])
proc dump*[N, T](format: JsonDumpFormat, writer: JsonWriterArg, v: array[N, T])
proc dump*[T](format: JsonDumpFormat, writer: JsonWriterArg, v: seq[T])
proc dump*[T: object](format: JsonDumpFormat, writer: JsonWriterArg, v: T)
proc dump*[T: distinct](format: JsonDumpFormat, writer: JsonWriterArg, v: T) {.inline.}

proc dump*[T: distinct](format: JsonDumpFormat, writer: JsonWriterArg, v: T) {.inline.} =
  mixin dump
  format.dump(writer, distinctBase(T)(v))

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: bool) {.inline.} =
  if v:
    writer.write "true"
  else:
    writer.write "false"

const lookup = block:
  ## Generate 00, 01, 02 ... 99 pairs.
  var s = ""
  for i in 0 ..< 100:
    if ($i).len == 1:
      s.add("0")
    s.add($i)
  s

proc dumpNumberSlow(writer: JsonWriterArg, v: uint|uint8|uint16|uint32|uint64) {.inline.} =
  writer.write $v.uint64

proc dumpNumberFast(writer: JsonWriterArg, v: uint|uint8|uint16|uint32|uint64) =
  # Its faster to not allocate a string for a number,
  # but to write it out the digits directly.
  if v == 0:
    writer.write '0'
    return
  # Max size of a uin64 number is 20 digits.
  var digits: array[20, char]
  var v = v
  var p = 0
  while v != 0:
    # Its faster to look up 2 digits at a time, less int divisions.
    let idx = v mod 100
    digits[p] = lookup[idx*2+1]
    inc p
    digits[p] = lookup[idx*2]
    inc p
    v = v div 100
  var at = writer.currentBuffer.len
  if digits[p-1] == '0':
    dec p
  writer.currentBuffer.setLen(writer.currentBuffer.len + p)
  dec p
  while p >= 0:
    writer.currentBuffer[at] = digits[p]
    dec p
    inc at
  writer.consumeBuffer()

template uintImpl() =
  when jsonyIntOutput:
    when nimvm:
      writer.dumpNumberSlow(v)
    else:
      when defined(js):
        writer.dumpNumberSlow(v)
      else:
        writer.dumpNumberFast(v)
  else:
    writer.buffer.addInt v
    writer.consumeBuffer()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: uint) {.inline.} =
  uintImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: uint8) {.inline.} =
  uintImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: uint16) {.inline.} =
  uintImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: uint32) {.inline.} =
  uintImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: uint64) {.inline.} =
  uintImpl()

template intImpl() =
  when jsonyIntOutput:
    if v < 0:
      writer.write '-'
      dump(format, writer, 0.uint64 - v.uint64)
    else:
      dump(format, writer, v.uint64)
  else:
    writer.buffer.addInt v
    writer.consumeBuffer()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: int) {.inline.} =
  intImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: int8) {.inline.} =
  intImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: int16) {.inline.} =
  intImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: int32) {.inline.} =
  intImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: int64) {.inline.} =
  intImpl()

template floatImpl() =
  #writer.write $v # original jsony
  let cls = classify(v)
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
    writer.currentBuffer.addFloat(v)
    writer.consumeBuffer()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: float) =
  floatImpl()

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: float32) =
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

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: string) =
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
              writer.currentBuffer[sLen + p] = v[copyStart + p]
          else:
            when not holoJsonStringCopyMem or defined(js) or defined(nimscript):
              for p in 0 ..< numBytes:
                writer.currentBuffer[sLen + p] = v[copyStart + p]
            else:
              copyMem(writer.currentBuffer[sLen].addr, v[copyStart].unsafeAddr, numBytes)
          writer.consumeBuffer()
        inCopy = false

  try:
    while i < v.len:
      let c = v[i]
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
        let r = v.validRuneAt(i, rune)
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
            writer.write v.toOpenArray(i, i + r - 1)
          i += r
  finally:
    when doCopy:
      finishCopy()

  writer.write '"'

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: char) =
  writer.write '"'
  if v < 32.char or v > 127.char or v == '\\' or v == '"':
    case v
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
      writer.escapeByte(v)
  else:
    writer.write v
  writer.write '"'

proc dump*[T: tuple](format: JsonDumpFormat, writer: JsonWriterArg, v: T) =
  mixin dump
  # XXX different for named tuple?
  writer.write '['
  var needsComma = false
  for _, e in v.fieldPairs:
    if needsComma: writer.write ','
    else: needsComma = true
    format.dump(writer, e)
  writer.write ']'

template dumpStaticStr(writer: JsonWriterArg, s: static string) =
  const s2 = holo_json.toJson(s)
  writer.write s2

proc dump*[T: enum](format: JsonDumpFormat, writer: JsonWriterArg, v: T) {.inline.} =
  case format.defaultEnumOutput
  of EnumName:
    template onEnumOutput(s: string) =
      writer.dumpStaticStr(s)
    when T is HasFieldMappings:
      const mappings = getActualFieldMappings(T, HoloJson)
    else:
      const mappings = default(FieldMappingPairs)
    # can always use it here, however will not work with custom `$` XXX
    # XXX no normalizer support
    mapEnumFieldOutput(T, v, mappings, nil, onEnumOutput)
    when false:
      format.dump(writer, $v)
  of EnumOrd:
    format.dump(writer, ord(v))

proc dump*[N, T](format: JsonDumpFormat, writer: JsonWriterArg, v: array[N, T]) =
  mixin dump
  writer.write '['
  var needsComma = false
  for e in v:
    if needsComma: writer.write ','
    else: needsComma = true
    format.dump(writer, e)
  writer.write ']'

proc dump*[T](format: JsonDumpFormat, writer: JsonWriterArg, v: seq[T]) =
  mixin dump
  writer.write '['
  for i, e in v:
    if i != 0:
      writer.write ','
    format.dump(writer, e)
  writer.write ']'

template dumpKey(writer: JsonWriterArg, v: static string) =
  const v2 = holo_json.toJson(v) & ":"
  writer.write v2

proc dump*[T: object](format: JsonDumpFormat, writer: JsonWriterArg, v: T) =
  mixin dump
  when false: # refs disabled
    when T is ref:
      if v.isNil:
        writer.write "null"
        return
  writer.write '{'
  var needsComma = false
  when jsonyPairsObject and compiles(for k, e in v.pairs: discard):
    # Tables and table like objects.
    for k, e in v.pairs:
      if needsComma: writer.write ','
      else: needsComma = true
      format.dump(writer, k)
      writer.write ':'
      format.dump(writer, e)
  else:
    # Normal objects.
    when jsonyHookCompatibility and (compiles do:
        for k, e in v.fieldPairs:
          discard skipHook(type(v), k)):
      for k, e in v.fieldPairs:
        when skipHook(type(v), k):
          discard
        else:
          # original jsony does not have rename hook here
          if needsComma: writer.write ','
          else: needsComma = true
          writer.dumpKey(k)
          format.dump(writer, e)
    else:
      template onFieldOutput(f, fName) =
        if needsComma: writer.write ','
        else: needsComma = true
        writer.dumpKey(fName)
        format.dump(writer, f)
      const mappings = getActualFieldMappings(T, HoloJson)
      # XXX no normalizer support
      mapFieldOutput(v, mappings, nil, jsonDefaultOutputName, onFieldOutput)
  writer.write '}'

proc dump*[N, T](format: JsonDumpFormat, writer: JsonWriterArg, v: array[N, t[T]]) =
  mixin dump
  writer.write '{'
  var needsComma = false
  # Normal objects.
  for (k, e) in v:
    if needsComma: writer.write ','
    else: needsComma = true
    format.dump(writer, k)
    writer.write ':'
    format.dump(writer, e)
  writer.write '}'

proc dump*[T](format: JsonDumpFormat, writer: JsonWriterArg, v: ref T) {.inline.} =
  mixin dump
  if v == nil:
    writer.write "null"
  else:
    format.dump(writer, v[])

proc dump*(format: JsonDumpFormat, writer: JsonWriterArg, v: RawJson) {.inline.} =
  writer.write v.string

proc dump*[T](format: JsonDumpFormat, s: var string, v: T) {.inline.} =
  mixin dump
  var writer = initJsonWriter()
  writer.startWrite()
  dump(format, writer, v)
  s = writer.finishWrite()

proc dumpJson*[T](writer: JsonWriterArg, v: T) {.inline.} =
  dump(JsonDumpFormat(), writer, v)

proc dumpJson*[T](s: var string, v: T) {.inline.} =
  dump(JsonDumpFormat(), s, v)

proc toJson*[T](v: T): string {.inline.} =
  dump(JsonDumpFormat(), result, v)

template toStaticJson*(v: untyped): static[string] =
  ## This will turn v into json at compile time and return the json string.
  const s = v.toJson()
  s
