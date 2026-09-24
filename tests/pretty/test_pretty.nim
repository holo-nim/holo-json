import holo_json, std/[math, json]

type
  Foo = object
    a: int
    b: float
    c: array[3, string]
    d: seq[Foo]

let testObj = Foo(a: 123, b: 4.56, c: ["a b c", "def", "g\nh\ni"], d: @[
  Foo(a: -1, b: NaN, c: ["", "\r\n  ", "\n\n\n"], d: @[
    Foo(a: 0, b: 0, c: ["", "", ""], d: @[])]),
  Foo(a: high(int), b: high(float), c: ["!#$", "'^+", "%&/"])])

let ser1 = toJson(testObj, JsonDumpFormat(pretty: true))
doAssert ser1 == """{
  "a": 123,
  "b": 4.56,
  "c": [
    "a b c",
    "def",
    "g\nh\ni"
  ],
  "d": [
    {
      "a": -1,
      "b": "nan",
      "c": [
        "",
        "\r\n  ",
        "\n\n\n"
      ],
      "d": [
        {
          "a": 0,
          "b": 0.0,
          "c": [
            "",
            "",
            ""
          ],
          "d": []
        }
      ]
    },
    {
      "a": 9223372036854775807,
      "b": "inf",
      "c": [
        "!#$",
        "'^+",
        "%&/"
      ],
      "d": []
    }
  ]
}"""

# deserializes:
proc `==`(a, b: Foo): bool {.noSideEffect.} =
  a.a == b.a and ((isNan(a.b) and isNan(b.b)) or a.b == b.b) and a.c == b.c and a.d == b.d
let deser1 = fromJsonAs(ser1, Foo)
doAssert testObj == deser1
let ser2 = toJson(deser1, JsonDumpFormat(pretty: true))
doAssert ser1 == ser2

# JsonNode round trip works (string comparison depends on order though):
let deserNode = fromJsonAs(ser1, JsonNode)
let serNode = toJson(deserNode, JsonDumpFormat(pretty: true))
doAssert ser1 == serNode
let deserNode2 = fromJsonAs(serNode, JsonNode)
doAssert deserNode == deserNode2
