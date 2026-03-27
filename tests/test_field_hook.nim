import holo_json, holo_map/fields

type
  Foo {.inheritable.} = object
    a {.mapping: "x".}: string
    case b {.mapping(Json, "wrong").}: uint8 #range[0..5] # https://github.com/nim-lang/Nim/pull/25585
    of 0..2:
      c {.mapping(HoloJson, "wrong").}: int
      #when true: # nim limitation
      d {.mapping: "wrong".}: bool
    else:
      discard
    notRenamed: string

  Bar = ref object of Foo
    e {.mapping: "u".}: int

proc getFieldMappings*(foo: typedesc[Bar], group: static MappingGroup): FieldMappingPairs =
  @{
    "a": toFieldMapping "x",
    "b": toFieldMapping "y",
    "c": toFieldMapping "z",
    "d": toFieldMapping "t",
    "e": toFieldMapping "u",
    "notRenamed": FieldMapping()
  }

import std/json

let obj1 = Bar(a: "foo", b: 1, c: 123, d: true, notRenamed: "bar", e: 456)
let ser = toJson(obj1)
doAssert ser.fromJson(JsonNode) == %*{"u":456,"x":"foo","y":1,"z":123,"t":true,"not_renamed":"bar"}
let obj2 = fromJson(ser, Bar)
doAssert obj1.a == obj2.a
doAssert obj1.b == obj2.b
doAssert obj1.c == obj2.c
doAssert obj1.d == obj2.d
doAssert obj1.e == obj2.e
doAssert obj1.notRenamed == obj2.notRenamed

type ObjInner = object
  a, b, c: int

proc getFieldMappings(_: type ObjInner, group: static MappingGroup): FieldMappingPairs =
  @{
    "a": ignore(),
    "b": toFieldMapping "x",
    "c": FieldMapping(input: InputFieldMapping(ignore: true), output: OutputFieldMapping(name: toName "Foo"))
  }

let refObj1 = (ref ObjInner)(a: 123, b: 456, c: 789)
let refObjJson = toJson(refObj1)
doAssert refObjJson.fromJson(JsonNode) == %*{"x": 456, "Foo": 789}
let refObj2 = refObjJson.fromJson(ref ObjInner)
doAssert refObj2[] == ObjInner(b: 456)
