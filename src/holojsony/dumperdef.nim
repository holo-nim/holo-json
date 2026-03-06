import hemodyne/syncartery

type
  JsonDumperOptions* = object
    keepUtf8*: bool = true
      ## keeps valid utf 8 codepoints in strings as-is instead of encoding an escape sequence 
    useXEscape*: bool
      ## uses \x instead of \u for characters known to be small, not in json standard
    # maybe pretty mode
  JsonDumper* = object
    options*: JsonDumperOptions
    artery*: Artery # for like buffering writing to a file
    flushLocks*: int
    flushPos*: int

{.push checks: off, stacktrace: off.}

proc initJsonDumper*(options = JsonDumperOptions()): JsonDumper {.inline.} =
  result = JsonDumper(options: options)

proc lockFlush*(dumper: var JsonDumper) {.inline.} =
  inc dumper.flushLocks

proc unlockFlush*(dumper: var JsonDumper) {.inline.} =
  doAssert dumper.flushLocks > 0, "unpaired flush unlock"
  dec dumper.flushLocks

proc startDump*(dumper: var JsonDumper, artery: Artery) {.inline.} =
  dumper.artery = artery
  dumper.flushLocks = 0
  dumper.flushPos = 0

proc startDump*(dumper: var JsonDumper) {.inline.} =
  dumper.startDump(Artery(buffer: "", bufferConsumer: nil))

proc finishDump*(dumper: var JsonDumper): string {.inline.} =
  ## returns leftover buffer
  doAssert dumper.flushLocks == 0, "unpaired flush lock"
  dumper.flushPos += dumper.artery.flushBufferFull(dumper.flushPos)
  if dumper.flushPos < dumper.artery.buffer.len:
    result = dumper.artery.buffer[dumper.flushPos ..< dumper.artery.buffer.len]
  else:
    result = ""

proc addToBuffer*(dumper: var JsonDumper, c: char) {.inline.} =
  dumper.flushPos -= dumper.artery.addToBuffer(c)

proc addToBuffer*(dumper: var JsonDumper, s: sink string) {.inline.} =
  dumper.flushPos -= dumper.artery.addToBuffer(s)

proc flushBuffer*(dumper: var JsonDumper) {.inline.} =
  # XXX maybe pick a better word, maybe "flow" or just "send" to be boring
  #dumper.artery.flushBufferOnce(bufferPos)
  dumper.flushPos += dumper.artery.flushBuffer(dumper.flushPos)
  if dumper.flushLocks == 0: dumper.artery.freeAfter = dumper.flushPos

proc write*(dumper: var JsonDumper, c: char) {.inline.} =
  dumper.addToBuffer(c)
  dumper.flushBuffer()

proc write*(dumper: var JsonDumper, s: sink string) {.inline.} =
  dumper.addToBuffer(s)
  dumper.flushBuffer()

{.pop.}
