
import ternary_tree

import ../types
import ../data
import ../data/virtual_list
import ../util/errors

proc checkExprStructure*(exprList: CirruData): bool =
  case exprList.kind
  of crDataSymbol: return true
  of crDataNumber: return true
  of crDataBool: return true
  of crDataNil: return true
  of crDataString: return true
  of crDataKeyword: return true
  of crDataTernary: return true
  of crDataList:
    for item in exprList:
      if not checkExprStructure(item):
        return false
    return true
  else:
    return false

# code of functions and macros
proc isADefinition*(code: CirruData): bool =
  if code.kind != crDataList:
    return false
  if code.listVal.len == 0:
    raiseEvalError("expects some code other than empty", code)
  if code.listVal[0].kind == crDataSymbol:
    let text = code.listVal[0].symbolVal
    if text == "defn" or text == "defmacro":
      return true
  return false

# for macros
proc replaceExpr*(exprList: CirruData, interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  case exprList.kind
  of crDataSymbol: return exprList
  of crDataString: return exprList
  of crDataNumber: return exprList
  of crDataTernary: return exprList
  of crDataBool: return exprList
  of crDataKeyword: return exprList
  of crDataNil: return exprList
  of crDataList:
    if exprList.len == 0:
      return CirruData(kind: crDataList, listVal: initCrVirtualList[CirruData](@[]))
    if exprList[0].isSymbol and exprList[0].symbolVal == "~":
      if exprList.len != 2:
        raiseEvalError "Expected 1 argument in ~ of quote-replace", exprList
      return interpret(exprList[1], scope, ns)

    var list = initCrVirtualList[CirruData](@[])
    for item in exprList:
      if item.kind == crDataList and item.listVal.len > 0:
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
