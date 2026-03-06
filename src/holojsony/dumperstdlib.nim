import ./[common, dumperdef, dumperbasic], std/[options, sets, tables]

proc dump*[T](dumper: var JsonDumper, v: Option[T]) {.inline.} =
  if v.isNone:
    dumper.write "null"
  else:
    dumper.dump(v.get())

proc dump*[T](dumper: var JsonDumper, v: SomeSet[T]) =
  dumper.write '['
  var i = 0
  for e in v:
    if i != 0:
      dumper.write ','
    dumper.dump(e)
    inc i
  dumper.write ']'

proc dump*[T](dumper: var JsonDumper, v: set[T]) =
  dumper.write '['
  var i = 0
  for e in v:
    if i != 0:
      dumper.write ','
    dumper.dump(e)
    inc i
  dumper.write ']'

proc dump*[K: string | enum, V](dumper: var JsonDumper, tab: SomeTable[K, V]) =
  ## Dump an object.
  # not in original jsony
  when tab is ref:
    if isNil(v):
      dumper.write "null"
      return
  dumper.write '{'
  var comma = false
  for k, v in tab:
    if comma:
      dumper.write ','
    else:
      comma = true
    dumper.dump $k
    dumper.write ':'
    dumper.dump v
  dumper.write '}'
