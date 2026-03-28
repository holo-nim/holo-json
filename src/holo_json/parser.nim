import ./[common, read_common], std/[strutils, unicode]

proc parseError*(reader: JsonReaderArg, msg: string) {.inline.} =
  ## Shortcut to raise an exception.
  when supportsLineColumn(reader):
    let msg = "(" & $reader.state.line & ", " & $reader.state.column & ") " & msg
  raise newException(JsonParseError, msg)

proc skipSpace*(reader: JsonReaderArg) {.inline.} =
  ## Will consume whitespace.
  for c in reader.chars():
    if c notin Whitespace:
      break

type
  JsonValueKind* = enum
    JsonInvalid
    JsonObject
    JsonArray
    JsonString
    JsonNumber
    JsonRawNan, JsonRawInf, JsonRawNegInf
    JsonTrue, JsonFalse
    JsonNull
  RawJsonValue* = object
    kind*: JsonValueKind
    raw*: RawJson

proc peekRawKind*(format: JsonReadFormat, reader: JsonReaderArg): JsonValueKind =
  ## guesses which kind the next object is, assumes spaces are skipped
  ## not guaranteed to be accurate, all numbers are assumed float
  let start = reader.peekOrZero()
  result = JsonInvalid
  case start
  of '{':
    result = JsonObject
  of '[':
    result = JsonArray
  of '"':
    result = JsonString
  of '-':
    if format.rawJsNanInf and
        reader.peekMatch('I', offset = 1) and
        reader.peekMatch("-Infinity"):
      result = JsonRawNegInf
    else:
      result = JsonNumber
  of '+', '0'..'9':
    result = JsonNumber
  of 'n':
    if reader.peekMatch("null"):
      result = JsonNull
  of 't':
    if reader.peekMatch("true"):
      result = JsonTrue
  of 'f':
    if reader.peekMatch("false"):
      result = JsonFalse
  of 'N':
    if format.rawJsNanInf and reader.peekMatch("NaN"):
      result = JsonRawNan
  of 'I':
    if format.rawJsNanInf and reader.peekMatch("Infinity"):
      result = JsonRawInf
  else:
    result = JsonInvalid
  if result == JsonInvalid:
    var msg = "unknown value starting with character "
    msg.addQuoted(start)
    reader.parseError(msg)

proc peekRawKindSkipSpace*(format: JsonReadFormat, reader: JsonReaderArg): JsonValueKind {.inline.} =
  ## guesses which kind the next object is, skips spaces
  ## not guaranteed to be accurate, all numbers are assumed float
  skipSpace(reader)
  result = peekRawKind(format, reader)

proc skipChar*(reader: JsonReaderArg, c: char) {.inline.} =
  ## Will consume space before and then the character `c`.
  ## Will raise a parsing error if `c` is not found.
  skipSpace(reader)
  var c2: char
  if not reader.next(c2):
    reader.parseError("Expected " & c & " but end reached.")
  elif c != c2:
    reader.parseError("Expected " & c & " but got " & c2 & " instead.")

proc skipNumber*(format: JsonReadFormat, reader: JsonReaderArg): int =
  ## returns start position in buffer
  result = -1
  let start = reader.bufferPos
  block signPart:
    var sign: char
    if reader.nextMatch({'-', '+'}, sign):
      discard
  block integerPart:
    var hasDigit = false
    for c in reader.chars():
      case c
      of '0'..'9':
        hasDigit = true
      else: break
    if not hasDigit:
      return -1
  block decimalPoint:
    if reader.peekMatch('.') and reader.peekMatch({'0'..'9'}, offset = 1):
      reader.unsafeNext()
      for c in reader.chars():
        case c
        of '0'..'9': discard
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
        let firstSkip = reader.next(c)
        assert firstSkip
        if hasSign:
          let secondSkip = reader.next(c)
          assert secondSkip
        for c in reader.chars():
          case c
          of '0'..'9': discard
          else: break
  if reader.bufferPos != start:
    result = start + 1

proc validRune*(reader: JsonReaderArg, rune: var Rune, start: char): int =
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

proc parseHexInt*[I](reader: JsonReaderArg, a: array[I, char]): int {.inline.} =
  result = 0
  for i in 0 ..< a.len:
    let c = a[i]
    case c
    of '0'..'9': result = (result shl 4) or (c.int - '0'.int)
    of 'A'..'F': result = (result shl 4) or (10 + c.int - 'A'.int)
    of 'a'..'f': result = (result shl 4) or (10 + c.int - 'a'.int)
    else: reader.parseError("expected hex char in escape sequence, got " & $c)

proc parseUnicodeEscape*(format: JsonReadFormat, reader: JsonReaderArg): int =
  #reader.unsafeNext() # u already skipped
  var hexStr: array[4, char]
  if not reader.peek(hexStr):
    reader.parseError("Expected unicode escape hex but end reached.")
  reader.unsafeNextBy(hexStr.len)
  result = parseHexInt(reader, hexStr)
  if format.handleUtf16:
    # Deal with UTF-16 surrogates. Most of the time strings are encoded as utf8
    # but some APIs will reply with UTF-16 surrogate pairs which needs to be dealt
    # with.
    if (result and 0xfc00) == 0xd800:
      if not reader.nextMatch("\\u"):
        # maybe make the option an enum for whether or not to error here
        reader.parseError("Found an Orphan Surrogate.")
      var nextHexStr: array[4, char]
      if not reader.peek(nextHexStr):
        reader.parseError("Expected unicode escape hex but end reached.")
      reader.unsafeNextBy(nextHexStr.len)
      let nextRune = parseHexInt(reader, nextHexStr)
      if (nextRune and 0xfc00) == 0xdc00:
        result = 0x10000 + (((result - 0xd800) shl 10) or (nextRune - 0xdc00))

proc parseByteEscape*(reader: JsonReaderArg): byte =
  #reader.unsafeNext() # x already skipped
  var hexStr: array[2, char]
  if not reader.peek(hexStr):
    reader.parseError("Expected byte escape hex but end reached.")
  reader.unsafeNextBy(hexStr.len)
  result = parseHexInt(reader, hexStr).byte

proc parseString*(format: JsonReadFormat, reader: JsonReaderArg, quoteSkipped = false): string =
  if not quoteSkipped: skipChar(reader, '"')

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
          let vLen = result.len
          result.setLen(vLen + numBytes)
          when nimvm:
            for p in 0 ..< numBytes:
              result[vLen + p] = reader.currentBuffer[copyStart + p]
          else:
            when not holoJsonStringCopyMem or defined(js) or defined(nimscript):
              for p in 0 ..< numBytes:
                result[vLen + p] = reader.currentBuffer[copyStart + p]
            else:
              copyMem(result[vLen].addr, reader.currentBuffer[copyStart].unsafeAddr, numBytes)
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
          reader.parseError("Found invalid UTF-8 character.")
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
          of '"', '\\', '/': result.add(c)
          of 'b': result.add '\b'
          of 'f': result.add '\f'
          of 'n': result.add '\n'
          of 'r': result.add '\r'
          of 't': result.add '\t'
          of 'u':
            result.add(Rune(parseUnicodeEscape(format, reader)))
            continue
          of 'x':
            result.add(char(parseByteEscape(reader)))
            continue
          else:
            result.add(c)
        else:
          reader.unsafeNext()
          when doCopy:
            enterCopy()
          else:
            result.add c
  finally:
    when doCopy:
      finishCopy()
  skipChar(reader, '"')

proc skipValue*(format: JsonReadFormat, reader: JsonReaderArg): int =
  ## Used to skip values of extra fields, or wrongly typed values for errors.
  ## returns start position in buffer
  result = -1
  skipSpace(reader)
  case peekRawKind(format, reader)
  of JsonInvalid:
    result = -1
  of JsonObject:
    unsafeNext(reader)
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
  of JsonArray:
    unsafeNext(reader)
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
  of JsonString:
    unsafeNext(reader)
    result = reader.bufferPos
    discard parseString(format, reader, quoteSkipped = true)
  of JsonNumber:
    result = skipNumber(format, reader)
  of JsonNull:
    result = reader.bufferPos + 1
    unsafeNextBy(reader, "null".len)
  of JsonTrue:
    result = reader.bufferPos + 1
    unsafeNextBy(reader, "true".len)
  of JsonFalse:
    result = reader.bufferPos + 1
    unsafeNextBy(reader, "false".len)
  of JsonRawNan:
    result = reader.bufferPos + 1
    unsafeNextBy(reader, "NaN".len)
  of JsonRawInf:
    result = reader.bufferPos + 1
    unsafeNextBy(reader, "Infinity".len)
  of JsonRawNegInf:
    result = reader.bufferPos + 1
    unsafeNextBy(reader, "-Infinity".len)

proc readRawValue*(format: JsonReadFormat, reader: JsonReaderArg): RawJsonValue =
  reader.lockBuffer()
  try:
    skipSpace(reader)
    let kind = peekRawKind(format, reader)
    let firstPos = skipValue(format, reader)
    result = RawJsonValue(kind: kind, raw: reader.currentBuffer[firstPos .. reader.bufferPos].RawJson)
  finally:
    reader.unlockBuffer()

proc peekRawValueSkipSpace*(format: JsonReadFormat, reader: JsonReaderArg): RawJsonValue =
  ## reads a full raw json value, relatively inefficient and mostly meant for errors
  var savedState = reader.state # XXX using `let` makes VM not copy here
  reader.lockBuffer()
  try:
    skipSpace(reader)
    let kind = peekRawKind(format, reader)
    let firstPos = skipValue(format, reader)
    result = RawJsonValue(kind: kind, raw: reader.currentBuffer[firstPos .. reader.bufferPos].RawJson)
  finally:
    reader.unlockBuffer()
    reader.state = savedState
