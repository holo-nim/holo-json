import holo_json, std/strutils

type
  Foo {.inheritable.} = object
    abcDef: string
    x_Y_z: string

  Bar = ref object of Foo
    e {.mapping: "uUu_Uu".}: int

proc normalizeField*(foo: typedesc[Bar], format: type JsonReadFormat, name: string): string =
  normalize(name)

let ser = """{"Abc_d_Ef": "abc", "XyZ": "xyz", "uuuuu": 123}"""
doAssert ser.fromJson(Bar)[] == Bar(e: 123, abcDef: "abc", x_Y_z: "xyz")[], $ser.fromJson(Bar)[]
