import holo_json

proc dump*(format: JsonOutputFormat, s: var HoloWriter, v: object) =
  s.write '{'
  var i = 0
  # Normal objects.
  for k, e in v.fieldPairs:
    when compiles(e != nil) and e isnot string:
      if e != nil:
        if i > 0:
          s.write ','
        format.dump(s, k)
        format.dump(s, e)
        inc i
    else:
      if i > 0:
        s.write ','
      format.dump(s, k)
      format.dump(s, e)
      inc i
  s.write '}'

type
  Foo = ref object
    count: int

  Bar = object
    id: string
    something: Foo

var
  foo1 = Bar(
    id: "123",
    something: Foo(count: 1)
  )
  foo2 = Bar(
    id: "456",
    something: nil
  )

echo foo1.toJson()
echo foo2.toJson()
