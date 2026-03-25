import holo_json, std/strutils, holo_map/caseutils

type
  Foo {.inheritable.} = object
    AbcDef: string
    x_Y_z: string

  Bar = ref object of Foo
    e {.mapping: "uUu_Uu".}: int

let ser = """{"Abc_d_Ef": "abc", "xyZ": "xyz", "uuuuu": 123}"""
doAssert ser.fromJson(Bar)[] == Bar(e: 123, AbcDef: "abc", x_Y_z: "xyz")[], $ser.fromJson(Bar)[]
