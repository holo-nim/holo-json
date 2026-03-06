import std/[macros, tables], ../common

proc realBasename(n: NimNode): string =
  var n = n
  if n.kind == nnkPragmaExpr: n = n[0]
  if n.kind == nnkPostfix: n = n[^1]
  result = $n

proc iterFieldNames(names: var seq[string], list: NimNode) =
  case list.kind
  of nnkRecList:
    for r in list:
      iterFieldNames(names, r)
  of nnkRecCase:
    iterFieldNames(names, list[0])
    for bi in 1 ..< list.len:
      expectKind list[bi], {nnkOfBranch, nnkElifBranch, nnkElse}
      iterFieldNames(names, list[bi][^1])
  of nnkRecWhen:
    for bi in 0 ..< list.len:
      expectKind list[bi], {nnkElifBranch, nnkElse}
      iterFieldNames(names, list[bi][^1])
  of nnkIdentDefs:
    for i in 0 ..< list.len - 2:
      let name = realBasename(list[i])
      if name notin names:
        names.add(name)
  of nnkSym:
    let name = $list
    names.add(name)
  of nnkDiscardStmt, nnkNilLit, nnkEmpty: discard
  else:
    error "unknown object field AST kind " & $list.kind, list

macro fieldOptionPairs*[T: object | ref object](obj: T): untyped =
  var names: seq[string] = @[]
  var t = obj
  while t != nil:
    var impl = getTypeImpl(t)
    while true:
      if impl.kind in {nnkRefTy, nnkPtrTy, nnkVarTy, nnkOutTy}:
        impl = getTypeImpl(impl[^1])
      elif impl.kind == nnkBracketExpr and impl[0].eqIdent"typeDesc":
        impl = getTypeImpl(impl[1])
      else:
        break
    if impl.kind != nnkObjectTy:
      error "got unknown object type kind " & $impl.kind, impl
    iterFieldNames(names, impl[^1])
    t = nil
    if impl[1].kind != nnkEmpty:
      expectKind impl[1], nnkOfInherit
      t = impl[1][0]
  result = newNimNode(nnkBracket, obj)
  var pragmaSym = bindSym("json")
  if pragmaSym.kind in {nnkOpenSymChoice, nnkClosedSymChoice}:
    for s in pragmaSym:
      let imp = getImpl(s)
      if imp != nil and imp.kind == nnkTemplateDef:
        pragmaSym = s
        break
  for name in names:
    let ident = ident(name)
    result.add(newTree(nnkTupleConstr,
      newLit(name),
      quote do:
        when hasCustomPragma(`obj`.`ident`, `pragmaSym`):
          toFieldOptions(getCustomPragmaVal(`obj`.`ident`, `pragmaSym`))
        else:
          FieldJsonOptions()))

macro fieldOptionTable*[T: object | ref object](obj: T): Table[string, FieldJsonOptions] =
  result = newCall(bindSym"toTable", getAst(fieldOptionPairs(obj)))

# XXX types could also define hooks for these too
