import tables
import strutils
import sequtils
import sets
import options

import ./types

proc toString*(val: CirruData): string

proc fromArrayToString(children: seq[CirruData]): string =
  return "[" & children.mapIt(toString(it)).join(" ") & "]"

proc fromSeqToString(children: seq[CirruData]): string =
  return "(" & children.mapIt(toString(it)).join(" ") & ")"

proc fromSetToString(children: HashSet[CirruData]): string =
  return "#{" & children.mapIt(toString(it)).join(" ") & "}"

proc fromTableToString(children: Table[CirruData, CirruData]): string =
  let size = children.len()
  if size > 20:
    return "{...(20)...}"
  var tableStr = "{"
  var counted = 0
  for k, child in pairs(children):
    tableStr = tableStr & toString(k) & " " & toString(child)
    counted = counted + 1
    if counted < children.len:
      tableStr = tableStr & ", "
  tableStr = tableStr & "}"
  return tableStr

proc toString*(val: CirruData): string =
  case val.kind:
    of crDataBool:
      if val.boolVal:
        "true"
      else:
        "false"
    of crDataNumber: $(val.numberVal)
    of crDataString: val.stringVal
    of crDataVector: fromArrayToString(val.vectorVal)
    of crDataList: fromSeqToString(val.listVal)
    of crDataSet: fromSetToString(val.setVal)
    of crDataMap: fromTableToString(val.mapVal)
    of crDataNil: "nil"
    of crDataKeyword: ":" & val.keywordVal
    of crDataFn: "::fn"
    of crDataMacro: "::macro"
    of crDataSymbol:
      if val.scope.isSome:
        "scoped::" & val.ns & "/" & val.symbolVal
      else:
        val.ns & "/" & val.symbolVal

proc `$`*(v: CirruData): string =
  v.toString
