import holo_json, cosm/fields

# default:

type Color = enum
  cRed
  cBlue
  cGreen

doAssert Color.fromJson("0") == cRed
doAssert Color.fromJson("1") == cBlue
doAssert Color.fromJson("2") == cGreen

doAssert Color.fromJson(""" "cred" """) == cRed
doAssert Color.fromJson(""" "c_blue" """) == cBlue
doAssert Color.fromJson(""" "cGrEeN" """) == cGreen

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

doAssert Color2.fromJson(""" "Red" """) == c2Red
doAssert Color2.fromJson(""" "BLUE" """) == c2Blue
doAssert Color2.fromJson(""" "GReen" """) == c2Green
