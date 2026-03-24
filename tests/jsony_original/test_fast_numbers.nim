import holo_json

doAssertRaises JsonParseError:
  var
    reader = initHoloReader()
    n: uint64
  readJson(reader, n)

for i in 0 .. 10000:
  var s = ""
  dumpJson(s, i)
  doAssert $i == s

for i in 0 .. 10000:
  var s = $i
  var reader = initHoloReader()
  reader.startRead(s)
  var v: int
  readJson(reader, v)
  doAssert i == v
