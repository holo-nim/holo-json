import holo_json

type Node = ref object
  kind {.mapping: "type".}: string

const nodeJson = """{"type":"root"}"""
var node = Node.fromJson(nodeJson)
doAssert node.kind == "root"
doAssert node.toJson() == nodeJson

type
  NodeNumKind = enum # the different node types
    nkNone,
    nkInt,           # a leaf with an integer value
    nkFloat,         # a leaf with a float value
  RefNode = ref object
    active: bool
    case kind {.mapping: "type".}: NodeNumKind # the ``kind`` field is the discriminator
    of nkNone: discard
    of nkInt: intVal: int
    of nkFloat: floatVal: float
  ValueNode = object
    active: bool
    case kind {.mapping: "type".}: NodeNumKind # the ``kind`` field is the discriminator
    of nkNone: discard
    of nkInt: intVal: int
    of nkFloat: floatVal: float

# Test renameHook and discriminator Field Name not being first/missing.
block:
  let
    a = RefNode.fromJson("""{"active":true,"type":"nkFloat","float_val":3.14}""")
    b = RefNode.fromJson("""{"float_val":3.14,"active":true,"type":"nkFloat"}""")
    c = RefNode.fromJson("""{"type":"nkFloat","float_val":3.14,"active":true}""")
    d = RefNode.fromJson("""{"active":true,"int_val":42}""")
  doAssert a.kind == nkFloat
  doAssert b.kind == nkFloat
  doAssert c.kind == nkFloat
  doAssert d.kind == nkInt
  doAssert RefNode.fromJson(a.toJson()).kind == a.kind
  doAssert RefNode.fromJson(b.toJson()).kind == b.kind
  doAssert RefNode.fromJson(c.toJson()).kind == c.kind
  doAssert RefNode.fromJson(d.toJson()).kind == d.kind

block:
  let
    a = ValueNode.fromJson("""{"active":true,"type":"nkFloat","float_val":3.14}""")
    b = ValueNode.fromJson("""{"float_al":3.14,"active":true,"type":"nkFloat"}""")
    c = ValueNode.fromJson("""{"type":"nkFloat","float_val":3.14,"active":true}""")
    d = ValueNode.fromJson("""{"active":true,"int_val":42}""")
  doAssert a.kind == nkFloat
  doAssert b.kind == nkFloat
  doAssert c.kind == nkFloat
  doAssert d.kind == nkInt
  doAssert ValueNode.fromJson(a.toJson()).kind == a.kind
  doAssert ValueNode.fromJson(b.toJson()).kind == b.kind
  doAssert ValueNode.fromJson(c.toJson()).kind == c.kind
  doAssert ValueNode.fromJson(d.toJson()).kind == d.kind

import std/json

# test https://forum.nim-lang.org/t/7619

type
  FooBar = object
    `Foo Bar` {.mapping: "Foo Bar".}: string

const jsonString = "{\"Foo Bar\": \"Hello World\"}"

doAssert FooBar.fromJson(jsonString).`Foo Bar` == "Hello World"
doAssert JsonNode.fromJson(jsonString) == %*{"Foo Bar": "Hello World"}
