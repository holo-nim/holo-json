import holo_json

type Color = enum
  cRed
  cBlue
  cGreen

doAssert "0".fromJsonAs(Color) == cRed
doAssert "1".fromJsonAs(Color) == cBlue
doAssert "2".fromJsonAs(Color) == cGreen

doAssert """ "cRed" """.fromJsonAs(Color) == cRed
doAssert """ "cBlue" """.fromJsonAs(Color) == cBlue
doAssert """ "cGreen" """.fromJsonAs(Color) == cGreen

type Color2 = enum
  c2Red
  c2Blue
  c2Green

proc enumHook(s: string, v: var Color2) =
  v = case s:
  of "RED": c2Red
  of "BLUE": c2Blue
  of "GREEN": c2Green
  else: c2Red

doAssert """ "RED" """.fromJsonAs(Color2) == c2Red
doAssert """ "BLUE" """.fromJsonAs(Color2) == c2Blue
doAssert """ "GREEN" """.fromJsonAs(Color2) == c2Green
