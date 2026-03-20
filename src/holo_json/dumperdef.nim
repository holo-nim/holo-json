## defines the `JsonDumper` object along with helpers to use it

import ./common, holo_flow/writer, std/streams

type
  JsonDumper* = object
    options*: JsonDumperOptions
    data*: HoloWriter

template buffer*(dumper: JsonDumper): string = dumper.data.artery.buffer
template flushLocks*(dumper: JsonDumper): int = dumper.data.flushLocks
template flushPos*(dumper: JsonDumper): int = dumper.data.flushPos

proc initJsonDumper*(options = JsonDumperOptions()): JsonDumper {.inline.} =
  result = JsonDumper(options: options, data: initHoloWriter())

proc lockFlush*(dumper: var JsonDumper) {.inline.} =
  dumper.data.lockFlush()

proc unlockFlush*(dumper: var JsonDumper) {.inline.} =
  dumper.data.unlockFlush()

proc startDump*(dumper: var JsonDumper, bufferCapacity = 16) {.inline.} =
  dumper.data.startDump(bufferCapacity)

proc startDump*(dumper: var JsonDumper, stream: Stream) {.inline.} =
  dumper.data.startDump(stream)

proc finishDump*(dumper: var JsonDumper): string {.inline.} =
  dumper.data.finishDump()

proc addToBuffer*(dumper: var JsonDumper, c: char) {.inline.} =
  dumper.data.addToBuffer(c)

proc addToBuffer*(dumper: var JsonDumper, s: sink string) {.inline.} =
  dumper.data.addToBuffer(s)

proc consumeBuffer*(dumper: var JsonDumper) {.inline.} =
  dumper.data.consumeBuffer()

proc write*(dumper: var JsonDumper, c: char) {.inline.} =
  dumper.data.write(c)

proc write*(dumper: var JsonDumper, s: sink string) {.inline.} =
  dumper.data.write(s)
