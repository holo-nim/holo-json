import holo_json, cosm/fields

# default:

type Color = enum
  cRed
  cBlue
  cGreen

proc getFieldMappings(T: type Color, group: static MappingGroup): FieldMappingPairs =
  result = @{
    "cRed": FieldMapping(),
    "cBlue": FieldMapping(),
    "cGreen": FieldMapping(),
  }

doAssert "0".fromJson(Color) == cRed
doAssert "1".fromJson(Color) == cBlue
doAssert "2".fromJson(Color) == cGreen

doAssert """ "cRed" """.fromJson(Color) == cRed
doAssert """ "cBlue" """.fromJson(Color) == cBlue
doAssert """ "cGreen" """.fromJson(Color) == cGreen

# custom:

type Color2 = enum
  c2Red
  c2Blue
  c2Green

proc getFieldMappings(T: type Color2, group: static MappingGroup): FieldMappingPairs =
  result = @{
    "c2Red": toFieldMapping "RED",
    "c2Blue": toFieldMapping "BLUE",
    "c2Green": toFieldMapping "GREEN"
  }

doAssert """ "RED" """.fromJson(Color2) == c2Red
doAssert """ "BLUE" """.fromJson(Color2) == c2Blue
doAssert """ "GREEN" """.fromJson(Color2) == c2Green
