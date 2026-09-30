# holo-json

JSON library based on the codebase and structure of [jsony](https://github.com/treeform/jsony) by treeform, overhauled for better usability in applications, while retaining performance ([comparison](https://github.com/holo-nim/holo-json/issues/24)). I am not keen on licenses so if I am missing any credit anywhere for forking jsony I am willing to fix it.

Library is still unstable but has worked well for a while now.

Also works in JS and compile time, these are tested.

# Description

## Structure

For a given type, the following hooks are implemented:

```nim
proc read(format: JsonRead, reader: JsonReaderArg, value: var Foo) = ...
proc dump(format: JsonDump, writer: JsonWriterArg, value: Foo) = ...
```

The `format` argument is an invariant containing options for the current operation,
i.e. pretty mode for dumping, checking strings for utf8 for reading, or NaN/Infinity output for both.
It also serves as a way to namespace the hooks under a nominal type.

The `reader`/`writer` arguments include the actual input/output buffers and read/write states.
These use the implementations from the [fleu](https://github.com/holo-nim/fleu) library,
which allow custom data streams with minimal overhead for the case
where the buffer is not dynamic (i.e. a direct string).

They also allow for things like line/column tracking or indented output,
but by default the implementations that allow these are not used, as the chief
use of this library is serialization, which prefers performance over readability
(unlike data streaming, these do impact performance since they are checked for every character).
The implementation can be configured using a compile-time define (see
[reader](https://holo-nim.github.io/holo-json/docs/read_common.html) and
[writer](https://holo-nim.github.io/holo-json/docs/dump_common.html) options).
The same thing could have been achieved with generic readers/writers,
but I figured this would be too cumbersome.

The hooks can then be called directly with manually constructed format/reader/writer objects,
or with the following convenience procs:

```nim
let s = toJson(Foo(...))
let foo = Foo.fromJson(s)
let foo = s.fromJsonAs(Foo)

# with optional format argument:
let s = toJson(Foo(...), format = JsonDump(...))
let foo = Foo.fromJson(s, format = JsonRead(...))
let foo = s.fromJsonAs(Foo, format = JsonRead(...))
```

The base read/dump implementations are modularized, you can import one without the other.
The implementations for stdlib types are also in separate modules so that you can selectively
not import them and implement them yourself.

### Differences with jsony

The equivalent hooks in jsony are:

```nim
proc parseHook(s: string, i: var int, v: var Foo) = ...
proc dumpHook(s: var string, v: Foo) = ...
```

There is a small drawback compared to these in that the `string` argument being
different from the `var int` argument (the read state) saves an extra pointer dereference
vs. the entire reader being wrapped in a `var`.
However this is not the case for the `ViewReader` implementation.
Otherwise I think this compromise is worth it for better structure.

Also the order of `fromJson` is changed, the old order is used for `fromJsonAs`.

## Implementing hooks

The focus on "parsing" and string manipulation is diminished in general
in favor of more abstract "reading" and creation of a document.
Helpers are added to make writing hooks easier.

```nim
type Header = object
  key: string
  value: string

proc read(format: JsonRead, reader: JsonReaderArg, value: var seq[Header]) =
  for k in readObject[string](format, reader):
    var v: string
    read(format, reader, v)
    value.add(Header(key: k, value: v))
proc dump(format: JsonDump, writer: JsonWriterArg, value: seq[Header]) =
  var obj: ObjectDump
  obj.dumpTo format, writer:
    for header in value:
      obj.withField format, writer, header.key:
        dump(format, writer, header.value)
```

The raw string handling version as in jsony is still possible,
but requires the user to account for input/output options:

<details>

```nim
# raw string handling (and ignoring format options), as in jsony:
import holo_json/[read_common, parser]
proc read(format: JsonRead, reader: JsonReaderArg, value: var seq[Header]) =
  expectChar(format, reader, '{')
  while reader.hasNext():
    skipSpace(format, reader)
    if reader.peekMatch('}'):
      break
    var key, value: string
    read(format, reader, key)
    skipChar(format, reader, ':')
    read(format, reader, value)
    value.add(Header(key: key, value: value))
    skipSpace(format, reader)
    if reader.nextMatch(','):
      discard
    else:
      break
  skipChar(format, reader, '}')
proc dump(format: JsonDump, writer: JsonWriterArg, value: seq[Header]) =
  writer.write '{'
  for header in value:
    dump(format, writer, header.key)
    writer.write ':'
    dump(format, writer, header.value)
  writer.write '}'
```

</details>

In general though, the aim is to reduce the number of cases where a custom hook has to be written.

## Declarative customization

The main way this is done is through pragmas using the [cosm](https://github.com/holo-nim/cosm) library.

```nim
type Node = ref object
  kind {.mapping: "type".}: string

let node = Node.fromJson("""{"type":"root"}""")
doAssert node.kind == "root"
```

Hooks can also be used to manually provide options (works for enums as well):

```nim
type Node = ref object
  kind: string
proc getFieldMappings(T: type Node, group: type): FieldMappingPairs =
  # note: expected to be complete, can call getDefaultFieldMappings and modify it instead
  result = @{
    "kind": toFieldMapping "type"
  }

let node = Node.fromJson("""{"type":"root"}""")
doAssert node.kind == "root"
```

This allows to build information about how to interpret the type at compile time,
which makes it possible to produce efficient `case` statements for parsing objects.
This replaces `renameHook`/`skipHook`/`enumHook` from jsony.

## JSON output/syntax

By default, object fields convert to snake case in output,
and accept either their snake case variants and original names in input.
It is possible to define a `normalizeField` hook to make fields style insensitive as well.

Object variant branches can be detected without being provided with the actual variant discriminator field.

```nim
type
  FooKind = enum
    FieldA, FieldB, FieldC
  Foo = object
    case kind: FooKind
    of FieldA: a: int
    of FieldB: b: string
    of FieldC: c: float

echo fromJson(Foo, """{"a": 123}""") # (kind: FieldA, a: 123)
echo fromJson(Foo, """{"b": "xyz"}""") # (kind: FieldB, b: "xyz")
```

Floats support `NaN`/infinity, by default by using strings as in stdlib json,
or optionally with their raw JS equivalents as in JSON5.

Enums allow representation as integers instead of strings via a runtime option.
Although this can be done with hooks it's nicer to be able to change what's opt in and what's opt out.

`\x` is optionally supported for nicer byte strings (I guess if base64 isn't available).

Comments are supported, but with a compile time define, as these also impact performance.

## Misc

Parsing errors and value errors are properly separated. When a value is encountered that is unexpected by the current type, the full raw JSON value will be parsed (skipped) before giving a value error. If that single value cannot be parsed, a parsing error is given. This does not mean that types are not allowed to override the JSON grammar, but error reporting prioritizes valid JSON.


