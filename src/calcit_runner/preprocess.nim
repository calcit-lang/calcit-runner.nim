
import sets

import ternary_tree

import ./types
import ./data
import ./util/errors

type
  FnPreprocess = proc(code: CirruData, localDefs: Hashset[string], ns: string): CirruData

proc processAll*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len < 1:
    raiseEvalError("Expects len >1", xs)

  let head = xs[0]
  let body = xs.listVal.rest()

  var ys = initTernaryTreeList[CirruData](@[head])
  for item in body:
    ys = ys.append preprocess(item, localDefs, ns)
  return CirruData(kind: crDataList, listVal: ys)

proc processDefn*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len <= 3:
    raiseEvalError("Expects len >3 for defn", xs)

  var ys = xs.listVal.slice(0,3)
  let args = xs[2]
  let body = xs.listVal.slice(3, xs.len)

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

proc processNativeLet*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len < 3:
    raiseEvalError("Expects len >=3", xs)

  let head = xs[0]
  let pair = xs[1]
  let body = xs.listVal.slice(2, xs.len)
  var newDefs = localDefs

  var ys = initTernaryTreeList[CirruData](@[head])

  var bindingBuffer = initTernaryTreeList[CirruData](@[])

  if pair.kind != crDataList:
    raiseEvalError("Expects a list in &let", pair)
  if pair.len != 2:
    raiseEvalError("Expects pair len =2 in &let", pair)

  let defName = pair[0]
  let detail = pair[1]

  let newPair = CirruData(kind: crDataList, listVal: initTernaryTreeList(@[
    defName,
    preprocess(detail, newDefs, ns)
  ]))

  if defName.kind != crDataSymbol:
    raiseEvalError("Expects a symbol in &let:", xs)

  if defName.symbolVal != "&":
    newDefs.incl(defName.symbolVal)

  ys = ys.append newPair

  for item in body:
    ys = ys.append preprocess(item, newDefs, ns)

  return CirruData(kind: crDataList, listVal: ys)

proc processQuote*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len < 1:
    raiseEvalError("Expects len >1", xs)

  let body = xs.listVal.rest()

  for item in body:
    discard preprocess(item, localDefs, ns)

  xs

proc processDefAtom*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess, ns: string): CirruData =
  if xs.kind != crDataList or xs.listVal.len != 3:
    raiseEvalError("Expects a list of 3 for defatom", xs)

  var ys = xs.listVal.slice(0,2)
  ys = ys.append preprocess(xs.listVal[2], localDefs, ns)

  return CirruData(kind: crDataList, listVal: ys)
