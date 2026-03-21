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

import holo_map/fields
export fields

const Json* = MappingGroup"json"
const jsonDefaultInputNames* = 
  if jsonyFieldCompatibility: @[verbatim(), snakeCase()]
  else: @[snakeCase()]
const jsonDefaultOutputName* =
  if jsonyFieldCompatibility: verbatim()
  else: snakeCase()
