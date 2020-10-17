
import sets

import ternary_tree

import ./types
import ./data
import ./helpers
# import ./format

type
  FnPreprocess = proc(code: CirruData, localDefs: Hashset[string]): CirruData

proc processAll*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len < 1:
    raiseEvalError("Expects len >1", xs)

  let head = xs[0]
  let body = xs.listVal.rest()

  var ys = initTernaryTreeList[CirruData](@[head])
  for item in body:
    ys = ys.append preprocess(item, localDefs)
  return CirruData(kind: crDataList, listVal: ys)

proc processMap*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len < 1:
    raiseEvalError("Expects len >1", xs)

  let head = xs[0]
  let body = xs.listVal.rest()

  var ys = initTernaryTreeList[CirruData](@[head])
  for pair in body:
    if pair.kind != crDataList:
      raiseEvalError("Expects a list", xs)
    if pair.len != 2:
      raiseEvalError("Expects len of 2", pair)

    let newPair = CirruData(kind: crDataList, listVal: initTernaryTreeList(@[
      preprocess(pair[0], localDefs),
      preprocess(pair[1], localDefs),
    ]))
    ys = ys.append newPair

  return CirruData(kind: crDataList, listVal: ys)

proc processDefn*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len <= 3:
    raiseEvalError("Expects len >3", xs)

  var ys = xs.listVal.slice(0,3)
  let args = xs[2]
  let body = xs.listVal.slice(3, xs.len)

  var newDefs = localDefs
  if args.kind != crDataList:
    raiseEvalError("Expects a list", args)

  for item in args:
    if item.kind != crDataSymbol:
      raiseEvalError("Expects a symbol", item)
    if item.symbolVal != "&":
      newDefs.incl(item.symbolVal)

  # echo "DEBUG"
  # echo CirruData(kind: crDataList, listVal: ys)
  # echo CirruData(kind: crDataList, listVal: body)

  for item in body:
    ys = ys.append preprocess(item, newDefs)

  return CirruData(kind: crDataList, listVal: ys)

proc processFn*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len < 3:
    raiseEvalError("Expects len >=3", xs)

  var ys = xs.listVal.slice(0,2)
  let args = xs[1]
  let body = xs.listVal.slice(2, xs.len)

  # echo "DEBUG"
  # echo CirruData(kind: crDataList, listVal: ys)
  # echo CirruData(kind: crDataList, listVal: body)

  var newDefs = localDefs
  if args.kind != crDataList:
    raiseEvalError("Expects a list", args)

  for item in args:
    if item.kind != crDataSymbol:
      raiseEvalError("Expects a symbol", item)
    if item.symbolVal != "&":
      newDefs.incl(item.symbolVal)

  for item in body:
    ys = ys.append preprocess(item, newDefs)

  return CirruData(kind: crDataList, listVal: ys)

proc processBinding*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len < 3:
    raiseEvalError("Expects len >=3", xs)

  let head = xs[0]
  let bindings = xs[1]
  let body = xs.listVal.slice(2, xs.len)
  var newDefs = localDefs

  var ys = initTernaryTreeList[CirruData](@[head])

  var bindingBuffer = initTernaryTreeList[CirruData](@[])
  if bindings.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  for pair in bindings.listVal:
    if pair.kind != crDataList:
      raiseEvalError("Expects a list", pair)
    if pair.len != 2:
      raiseEvalError("Expects len =2", pair)

    let defName = pair[0]
    let detail = pair[1]

    let newPair = CirruData(kind: crDataList, listVal: initTernaryTreeList(@[
      defName,
      preprocess(detail, newDefs)
    ]))

    if defName.kind != crDataSymbol:
      raiseEvalError("Expects a symbol", defName)

    if defName.symbolVal != "&":
      newDefs.incl(defName.symbolVal)

    bindingBuffer = bindingBuffer.append newPair

  ys = ys.append CirruData(kind: crDataList, listVal: bindingBuffer)

  for item in body:
    ys = ys.append preprocess(item, newDefs)

  return CirruData(kind: crDataList, listVal: ys)

proc processQuote*(xs: CirruData, localDefs: Hashset[string], preprocess: FnPreprocess): CirruData =
  if xs.kind != crDataList:
    raiseEvalError("Expects a list", xs)
  if xs.len < 1:
    raiseEvalError("Expects len >1", xs)

  let body = xs.listVal.rest()

  for item in body:
    discard preprocess(item, localDefs)

  xs
