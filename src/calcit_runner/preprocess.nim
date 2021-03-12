
import sets

import ternary_tree

import ./types
import ./data
import ./data/virtual_list
import ./util/errors

type
  FnPreprocess = proc(code: CirruData, localDefs: Hashset[string], ns: string): CirruData

proc processAll*(head: CirruData, args: seq[CirruData], localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  var ys = initCrVirtualList[CirruData](@[head])
  for item in args:
    ys = ys.append preprocess(item, localDefs, ns)
  return CirruData(kind: crDataList, listVal: ys)

proc processDefn*(head: CirruData, xs: seq[CirruData], localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if xs.len < 2:
    raiseEvalError("Expects len >=2 for defn", xs)

  var defName = xs[0]
  defName.resolved = ResolvedPath(kind: resolvedLocal)
  let args = xs[1]
  var ys = initCrVirtualList(@[head, defName, args])
  let body = xs[2..^1]

  var newDefs = localDefs
  if args.kind != crDataList:
    raiseEvalError("Expects a list", args)

  for item in args:
    if item.kind != crDataSymbol:
      raiseEvalError("Expects a symbol in defn:", xs)
    if item.symbolVal != "&":
      newDefs.incl(item.symbolVal)

  # echo "DEBUG"
  # echo CirruData(kind: crDataList, listVal: ys)
  # echo CirruData(kind: crDataList, listVal: body)

  for item in body:
    ys = ys.append preprocess(item, newDefs, ns)

  return CirruData(kind: crDataList, listVal: ys)

proc processNativeLet*(head: CirruData, args: seq[CirruData], localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if args.len < 2:
    raiseEvalError("Expected &let to take >=2 nodes", args)

  let pair = args[0]
  let body = args[1..^1]
  var newDefs = localDefs

  var ys = initCrVirtualList[CirruData](@[head])

  var bindingBuffer = initCrVirtualList[CirruData](@[])

  if pair.kind != crDataList:
    raiseEvalError("Expects a list in &let", pair)
  if pair.len != 2:
    raiseEvalError("Expects pair len =2 in &let", pair)

  var defName = pair[0]
  let detail = pair[1]

  let newPair = CirruData(kind: crDataList, listVal: initCrVirtualList(@[
    defName,
    preprocess(detail, newDefs, ns)
  ]))

  if defName.kind != crDataSymbol:
    raiseEvalError("Expects a symbol in &let:", args)
  if defName.symbolVal == "&":
    defName.resolved = ResolvedPath(kind: resolvedSyntax)
  else:
    defName.resolved = ResolvedPath(kind: resolvedLocal)
    newDefs.incl(defName.symbolVal)

  ys = ys.append newPair

  for item in body:
    ys = ys.append preprocess(item, newDefs, ns)

  return CirruData(kind: crDataList, listVal: ys)

proc processQuote*(head: CirruData, xs: seq[CirruData], localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if xs.len != 1:
    raiseEvalError("Expected quote to take 1 argument", xs)

  # quote just returns content, no need to preprocess
  # let body = xs.listVal[1]

  var detail = xs[0]
  return CirruData(kind: crDataList, listVal: initCrVirtualList[CirruData](@[
    head, detail
  ]))

proc processDefAtom*(head: CirruData, xs: seq[CirruData], localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if xs.len != 2:
    raiseEvalError("Expects 2 nodes for defatom", xs)

  var defName = xs[0]
  var ys = initCrVirtualList[CirruData](@[head, defName])
  ys = ys.append preprocess(xs[1], localDefs, ns)

  return CirruData(kind: crDataList, listVal: ys)
