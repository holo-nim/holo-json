## implements reading behavior for basic types

import ./common, holo_map/[caseutils, variants], holo_flow/holo_reader
import std/[unicode, parseutils, typetraits, macros, importutils, tables]
import std/strutils except format
import std/json #from std/json import JsonNodeKind, JsonNode
export HoloReader, initHoloReader, startRead

# XXX make sure "wrong parses" are properly dealt with, ie if it expects a integer and receives "123abc" it should not parse 123 and be done with it

proc error*(reader: var HoloReader, msg: string) {.inline.} =
  ## Shortcut to raise an exception.
  raise newException(JsonValueError, "(" & $reader.line & ", " & $reader.column & ") " & msg)

proc parseError*(reader: var HoloReader, msg: string) {.inline.} =
  ## Shortcut to raise an exception.
  raise newException(JsonParseError, "(" & $reader.line & ", " & $reader.column & ") " & msg)

proc read*[T](format: JsonReadFormat, reader: var HoloReader, v: var seq[T])
proc read*[T: enum](format: JsonReadFormat, reader: var HoloReader, v: var T) {.inline.}
proc read*[T: object|ref object](format: JsonReadFormat, reader: var HoloReader, v: var T)
proc read*[T: tuple](format: JsonReadFormat, reader: var HoloReader, v: var T)
proc read*[T: array](format: JsonReadFormat, reader: var HoloReader, v: var T)
proc read*[T: not object](format: JsonReadFormat, reader: var HoloReader, v: var ref T) {.inline.}
proc read*(format: JsonReadFormat, reader: var HoloReader, v: var JsonNode)
proc read*(format: JsonReadFormat, reader: var HoloReader, v: var string)
proc read*[T: distinct](format: JsonReadFormat, reader: var HoloReader, v: var T) {.inline.}

template skipSpace*(reader: var HoloReader) =
  ## Will consume whitespace.
  for c in reader.peekNext():
    if c notin Whitespace:
      break

proc skipChar*(reader: var HoloReader, c: char) {.inline.} =
  ## Will consume space before and then the character `c`.
  ## Will raise a parsing error if `c` is not found.
  skipSpace(reader)
  var c2: char
  if not reader.next(c2):
    reader.parseError("Expected " & c & " but end reached.")
  elif c != c2:
    reader.parseError("Expected " & c & " but got " & c2 & " instead.")

proc expectChar*(reader: var HoloReader, c: char) {.inline.} =
  ## Will consume space before and then the character `c`.
  ## Will raise a value error if `c` is not found,
  ## and a parse error if the end is reached.
  skipSpace(reader)
  var c2: char
  if not reader.next(c2):
    reader.parseError("Expected " & c & " but end reached.")
  elif c != c2:
    reader.error("Expected " & c & " but got " & c2 & " instead.")

proc parseSymbol*(reader: var HoloReader): string =
  ## Will read a symbol and return it.
  ## Used for numbers and booleans.
  # XXX numbers??
  skipSpace(reader)
  result = ""
  for c in reader.peekNext():
    case c
    of ',', '}', ']', Whitespace:
      break
    else:
      result.add c

iterator readObjectFields*(format: JsonReadFormat, reader: var HoloReader): string =
  while reader.hasNext():
    skipSpace(reader)
    if reader.peekMatch('}'):
      break
    var key: string
    read(format, reader, key)
    skipChar(reader, ':')
    yield key
    skipSpace(reader)
    if reader.nextMatch(','):
      discard

iterator readObject*(format: JsonReadFormat, reader: var HoloReader): string =
  expectChar(reader, '{')
  for name in readObjectFields(format, reader):
    yield name
  skipChar(reader, '}')

iterator readArrayItems*(format: JsonReadFormat, reader: var HoloReader, start = 0): int =
  var i = start
  while reader.hasNext():
    skipSpace(reader)
    if reader.peekMatch(']'):
      break
    yield i
    skipSpace(reader)
    if reader.nextMatch(','):
      discard
    elif reader.peekMatch(']'):
      discard
    else:
      # maybe improve error message wasnt in original
      reader.parseError("expected comma")
    inc i

iterator readArray*(format: JsonReadFormat, reader: var HoloReader): int =
  expectChar(reader, '[')
  for i in readArrayItems(format, reader):
    yield i
  skipChar(reader, ']')

proc peekRawKind*(format: JsonReadFormat, reader: var HoloReader): JsonNodeKind =
  ## guesses which kind the next object is, assumes spaces are skipped
  ## not guaranteed to be accurate, all numbers are assumed float
  let start = reader.peekOrZero()
  case start
  of '{':
    result = JObject
  of '[':
    result = JArray
  of '"':
    result = JString
  of '-', '+', '0'..'9':
    result = JFloat # all numbers float?
  else:
    if reader.peekMatch("true") or reader.peekMatch("false"):
      result = JBool
    elif reader.peekMatch("null"):
      result = JNull
    else:
      # XXX nan inf
      var msg = "unknown value starting with character "
      msg.addQuoted(start)
      reader.parseError(msg)

proc peekRawKindSkipSpace*(format: JsonReadFormat, reader: var HoloReader): JsonNodeKind {.inline.} =
  ## guesses which kind the next object is, skips spaces
  ## not guaranteed to be accurate, all numbers are assumed float
  skipSpace(reader)
  result = peekRawKind(format, reader)

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var bool) {.inline.} =
  ## Will parse boolean true or false.
  when nimvm:
    # XXX either should be fine but test
    case parseSymbol(reader)
    of "true":
      v = true
    of "false":
      v = false
    else:
      reader.error("Boolean true or false expected.")
  else:
    # Its faster to do char by char scan:
    skipSpace(reader)
    if reader.nextMatch("true"):
      v = true
    elif reader.nextMatch("false"):
      v = false
    else:
      reader.error("Boolean true or false expected.")

template uintImpl() =
  #when nimvm: v = type(v)(parseBiggestUInt(parseSymbol(reader)))
  skipSpace(reader)
  if reader.nextMatch('+'):
    discard
  type UintImpl = (
    when sizeof(uint) == sizeof(uint64) or v is uint64:
      uint64
    else: # for JS etc
      uint
  )
  var
    v2: UintImpl = 0
    gotChar = false
  for c in reader.peekNext():
    case c
    of '0'..'9':
      gotChar = true
      # XXX handle overflow
      #let prev = v2
      #if prev >= (high(typeof(v)) div 10 - digit):
      #  reader.error("uint overflow: got " & $prev & $c & "... > " & $high(typeof(v)))
      v2 = v2 * 10 + (UintImpl(c) - UintImpl('0'))
      #if v2 < prev:
      #  reader.error("uint overflow: got " & $prev & $c & "... > " & $high(typeof(v)))
    else:
      break
  if not gotChar:
    reader.error("Number expected.")
  when v isnot uint64:
    if v2 > UintImpl(high(typeof(v))):
      reader.error("got uint value: " & $v2 & " > max of " & $typeof(v) & ": " & $high(typeof(v)))
  v = typeof(v)(v2)

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var uint) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var uint8) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var uint16) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var uint32) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var uint64) {.inline.} =
  ## Will parse unsigned integers.
  uintImpl()

template intImpl() =
  #when nimvm: v = type(v)(parseBiggestInt(parseSymbol(reader)))
  skipSpace(reader)
  type UintImpl = (
    when sizeof(uint) == sizeof(uint64) or v is int64:
      uint64
    else: # for JS etc
      uint
  )
  if reader.nextMatch('+'):
    discard
  if reader.nextMatch('-'):
    var v2: UintImpl
    read(format, reader, v2)
    if v2 > UintImpl(high(typeof(v))) + 1:
      reader.error("got int value: -" & $v2 & " < min of " & $typeof(v) & ": " & $low(typeof(v)))
    v = -typeof(v)(v2)
  else:
    var v2: UintImpl
    read(format, reader, v2)
    if v2 > UintImpl(high(typeof(v))):
      reader.error("got int value: " & $v2 & " < max of " & $typeof(v) & ": " & $high(typeof(v)))
    v = typeof(v)(v2)

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var int) {.inline.} =
  ## Will parse signed integers.
  intImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var int8) {.inline.} =
  ## Will parse signed integers.
  intImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var int16) {.inline.} =
  ## Will parse signed integers.
  intImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var int32) {.inline.} =
  ## Will parse signed integers.
  intImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var int64) {.inline.} =
  ## Will parse signed integers.
  intImpl()

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var float) =
  ## Will parse floats.
  # XXX clean this up later
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
      reader.error("invalid float string")
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
  var s = ""
  block fullFloat:
    block signPart:
      var sign: char
      if reader.nextMatch({'-', '+'}, sign):
        s.add sign
    block integerPart:
      var hasDigit = false
      for c in reader.peekNext():
        case c
        of '0'..'9':
          hasDigit = true
          s.add c
        else: break
      if not hasDigit:
        s = ""
        break fullFloat
    block decimalPoint:
      if reader.peekMatch('.') and reader.peekMatch({'0'..'9'}, offset = 1):
        s.add '.'
        reader.unsafeNext()
        for c in reader.peekNext():
          case c
          of '0'..'9': s.add c
          else: break
    block exponent:
      var hasSign = false
      if reader.peekMatch({'e', 'E'}):
        var digitOffset = 1
        hasSign = reader.peekMatch({'+', '-'}, offset = 1)
        if hasSign:
          inc digitOffset
        if reader.peekMatch({'0'..'9'}, offset = digitOffset):
          var c: char
          doAssert reader.next(c)
          s.add c # e/E
          if hasSign:
            doAssert reader.next(c)
            s.add c
          for c in reader.peekNext():
            case c
            of '0'..'9': s.add c
            else: break
  if s.len == 0:
    reader.error("Failed to parse a float.")
  var i = 0
  var f: float
  let chars = parseutils.parseFloat(s, f, i)
  if chars == 0 or chars < s.len:
    reader.error("Failed to parse a float.")
  v = f

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var float32) {.inline.} =
  ## Will parse floats.
  var f: float
  read(format, reader, f)
  v = float32(f)

proc validRune(reader: var HoloReader, rune: var Rune, start: char): int =
  # returns number of skipped bytes
  # Based on fastRuneAt from std/unicode
  result = 0

  template ones(n: untyped): untyped = ((1 shl n)-1)

  let startByte = start.byte
  if startByte <= 127:
    result = 1
    rune = Rune(startByte)
  elif startByte shr 5 == 0b110:
    var bytes: array[2, char]
    if reader.peek(bytes):
      let valid = (uint(bytes[1]) shr 6 == 0b10)
      if valid:
        result = 2
        rune = Rune(
          (uint(bytes[0]) and ones(5)) shl 6 or
          (uint(bytes[1]) and ones(6))
        )
  elif startByte shr 4 == 0b1110:
    var bytes: array[3, char]
    if reader.peek(bytes):
      let valid =
        (uint(bytes[1]) shr 6 == 0b10) and
        (uint(bytes[2]) shr 6 == 0b10)
      if valid:
        result = 3
        rune = Rune(
          (uint(bytes[0]) and ones(4)) shl 12 or
          (uint(bytes[1]) and ones(6)) shl 6 or
          (uint(bytes[2]) and ones(6))
        )
  elif startByte shr 3 == 0b11110:
    var bytes: array[4, char]
    if reader.peek(bytes):
      let valid =
        (uint(bytes[1]) shr 6 == 0b10) and
        (uint(bytes[2]) shr 6 == 0b10) and
        (uint(bytes[3]) shr 6 == 0b10)
      if valid:
        result = 4
        rune = Rune(
          (uint(bytes[0]) and ones(3)) shl 18 or
          (uint(bytes[1]) and ones(6)) shl 12 or
          (uint(bytes[2]) and ones(6)) shl 6 or
          (uint(bytes[3]) and ones(6))
        )

proc parseHexInt[I](reader: var HoloReader, a: array[I, char]): int {.inline.} =
  result = 0
  for i in 0 ..< a.len:
    let c = a[i]
    case c
    of '0'..'9': result = (result shl 4) or (c.int - '0'.int)
    of 'A'..'F': result = (result shl 4) or (10 + c.int - 'A'.int)
    of 'a'..'f': result = (result shl 4) or (10 + c.int - 'a'.int)
    else: reader.parseError("expected hex char in escape sequence, got " & $c)

proc parseUnicodeEscape(format: JsonReadFormat, reader: var HoloReader): int =
  #reader.unsafeNext() # u already skipped
  var hexStr: array[4, char]
  if not reader.peek(hexStr):
    reader.parseError("Expected unicode escape hex but end reached.")
  for i in 1..hexStr.len: reader.unsafeNext()
  result = parseHexInt(reader, hexStr)
  if format.handleUtf16:
    # Deal with UTF-16 surrogates. Most of the time strings are encoded as utf8
    # but some APIs will reply with UTF-16 surrogate pairs which needs to be dealt
    # with.
    if (result and 0xfc00) == 0xd800:
      if not reader.nextMatch("\\u"):
        # maybe make the option an enum for whether or not to error here
        reader.error("Found an Orphan Surrogate.")
      var nextHexStr: array[4, char]
      if not reader.peek(nextHexStr):
        reader.error("Expected unicode escape hex but end reached.")
      for i in 1..nextHexStr.len: reader.unsafeNext()
      let nextRune = parseHexInt(reader, nextHexStr)
      if (nextRune and 0xfc00) == 0xdc00:
        result = 0x10000 + (((result - 0xd800) shl 10) or (nextRune - 0xdc00))

proc parseByte(reader: var HoloReader): byte =
  #reader.unsafeNext() # x already skipped
  var hexStr: array[2, char]
  if not reader.peek(hexStr):
    reader.parseError("Expected byte escape hex but end reached.")
  reader.unsafeNextBy(hexStr.len)
  result = parseHexInt(reader, hexStr).byte

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var string) =
  ## Parse string.
  skipSpace(reader)
  if false:
    # XXX disabled for now maybe config option
    if reader.nextMatch("null"):
      return

  expectChar(reader, '"')

  const doCopy = holoJsonBatchStringAdd

  when doCopy:
    var
      copyStart = 0
      inCopy = false
    template enterCopy() =
      if not inCopy:
        reader.lockBuffer()
        copyStart = reader.bufferPos
        inCopy = true
    template finishCopy() =
      if inCopy:
        if reader.bufferPos >= copyStart:
          let numBytes = reader.bufferPos - copyStart + 1
          let vLen = v.len
          v.setLen(vLen + numBytes)
          when nimvm:
            for p in 0 ..< numBytes:
              v[vLen + p] = reader.buffer[copyStart + p]
          else:
            when not holoJsonStringCopyMem or defined(js) or defined(nimscript):
              for p in 0 ..< numBytes:
                v[vLen + p] = reader.buffer[copyStart + p]
            else:
              copyMem(v[vLen].addr, reader.buffer[copyStart].unsafeAddr, numBytes)
        reader.unlockBuffer()
        inCopy = false

  try:
    var c: char
    while reader.peek(c):
      if format.forceUtf8Strings and (cast[uint8](c) and 0b10000000) != 0: # Multi-byte characters
        var r: Rune
        let byteCount = reader.validRune(r, c)
        if byteCount != 0:
          reader.unsafeNextBy(byteCount)
        else: # Not a valid rune
          reader.error("Found invalid UTF-8 character.")
      else:
        # When the high bit is not set this is a single-byte character (ASCII)
        case c
        of '"':
          break
        of '\\':
          if not reader.hasNext(offset = 1):
            reader.parseError("Expected escaped character but end reached.")
          when doCopy:
            finishCopy()
          reader.unsafeNext() # first \
          let c = reader.unsafePeek()
          reader.unsafeNext() # escape character
          case c
          of '"', '\\', '/': v.add(c)
          of 'b': v.add '\b'
          of 'f': v.add '\f'
          of 'n': v.add '\n'
          of 'r': v.add '\r'
          of 't': v.add '\t'
          of 'u':
            v.add(Rune(parseUnicodeEscape(format, reader)))
            continue
          of 'x':
            v.add(char(parseByte(reader)))
            continue
          else:
            v.add(c)
        else:
          reader.unsafeNext()
          when doCopy:
            enterCopy()
          else:
            v.add c
  finally:
    when doCopy:
      finishCopy()

  skipChar(reader, '"')

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var char) {.inline.} =
  var str: string
  format.read(reader, str)
  if str.len != 1:
    reader.error("String can't fit into a char.")
  v = str[0]

proc read*[T](format: JsonReadFormat, reader: var HoloReader, v: var seq[T]) =
  ## Parse seq.
  mixin read
  for i in readArray(format, reader):
    var element: T
    read(format, reader, element)
    v.add element

proc read*[T: array](format: JsonReadFormat, reader: var HoloReader, v: var T) =
  mixin read
  skipSpace(reader)
  expectChar(reader, '[')
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

proc read*[T: not object](format: JsonReadFormat, reader: var HoloReader, v: var ref T) {.inline.} =
  mixin read
  skipSpace(reader)
  if reader.nextMatch("null"):
    v = nil # changed from original jsony which did nothing, pretty unambiguous here
    return
  new(v)
  read(format, reader, v[])

proc skipValue*(format: JsonReadFormat, reader: var HoloReader): int =
  ## Used to skip values of extra fields.
  ## returns start position in buffer
  result = -1
  skipSpace(reader)
  if reader.nextMatch('{'):
    result = reader.bufferPos
    while reader.hasNext():
      skipSpace(reader)
      if reader.peekMatch('}'):
        break
      discard skipValue(format, reader)
      skipChar(reader, ':')
      discard skipValue(format, reader)
      skipSpace(reader)
      if reader.nextMatch(','):
        discard
    skipChar(reader, '}')
  elif reader.nextMatch('['):
    result = reader.bufferPos
    while reader.hasNext():
      skipSpace(reader)
      if reader.peekMatch(']'):
        break
      discard skipValue(format, reader)
      skipSpace(reader)
      if reader.nextMatch(','):
        discard
    skipChar(reader, ']')
  elif reader.peekMatch('"'):
    result = reader.bufferPos + 1
    var str: string
    read(format, reader, str)
  else:
    result = reader.bufferPos + 1
    discard parseSymbol(reader)

proc crudeReplaceIdent(n: NimNode, name: string, val: NimNode): NimNode =
  if n.kind in {nnkIdent, nnkAccQuoted, nnkSym, nnkOpenSymChoice, nnkClosedSymChoice}:
    if n.eqIdent(name):
      result = copy val
    else:
      result = n
  elif n.kind in AtomicNodes or n.len == 0:
    result = n
  else:
    result = newNimNode(n.kind, n)
    for a in n:
      result.add(crudeReplaceIdent(a, name, val))

proc finishObjectRead*[T](format: JsonReadFormat, reader: var HoloReader, v: var T) {.inline.} =
  ## hook called into when an object/ref object/named tuple has finished reading all fields
  discard

proc parseObjectInner[T](format: JsonReadFormat, reader: var HoloReader, v: var T) {.inline.} =
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
      when jsonyHookCompatibility and compiles(renameHook(v, key)):
        renameHook(v, key)
        block all:
          for k, v in fieldPairs(when v is ref: v[] else: v):
            if k == key or static(toSnakeCase(k)) == key:
              var v2: type(v)
              read(format, reader, v2)
              v = v2
              break all
          discard skipValue(format, reader)
      else:
        template onFieldInput(f) =
          # XXX compiler thinks this is immutable:
          #read(reader, f)
          var v2: typeof(f)
          read(format, reader, v2)
          f = v2
        const fieldMappings = fieldMappings(v, HoloJson)
        mapFieldInput(v, key, fieldMappings, jsonDefaultInputNames, onFieldInput):
          discard skipValue(format, reader)
    skipSpace(reader)
    if reader.nextMatch(','):
      discard
    else:
      break
  mixin finishObjectRead
  finishObjectRead(format, reader, v)

proc read*[T: tuple](format: JsonReadFormat, reader: var HoloReader, v: var T) =
  mixin read
  skipSpace(reader)
  when T.isNamedTuple():
    if reader.nextMatch('{'):
      parseObjectInner(format, reader, v)
      skipChar(reader, '}')
      return
  expectChar(reader, '[')
  for name, value in v.fieldPairs:
    skipSpace(reader)
    read(format, reader, value)
    skipSpace(reader)
    if reader.nextMatch(','):
      discard
  skipChar(reader, ']')

proc read*[T: enum](format: JsonReadFormat, reader: var HoloReader, v: var T) {.inline.} =
  skipSpace(reader)
  var strV: string
  if reader.peekMatch('"'):
    read(format, reader, strV)
    when jsonyHookCompatibility and compiles(enumHook(strV, v)):
      enumHook(strV, v)
    elif T is HasFieldMappings:
      # XXX cannot use by default since normalization is not supported yet unlike `parseEnum`
      template onEnumInput(e: T) =
        v = e
      const fieldMappings = fieldMappings(v, HoloJson)
      mapEnumFieldInput(T, strV, fieldMappings, onEnumInput)
    else:
      try:
        v = parseEnum[T](strV)
      except:
        reader.error("Can't parse enum.")
  else:
    try:
      strV = parseSymbol(reader)
      v = T(parseInt(strV))
    except:
      reader.error("Can't parse enum.")

proc startObjectRead*[T](format: JsonReadFormat, reader: var HoloReader, v: var T) {.inline.} =
  ## hook called into when an object/ref object/named tuple are about to read their fields
  discard

template initObj[T](v: var T) =
  mixin startObjectRead
  when v is ref:
    new(v)
  startObjectRead(format, reader, v)

template initObjVariant[T](v: var T, discrimField, discrimValue) =
  mixin startObjectRead
  v = T(`discrimField`: `discrimValue`)
  startObjectRead(format, reader, v)

proc read*[T: object|ref object](format: JsonReadFormat, reader: var HoloReader, v: var T) =
  ## Parse an object or ref object.
  privateAccess(T) # important
  mixin read
  skipSpace(reader)
  when T is ref: # changed from original jsony, which allows object
    # XXX maybe config option? has test
    if reader.nextMatch("null"):
      v = nil # changed from original jsony, where it does nothing
      return
  expectChar(reader, '{')
  when not hasVariants(T):
    initObj(v)
  else:
    # scan for field names belonging to a variant branch, or the variant field itself
    skipSpace(reader)
    reader.lockBuffer()
    var saveI = reader.bufferPos
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
          const fieldMappings = fieldMappings(v, HoloJson)
          mapInputVariantFieldName(T, key,
            fieldMappings, jsonDefaultInputNames,
            onInnerField, onVariantField): discard
        discard skipValue(format, reader)
        if not reader.peekMatch('}'):
          # needs space skipped above?
          skipChar(reader, ',')
        else:
          initObj(v)
          break
    finally:
      reader.bufferPos = saveI
      reader.unlockBuffer()
  parseObjectInner(format, reader, v)
  skipChar(reader, '}')

proc read*[T: distinct](format: JsonReadFormat, reader: var HoloReader, v: var T) {.inline.} =
  mixin read
  read(format, reader, distinctBase(T)(v))

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var JsonNode) =
  ## Parses a regular json node.
  skipSpace(reader)
  if reader.peekMatch('{'):
    v = newJObject()
    for k in readObject(format, reader):
      var e: JsonNode
      read(format, reader, e)
      v[k] = e
  elif reader.peekMatch('['):
    v = newJArray()
    for i in readArray(format, reader):
      var e: JsonNode
      read(format, reader, e)
      v.add(e)
  elif reader.peekMatch('"'):
    var str: string
    read(format, reader, str)
    v = newJString(str)
  else:
    var data = parseSymbol(reader)
    if data == "null":
      v = newJNull()
    elif data == "true":
      v = newJBool(true)
    elif data == "false":
      v = newJBool(false)
    elif data.len > 0 and data[0] in {'0'..'9', '-', '+'}:
      try:
        v = newJInt(parseInt(data))
      except ValueError:
        try:
          v = newJFloat(parseFloat(data))
        except ValueError:
          reader.error("Invalid number.")
    else:
      reader.error("Unexpected.")

proc read*(format: JsonReadFormat, reader: var HoloReader, v: var RawJson) {.inline.} =
  reader.lockBuffer()
  try:
    let start = skipValue(format, reader)
    v = reader.buffer[start .. reader.bufferPos].RawJson
  finally:
    reader.unlockBuffer()

proc readJson*[T](reader: var HoloReader, v: var T) {.inline.} =
  read(JsonReadFormat(), reader, v)

proc fromJson*[T](s: string, x: typedesc[T]): T {.inline.} =
  ## Takes json and outputs the object it represents.
  ## * Extra json fields are ignored.
  ## * Missing json fields keep their default values.
  ## * `proc startObjectRead(format: JsonReadFormat, reader: var HoloReader, foo: var ...)` Can be used to populate default values.
  mixin read
  result = default(T)
  var reader = initHoloReader(doLineColumn = holoJsonLineColumn)
  reader.startRead(s)
  readJson(reader, result)
  skipSpace(reader)
  if reader.hasNext():
    var msg = "Found non-whitespace character after JSON data: "
    msg.addQuoted(reader.peekOrZero())
    reader.parseError(msg)

proc fromJson*(s: string): JsonNode {.inline.} =
  ## Takes json parses it into `JsonNode`s.
  result = fromJson(s, JsonNode)
