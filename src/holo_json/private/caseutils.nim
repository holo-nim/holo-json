import std/strutils

proc snakeCaseDynamic*(s: string): string =
  # originally written by treeform in jsony https://github.com/treeform/jsony
  if s.len == 0:
    return
  var prevCap = false
  for i, c in s:
    if c in {'A'..'Z'}:
      if result.len > 0 and result[result.len-1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
      result.add c.toLowerAscii()
    else:
      prevCap = false
      result.add c
