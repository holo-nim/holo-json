import ./[common, parser], holo_flow/holo_reader, std/strbasics
export skipSpace, JsonValueKind, RawJsonValue, peekRawKind, peekRawKindSkipSpace, skipValue, readRawValue, peekRawValueSkipSpace
export HoloReader, initHoloReader, startRead

proc error*(reader: var HoloReader, msg: string) {.inline.} =
  ## Shortcut to raise an exception.
  raise newException(JsonValueError, "(" & $reader.line & ", " & $reader.column & ") " & msg)

proc endError*(reader: var HoloReader, expected: string) {.inline.} =
  reader.parseError("expected " & expected & " but end reached")

const jsonUnexpectedValueErrorLength* {.intdefine.} = 100
  ## number of characters a raw unexpected value can show in an error message
  ## if negative, no maximum
  ## if zero, just gives value kind

proc valueErrorMsg(got: RawJsonValue, expected: string): string =
  result = "expected "
  result.add expected
  result.add " but got "
  when jsonUnexpectedValueErrorLength < 0:
    result.add got.raw.string
  elif jsonUnexpectedValueErrorLength == 0:
    result.add $got.kind
  else:
    if got.raw.string.len < jsonUnexpectedValueErrorLength:
      result.add got.raw.string
    else:
      # copies but whatever:
      result.add got.raw.string.toOpenArray(0, jsonUnexpectedValueErrorLength - 1)
      result.add "..."

proc valueError*(reader: var HoloReader, format: JsonReadFormat, expected: string) {.inline.} =
  let got = peekRawValueSkipSpace(format, reader) # important: this can give parse errors by itself
  reader.error(valueErrorMsg(got, expected))

proc unexpectedError*(reader: var HoloReader, format: JsonReadFormat, expected: string) {.inline.} =
  var dummy: char
  if not reader.peek(dummy):
    endError(reader, expected)
  else:
    valueError(reader, format, expected)

proc expectChar*(format: JsonReadFormat, reader: var HoloReader, c: char) {.inline.} =
  ## Will consume space before and then the character `c`.
  ## Will raise a value error if `c` is not found,
  ## and a parse error if the end is reached.
  skipSpace(reader)
  var c2: char
  if not reader.peek(c2):
    reader.endError("character ' " & c & "'")
  elif c != c2:
    reader.valueError(format, "character '" & $c & "'")
  else:
    reader.unsafeNext()

iterator readObjectFields*[K](format: JsonReadFormat, reader: var HoloReader): K =
  mixin read
  while reader.hasNext():
    skipSpace(reader)
    if reader.peekMatch('}'):
      break
    var key: K
    read(format, reader, key)
    skipChar(reader, ':')
    yield key
    skipSpace(reader)
    if reader.nextMatch(','):
      discard

iterator readObject*[K](format: JsonReadFormat, reader: var HoloReader): K =
  expectChar(format, reader, '{')
  for name in readObjectFields[K](format, reader):
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
  expectChar(format, reader, '[')
  for i in readArrayItems(format, reader):
    yield i
  skipChar(reader, ']')
