import holo_json

doAssertRaises(JsonValueError):
  discard "{invalid".fromJson()

doAssertRaises(JsonValueError):
  discard "{a:}".fromJson()

doAssertRaises(JsonValueError):
  discard "1.23.23".fromJson()
