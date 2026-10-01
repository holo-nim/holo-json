import holo_json, std/[tables, hashes, json]

type Foo = distinct string
proc hash*(s: Foo): Hash {.borrow.}
proc `==`*(a, b: Foo): bool {.borrow.}
proc `$`*(s: Foo): string {.borrow.}

let tab = toTable {Foo"abc": 123, Foo"def": 456}
doAssert JsonNode.fromJson(toJson(tab)) == %*{"abc": 123, "def": 456}
