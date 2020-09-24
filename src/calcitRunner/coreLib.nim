
import tables
import json
import math
import strformat

import ./types
import ./data
import ./helpers

let coreNs* = "calcit.core"

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
  if b.numberVal == 0.0: coreFnError("Cannot divide by 0", CirruData(kind: crDataList, listVal: args))
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
  of crDataVector:
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
  of crDataList, crDataVector:
    if b.kind != crDataNumber:
      raiseEvalError("Required number index for list", b)
    if b.numberVal.round.float != b.numberVal:
      raiseEvalError("Required round number index for list", b)
    if b.numberVal > a.len.float or b.numberVal < 0.float:
      return CirruData(kind: crDataNil)
    else:
      return a[b.numberVal.int]

  of crDataMap:
    return b.mapVal[a]
  else:
    raiseEvalError("Cannot get from data of this type", a)

proc nativeRest(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: coreFnError("Expected 1 arguments in native rest")
  let a = args[0]
  case a.kind
  of crDataNil:
    return CirruData(kind: crDataNil)
  of crDataList, crDataVector:
    if a.len == 0:
      return CirruData(kind: crDataList, listVal: @[])
    return CirruData(kind: crDataList, listVal: a[1..^1])
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
    of crDataVector: CirruData(kind: crDataKeyword, keywordVal: "array")
    of crDataMap: CirruData(kind: crDataKeyword, keywordVal: "table")
    of crDataFn: CirruData(kind: crDataKeyword, keywordVal: "fn")
    else: CirruData(kind: crDataKeyword, keywordVal: "unknown")

proc nativeReadFile*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("Required 1 argument for file name!", CirruData(kind: crDataList, listVal: args))

  let node = args[1]
  let fileName = interpret(node, scope)
  if fileName.kind != crDataString:
    raiseEvalError("Expected path name in string", node)
  let content = readFile(fileName.stringVal)
  return CirruData(kind: crDataString, stringVal: content)

proc nativeWriteFile*(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("Required 2 arguments for writing a file", CirruData(kind: crDataList, listVal: args))

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
    raiseEvalError("load-json requires relative path to json file", CirruData(kind: crDataList, listVal: args))

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
    raiseEvalError("load-json requires relative path to json file", CirruData(kind: crDataList, listVal: args))

  let code = args[0]
  if notListData(code) or not checkExprStructure(code) or code.len == 0:
    raiseEvalError("Unexpected structure from macroexpand", code)

  let value = interpret(code[0], scope)
  if value.kind != crDataMacro:
    raiseEvalError("Expected a macro in the expression", code)
  let f = value.macroVal
  let quoted = f(code[1..^1], interpret, scope)
  return quoted


# TODO keyword
# TODO symbol

# TODO load edn

# TODO reduce-find


proc fakeNativeCode(info: string): RefCirruData =
  RefCirruData(kind: crDataList, listVal: @[
    CirruData(kind: crDataSymbol, symbolVal: "defnative", ns: coreNs),
    CirruData(kind: crDataSymbol, symbolVal: info, ns: coreNs),
    CirruData(kind: crDataSymbol, symbolVal: "__native_code__", ns: coreNs)
  ])

# injecting functions to calcit.core directly
proc loadCoreDefs*(programData: var Table[string, ProgramFile], programCode: var Table[string, FileSource], interpret: EdnEvalFn): void =
  var coreFile: ProgramFile
  var coreSource: FileSource
  let rootScope = CirruDataScope()

  coreFile.defs["&+"] = CirruData(kind: crDataFn, fnVal: nativeAdd, fnCode: fakeNativeCode("&+"))
  coreFile.defs["&-"] = CirruData(kind: crDataFn, fnVal: nativeMinus, fnCode: fakeNativeCode("&-"))
  coreFile.defs["&*"] = CirruData(kind: crDataFn, fnVal: nativeMultiply, fnCode: fakeNativeCode("&*"))
  coreFile.defs["&/"] = CirruData(kind: crDataFn, fnVal: nativeDivide, fnCode: fakeNativeCode("&/"))
  coreFile.defs["&<"] = CirruData(kind: crDataFn, fnVal: nativeLessThan, fnCode: fakeNativeCode("&<"))
  coreFile.defs["&>"] = CirruData(kind: crDataFn, fnVal: nativeGreaterThan, fnCode: fakeNativeCode("&>"))
  coreFile.defs["&="] = CirruData(kind: crDataFn, fnVal: nativeEqual, fnCode: fakeNativeCode("&="))
  coreFile.defs["&and"] = CirruData(kind: crDataFn, fnVal: nativeAnd, fnCode: fakeNativeCode("&and"))
  coreFile.defs["&or"] = CirruData(kind: crDataFn, fnVal: nativeOr, fnCode: fakeNativeCode("&or"))
  coreFile.defs["not"] = CirruData(kind: crDataFn, fnVal: nativeNot, fnCode: fakeNativeCode("not"))
  coreFile.defs["count"] = CirruData(kind: crDataFn, fnVal: nativeCount, fnCode: fakeNativeCode("count"))
  coreFile.defs["get"] = CirruData(kind: crDataFn, fnVal: nativeGet, fnCode: fakeNativeCode("get"))
  coreFile.defs["rest"] = CirruData(kind: crDataFn, fnVal: nativeRest, fnCode: fakeNativeCode("rest"))
  coreFile.defs["raise-at"] = CirruData(kind: crDataFn, fnVal: nativeRaiseAt, fnCode: fakeNativeCode("raise-at"))
  coreFile.defs["type-of"] = CirruData(kind: crDataFn, fnVal: nativeTypeOf, fnCode: fakeNativeCode("type-of"))
  coreFile.defs["read-file"] = CirruData(kind: crDataFn, fnVal: nativeReadFile, fnCode: fakeNativeCode("read-file"))
  coreFile.defs["write-file"] = CirruData(kind: crDataFn, fnVal: nativeWriteFile, fnCode: fakeNativeCode("write-file"))
  coreFile.defs["load-json"] = CirruData(kind: crDataFn, fnVal: nativeLoadJson, fnCode: fakeNativeCode("load-json"))
  coreFile.defs["macroexpand"] = CirruData(kind: crDataFn, fnVal: nativeMacroexpand, fnCode: fakeNativeCode("macroexpand"))

  let codeUnless = (%*
    ["defmacro", "unless", ["cond", "true-branch", "false-branch"],
      ["quote-replace", ["if", ["~", "cond"],
                               ["~", "false-branch"],
                               ["~", "true-branch"]]]
  ]).toCirruCode(coreNs)

  let codeNativeNotEqual = (%*
    ["defn", "&!=", ["x", "y"], ["not", ["&=", "x", "y"]]]
  ).toCirruCode(coreNs)

  let codeNativeLittlerEqual = (%*
    ["defn", "&<=", ["a", "b"],
      ["&or", ["&<", "a", "b"], ["&=", "a", "b"]]]
  ).toCirruCode(coreNs)

  let codeNativeLargerEqual = (%*
    ["defn", "&>=", ["a", "b"],
      ["&or", ["&>", "a", "b"], ["&=", "a", "b"]]]
  ).toCirruCode(coreNs)

  let codeEmpty = (%*
    ["defmacro", "empty?", ["x"],
      ["quote-replace", ["&=", "0", ["count", ["~", "x"]]]]]
  ).toCirruCode(coreNs)

  let codeFirst = (%*
    ["defmacro", "first", ["xs"],
      ["quote-replace", ["get", ["~", "xs"], "0"]]]
  ).toCirruCode(coreNs)

  let codeWhen = (%*
    ["defmacro", "when", ["cond", "&", "body"],
      ["quote-replace", ["if", ["do", ["~@", "body"]], "nil"]]]
  ).toCirruCode(coreNs)

  let codeFoldl = (%*
    ["defn", "foldl", ["f", "xs", "acc"],
      ["if", ["empty?", "xs"], "acc",
             ["foldl", "f", ["rest", "xs"], ["f", "acc", ["first", "xs"]]]]]
  ).toCirruCode(coreNs)

  let codeAdd = (%*
    ["defn", "+", ["x", "&", "ys"],
      ["foldl", "&+", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeMinus = (%*
    ["defn", "-", ["x", "&", "ys"],
      ["foldl", "&-", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeMultiply = (%*
    ["defn", "*", ["x", "&", "ys"],
      ["foldl", "&*", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeDivide = (%*
    ["defn", "/", ["x", "&", "ys"],
      ["foldl", "&/", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeFoldlCompare = (%*
    ["defn", "foldl-compare", ["f", "xs", "acc"],
      ["if", ["empty?", "xs"], "true",
             ["if", ["f", "acc", ["first", "xs"]],
                    ["foldl-compare", "f", ["rest", "xs"], ["first", "xs"]],
                    "false"]]]
  ).toCirruCode(coreNs)

  let codeLittlerThan = (%*
    ["defn", "<", ["x", "&", "ys"], ["foldl-compare", "&<", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeLargerThan = (%*
    ["defn", ">", ["x", "&", "ys"], ["foldl-compare", "&>", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeEqual = (%*
    ["defn", "=", ["x", "&", "ys"], ["foldl-compare", "&=", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeNotEqual = (%*
    ["defn", "!=", ["x", "&", "ys"], ["foldl-compare", "&!=", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeLargerEqual = (%*
    ["defn", ">=", ["x", "&", "ys"], ["foldl-compare", "&>=", "ys", "x"]]
  ).toCirruCode(coreNs)

  let codeLittlerEqual = (%*
    ["defn", "<=", ["x", "&", "ys"], ["foldl-compare", "&<=", "ys", "x"]]
  ).toCirruCode(coreNs)

  coreSource.defs["unless"] = codeUnless
  coreSource.defs["&!="] = codeNativeNotEqual
  coreSource.defs["&<="] = codeNativeLittlerEqual
  coreSource.defs["&>="] = codeNativeLargerEqual
  coreSource.defs["empty?"] = codeEmpty
  coreSource.defs["first"] = codeFirst
  coreSource.defs["when"] = codeWhen
  coreSource.defs["foldl"] = codeFoldl
  coreSource.defs["+"] = codeAdd
  coreSource.defs["-"] = codeMinus
  coreSource.defs["*"] = codeMultiply
  coreSource.defs["/"] = codeDivide
  coreSource.defs["foldl-compare"] = codeFoldlCompare
  coreSource.defs["<"] = codeLittlerThan
  coreSource.defs[">"] = codeLargerThan
  coreSource.defs["="] = codeEqual
  coreSource.defs["!="] = codeNotEqual
  coreSource.defs[">="] = codeLargerEqual
  coreSource.defs["<="] = codeLittlerEqual

  programCode[coreNs] = coreSource
  programData[coreNs] = coreFile
