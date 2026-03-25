import holo_json, holo_map/fields

# default:

type Color = enum
  cRed
  cBlue
  cGreen

doAssert "0".fromJson(Color) == cRed
doAssert "1".fromJson(Color) == cBlue
doAssert "2".fromJson(Color) == cGreen

doAssert """ "cred" """.fromJson(Color) == cRed
doAssert """ "c_blue" """.fromJson(Color) == cBlue
doAssert """ "cGrEeN" """.fromJson(Color) == cGreen

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

doAssert """ "Red" """.fromJson(Color2) == c2Red
doAssert """ "BLUE" """.fromJson(Color2) == c2Blue
doAssert """ "GReen" """.fromJson(Color2) == c2Green
