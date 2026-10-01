const holoJsonLineColumn* {.booldefine.} = true
  ## enables/disables line column tracking by default at runtime if implementation allows it,
  ## default implementation does not

const holoJsonBatchStringAdd* {.booldefine.} = not defined(js)
  ## adds/copies a range of string characters to read/dump output all at once whenever possible,
  ## should be faster due to single use of `setLen` but this can also make it slower on JS

const holoJsonStringCopyMem* {.booldefine.} = true
  ## uses `copyMem` to copy batched string characters whenever available,
  ## given `holoJsonBatchStringAdd` is enabled

const holoJsonObjectStyleInsensitivity* {.booldefine.} = false
  ## defines a normalizer hook for object fields to implement style insensitivity

const holoJsonEnumStyleInsensitivity* {.booldefine.} = false
  ## defines a normalizer hook for enum fields to implement style insensitivity

const holoJsonCommentSupport* {.booldefine.} = false
  ## adds support for comments where whitespace is allowed, not tested well and can hurt performance
  ## supports both // and /* */ comments

type
  JsonRead* = object
    ## json input format (options)
    allowComments*: bool
      ## allows comments, note that `-d:holoJsonCommentSupport` has to be enabled
      ## as this can impact performance
    handleUtf16*: bool = true
      ## jsony converts utf 16 characters in strings by default apparently so does stdlib json
    forceUtf8Strings*: bool
      ## jsony errors if binary data in strings is not utf8, this is now opt in
    rawJsNanInf*: bool
      ## parses raw NaN/Infinity/-Infinity as in js and json5
  EnumOutput* = enum
    EnumName, EnumOrd
  InvalidUtf8Output* = enum
    EscapeInvalidUtf8 ## encodes invalid utf8 in escape sequence
    ReplaceInvalidUtf8 ## replaces invalid utf8 with replacement character
    KeepInvalidUtf8 ## keeps invalid utf8 characters as-is
  PrettyModeClosingBrace* = enum
    SeparateLine ## closing brace is on separate line, default behavior
    InlineSpace ## an inline space is added before the closing brace
    NoSpacing ## closing brace is added directly after the last character
  JsonDump* = object
    ## json output format (options)
    keepUtf8*: bool = true
      ## keeps valid utf 8 codepoints in strings as-is instead of encoding an escape sequence
    invalidUtf8*: InvalidUtf8Output = EscapeInvalidUtf8
    useXEscape*: bool
      ## uses \x instead of \u for characters known to be small, not in json standard
    rawJsNanInf*: bool
      ## produces raw NaN/Infinity/-Infinity as in js and json5, as opposed to strings as in nim json
    defaultEnumOutput*: EnumOutput
    pretty*: bool
      ## pretty output, requires indented writer
    prettyClosingBrace*: PrettyModeClosingBrace
      ## chooses pretty mode behavior for closing ] and } braces

const jsonyHookCompatibility* {.booldefine.} = false
  ## allows compatibility with `renameHook` and `skipHook` which have been replaced with pragmas,
  ## these may become compile time hooks instead. since all other hooks are simply renamed or
  ## had their signature changed, this flag does not affect other hooks

const jsonyFieldCompatibility* {.booldefine.} = false
  ## uses the jsony field name patterns by default, which is: to read the original name and a snake case
  ## version of the name, and to output the original name of the field.
  ## false by default, when disabled only the snake case version of the name is used for both reading and output.

const jsonyIntOutput* {.booldefine.} = true
  ## uses the jsony code for dumping ints instead of just using standard library `addInt`

const jsonyPairsObject* {.booldefine.} = false
  ## enables generalized pair object (i.e. tables) output from jsony,
  ## disabled by default since it includes non-string keys

type
  RawJson* = distinct string
  JsonError* = object of ValueError
  JsonValueError* = object of JsonError
    ## error for when a value can be parsed,
    ## but could not be fit into the expected value
  JsonParseError* = object of JsonError
    ## error for invalid json grammar according to the given format

import cosm, cosm/common_groups
export cosm, common_groups.Json

#const HoloJson* = MappingGroup(id: "holo-json", parents: @[Json])
type HoloJson* = object
  ## mapping group type for cosm
template eachParent*(_: type HoloJson, toApply) =
  toApply Json
const jsonDefaultInputNames* = 
  if jsonyFieldCompatibility: @[verbatim(), snakeCase()]
  else: @[snakeCase()]
const jsonDefaultOutputName* =
  if jsonyFieldCompatibility: verbatim()
  else: snakeCase()

template jsonUseStringKey*[T](_: typedesc[T]): bool =
  ## overload to make this type use string keys in an object to represent tables
  ##
  ## by default, this is enabled for strings and enums, but not cstrings as they can be nil
  false

template jsonUseStringKey*(_: type string): bool =
  true

# no cstring, can be nil

template jsonUseStringKey*[T: enum](_: type T): bool =
  true

import std/typetraits

template jsonUseStringKey*[T: distinct](_: type T): bool =
  mixin jsonUseStringKey
  jsonUseStringKey(distinctBase(T))
