import holo_json

type
  Foo = enum A, B, C
  Bar = enum D, E, F

template enumOutput*(format: JsonDump, _: type Foo): EnumOutput = EnumOrd

doAssert toJson([A, B, C]) == "[0,1,2]"
doAssert toJson([D, E, F]) == "[\"D\",\"E\",\"F\"]"

import std/[tables, json, strutils]

template jsonUseStringKey*(_: type Bar): bool = false

let tab1 = toTable {A: 1, B: 2, C: 3}
doAssert JsonNode.fromJson(toJson(tab1)) == %*{"A": 1, "B": 2, "C": 3}
doAssert typeof(tab1).fromJson(toJson(tab1)) == tab1

let tab2 = toTable {D: 4, E: 5, F: 6}
let node2 = JsonNode.fromJson(toJson(tab2))
doAssert node2.kind == JArray and node2.len == 3
var encountered: set[Bar]
for elem in node2:
  doAssert elem.kind == JArray and elem.len == 2
  doAssert elem[0].kind == JString and elem[1].kind == JInt
  let bar = parseEnum[Bar](elem[0].getStr)
  doAssert bar notin encountered
  encountered.incl(bar)
  doAssert elem[1].getInt == tab2[bar]
doAssert encountered == {D, E, F}
doAssert typeof(tab2).fromJson(toJson(tab2)) == tab2
