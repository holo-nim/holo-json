# holo-json

JSON library based on the codebase and structure of [jsony](https://github.com/treeform/jsony) by [treeform](https://github.com/treeform), overhauled for better usability in applications. I am not keen on licenses so if I am missing any credit anywhere for forking jsony I am willing to fix it.

Currently about 2x slower than original jsony, presumably due to the level of abstraction but I can't pinpoint why. (double pointer dereference for reading?) Still faster than the other libraries in the benchmarks though. Also still works in JS and compile time, these are tested.

Not compatible with jsony's parsing/conversion behavior.

## Differences with jsony

### Structure

* Instead of using a `string, var int` pair in read hooks, a `var JsonReader` type is used instead. Similarly `var JsonDumper` is used instead of `var string` for dumping. This may hurt efficiency a bit but helps to not pollute the namespace and distinguishes the hooks by changing the signature rather than giving a unique name. On that note the "Hook" part in names are removed, i.e. `dumpHook` just becomes `dump`.
  
  ```nim
  # old:
  proc parseHook(s: string, i: var int, obj: Foo) = ...
  # new:
  proc read(reader: var JsonReader, obj: Foo) = ...
  ```

* The focus on "parsing" and string manipulation is diminished in general in favor of more abstract "reading" and creation of a document. Helpers are added to make this easier but there might be more room for improvement on this.

  ```nim
  type Header = object
    key: string
    value: string

  # new:
  proc read(reader: var JsonReader, v: var seq[Header]) =
    for key in readObject(reader):
      var value: string
      read(reader, value)
      v.add(Header(key: key, value: value))
  proc dump(dumper: var JsonDumper, v: seq[Header]) =
    var obj: ObjectDump
    dumper.withObjectDump(obj):
      for header in v:
        dumper.withObjectField(obj, header.key):
          dump(dumper, header.value)

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

* Instead of `renameHook` and `skipHook` for objects, options for fields in the form of a pragma are preferred. There might be a hook for these in the future as well but it will likely have to work at compile time. More info on the possible field options are in the [documentation](https://holo-nim.github.io/holo-json/docs/common.html#json.t%2CFieldJsonOptions).

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
    kind {.json: "type".}: string

  var node = """{"type":"root"}""".fromJson(Node)
  doAssert node.kind == "root"
  ```

  By knowing the field behavior at compile time we can generate a single `case` statement for reading an object field rather than using the magic `fields` iterator and individually checking the name of each field. This could theoretically improve performance but it might not matter much if the objects are small.

  One potential caveat is that this could make compile times worse but the macro code for this is not particularly complex. The `fields` magic can't be much more efficient anyway.

* Reading/dumping behavior is modularized, you can import one without the other. The default hooks for stdlib types like tables and sets are also moved to their own modules so they can be selectively not imported.

### Data handling

* Instead of working on bare strings a "dynamic buffer" is used that can be read/written to either immediately or when it becomes available via a callback (which can read from streams etc). It also shrinks to remove data up to a position marked as read when it needs to resize, although a queue would be better for this, but strings keep compatibility. The library that does this is very immature though and it may be replaced in the future. Also the data loading is entirely sync as an async json parser would be ridiculous.

* The existence of the reader/dumper objects allows for line/column handling and options for different behavior, a potential option is for pretty output but is not implemented yet.

### Data representation

* Object field names convert to snake case by default instead of using the original name, and only accept this snake case version rather than either snake case or the original name. Outputting snake case by default is to make the most common real world use cases more convenient, not reading the original name is to not unnecessarily complicate the generated case statements. The original jsony behavior can be brought back with `-d:jsonyFieldCompatibility`.
  * Not the case for enums though. But enum behavior is not finished yet.
* Floats support `NaN`/infinity, by default by using strings as in stdlib json, or optionally with their raw JS equivalents as in JSON5. (Nothing else from JSON5 is supported yet though.)
* Enums allow representation as integers instead of strings via an option. Although this can be done with hooks it's nicer to be able to change what's opt in and what's opt out.
* Some weird `null` handling is removed: Non-ref objects and strings accepted `null` and interpreted it to mean "empty", as in reading nothing. Now it is allowed only where an explicit `null` value exists (like `nil` or `None`). The old behavior might become a config option but it is hard to justify for specifically objects and strings.
* `\x` is optionally supported for nicer byte strings (I guess if base64 isn't available).
* The generalized `pairs` dumper for objects is removed as it causes problems when the key isn't a string, instead there is a manual `string | enum` table implementation in `dumperstdlib` same as the read hook from the original jsony.
