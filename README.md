# holo-json

JSON library based on the codebase and structure of [jsony](https://github.com/treeform/jsony) by [treeform](https://github.com/treeform), overhauled for better usability in applications. I am not keen on licenses so if I am missing any credit anywhere for forking jsony I am willing to fix it.

Currently about 2x slower than original jsony, presumably due to the level of abstraction but I can't pinpoint why. (double pointer dereference for reading?) Still faster than the other libraries in the benchmarks though.

Not compatible with jsony's parsing/conversion behavior.

## Differences with jsony


