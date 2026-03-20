import private/caseutils

const holojsonLineColumn* {.booldefine.} = true
  ## enables/disables line column tracking by default, has very little impact on performance

type
  JsonReadFormat* = object
    handleUtf16*: bool = true
      ## jsony converts utf 16 characters in strings by default apparently so does stdlib json
    forceUtf8Strings*: bool
      ## jsony errors if binary data in strings is not utf8, this is now opt in
    rawJsNanInf*: bool
      ## parses raw NaN/Infinity/-Infinity as in js and json5
    # XXX comments?
  EnumOutput* = enum
    EnumName, EnumOrd
  JsonDumpFormat* = object
    keepUtf8*: bool = true
      ## keeps valid utf 8 codepoints in strings as-is instead of encoding an escape sequence
    useXEscape*: bool
      ## uses \x instead of \u for characters known to be small, not in json standard
    rawJsNanInf*: bool
      ## produces raw NaN/Infinity/-Infinity as in js and json5, as opposed to strings as in nim json
    defaultEnumOutput*: EnumOutput
    # XXX maybe pretty mode

const jsonyHookCompatibility* {.booldefine.} = true
  ## allows compatibility with `renameHook` and `skipHook` which have been replaced with pragmas,
  ## these may become compile time hooks instead. since all other hooks are simply renamed or
  ## had their signature changed, this flag does not affect other hooks

const jsonyFieldCompatibility* {.booldefine.} = false
  ## uses the jsony field name patterns by default, which is: to read the original name and a snake case
  ## version of the name, and to output the original name of the field.
  ## false by default, when disabled only the snake case version of the name is used for both reading and output.

const jsonyIntOutput* {.booldefine.} = true
  ## uses the jsony code for dumping ints instead of just using standard library `addInt`

type
  RawJson* = distinct string
  JsonValueError* = object of ValueError
  JsonParseError* = object of CatchableError
    ## error that signifies a violation of json grammar,
    ## currently not used in all such cases

type
  NamePatternKind* = enum
    NoName,
    NameOriginal, ## uses the field name
    NameString, ## uses custom string and ignores field name
    NameSnakeCase ## converts field name to snake case
    # maybe raw json unquoted name
    NameConcat
  NamePattern* = object
    ## string pattern to apply to a given field name to use in json
    case kind*: NamePatternKind
    of NoName: discard
    of NameOriginal: discard
    of NameString: str*: string
    of NameSnakeCase: discard
    of NameConcat: concat*: seq[NamePattern]
  FieldMapping* = object
    ## json serialization/deserialization options for an object field
    readNames*: seq[NamePattern]
      ## names that are accepted for this field when encountered in json
      ## if none are given, this defaults to the original field name and a snake case version of it
    ignoreRead*, ignoreDump*: bool
      ## whether or not to ignore a field when encountered in json or when dumping to json
    dumpName*: NamePattern
      ## name to dump this field in json by
      ## if not given, this defaults to the original field name
    # maybe normalize case option

template mapping*(options: FieldMapping) {.pragma.}
  ## sets the json serialization/deserialization options for a field
template mapping*(name: string) {.pragma.}
  ## sets a single name between json serialization/deserialization for a field,
  ## can be fine tuned by giving a custom options object
template mapping*(enabled: bool) {.pragma.}
  ## whether or not to enable this field for both json serialization and deserialization,
  ## can be fine tuned by giving a custom options object

proc toName*(str: string): NamePattern =
  ## creates a name pattern that uses a specific string instead of the field name
  NamePattern(kind: NameString, str: str)

proc snakeCase*(): NamePattern =
  ## creates a name pattern that just converts a field name to snake case
  NamePattern(kind: NameSnakeCase)

proc toFieldMapping*(options: FieldMapping): FieldMapping {.inline.} =
  ## hook called on the argument to the `json` pragma to convert it to a full field option object
  options

proc toFieldMapping*(name: NamePattern): FieldMapping =
  ## hook called on the argument to the `json` pragma to convert it to a full field option object,
  ## for a name pattern this sets both the serialization and deserialization name of the field to it
  FieldMapping(readNames: @[name], dumpName: name)

proc toFieldMapping*(name: string): FieldMapping =
  ## hook called on the argument to the `json` pragma to convert it to a full field option object,
  ## for a string this sets both the serialization and deserialization name of the field to it
  toFieldMapping(toName(name))

proc toFieldMapping*(enabled: bool): FieldMapping =
  ## hook called on the argument to the `json` pragma to convert it to a full field option object,
  ## for a bool this sets whether or not to enable serialization and deserialization for this field
  FieldMapping(ignoreRead: not enabled, ignoreDump: not enabled)

proc ignore*(): FieldMapping =
  ## creates a field option object that ignores this field in both serialization and deserialization
  FieldMapping(ignoreRead: true, ignoreDump: true)

proc apply*(pattern: NamePattern, name: string): string =
  ## applies a name pattern to a given name
  case pattern.kind
  of NoName:
    result = ""
  of NameOriginal:
    result = name
  of NameString:
    result = pattern.str
  of NameSnakeCase:
    result = snakeCaseDynamic(name)
  of NameConcat:
    if pattern.concat.len == 0: return ""
    result = apply(pattern.concat[0], name)
    for i in 1 ..< pattern.concat.len: result.add apply(pattern.concat[i], name)

proc getReadNames*(fieldName: string, options: FieldMapping): seq[string] =
  ## gives the names accepted for this field when encountered in json
  ## if none are given, this defaults to the original field name and a snake case version of it
  if options.readNames.len != 0:
    result = @[]
    for pat in options.readNames:
      let name = apply(pat, fieldName)
      if name notin result: result.add name
  else:
    if jsonyFieldCompatibility:
      result = @[fieldName]
      let snakeCase = snakeCaseDynamic(fieldName)
      if snakeCase != fieldName: result.add snakeCase
    else:
      result = @[snakeCaseDynamic(fieldName)]

proc getDumpName*(fieldName: string, options: FieldMapping): string =
  ## gives the name to dump this field in json by
  ## if not given, this defaults to the original field name
  if options.dumpName.kind != NoName:
    result = apply(options.dumpName, fieldName)
  else:
    if jsonyFieldCompatibility:
      result = fieldName
    else:
      result = snakeCaseDynamic(fieldName)
