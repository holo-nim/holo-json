## implements dumping behavior for basic types 

import ./common, holo_flow/holo_writer, std/[json, typetraits, unicode, tables]
import std/math # for classify

export HoloWriter, initHoloWriter, startWrite, finishWrite, write

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: string)
type t[T] = tuple[a: string, b: T]
proc dump*[N, T](format: JsonDumpFormat, writer: var HoloWriter, v: array[N, t[T]])
proc dump*[N, T](format: JsonDumpFormat, writer: var HoloWriter, v: array[N, T])
proc dump*[T](format: JsonDumpFormat, writer: var HoloWriter, v: seq[T])
proc dump*[T: object](format: JsonDumpFormat, writer: var HoloWriter, v: T)
proc dump*[T: distinct](format: JsonDumpFormat, writer: var HoloWriter, v: T) {.inline.}

# don't dogfood these yet if they add to compile times:
type
  ArrayDump* = object
    needsComma*: bool
  ObjectDump* = object
    needsComma*: bool

proc startArrayDump*(format: JsonDumpFormat, writer: var HoloWriter): ArrayDump {.inline.} =
  result = ArrayDump(needsComma: false)
  writer.write '['

proc finishArrayDump*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ArrayDump) {.inline.} =
  writer.write ']'

proc startArrayItem*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ArrayDump) {.inline.} =
  if arr.needsComma:
    writer.write ','
  else:
    arr.needsComma = true

proc finishArrayItem*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ArrayDump) {.inline.} =
  discard

template withArrayDump*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ArrayDump, body: typed) =
  arr = startArrayDump(format, writer)
  body
  finishArrayDump(format, writer, arr)

template withArrayItem*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ArrayDump, body: typed) =
  startArrayItem(format, writer, arr)
  body
  finishArrayItem(format, writer, arr)

proc startObjectDump*(format: JsonDumpFormat, writer: var HoloWriter): ObjectDump {.inline.} =
  result = ObjectDump(needsComma: false)
  writer.write '{'

proc finishObjectDump*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ObjectDump) {.inline.} =
  writer.write '}'

proc startObjectField*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ObjectDump, name: string, raw = false) {.inline.} =
  if arr.needsComma:
    writer.write ','
  else:
    arr.needsComma = true
  if raw:
    writer.write name
  else:
    format.dump writer, name
  writer.write ':'

proc finishObjectField*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ObjectDump) {.inline.} =
  discard

template withObjectDump*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ObjectDump, body: typed) =
  arr = startObjectDump(format, writer)
  body
  finishObjectDump(format, writer, arr)

template withObjectField*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ObjectDump, name: string, body: typed) =
  startObjectField(format, writer, arr, name)
  body
  finishObjectField(format, writer, arr)

template withRawObjectField*(format: JsonDumpFormat, writer: var HoloWriter, arr: var ObjectDump, name: string, body: typed) =
  startObjectField(format, writer, arr, name, raw = true)
  body
  finishObjectField(format, writer, arr)

proc dump*[T: distinct](format: JsonDumpFormat, writer: var HoloWriter, v: T) {.inline.} =
  mixin dump
  format.dump(writer, distinctBase(T)(v))

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: bool) {.inline.} =
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

proc dumpNumberSlow(writer: var HoloWriter, v: uint|uint8|uint16|uint32|uint64) {.inline.} =
  writer.write $v.uint64

proc dumpNumberFast(writer: var HoloWriter, v: uint|uint8|uint16|uint32|uint64) =
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
  var at = writer.buffer.len
  if digits[p-1] == '0':
    dec p
  writer.buffer.setLen(writer.buffer.len + p)
  dec p
  while p >= 0:
    writer.buffer[at] = digits[p]
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

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: uint) {.inline.} =
  uintImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: uint8) {.inline.} =
  uintImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: uint16) {.inline.} =
  uintImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: uint32) {.inline.} =
  uintImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: uint64) {.inline.} =
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

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: int) {.inline.} =
  intImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: int8) {.inline.} =
  intImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: int16) {.inline.} =
  intImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: int32) {.inline.} =
  intImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: int64) {.inline.} =
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
    writer.buffer.addFloat(v)
    writer.consumeBuffer()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: float) =
  floatImpl()

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: float32) =
  floatImpl()

proc validRuneAt(s: string, i: int, rune: var Rune): int =
  # returns number of skipped bytes
  # Based on fastRuneAt from std/unicode
  result = 0

  template ones(n: untyped): untyped = ((1 shl n)-1)

  if uint(s[i]) <= 127:
    result = 1
    rune = Rune(uint(s[i]))
  elif uint(s[i]) shr 5 == 0b110:
    if i <= s.len - 2:
      let valid = (uint(s[i+1]) shr 6 == 0b10)
      if valid:
        result = 2
        rune = Rune(
          (uint(s[i]) and (ones(5))) shl 6 or
          (uint(s[i+1]) and ones(6))
        )
  elif uint(s[i]) shr 4 == 0b1110:
    if i <= s.len - 3:
      let valid =
        (uint(s[i+1]) shr 6 == 0b10) and
        (uint(s[i+2]) shr 6 == 0b10)
      if valid:
        result = 3
        rune = Rune(
          (uint(s[i]) and ones(4)) shl 12 or
          (uint(s[i+1]) and ones(6)) shl 6 or
          (uint(s[i+2]) and ones(6))
        )
  elif uint(s[i]) shr 3 == 0b11110:
    if i <= s.len - 4:
      let valid =
        (uint(s[i+1]) shr 6 == 0b10) and
        (uint(s[i+2]) shr 6 == 0b10) and
        (uint(s[i+3]) shr 6 == 0b10)
      if valid:
        result = 4
        rune = Rune(
          (uint(s[i]) and ones(3)) shl 18 or
          (uint(s[i+1]) and ones(6)) shl 12 or
          (uint(s[i+2]) and ones(6)) shl 6 or
          (uint(s[i+3]) and ones(6))
        )

const hex = [
  '0', '1', '2', '3', '4', '5', '6', '7',
  '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: string) =
  writer.write '"'

  var
    i = 0
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
        when nimvm:
          for p in 0 ..< numBytes:
            writer.buffer.add v[copyStart + p]
        else:
          when defined(js) or defined(nimscript):
            for p in 0 ..< numBytes:
              writer.buffer.add v[copyStart + p]
          else:
            let sLen = writer.buffer.len
            writer.buffer.setLen(sLen + numBytes)
            copyMem(writer.buffer[sLen].addr, v[copyStart].unsafeAddr, numBytes)
        writer.consumeBuffer()
      inCopy = false
  try:
    while i < v.len:
      let c = v[i]
      if (cast[uint8](c) and 0b10000000) == 0:
        # When the high bit is not set this is a single-byte character (ASCII)
        # Does this character need escaping?
        if c < 32.char or c == '\\' or c == '"':
          finishCopy()
          case c:
          of '\\': writer.write r"\\"
          of '\b': writer.write r"\b"
          of '\f': writer.write r"\f"
          of '\n': writer.write r"\n"
          of '\r': writer.write r"\r"
          of '\t': writer.write r"\t"
          of '\v':
            if format.useXEscape:
              writer.write r"\x0b"
            else:
              writer.write r"\u000b"
          of '"': writer.write r"\"""
          of '\0'..'\7', '\14'..'\31':
            if format.useXEscape:
              writer.write r"\x"
            else:
              writer.write r"\u00"
            writer.write hex[c.int shr 4]
            writer.write hex[c.int and 0xf]
          else:
            discard # Not possible
          inc i
        else:
          enterCopy()
          inc i
      else: # Multi-byte characters
        var r = 0
        if format.keepUtf8:
          var rune: Rune # not used apparently
          r = v.validRuneAt(i, rune)
        if r != 0:
          enterCopy()
          i += r
        else: # Not a valid rune, use replacement character 
          finishCopy()
          when false:
            s.add Rune(0xfffd) # ??? this is just bad
          if format.useXEscape:
            writer.write r"\x"
          else:
            writer.write r"\u00"
          writer.write hex[c.int shr 4]
          writer.write hex[c.int and 0xf]
          inc i
  finally:
    finishCopy()

  writer.write '"'

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: char) =
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
      if format.useXEscape:
        writer.write r"\x0b"
      else:
        writer.write r"\u000b"
    of '"': writer.write r"\"""
    else:
      if format.useXEscape:
        writer.write r"\x"
      else:
        writer.write r"\u00"
      writer.write hex[v.int shr 4]
      writer.write hex[v.int and 0xf]
  else:
    writer.write v
  writer.write '"'

proc dump*[T: tuple](format: JsonDumpFormat, writer: var HoloWriter, v: T) =
  mixin dump
  writer.write '['
  var i = 0
  for _, e in v.fieldPairs:
    if i > 0:
      writer.write ','
    format.dump(writer, e)
    inc i
  writer.write ']'

proc dump*[T: enum](format: JsonDumpFormat, writer: var HoloWriter, v: T) {.inline.} =
  case format.defaultEnumOutput
  of EnumName:
    format.dump(writer, $v)
  of EnumOrd:
    format.dump(writer, ord(v))

proc dump*[N, T](format: JsonDumpFormat, writer: var HoloWriter, v: array[N, T]) =
  mixin dump
  writer.write '['
  var i = 0
  for e in v:
    if i != 0:
      writer.write ','
    format.dump(writer, e)
    inc i
  writer.write ']'

proc dump*[T](format: JsonDumpFormat, writer: var HoloWriter, v: seq[T]) =
  mixin dump
  writer.write '['
  for i, e in v:
    if i != 0:
      writer.write ','
    format.dump(writer, e)
  writer.write ']'

template dumpKey(writer: var HoloWriter, v: static string) =
  const v2 = holo_json.toJson(v) & ":"
  writer.write v2

proc dump*[T: object](format: JsonDumpFormat, writer: var HoloWriter, v: T) =
  mixin dump
  writer.write '{'
  var i = 0
  when false and compiles(for k, e in v.pairs: discard):
    # XXX disabled, arbitrary keys dont work
    # Tables and table like objects.
    for k, e in v.pairs:
      if i > 0:
        writer.write ','
      format.dump(writer, k)
      writer.write ':'
      format.dump(writer, e)
      inc i
  else:
    # Normal objects.
    const fieldMappings = fieldMappingTable(v, Json)
    for k, e in v.fieldPairs:
      when jsonyHookCompatibility and compiles(skipHook(type(v), k)):
        when skipHook(type(v), k):
          discard
        else:
          if i > 0:
            writer.write ','
          writer.dumpKey(k)
          format.dump(writer, e)
          inc i
      else:
        const options = fieldMappings.getOrDefault(k)
        when not options.ignoreDump:
          if i > 0:
            writer.write ','
          # rename hook not in original jsony
          writer.dumpKey(getDumpName(k, options, jsonDefaultDumpName))
          format.dump(writer, e)
          inc i
  writer.write '}'

proc dump*[N, T](format: JsonDumpFormat, writer: var HoloWriter, v: array[N, t[T]]) =
  mixin dump
  writer.write '{'
  var i = 0
  # Normal objects.
  for (k, e) in v:
    if i > 0:
      writer.write ','
    format.dump(writer, k)
    writer.write ':'
    format.dump(writer, e)
    inc i
  writer.write '}'

proc dump*[T](format: JsonDumpFormat, writer: var HoloWriter, v: ref T) {.inline.} =
  mixin dump
  if v == nil:
    writer.write "null"
  else:
    format.dump(writer, v[])

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: JsonNode) =
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

proc dump*(format: JsonDumpFormat, writer: var HoloWriter, v: RawJson) {.inline.} =
  writer.write v.string

proc dump*[T](format: JsonDumpFormat, s: var string, v: T) {.inline.} =
  mixin dump
  var writer = initHoloWriter()
  writer.startWrite()
  dump(format, writer, v)
  s = writer.finishWrite()

proc dumpJson*[T](writer: var HoloWriter, v: T) {.inline.} =
  dump(JsonDumpFormat(), writer, v)

proc dumpJson*[T](s: var string, v: T) {.inline.} =
  dump(JsonDumpFormat(), s, v)

proc toJson*[T](v: T): string {.inline.} =
  dump(JsonDumpFormat(), result, v)

template toStaticJson*(v: untyped): static[string] =
  ## This will turn v into json at compile time and return the json string.
  const s = v.toJson()
  s
