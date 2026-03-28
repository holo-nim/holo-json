import holo_json, std/json

let j = """{
  "a": "b", // line comment ///// a a
  /* multiline
  comment */"c": /*between spaces /*/*nested*/*/*/5/* inline */ ,"d": true
}"""
doAssert j.fromJson(JsonNode) == %*{"a": "b", "c": 5, "d": true}
