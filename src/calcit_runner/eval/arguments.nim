
import strformat

import ternary_tree
import cirru_edn

import ../types
import ../data
import ../data/virtual_list
import ../util/errors

proc spreadArgs*(xs: seq[CirruData]): seq[CirruData] =
  var noSpread = true
  for x in xs:
    if x.kind == crDataSymbol and x.symbolVal == "&":
      noSpread = false
      break
  if noSpread:
    return xs

  var args: seq[CirruData]
  var spreadMode = false
  for x in xs:
    if spreadMode:
      if x.isList.not:
        raiseEvalError("Spread mode expects a list: " & $x, xs)
      for y in x:
        args.add y
      spreadMode = false
    elif x.isSymbol and x.symbolVal == "&":
      spreadMode = true
    else:
      args.add x
  args

proc spreadFuncArgs*(xs: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): seq[CirruData] =
  var noSpread = true
  for x in xs:
    if x.kind == crDataSymbol and x.symbolVal == "&":
      noSpread = false
      break
  if noSpread:
    var args = newSeq[CirruData](xs.len)
    for idx, x in xs:
      args[idx] = interpret(x, scope, ns)
    return args

  var args: seq[CirruData] = @[]
  var spreadMode = false
  for x in xs:
    if spreadMode:
      let ys = interpret(x, scope, ns)
      if not ys.isList:
        raiseEvalError("Spread mode expects a list", xs)
      for y in ys.listVal:
        args.add y
      spreadMode = false
    elif x.isSymbol and x.symbolVal == "&":
      spreadMode = true
    else:
      args.add interpret(x, scope, ns)
  args

proc processArguments*(definedArgs: CrVirtualList[CirruData], passedArgs: seq[CirruData]): CirruDataScope =
  var argsScope: CirruDataScope
  var splitPosition = -1
  var optionalPosition = -1

  for idx, item in definedArgs:
    if item.kind == crDataSymbol:
      if item.symbolVal == "&":
        if optionalPosition >= 0:
          raiseEvalError("already in optional args mode", definedArgs)
        splitPosition = idx
        break
      if item.symbolVal == "?":
        if splitPosition >= 0:
          raiseEvalError("already in spreading args mode", definedArgs)
        optionalPosition = idx
        break

  if splitPosition >= 0:
    if passedArgs.len < splitPosition:
      raiseEvalError("No enough arguments for:" & $CirruData(kind: crDataList, listVal: definedArgs), CirruData(kind: crDataList, listVal: definedArgs))
    if splitPosition != (definedArgs.len - 2):
      raiseEvalError("& should appear before last argument", CirruData(kind: crDataList, listVal: definedArgs))
    for idx in 0..<splitPosition:
      let definedArgName = definedArgs[idx]
      if definedArgName.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", definedArgName)
      argsScope = argsScope.assoc(definedArgName.symbolVal, passedArgs[idx])
    var varList = initCrVirtualList[CirruData](@[])
    for idx in splitPosition..<passedArgs.len:
      varList = varList.append passedArgs[idx]
    let varArgName = definedArgs[definedArgs.len - 1]
    if varArgName.kind != crDataSymbol:
      raiseEvalError("Expected var arg in symbol", varArgName)
    argsScope = argsScope.assoc(varArgName.symbolVal, CirruData(kind: crDataList, listVal: varList))
    return argsScope
  elif optionalPosition >= 0:
    if passedArgs.len < optionalPosition:
      raiseEvalError("No enough arguments for:" & $CirruData(kind: crDataList, listVal: definedArgs), definedArgs)
    if passedArgs.len > definedArgs.len - 1:
      raiseEvalError("Too many arguments for:" & $CirruData(kind: crDataList, listVal: definedArgs), definedArgs)
    for idx in 0..<optionalPosition:
      let definedArgName = definedArgs[idx]
      if definedArgName.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", definedArgName)
      argsScope = argsScope.assoc(definedArgName.symbolVal, passedArgs[idx])
    for idx in (optionalPosition + 1)..<definedArgs.len:
      let definedArgName = definedArgs[idx]
      if definedArgName.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", definedArgName)
      let pos = idx - 1
      if pos < passedArgs.len:
        argsScope = argsScope.assoc(definedArgName.symbolVal, passedArgs[pos])
      else:
        argsScope = argsScope.assoc(definedArgName.symbolVal, CirruData(kind: crDataNil))
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

proc evaluateMacroData*(macroValue: CirruData, args: seq[CirruData], interpret: FnInterpret, ns: string): CirruData =
  if macroValue.kind != crDataMacro: raiseEvalError("Expects a macro", macroValue)

  let emptyScope = CirruDataScope()
  let innerScope = emptyScope.merge(processArguments(macroValue.macroArgs, spreadArgs(args)))

  var quoted = CirruData(kind: crDataNil)
  for child in macroValue.macroCode:
    quoted = interpret(child, innerScope, macroValue.macroNs)

  while quoted.isRecur:
    let loopScope = emptyScope.merge(processArguments(macroValue.macroArgs, spreadArgs(quoted.recurArgs)))
    for child in macroValue.macroCode:
      quoted = interpret(child, loopScope, macroValue.macroNs)

  case quoted.kind
  of crDataList, crDataSymbol, crDataNumber, crDataString, crDataMap, crDataBool, crDataTernary, crDataKeyword, crDataNil:
    discard
  else:
    raiseEvalError("expects a list or a literal from defmacro, but got: " & $quoted.kind, quoted)

  return quoted
