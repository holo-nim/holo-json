## defines the `JsonReader` object along with helpers to use it

import ./common, holo_flow/reader, std/streams

type
  JsonReader* = object
    options*: JsonReaderOptions
    data*: HoloReader

template buffer*(reader: JsonReader): string = reader.data.vein.buffer
template bufferLocks*(reader: JsonReader): int = reader.data.bufferLocks
template bufferPos*(reader: JsonReader): int = reader.data.bufferPos
template line*(reader: JsonReader): int = reader.data.line
template column*(reader: JsonReader): int = reader.data.column

proc initJsonReader*(options = JsonReaderOptions()): JsonReader {.inline.} =
  result = JsonReader(options: options, data: initHoloReader(options.doLineColumn))

proc startRead*(reader: var JsonReader, str: string) {.inline.} =
  reader.data.startRead(str)

proc startRead*(reader: var JsonReader, stream: Stream, loadAmount = 4) {.inline.} =
  reader.data.startRead(stream, loadAmount)

proc error*(reader: var JsonReader, msg: string) {.inline.} =
  ## Shortcut to raise an exception.
  raise newException(JsonValueError, "(" & $reader.line & ", " & $reader.column & ") " & msg)

proc parseError*(reader: var JsonReader, msg: string) {.inline.} =
  ## Shortcut to raise an exception.
  raise newException(JsonParseError, "(" & $reader.line & ", " & $reader.column & ") " & msg)

proc loadBufferOne*(reader: var JsonReader) {.inline.} =
  reader.data.loadBufferOne()

proc loadBufferBy*(reader: var JsonReader, n: int) {.inline.} =
  reader.data.loadBufferBy(n)

proc peek*(reader: var JsonReader, c: var char): bool {.inline.} =
  reader.data.peek(c)

proc unsafePeek*(reader: var JsonReader): char {.inline.} =
  reader.data.unsafePeek()

proc peek*(reader: var JsonReader, c: var char, offset: int): bool {.inline.} =
  reader.data.peek(c, offset)

proc unsafePeek*(reader: var JsonReader, offset: int): char {.inline.} =
  reader.data.unsafePeek(offset)

proc peek*(reader: var JsonReader, cs: var openArray[char]): bool {.inline.} =
  reader.data.peek(cs)

proc peek*[I](reader: var JsonReader, cs: var array[I, char]): bool {.inline.} =
  reader.data.peek(cs)

proc peekOrZero*(reader: var JsonReader): char {.inline.} =
  reader.data.peekOrZero()

proc hasNext*(reader: var JsonReader): bool {.inline.} =
  reader.data.hasNext()

proc hasNext*(reader: var JsonReader, offset: int): bool {.inline.} =
  reader.data.hasNext(offset)

proc lockBuffer*(reader: var JsonReader) {.inline.} =
  reader.data.lockBuffer()

proc unlockBuffer*(reader: var JsonReader) {.inline.} =
  reader.data.unlockBuffer()

proc unsafeNext*(reader: var JsonReader) {.inline.} =
  reader.data.unsafeNext()

proc unsafeNextBy*(reader: var JsonReader, n: int) {.inline.} =
  reader.data.unsafeNextBy(n)

proc next*(reader: var JsonReader, c: var char): bool {.inline.} =
  reader.data.next(c)

proc next*(reader: var JsonReader): bool {.inline.} =
  reader.data.next()

iterator peekNext*(reader: var JsonReader): char =
  for c in reader.data.peekNext(): yield c

proc peekMatch*(reader: var JsonReader, c: char): bool {.inline.} =
  reader.data.peekMatch(c)

proc nextMatch*(reader: var JsonReader, c: char): bool {.inline.} =
  reader.data.nextMatch(c)

proc peekMatch*(reader: var JsonReader, c: char, offset: int): bool {.inline.} =
  reader.data.peekMatch(c, offset)

proc peekMatch*(reader: var JsonReader, cs: set[char], c: var char): bool {.inline.} =
  reader.data.peekMatch(cs, c)

proc nextMatch*(reader: var JsonReader, cs: set[char], c: var char): bool {.inline.} =
  reader.data.nextMatch(cs, c)

proc peekMatch*(reader: var JsonReader, cs: set[char]): bool {.inline.} =
  reader.data.peekMatch(cs)

proc nextMatch*(reader: var JsonReader, cs: set[char]): bool {.inline.} =
  reader.data.nextMatch(cs)

proc peekMatch*(reader: var JsonReader, cs: set[char], offset: int, c: var char): bool {.inline.} =
  reader.data.peekMatch(cs, offset, c)

proc peekMatch*(reader: var JsonReader, cs: set[char], offset: int): bool {.inline.} =
  reader.data.peekMatch(cs, offset)

proc peekMatch*(reader: var JsonReader, str: openArray[char]): bool {.inline.} =
  reader.data.peekMatch(str)

proc peekMatch*[I](reader: var JsonReader, str: array[I, char]): bool {.inline.} =
  reader.data.peekMatch(str)

proc peekMatch*(reader: var JsonReader, str: static string): bool {.inline.} =
  reader.data.peekMatch(str)

proc nextMatch*(reader: var JsonReader, str: openArray[char]): bool {.inline.} =
  reader.data.nextMatch(str)

proc nextMatch*[I](reader: var JsonReader, str: array[I, char]): bool {.inline.} =
  reader.data.nextMatch(str)

proc nextMatch*(reader: var JsonReader, str: static string): bool {.inline.} =
  reader.data.nextMatch(str)
