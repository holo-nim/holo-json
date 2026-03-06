import ./[common, readerdef, readerbasic], std/[options, tables, sets]

proc read*[T](reader: var JsonReader, v: var Option[T]) =
  ## Parse an Option.
  mixin read
  eatSpace(reader)
  if reader.nextMatch("null"):
    # v = none(T)?
    return
  var e: T
  read(reader, e)
  v = some(e)

proc read*[K: string | enum, V](reader: var JsonReader, v: var SomeTable[K, V]) =
  ## Parse an object.
  mixin read
  when v is ref:
    if reader.nextMatch("null"):
      # this is added this time
      return
    new(v)
  eatChar(reader, '{')
  while reader.hasNext():
    eatSpace(reader)
    if reader.peekMatch('}'):
      break
    var key: K
    read(reader, key)
    eatChar(reader, ':')
    var element: V
    read(reader, element)
    v[key] = element
    if reader.nextMatch(','):
      discard
    else:
      break
  eatChar(reader, '}')

proc read*[T](reader: var JsonReader, v: var SomeSet[T]) =
  ## Parses `HashSet` or `OrderedSet`.
  mixin read
  for i in readArray(reader):
    var e: T
    read(reader, e)
    v.incl(e)

proc read*[T](reader: var JsonReader, v: var set[T]) =
  ## Parses the built-in `set` type.
  # separate overload for bitflags or something
  mixin read
  for i in readArray(reader):
    var e: T
    read(reader, e)
    v.incl(e)
