when (NimMajor, NimMinor) >= (1, 4):
  when (compiles do: import nimbleutils):
    import nimbleutils
    # https://github.com/metagn/nimbleutils

when not declared(runTests):
  {.error: "tests task not implemented, need nimbleutils".}

# run from project root
if not defined(runBench):
  runTests(
    backends = {c, js, nims},
    recursiveDir = true
  )

block bench:
  let base = "-d:release"
  var combos = @[
    base,
    base & " -d:holoJsonReaderImpl=view",
    base & " -d:holoJsonReaderImpl=tracked-load",
    base & " -d:holoJsonReaderImpl=tracked-view"
  ]
  if defined(runBench):
    if not defined(runBenchJs):
      var refcCombos = combos
      for opt in refcCombos.mitems: opt.add " --mm:refc"
      var arcCombos = combos
      for opt in arcCombos.mitems: opt.add " --mm:arc"
      combos.add refcCombos
      combos.add arcCombos
  else:
    var withExperimentalViews = combos
    for opt in withExperimentalViews.mitems: opt.add " --experimental:views"
    combos.add withExperimentalViews
  let command =
    if defined(runBench): ""
    else: "check"
  let backends =
    if defined(runBenchJs): {js}
    elif defined(runBench): {c}
    else: {c, js}
  runTests(
    @["tests/jsony_original/bench.nim", "tests/jsony_original/bench_parts.nim"],
    subcommand = command,
    backends = backends,
    optionCombos = combos
  )
