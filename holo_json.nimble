version     = "0.1.0"
author      = "Andre von Houck -> metagn"
description = "usable fork of jsony"
license     = "MIT"

srcDir = "src"

requires "nim >= 2.0.0"
requires "https://github.com/holo-nim/holo-flow#HEAD"
requires "https://github.com/holo-nim/cosm#HEAD"

task docs, "build docs for all modules":
  exec "nim r tasks/build_docs.nim"

task tests, "run tests for multiple backends and defines":
  exec "nim r tasks/run_tests.nim"
