version     = "0.1.0"
author      = "Andre von Houck -> metagn"
description = "fork of jsony adapted to holo-flow"
license     = "MIT"

srcDir = "src"

requires "nim >= 2.0.0"
requires "https://github.com/holo-nim/holo-flow#HEAD"

when (NimMajor, NimMinor) >= (1, 4):
  when (compiles do: import nimbleutils):
    import nimbleutils
    # https://github.com/metagn/nimbleutils

task docs, "build docs for all modules":
  when declared(buildDocs):
    buildDocs(gitUrl = "https://github.com/holo-nim/holo-json")
  else:
    echo "docs task not implemented, need nimbleutils"

task tests, "run tests for multiple backends and defines":
  when declared(runTests):
    runTests(
      backends = {c, js, nims},
      recursiveDir = true
    )
  else:
    echo "tests task not implemented, need nimbleutils"
