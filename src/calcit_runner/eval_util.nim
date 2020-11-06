
import strformat

import ternary_tree
import cirru_edn

import ./types
import ./data
import ./errors

proc processArguments*(definedArgs: TernaryTreeList[CirruData], passedArgs: seq[CirruData]): CirruDataScope =
  var argsScope: CirruDataScope

  let splitPosition = definedArgs.findIndex(proc(item: CirruData): bool =
    item.kind == crDataSymbol and item.symbolVal == "&"
  )

  if splitPosition >= 0:
    if passedArgs.len < splitPosition:
      raiseEvalError("No enough arguments", CirruData(kind: crDataList, listVal: definedArgs))
    if splitPosition != (definedArgs.len - 2):
      raiseEvalError("& should appear before last argument", CirruData(kind: crDataList, listVal: definedArgs))
    for idx in 0..<splitPosition:
      let definedArgName = definedArgs[idx]
      if definedArgName.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", definedArgName)
      argsScope = argsScope.assoc(definedArgName.symbolVal, passedArgs[idx])
    var varList = initTernaryTreeList[CirruData](@[])
    for idx in splitPosition..<passedArgs.len:
      varList = varList.append passedArgs[idx]
    let varArgName = definedArgs[definedArgs.len - 1]
    if varArgName.kind != crDataSymbol:
      raiseEvalError("Expected var arg in symbol", varArgName)
    argsScope = argsScope.assoc(varArgName.symbolVal, CirruData(kind: crDataList, listVal: varList))
    return argsScope

  else:
    var counter = 0
    if definedArgs.len != passedArgs.len:
      raiseEvalError(fmt"Args length mismatch, defined:{definedArgs.len} passed:{passedArgs.len}", CirruData(kind: crDataList, listVal: definedArgs))
    definedArgs.each(proc(arg: CirruData): void =
      if arg.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", arg)
      argsScope = argsScope.assoc(arg.symbolVal, passedArgs[counter])
      counter += 1
    )
    return argsScope

proc evaluteFnData*(fnValue: CirruData, args: seq[CirruData], interpret: FnInterpret, ns: string): CirruData =
  if fnValue.kind != crDataFn: raiseEvalError("Expects a funtion", fnValue)

  let innerScope = fnValue.fnScope.merge(processArguments(fnValue.fnArgs, args))
  var ret = CirruData(kind: crDataNil)
  for child in fnValue.fnCode:
    ret = interpret(child, innerScope, fnValue.fnNs)

  while ret.isRecur:
    let loopScope = fnValue.fnScope.merge(processArguments(fnValue.fnArgs, ret.recurArgs))
    for child in fnValue.fnCode:
      ret = interpret(child, loopScope, fnValue.fnNs)

  return ret

proc evaluteMacroData*(macroValue: CirruData, args: seq[CirruData], interpret: FnInterpret, ns: string): CirruData =
  if macroValue.kind != crDataMacro: raiseEvalError("Expects a macro", macroValue)

  let emptyScope = CirruDataScope()
  let innerScope = emptyScope.merge(processArguments(macroValue.macroArgs, args))

  var quoted = CirruData(kind: crDataNil)
  for child in macroValue.macroCode:
    quoted = interpret(child, innerScope, macroValue.macroNs)

  while quoted.isRecur:
    let loopScope = emptyScope.merge(processArguments(macroValue.macroArgs, spreadArgs(quoted.recurArgs)))
    for child in macroValue.macroCode:
      quoted = interpret(child, loopScope, macroValue.macroNs)

  if quoted.isList.not and quoted.isRecur.not and quoted.isSymbol.not:
    raiseEvalError("Expected list or recur from defmacro", quoted)

  return quoted
