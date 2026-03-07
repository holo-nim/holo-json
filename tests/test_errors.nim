import holo_jsony

doAssertRaises(CatchableError):
  discard "{invalid".fromJson()

doAssertRaises(CatchableError):
  discard "{a:}".fromJson()

doAssertRaises(CatchableError):
  discard "1.23.23".fromJson()
