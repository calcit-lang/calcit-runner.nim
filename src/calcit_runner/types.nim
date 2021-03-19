
import tables
import options
import sets
import hashes
import sequtils
import strutils
import math
import strformat
import system

import ternary_tree
import dual_balanced_ternary

import ./data/virtual_list

proc loadKeyword*(content: string): string =
  return content

type ImportKind* = enum
  importNs, importDef
type ImportInfo* = object
  ns*: string
  nsInStr*: bool # js modules uses a string based path
  case kind*: ImportKind
  of importNs:
    discard
  of importDef:
    def*: string

type

  CirruDataScope* = TernaryTreeMap[string, CirruData]

  CirruDataKind* = enum
    crDataNil,
    crDataBool,
    crDataNumber,
    crDataString,
    crDataKeyword,
    crDataList,
    crDataSet,
    crDataMap,
    crDataProc,
    crDataFn,
    crDataMacro,
    crDataSymbol,
    crDataSyntax,
    crDataRecur,
    crDataAtom,
    crDataTernary,
    crDataThunk,
    crDataRecord,

  FnInterpret* = proc(expr: CirruData, scope: CirruDataScope, ns: string): CirruData

  FnInData* = proc(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData

  ResolvedPathKind* = enum
    notResolved,
    resolvedLocal,
    resolvedSyntax,
    resolvedDef,

  ResolvedPath* = object
    case kind*: ResolvedPathKind
    of notResolved: discard
    of resolvedLocal: discard
    of resolvedSyntax: discard
    of resolvedDef:
      def*: string
      ns*: string
      nsInStr*: bool

  CirruData* = object
    case kind*: CirruDataKind
    of crDataNil: discard
    of crDataBool: boolVal*: bool
    of crDataNumber: numberVal*: float
    of crDataString: stringVal*: string
    of crDataKeyword:
      # TODO Clojure reused memory of keywords, need something similar
      # `ref string` was used, but it breaks compiler and breaks js backend
      keywordVal*: string
    of crDataProc:
      procVal*: FnInData
    of crDataFn:
      fnName*: string
      fnScope*: CirruDataScope
      fnArgs*: CrVirtualList[CirruData]
      fnCode*: seq[CirruData]
      fnNs*: string
    of crDataMacro:
      macroName*: string
      macroArgs*: CrVirtualList[CirruData]
      macroCode*: seq[CirruData]
      macroNs*: string
    of crDataSyntax:
      syntaxVal*: FnInData
    of crDataList: listVal*: CrVirtualList[CirruData]
    of crDataSet: setVal*: HashSet[CirruData]
    of crDataMap: mapVal*: TernaryTreeMap[CirruData, CirruData]
    of crDataSymbol:
      symbolVal*: string
      ns*: string
      resolved*: ResolvedPath
    of crDataRecur:
      recurArgs*: seq[CirruData]
    of crDataAtom:
      atomNs*: string
      atomDef*: string
    of crDataTernary:
      ternaryVal*: DualBalancedTernary
    # in calcit, thunks are only used for top-left expressions,
    # to ensure the order of execution.
    # functions and macros should not be represented as thunks
    of crDataThunk:
      thunkCode*: ref CirruData
      thunkScope*: CirruDataScope
      thunkNs*: string
    of crDataRecord:
      recordName*: string
      recordFields*: seq[string]
      recordValues*: seq[CirruData]

  RefCirruData* = ref CirruData

type ProgramFile* = object
  ns*: Option[Table[string, ImportInfo]]
  defs*: Table[string, CirruData]
  states*: Table[string, CirruData]

type CodeConfigs* = object
  pkg*: string
  initFn*: string
  reloadFn*: string
  modules*: seq[string]

type FileSource* = object
  ns*: CirruData
  run*: CirruData
  defs*: Table[string, CirruData]

const coreNs* = "calcit.core"

# formatting for CirruData

# recursion
proc `$`*(xs: seq[CirruData]): string

proc toString*(val: CirruData, stringDetail: bool, symbolDetail: bool): string

proc fromListToString(children: seq[CirruData], symbolDetail: bool): string =
  return "([] " & children.mapIt(toString(it, true, symbolDetail)).join(" ") & ")"

proc fromSetToString(children: HashSet[CirruData], symbolDetail: bool): string =
  return "(#{} " & children.mapIt(toString(it, true, symbolDetail)).join(" ") & ")"

proc fromMapToString(children: TernaryTreeMap[CirruData, CirruData], symbolDetail: bool): string =
  let size = children.len()
  if size > 100:
    return "({} 100+...)"
  var tableStr = "({}"
  for k, child in pairs(children):
    tableStr = tableStr & " (" &
               toString(k, true, symbolDetail) & " " &
               toString(child, true, symbolDetail) & ")"
  return tableStr & ")"

proc fromRecordToString(name: string, fields: seq[string], values: seq[CirruData], symbolDetail: bool): string =
  result = "(%{} " & name
  for idx, fieldName in fields:
    result &= " (" & fieldName & " " & toString(values[idx], true, symbolDetail) & ")"
  result &= ")"

# based on https://github.com/nim-lang/Nim/blob/version-1-4/lib/pure/strutils.nim#L2322
# strutils.escape turns Chinese into longer something "\xE6\xB1\x89",
# so... this is a simplified one according to Cirru Parser
proc escapeCirruStr*(s: string, prefix = "\"", suffix = "\""): string =
  result = newStringOfCap(s.len + s.len shr 2)
  result.add(prefix)
  for c in items(s):
    case c
    # disabled since not sure if useful for Cirru
    # of '\0'..'\31', '\127'..'\255':
    #   add(result, "\\x")
    #   add(result, toHex(ord(c), 2))
    of '\\': add(result, "\\\\")
    of '\"': add(result, "\\\"")
    of '\n': add(result, "\\n")
    of '\t': add(result, "\\t")
    else: add(result, c)
  add(result, suffix)

proc escapeString(x: string): string =
  if x.contains("\"") or x.contains(' ') or x.contains('(') or x.contains(')'):
    escapeCirruStr("|" & x)
  else:
    "|" & x

proc toString*(val: CirruData, stringDetail: bool, symbolDetail: bool): string =
  case val.kind:
    of crDataBool:
      if val.boolVal:
        "true"
      else:
        "false"
    of crDataNumber:
      if val.numberVal.trunc == val.numberVal:
        $(val.numberVal.int)
      else:
        $(val.numberVal)
    of crDataString:
      if stringDetail:
        val.stringVal.escapeString
      else:
        val.stringVal
    of crDataList: fromListToString(val.listVal.toSeq, symbolDetail)
    of crDataSet: fromSetToString(val.setVal, symbolDetail)
    of crDataMap: fromMapToString(val.mapVal, symbolDetail)
    of crDataRecord: fromRecordToString(val.recordName, val.recordFields, val.recordValues, symbolDetail)
    of crDataNil: "nil"
    of crDataKeyword: ":" & val.keywordVal
    of crDataProc: "(:&proc)"
    of crDataFn:
      "(:&function " & val.fnName & " " & $val.fnArgs.toSeq & " " & $val.fnCode & ")"
    of crDataMacro:
      "(:&macro " & val.macroName & " " & $val.macroArgs.toSeq & " " & $val.macroCode & ")"
    of crDataSyntax: "(:&syntax)"
    of crDataRecur:
      let content = val.recurArgs.mapIt(it.toString(stringDetail, symbolDetail)).join(" ")
      "(:&recur " & content & " )"
    of crDataSymbol:
      if symbolDetail:
        val.ns & "/" & escapeString(val.symbolVal)
      else:
        val.symbolVal
    of crDataAtom:
      "(&atom " & val.atomNs & "/" & val.atomDef & " )"
    of crDataTernary:
      $val.ternaryVal
    of crDataThunk:
      "(:&thunk " & $val.thunkCode[] & ")"

proc `$`*(v: CirruData): string =
  v.toString(false, false)

proc toString*(children: CirruDataScope): string =
  let size = children.len()
  if size > 100:
    return "{...(100)...}"
  var tableStr = "{"
  var counted = 0
  for k, child in pairs(children):
    tableStr = tableStr & k & " " & $child
    counted = counted + 1
    if counted < children.len:
      tableStr = tableStr & ", "
  tableStr = tableStr & "}"
  return tableStr

proc `$`*(children: CirruDataScope): string =
  children.toString

proc `$`*(xs: seq[CirruData]): string =
  return "(:&seq " & xs.map(`$`).join(" ") & ")"

# mutual recursion
proc hash*(value: CirruData): Hash

proc hash*[T](scope: CrVirtualList[T]): Hash =
  result = hash("virtual-list:")
  for item in scope:
    result = result !& hash(item)
  return result

proc hash*(scope: CirruDataScope): Hash =
  result = hash("scope:")
  for k, v in scope:
    result = result !& hash(k)
    result = result !& hash(v)
  return result

proc hash*(value: CirruData): Hash =
  case value.kind
    of crDataNumber:
      return hash("number:" & $value.numberVal)
    of crDataString:
      return hash("string:" & value.stringVal)
    of crDataNil:
      return hash("nil:")
    of crDataBool:
      return hash("bool:" & $(value.boolVal))
    of crDataKeyword:
      return hash("keyword:" & value.keywordVal)
    of crDataProc:
      result = hash("proc:")
      result = result !& hash(value.procVal)
      result = !$ result
    of crDataFn:
      result = hash("fn:")
      result = result !& hash(value.fnArgs)
      result = result !& hash(value.fnCode)
      result = result !& hash(value.fnScope)
      result = !$ result
    of crDataSyntax:
      result = hash("syntax:")
      result = result !& hash(value.syntaxVal)
      result = !$ result
    of crDataMacro:
      result = hash("macro:")
      result = result !& hash(value.macroArgs)
      result = result !& hash(value.macroCode)
      result = !$ result
    of crDataList:
      result = hash("list:")
      for x in value.listVal:
        result = result !& hash(x)
      result = !$ result
    of crDataSet:
      result = hash("set:")
      for x in value.setVal.items:
        result = result !& hash(x)
      result = !$ result
    of crDataMap:
      result = hash("map:")
      for k, v in value.mapVal.pairs:
        result = result !& hash(k)
        result = result !& hash(v)
      result = !$ result

    of crDataRecord:
      result = hash("record:")
      for idx, field in value.recordFields:
        result = result !& hash(field)
        result = result !& hash(value.recordValues[idx])
      result = !$ result

    of crDataSymbol:
      result = hash("symbol:")
      result = result !& hash(value.symbolVal)
      result = !$ result
    of crDataRecur:
      result = hash("recur:")
      result = result !& hash(value.recurArgs)
      result = !$ result

    of crDataAtom:
      result = hash("atom:")
      result = result !& hash(value.atomNs)
      result = result !& hash(value.atomDef)
      result = !$ result

    of crDataTernary:
      result = hash("ternary:")
      result = result !& hash(value.ternaryVal)
      result = !$ result

    of crDataThunk:
      result = hash("thunk:")
      result = result !& hash(value.thunkCode[])
      result = result !& hash(value.ns)
      # TODO skipped scope of thunk
      result = !$ result

proc `==`*(x, y: CirruData): bool =
  if x.kind != y.kind:
    return false
  else:
    case x.kind:
    of crDataNil:
      return true
    of crDataBool:
      return x.boolVal == y.boolVal
    of crDataString:
      return x.stringVal == y.stringVal
    of crDataNumber:
      return x.numberVal == y.numberVal
    of crDataKeyword:
      return x.keywordVal == y.keywordVal
    of crDataProc:
      return x.procVal == y.procVal
    of crDataFn:
      return x.fnArgs == y.fnArgs and x.fnCode == y.fnCode and x.fnScope == y.fnScope
    of crDataMacro:
      return x.macroArgs == y.macroArgs and x.macroCode == y.macroCode
    of crDataSyntax:
      return x.syntaxVal == y.syntaxVal

    of crDataList:
      if x.listVal.len != y.listVal.len:
        return false

      for idx, xi in x.listVal:
        if xi != y.listVal[idx]:
          return false
      return true

    of crDataSet:
      if x.setVal.len != y.setVal.len:
        return false

      for xi in x.setVal.items:
        if not y.setVal.contains(xi):
          return false
      return true

    of crDataMap:
      if x.mapVal.len != y.mapVal.len:
        return false

      for k, v in x.mapVal.pairs:
        if y.mapVal.loopGetDefault(k, CirruData(kind: crDataNil)) != v:
          return false

      return true

    of crDataRecord:
      if x.recordName != y.recordName:
        return false
      if x.recordFields.len != y.recordFields.len:
        return false
      for idx, field in x.recordFields:
        if field != y.recordFields[idx]:
          return false
        if x.recordValues[idx] != y.recordValues[idx]:
          return false
      return true

    of crDataSymbol:
      # TODO, ns not compared, not decided
      return x.symbolVal == y.symbolVal

    of crDataRecur:
      return x.recurArgs == y.recurArgs

    of crDataAtom:
      return x.atomNs == y.atomNs and x.atomDef == y.atomDef

    of crDataTernary:
      return x.ternaryVal == y.ternaryVal

    of crDataThunk:
      return x.thunkCode == y.thunkCode and x.thunkNs == y.thunkNs
