import holo_json

type
  FooKind = enum
    FieldA, FieldB, FieldC
  Foo = object
    case kind: FooKind
    of FieldA: a: int
    of FieldB: b: string
    of FieldC: c: float

let x = fromJson(r"{""a"": 123}", Foo) # (kind: FieldA, a: 123)
doAssert x.kind == FieldA
doAssert x.a == 123
let y = fromJson(r"{""b"": ""xyz""}", Foo) # (kind: FieldB, b: "xyz")
doAssert y.kind == FieldB
doAssert y.b == "xyz"
