import holo_json

doAssertRaises(JsonParseError):
  discard "{invalid".fromJson()

doAssertRaises(JsonParseError):
  discard "{a:}".fromJson()

doAssertRaises(JsonParseError):
  discard "1.23.23".fromJson()
