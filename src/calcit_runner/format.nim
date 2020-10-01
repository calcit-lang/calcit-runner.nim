import math
import strutils
import sequtils
import sets
import options

import ternary_tree

import ./types

proc toString*(val: CirruData, details: bool = false): string

proc fromListToString(children: seq[CirruData]): string =
  return "(" & children.mapIt(toString(it)).join(" ") & ")"

proc fromSetToString(children: HashSet[CirruData]): string =
  return "#{" & children.mapIt(toString(it)).join(" ") & "}"

proc fromMapToString(children: TernaryTreeMap[CirruData, CirruData]): string =
  let size = children.len()
  if size > 100:
    return "{...(100)...}"
  var tableStr = "{"
  var counted = 0
  for k, child in pairs(children):
    tableStr = tableStr & toString(k) & " " & toString(child)
    counted = counted + 1
    if counted < children.len:
      tableStr = tableStr & ", "
  tableStr = tableStr & "}"
  return tableStr

proc escapeString(x: string): string =
  if x.contains("\"") or x.contains(' '):
    escape(x)
  else:
    x

proc toString*(val: CirruData, details: bool = false): string =
  case val.kind:
    of crDataBool:
      if val.boolVal:
        "true"
      else:
        "false"
    of crDataNumber:
      if val.numberVal.trunc == val.numberVal:
        $val.numberVal.int
      else:
        $(val.numberVal)
    of crDataString: val.stringVal
    of crDataList: fromListToString(val.listVal.toSeq)
    of crDataSet: fromSetToString(val.setVal)
    of crDataMap: fromMapToString(val.mapVal)
    of crDataNil: "nil"
    of crDataKeyword: ":" & val.keywordVal
    of crDataFn: "<Function>"
    of crDataMacro: "<Macro>"
    of crDataSyntax: "<Syntax>"
    of crDataSymbol:
      if details:
        if val.scope.isSome:
          "scoped::" & val.ns & "/" & escapeString(val.symbolVal)
        else:
          val.ns & "/" & escapeString(val.symbolVal)
      else:
        val.symbolVal

proc `$`*(v: CirruData): string =
  v.toString(false)

proc shortenCode*(code: string, n: int): string =
  if code.len > n:
    code[0..<n] & "..."
  else:
    code
