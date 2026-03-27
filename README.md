# holo-json

JSON library based on the codebase and structure of [jsony](https://github.com/treeform/jsony) by [treeform](https://github.com/treeform), overhauled for better usability in applications. I am not keen on licenses so if I am missing any credit anywhere for forking jsony I am willing to fix it.

Performance comparison with jsony is [here](https://github.com/holo-nim/holo-json/issues/24). Also still works in JS and compile time, these are tested.

Not compatible with jsony's parsing/conversion behavior.

## Differences with jsony

### Structure

* Instead of using a `string, var int` pair in read hooks, a reader type is used. Similarly a writer type is used instead of `var string` for dumping.
  
  On top of these, a "format" argument is added to the beginning (as the subject), which is an object type that contains settings for the inputted/outputted JSON.
  
  These may hurt efficiency a bit, but they give structure to the hook overloads and distinguish them by changing the signature rather than giving a unique name. On that note the "Hook" part in names are removed, i.e. `dumpHook` just becomes `dump`.
  
  ```nim
  # old:
  proc parseHook(s: string, i: var int, obj: Foo) = ...
  # new:
  proc read(format: JsonReadFormat, reader: JsonReaderArg, obj: Foo) = ...
  ```

  This might look cluttered, but the goal is also to reduce the number of cases where a custom hook has to be written in the first place, as will be shown below.

* The focus on "parsing" and string manipulation is diminished in general in favor of more abstract "reading" and creation of a document. Helpers are added to make this easier but there might be more room for improvement on this.

  ```nim
  type Header = object
    key: string
    value: string

  # new:
  proc read(format: JsonReadFormat, reader: JsonReaderArg, v: var seq[Header]) =
    for key in readObject[string](format, reader):
      var value: string
      read(format, reader, value)
      v.add(Header(key: key, value: value))
  proc dump(format: JsonDumpFormat, writer: JsonWriterArg, v: seq[Header]) =
    var obj: ObjectDump
    format.withObjectDump(writer, obj):
      for header in v:
        format.withObjectField(writer, obj, header.key):
          dump(format, writer, header.value)

  # previous:
  proc parseHook(s: string, i: var int, v: var seq[Header]) =
    eatChar(s, i, '{')
    while i < s.len:
      eatSpace(s, i)
      if i < s.len and s[i] == '}':
        break
      var key, value: string
      parseHook(s, i, key)
      eatChar(s, i, ':')
      parseHook(s, i, value)
      v.add(Header(key: key, value: value))
      eatSpace(s, i)
      if i < s.len and s[i] == ',':
        inc i
      else:
        break
    eatChar(s, i, '}')
  proc dumpHook(s: var string, v: seq[Header]) =
    s.add '{'
    for header in v:
      s.dumpHook(header.key)
      s.add ':'
      s.dumpHook(header.value)
    s.add '}'
  ```

* Instead of `renameHook` and `skipHook` for objects, options for fields can be given in the form of a pragma, using [holo-map](https://github.com/holo-nim/holo-map). A hook can be used for the full field mapping as well, but it has to work at compile time. More info on the possible field options are in the [documentation](https://holo-nim.github.io/holo-map/docs/fields.html#FieldMapping).

  ```nim
  # previous:
  type Node = ref object
    kind: string

  proc renameHook(v: var Node, fieldName: var string) =
    if fieldName == "type":
      fieldName = "kind"

  var node = """{"type":"root"}""".fromJson(Node)
  doAssert node.kind == "root"
  
  # new:
  type Node = ref object
    kind {.mapping: "type".}: string
  # or:
  import holo_map/fields
  type Node = ref object
    kind: string
  proc getFieldMappings(T: type Node, group: static MappingGroup): FieldMappingPairs =
    # note: expected to be complete, can call getDefaultFieldMappings and modify it instead
    result = @{
      "kind": toFieldMapping "type"
    }

  var node = """{"type":"root"}""".fromJson(Node)
  doAssert node.kind == "root"
  ```

  The hook can also be overriden for enums, which replaces `enumHook`.

  By knowing the field behavior at compile time we can generate a single `case` statement for reading an object field rather than using the magic `fields` iterator and individually checking the name of each field. This could theoretically improve performance but it might not matter much if the objects are small.

  One potential caveat is that this could make compile times worse but the macro code for this is not particularly complex. The `fields` magic can't be much more efficient anyway.

* Using the holo-map library allows to generalize enough that this library is easier to copy for another data format,
  and switching between other data formats and this library is easy as well.
  Even the reader/writer types can be abstracted over thanks to the `format` argument.

* Reading/dumping behavior is modularized, you can import one without the other. The default hooks for stdlib types like tables and sets are also moved to their own modules so they can be selectively not imported.

* The runtime object hooks from jsony (adapted `startObjectRead`/`finishObjectRead` as well as compatibility-only `renameHook` and `skipHook`) no longer work when defined for ref objects. Instead they have to be defined on the dereferenced object type, which can be done easily like so:

  ```nim
  type Foo = ref object
  template derefType[T](_: typedesc[ref T]): typedesc[T] = T
  proc startObjectRead(format: JsonReadFormat, reader: JsonReaderArg, foo: var derefType(Foo)) = ...
  ```

  This is because the `read`/`dump` hooks for objects are no longer defined for ref objects, only normal objects.
  Ref objects instead go through the normal `ref` hook. This is so that `ref Foo` now works properly if
  `Foo` is an object with custom hooks. There were other ways to deal with this but the other `ref` hook
  also needed to exclude any constraints put on the `ref object` hook with `not` to avoid ambiguities.

  However the compile time hooks still work when defined on a ref object, i.e. `normalizeField` and `getFieldMappings`.
  This is because there are wrappers around them that also check for `ref T`, which is not possible with the runtime hooks.

### Data handling

* Instead of working on bare strings, reader and writer types from [holo-flow](https://github.com/holo-nim/holo-flow) are used. These keep the lightness of strings and allow loading from/flushing to streams as necessary.

* The existence of the format and reader/writer objects allows for line/column handling and options for different behavior, a potential option is for pretty output but is not implemented yet.

* Parsing errors and value errors are properly separated. When a value is encountered that is unexpected by the current type, the full raw JSON value will be parsed (skipped) before giving a value error. If that single value cannot be parsed, a parsing error is given. This does not mean that types are not allowed to override the JSON grammar, but error reporting prioritizes valid JSON.

### Data representation

#### New

* Object variants support detecting from inner fields of variant branches without needing the variant field as in original jsony.

  ```nim
  type
    FooKind = enum
      FieldA, FieldB, FieldC
    Foo = object
      case kind: FooKind
      of FieldA: a: int
      of FieldB: b: string
      of FieldC: c: float

  echo fromJson("""{"a": 123}""", Foo) # (kind: FieldA, a: 123)
  echo fromJson("""{"b": "xyz"}""", Foo) # (kind: FieldB, b: "xyz")
  ```

  This also helps to initialize variant objects sooner.

* Floats support `NaN`/infinity, by default by using strings as in stdlib json, or optionally with their raw JS equivalents as in JSON5. (Nothing else from JSON5 is supported yet though.)

* Enums allow representation as integers instead of strings via a runtime option. Although this can be done with hooks it's nicer to be able to change what's opt in and what's opt out.

* `\x` is optionally supported for nicer byte strings (I guess if base64 isn't available).

#### Breaking

* Object field names convert to snake case by default instead of using the original name, and only accept this snake case version rather than either snake case or the original name. Outputting snake case by default is to make the most common real world use cases more convenient, not reading the original name is to not unnecessarily complicate the generated case statements. The original jsony behavior can be brought back with `-d:jsonyFieldCompatibility`, and this behavior is represented by constants in `common.nim`.
  * Not the case for enums though.

* Some weird `null` handling is removed: Non-ref objects and strings accepted `null` and interpreted it to mean "empty", as in reading nothing. Now it is allowed only where an explicit `null` value exists (like `nil` or `None`). The old behavior might become a config option but it is hard to justify for specifically objects and strings.

* The generalized `pairs` dumper for objects is removed as it causes problems when the key isn't a string, instead there is a manual `string | enum` table implementation in `dump_stdlib` same as the read hook from the original jsony. This behavior can be brought back with `-d:jsonyPairsObject` but is not recommended.
