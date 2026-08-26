import holo_json

doAssertRaises(JsonParseError):
  discard "{invalid".fromJsonAs()

doAssertRaises(JsonParseError):
  discard "{a:}".fromJsonAs()

doAssertRaises(JsonParseError):
  discard "1.23.23".fromJsonAs()
