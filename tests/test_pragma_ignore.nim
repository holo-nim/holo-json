import holo_json

type
  Conn = object
    id: int
  Foo = object
    a: int
    password {.mapping: OutputFieldMapping(ignore: true).}: string
    b: float
    conn {.mapping: ignore().}: Conn

let v = Foo(a:1, password: "12345", b:0.6, conn: Conn(id: 1))
doAssert v.toJson() ==
  """{"a":1,"b":0.6}"""
doAssert Foo.fromJson("""{"a":2,"password":"45678","b":1.2}""") == Foo(a: 2, password: "45678", b: 1.2)
