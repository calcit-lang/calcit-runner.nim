
import strformat
import system
import tables
import hashes
import options

import ternary_tree

import ./data
import ./types
import ./errors
import ./gen_code
import ./atoms

proc nativeList(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  var args = initTernaryTreeList[CirruData](@[])
  for node in exprList:
    # commas in body are considered as nothing
    if node.kind == crDataSymbol and node.symbolVal == ",":
      continue
    args = args.append interpret(node, scope, ns)
  return CirruData(kind: crDataList, listVal: args)

proc nativeIf*(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if (exprList.len < 2):
    raiseEvalError(fmt"No arguments for if", exprList)
  elif (exprList.len == 2):
    let node = exprList[0]
    let cond = interpret(node, scope, ns)
    if cond.kind == crDataBool:
      if cond.boolVal:
        return interpret(exprList[1], scope, ns)
      else:
        return CirruData(kind: crDataNil)
    else:
      raiseEvalError("Not a bool in if", node)
  elif (exprList.len == 3):
    let node = exprList[0]
    let cond = interpret(node, scope, ns)
    if cond.kind == crDataBool:
      if cond.boolVal:
        return interpret(exprList[1], scope, ns)
      else:
        return interpret(exprList[2], scope, ns)
    else:
      raiseEvalError("Not a bool in if", node)
  else:
    raiseEvalError("Too many arguments for if", exprList)

proc nativeComment(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  return CirruData(kind: crDataNil)

proc nativeDefn(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if exprList.len < 2: raiseEvalError("Expects name and args for defn", exprList)
  let fnName = exprList[0]
  if fnName.kind != crDataSymbol: raiseEvalError("Expects fnName to be string", exprList)
  let argsList = exprList[1]
  if argsList.kind != crDataList: raiseEvalError("Expects args to be list", exprList)
  return CirruData(kind: crDataFn, fnNs: ns, fnName: fnName.symbolVal, fnArgs: argsList.listVal, fnCode: exprList[2..^1], fnScope: scope)

proc nativeLet(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  var letScope = scope
  if exprList.len < 1:
    raiseEvalError("No enough code for let, too short", exprList)
  let pairs = exprList[0]
  let body = exprList[1..^1]
  if pairs.kind != crDataList:
    raiseEvalError("Expect bindings in a list", pairs)
  for pair in pairs:
    if pair.kind != crDataList:
      raiseEvalError("Expect binding in a list", pair)
    if pair.len != 2:
      raiseEvalError("Expect binding in length 2", pair)
    let name = pair[0]
    let value = pair[1]
    if name.kind != crDataSymbol:
      raiseEvalError("Expecting binding name in string", name)
    letScope = letScope.assoc(name.symbolVal, interpret(value, letScope, ns))
  result = CirruData(kind: crDataNil)
  for child in body:
    result = interpret(child, letScope, ns)

proc nativeDo*(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  result = CirruData(kind: crDataNil)
  for child in exprList:
    result = interpret(child, scope, ns)

# TODO, symbols in macros refers to define scope
proc attachScope(exprList: CirruData, scope: CirruDataScope): CirruData =
  case exprList.kind
  of crDataSymbol:
    return CirruData(kind: crDataSymbol, symbolVal: exprList.symbolVal, ns: exprList.ns)
  of crDataList:
    var list = initTernaryTreeList[CirruData](@[])
    for item in exprList:
      list = list.append attachScope(item, scope)
    return CirruData(kind: crDataList, listVal: list)
  of crDataNil: return exprList
  of crDataBool: return exprList
  of crDataNumber: return exprList
  of crDataKeyword: return exprList
  of crDataString: return exprList
  else:
    raiseEvalError("Unexpected data for attaching", exprList)

proc nativeQuote(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if exprList.len != 1:
    raiseEvalError("quote expects 1 argument", exprList)
  let code = attachScope(exprList[0], scope)
  return code

proc replaceExpr(exprList: CirruData, interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  case exprList.kind
  of crDataSymbol: return exprList
  of crDataString: return exprList
  of crDataNumber: return exprList
  of crDataBool: return exprList
  of crDataKeyword: return exprList
  of crDataNil: return exprList
  of crDataList:
    if exprList.len == 0:
      return CirruData(kind: crDataList, listVal: initTernaryTreeList[CirruData](@[]))
    if exprList[0].isSymbol and exprList[0].symbolVal == "~":
      if exprList.len != 2:
        raiseEvalError "Expected 1 argument in ~ of quote-replace", exprList
      return interpret(exprList[1], scope, ns)

    var list = initTernaryTreeList[CirruData](@[])
    for item in exprList:
      if item.kind == crDataList:
        let head = item[0]
        if head.kind == crDataSymbol and head.symbolVal == "~":
          if item.len != 2:
            raiseEvalError "Expected 1 argument in ~ of quote-replace", item
          list = list.append interpret(item[1], scope, ns)
        elif head.kind == crDataSymbol and head.symbolVal == "~@":
          if item.len != 2:
            raiseEvalError "Expected 1 argument in ~@ of quote-replace", item
          let xs = interpret(item[1], scope, ns)
          if xs.kind != crDataList:
            raiseEvalError "Expected list for ~@ of quote-replace", xs
          for x in xs:
            list = list.append x
        else:
          list = list.append replaceExpr(item, interpret, scope, ns)
      else:
        list = list.append replaceExpr(item, interpret, scope, ns)
    return CirruData(kind: crDataList, listVal: list)
  else:
    raiseEvalError("Unknown data in expr", exprList)

proc nativeQuoteReplace(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if exprList.len != 1:
    raiseEvalError(fmt"quote-replace expects 1 argument, got {exprList.len}", exprList)

  let ret = replaceExpr(attachScope(exprList[0], scope), interpret, scope, ns)
  if not checkExprStructure(ret):
    raiseEvalError("Unexpected structure from quote-replace", ret)
  ret

proc nativeDefMacro(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  let macroName = exprList[0]
  if macroName.kind != crDataSymbol: raiseEvalError("Expects macro name a symbol", exprList)
  let argsList = exprList[1]
  if argsList.kind != crDataList: raiseEvalError("Expects macro args to be a list", exprList)
  return CirruData(kind: crDataMacro, macroName: macroName.symbolVal, macroArgs: argsList.listVal, macroCode: exprList[2..^1])

proc nativeAssert(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if exprList.len != 2:
    raiseEvalError("assert expects 2 arguments", exprList)
  let message = interpret(exprList[0], scope, ns)
  if message.kind != crDataString:
    raiseEvalError("Expected assert message in string", exprList[0])
  let target = interpret(exprList[1], scope, ns)
  if target.kind != crDataBool:
    raiseEvalError("Expected assert target in bool", exprList[1])
  if not target.boolVal:
    raiseEvalError(message.stringVal, exprList)

proc nativeDefAtom(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if exprList.len != 2:
    raiseEvalError("assert expects 2 arguments", exprList)
  let name = exprList[0]
  if name.kind != crDataSymbol: raiseEvalError("Expects a symbol for atom", exprList)
  let attempt = getAtomByPath(name.ns, name.symbolVal)
  if attempt.isNone:
    let value = interpret(exprList[1], scope, ns)
    setAtomByPath(name.ns, name.symbolVal, value)
  CirruData(kind: crDataAtom, atomNs: name.ns, atomDef: name.symbolVal)

proc loadCoreSyntax*(programData: var Table[string, ProgramFile], interpret: FnInterpret) =
  programData[coreNs].defs["[]"] = CirruData(kind: crDataSyntax, syntaxVal: nativeList)
  programData[coreNs].defs["assert"] = CirruData(kind: crDataSyntax, syntaxVal: nativeAssert)
  programData[coreNs].defs["quote-replace"] = CirruData(kind: crDataSyntax, syntaxVal: nativeQuoteReplace)
  programData[coreNs].defs["defmacro"] = CirruData(kind: crDataSyntax, syntaxVal: nativeDefMacro)
  programData[coreNs].defs[";"] = CirruData(kind: crDataSyntax, syntaxVal: nativeComment)
  programData[coreNs].defs["do"] = CirruData(kind: crDataSyntax, syntaxVal: nativeDo)
  programData[coreNs].defs["if"] = CirruData(kind: crDataSyntax, syntaxVal: nativeIf)
  programData[coreNs].defs["defn"] = CirruData(kind: crDataSyntax, syntaxVal: nativeDefn)
  programData[coreNs].defs["let"] = CirruData(kind: crDataSyntax, syntaxVal: nativeLet)
  programData[coreNs].defs["quote"] = CirruData(kind: crDataSyntax, syntaxVal: nativeQuote)
  programData[coreNs].defs["defatom"] = CirruData(kind: crDataSyntax, syntaxVal: nativeDefAtom)
