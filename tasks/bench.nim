when (NimMajor, NimMinor) >= (1, 4):
  when (compiles do: import nimbleutils):
    import nimbleutils
    # https://github.com/metagn/nimbleutils

when not declared(runTests):
  {.error: "bench task not implemented, need nimbleutils".}

# run from project root

type BenchKind = enum
  Check
  Run
  RunJs

proc bench(kind: BenchKind) =
  let base = "-d:release"
  var combos = @[
    base,
    base & " -d:holoJsonReaderImpl=view",
    base & " -d:holoJsonReaderImpl=tracked-load",
    base & " -d:holoJsonReaderImpl=tracked-view"
  ]
  case kind
  of Run:
    var refcCombos = @[combos[0]]
    for opt in refcCombos.mitems: opt.add " --mm:refc"
    var arcCombos = @[combos[0]]
    for opt in arcCombos.mitems: opt.add " --mm:arc"
    var memCombos = @[combos[0], combos[1]]
    for opt in memCombos.mitems: opt.add " -d:holoReaderPeekStrCopyMem -d:holoReaderMatchStrEqualMem"
    combos.add refcCombos
    combos.add arcCombos
  of RunJs: discard
  of Check:
    var withExperimentalViews = combos
    for opt in withExperimentalViews.mitems: opt.add " --experimental:views"
    combos.add withExperimentalViews
  let command =
    if kind == Check: "check"
    else: ""
  let backends =
    case kind
    of Check: {c, js}
    of RunJs: {js}
    of Run: {c}
  runTests(
    @["tests/jsony_original/bench.nim", "tests/jsony_original/bench_parts.nim"],
    subcommand = command,
    backends = backends,
    optionCombos = combos
  )

if defined(checkBench):
  bench(Check)
if defined(runBench):
  bench(Run)
if defined(runBenchJs):
  bench(RunJs)
