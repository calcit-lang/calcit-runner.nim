
import tables
import json
import math
import strformat
import sequtils
import strutils
import options

import ternary_tree

import ./types
import ./data
import ./format
import ./helpers

proc nativeAdd(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native add")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for adding", a)
  if b.kind != crDataNumber: coreFnError("Required number for adding", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal + b.numberVal)

proc nativeMinus(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native minus")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for minus", a)
  if b.kind != crDataNumber: coreFnError("Required number for minus", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal - b.numberVal)

proc nativeMultiply(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native multiply")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for multiply", a)
  if b.kind != crDataNumber: coreFnError("Required number for multiply", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal * b.numberVal)

proc nativeDivide(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native divide")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for divide", a)
  if b.kind != crDataNumber: coreFnError("Required number for divide", b)
  if b.numberVal == 0.0: coreFnError("Cannot divide by 0", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))
  return CirruData(kind: crDataNumber, numberVal: a.numberVal / b.numberVal)

proc nativeLessThan(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native <")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for <", a)
  if b.kind != crDataNumber: coreFnError("Required number for <", b)
  return CirruData(kind: crDataBool, boolVal: a.numberVal < b.numberVal)

proc nativeGreaterThan(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native >")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for >", a)
  if b.kind != crDataNumber: coreFnError("Required number for >", b)
  return CirruData(kind: crDataBool, boolVal: a.numberVal > b.numberVal)

# should be working for all data types
proc nativeEqual(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native =")
  let a = args[0]
  let b = args[1]
  return CirruData(kind: crDataBool, boolVal: a == b)

proc nativeAnd(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native &and")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataBool: coreFnError("Required bool for &and", a)
  if b.kind != crDataBool: coreFnError("Required bool for &and", b)
  return CirruData(kind: crDataBool, boolVal: a.boolVal and b.boolVal)

proc nativeOr(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native &or")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataBool: coreFnError("Required bool for &or", a)
  if b.kind != crDataBool: coreFnError("Required bool for &or", b)
  return CirruData(kind: crDataBool, boolVal: a.boolVal or b.boolVal)

proc nativeNot(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: coreFnError("Expected 1 arguments in native not")
  let a = args[0]
  if a.kind != crDataBool: coreFnError("Required bool for not", a)
  return CirruData(kind: crDataBool, boolVal: not a.boolVal)

proc nativeCount(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: coreFnError("Expected 1 arguments in native count")
  let a = args[0]
  case a.kind
  of crDataNil:
    return CirruData(kind: crDataNumber, numberVal: 0.0)
  of crDataList:
    return CirruData(kind: crDataNumber, numberVal: a.len.float)
  of crDataMap:
    return CirruData(kind: crDataNumber, numberVal: a.len.float)
  else:
    raiseEvalError("Cannot count data", a)

proc nativeGet(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native get")
  let a = args[0]
  let b = args[1]
  case a.kind
  of crDataList:
    if b.kind != crDataNumber:
      raiseEvalError("Required number index for list", b)
    if b.numberVal.round.float != b.numberVal:
      raiseEvalError("Required round number index for list", b)
    if b.numberVal > a.len.float or b.numberVal < 0.float:
      return CirruData(kind: crDataNil)
    else:
      return a[b.numberVal.int]

  of crDataMap:
    let ret = b.mapVal[a]
    if ret.isNone:
      return CirruData(kind: crDataNil)
    else:
      return ret.get
  else:
    raiseEvalError("Cannot get from data of this type", a)

proc nativeRest(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: coreFnError("Expected 1 arguments in native rest")
  let a = args[0]
  case a.kind
  of crDataNil:
    return CirruData(kind: crDataNil)
  of crDataList:
    if a.len == 0:
      return CirruData(kind: crDataNil)
    return CirruData(kind: crDataList, listVal: a.listVal.rest)
  else:
    raiseEvalError("Cannot rest from data of this type", a)

proc nativeRaiseAt(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native raise-at")
  let a = args[0]
  let b = args[1]
  if b.kind != crDataString:
    raiseEvalError("Expect message in string", b)
  raiseEvalError(b.stringVal, a)

proc nativeTypeOf*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: coreFnError("type gets 1 argument")
  let v = interpret(args[0], scope)
  case v.kind
    of crDataNil: CirruData(kind: crDataKeyword, keywordVal: "nil")
    of crDataNumber: CirruData(kind: crDataKeyword, keywordVal: "int")
    of crDataString: CirruData(kind: crDataKeyword, keywordVal: "string")
    of crDataBool: CirruData(kind: crDataKeyword, keywordVal: "bool")
    of crDataMap: CirruData(kind: crDataKeyword, keywordVal: "table")
    of crDataFn: CirruData(kind: crDataKeyword, keywordVal: "fn")
    else: CirruData(kind: crDataKeyword, keywordVal: "unknown")

proc nativeReadFile*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("Required 1 argument for file name!", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let node = args[1]
  let fileName = interpret(node, scope)
  if fileName.kind != crDataString:
    raiseEvalError("Expected path name in string", node)
  let content = readFile(fileName.stringVal)
  return CirruData(kind: crDataString, stringVal: content)

proc nativeWriteFile*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("Required 2 arguments for writing a file", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let node = args[0]
  let fileName = interpret(node, scope)
  if fileName.kind != crDataString:
    raiseEvalError("Expected path name in string", node)
  let contentNode = args[1]
  let content = interpret(contentNode, scope)
  if content.kind != crDataSymbol:
    raiseEvalError("Expected content in string", contentNode)
  writeFile(fileName.stringVal, content.stringVal)

  dimEcho fmt"Wrote to file {fileName.stringVal}"
  return CirruData(kind: crDataNil)

proc nativeLoadJson*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("load-json requires relative path to json file", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let filePath = interpret(args[0], scope)
  if filePath.kind != crDataString:
    raiseEvalError("load-json requires path in string", args[0])
  let content = readFile(filePath.stringVal)
  try:
    let jsonData = parseJson(content)
    return jsonData.toCirruData()
  except JsonParsingError as e:
    echo "Failed to parse"
    raiseEvalError("Failed to parse file", args[0])

proc nativeMacroexpand*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("load-json requires relative path to json file", (args))

  let code = args[0]
  if notListData(code) or not checkExprStructure(code) or code.len == 0:
    raiseEvalError("Unexpected structure from macroexpand", code)

  let value = interpret(code[0], scope)
  if value.kind != crDataMacro:
    raiseEvalError("Expected a macro in the expression", code)
  let f = value.macroVal
  let quoted = f(code[1..^1], interpret, scope)
  return quoted

proc nativePrintln*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  echo args.map(`$`).join(" ")
  return CirruData(kind: crDataNil)

proc nativePrStr*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  echo args.map(proc (x: CirruData): string =
    if x.kind == crDataSymbol:
      return escape(x.symbolVal)
    else:
      return $x
  ).join(" ")
  return CirruData(kind: crDataNil)

proc nativePrepend*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("prepend requires 2 args", (args))
  let base = args[0]
  let item = args[1]
  if base.kind != crDataList:
    raiseEvalError("prepend requires a list", (args))
  return CirruData(kind: crDataList, listVal: base.listVal.prepend(item))

proc nativeAppend*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("append requires 2 args", (args))
  let base = args[0]
  let item = args[1]
  if base.kind != crDataList:
    raiseEvalError("append requires a list", (args))
  return CirruData(kind: crDataList, listVal: base.listVal.append(item))

proc nativeFirst*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("first requires 1 args", (args))
  let base = args[0]
  case base.kind
  of crDataNil:
    return base
  of crDataList:
    if base.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return base.listVal.first
  else:
    raiseEvalError("first requires a list", (args))

proc nativeLast*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("last requires 1 args", (args))
  let base = args[0]

  case base.kind
  of crDataNil:
    return base
  of crDataList:
    if base.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return base.listVal.last
  else:
    raiseEvalError("last requires a list", (args))

proc nativeButlast*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("butlast requires 1 args", (args))
  let base = args[0]
  case base.kind
  of crDataNil:
    return base
  of crDataList:
    if base.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return CirruData(kind: crDataList, listVal: base.listVal.butlast)
  else:
    raiseEvalError("butlast requires a list", (args))


# TODO keyword
# TODO symbol
# TODO type-of

# TODO load-cirru-edn

# TODO reduce-find

# injecting functions to calcit.core directly
proc loadCoreDefs*(programData: var Table[string, ProgramFile], interpret: EdnEvalFn): void =
  programData[coreNs].defs["&+"] = CirruData(kind: crDataFn, fnVal: nativeAdd, fnCode: fakeNativeCode("&+"))
  programData[coreNs].defs["&-"] = CirruData(kind: crDataFn, fnVal: nativeMinus, fnCode: fakeNativeCode("&-"))
  programData[coreNs].defs["&*"] = CirruData(kind: crDataFn, fnVal: nativeMultiply, fnCode: fakeNativeCode("&*"))
  programData[coreNs].defs["&/"] = CirruData(kind: crDataFn, fnVal: nativeDivide, fnCode: fakeNativeCode("&/"))
  programData[coreNs].defs["&<"] = CirruData(kind: crDataFn, fnVal: nativeLessThan, fnCode: fakeNativeCode("&<"))
  programData[coreNs].defs["&>"] = CirruData(kind: crDataFn, fnVal: nativeGreaterThan, fnCode: fakeNativeCode("&>"))
  programData[coreNs].defs["&="] = CirruData(kind: crDataFn, fnVal: nativeEqual, fnCode: fakeNativeCode("&="))
  programData[coreNs].defs["&and"] = CirruData(kind: crDataFn, fnVal: nativeAnd, fnCode: fakeNativeCode("&and"))
  programData[coreNs].defs["&or"] = CirruData(kind: crDataFn, fnVal: nativeOr, fnCode: fakeNativeCode("&or"))
  programData[coreNs].defs["not"] = CirruData(kind: crDataFn, fnVal: nativeNot, fnCode: fakeNativeCode("not"))
  programData[coreNs].defs["count"] = CirruData(kind: crDataFn, fnVal: nativeCount, fnCode: fakeNativeCode("count"))
  programData[coreNs].defs["get"] = CirruData(kind: crDataFn, fnVal: nativeGet, fnCode: fakeNativeCode("get"))
  programData[coreNs].defs["rest"] = CirruData(kind: crDataFn, fnVal: nativeRest, fnCode: fakeNativeCode("rest"))
  programData[coreNs].defs["raise-at"] = CirruData(kind: crDataFn, fnVal: nativeRaiseAt, fnCode: fakeNativeCode("raise-at"))
  programData[coreNs].defs["type-of"] = CirruData(kind: crDataFn, fnVal: nativeTypeOf, fnCode: fakeNativeCode("type-of"))
  programData[coreNs].defs["read-file"] = CirruData(kind: crDataFn, fnVal: nativeReadFile, fnCode: fakeNativeCode("read-file"))
  programData[coreNs].defs["write-file"] = CirruData(kind: crDataFn, fnVal: nativeWriteFile, fnCode: fakeNativeCode("write-file"))
  programData[coreNs].defs["load-json"] = CirruData(kind: crDataFn, fnVal: nativeLoadJson, fnCode: fakeNativeCode("load-json"))
  programData[coreNs].defs["macroexpand"] = CirruData(kind: crDataFn, fnVal: nativeMacroexpand, fnCode: fakeNativeCode("macroexpand"))
  programData[coreNs].defs["println"] = CirruData(kind: crDataFn, fnVal: nativePrintln, fnCode: fakeNativeCode("println"))
  programData[coreNs].defs["echo"] = CirruData(kind: crDataFn, fnVal: nativePrintln, fnCode: fakeNativeCode("echo"))
  programData[coreNs].defs["pr-str"] = CirruData(kind: crDataFn, fnVal: nativePrStr, fnCode: fakeNativeCode("pr-str"))
  programData[coreNs].defs["prepend"] = CirruData(kind: crDataFn, fnVal: nativePrepend, fnCode: fakeNativeCode("prepend"))
  programData[coreNs].defs["append"] = CirruData(kind: crDataFn, fnVal: nativeAppend, fnCode: fakeNativeCode("append"))
  programData[coreNs].defs["first"] = CirruData(kind: crDataFn, fnVal: nativeFirst, fnCode: fakeNativeCode("first"))
  programData[coreNs].defs["last"] = CirruData(kind: crDataFn, fnVal: nativeLast, fnCode: fakeNativeCode("last"))
  programData[coreNs].defs["butlast"] = CirruData(kind: crDataFn, fnVal: nativeButlast, fnCode: fakeNativeCode("butlast"))
