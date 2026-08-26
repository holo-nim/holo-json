import holo_json, std/strutils

type Node = ref object
  kind: string

template derefType[T](_: typedesc[ref T]): type T = T

proc renameHook(v: var derefType(Node), fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

var node = """{"type":"root"}""".fromJsonAs(Node)
doAssert node.kind == "root"

type
  NodeNumKind = enum # the different node types
    nkNone
    nkInt,           # a leaf with an integer value
    nkFloat,         # a leaf with a float value
  RefNode = ref object
    active: bool
    case kind: NodeNumKind # the ``kind`` field is the discriminator
    of nkNone: discard
    of nkInt: intVal: int
    of nkFloat: floatVal: float
  ValueNode = object
    active: bool
    case kind: NodeNumKind # the ``kind`` field is the discriminator
    of nkNone: discard
    of nkInt: intVal: int
    of nkFloat: floatVal: float

proc renameHook*(v: var derefType(RefNode)|ValueNode, fieldName: var string) =
  # rename``type`` field name to ``kind``
  if fieldName == "type":
    fieldName = "kind"

# Test renameHook and discriminator Field Name not being first/missing.
block:
  let
    a = """{"active":true,"type":"nkFloat","floatVal":3.14}""".fromJsonAs(RefNode)
    b = """{"floatVal":3.14,"active":true,"type":"nkFloat"}""".fromJsonAs(RefNode)
    c = """{"type":"nkFloat","floatVal":3.14,"active":true}""".fromJsonAs(RefNode)
    d = """{"active":true,"intVal":42}""".fromJsonAs(RefNode)
  doAssert a.kind == nkFloat
  doAssert b.kind == nkFloat
  doAssert c.kind == nkFloat
  if false: doAssert d.kind == nkInt # never actually worked

block:
  let
    a = """{"active":true,"type":"nkFloat","floatVal":3.14}""".fromJsonAs(ValueNode)
    b = """{"floatVal":3.14,"active":true,"type":"nkFloat"}""".fromJsonAs(ValueNode)
    c = """{"type":"nkFloat","floatVal":3.14,"active":true}""".fromJsonAs(ValueNode)
    d = """{"active":true,"intVal":42}""".fromJsonAs(ValueNode)
  doAssert a.kind == nkFloat
  doAssert b.kind == nkFloat
  doAssert c.kind == nkFloat
  if false: doAssert d.kind == nkInt # never actually worked

# test https://forum.nim-lang.org/t/7619

type
  FooBar = object
    `Foo Bar`: string

const jsonString = "{\"Foo Bar\": \"Hello World\"}"

proc renameHook*(v: var FooBar, fieldName: var string) =
  if fieldName == "Foo Bar":
    fieldName = "FooBar"

echo jsonString.fromJsonAs(FooBar)
