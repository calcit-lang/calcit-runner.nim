
import tables
import json
import math
import strformat

import ./types
import ./data
import ./helpers

let coreNs* = "calcit.core"

proc coreFnError(msg: string, x: CirruData = CirruData(kind: crDataNil)) =
  raise newException(ValueError, msg)

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

# TODO keyword
# TODO symbol

# TODO read-file
# TODO write-file
# TODO load-json

# TODO reduce-to-false
# TODO reduce-find
# TODO reduce-acc

# injecting functions to calcit.core directly
proc loadCoreDefs*(programData: var Table[string, ProgramFile], interpret: EdnEvalFn): void =
  var coreFile: ProgramFile
  let rootScope = CirruDataScope()

  coreFile.defs["&+"] = CirruData(kind: crDataFn, fnVal: nativeAdd)
  coreFile.defs["&-"] = CirruData(kind: crDataFn, fnVal: nativeMinus)
  coreFile.defs["&<"] = CirruData(kind: crDataFn, fnVal: nativeLessThan)
  coreFile.defs["&>"] = CirruData(kind: crDataFn, fnVal: nativeGreaterThan)
  coreFile.defs["&="] = CirruData(kind: crDataFn, fnVal: nativeEqual)
  coreFile.defs["&and"] = CirruData(kind: crDataFn, fnVal: nativeAnd)
  coreFile.defs["&or"] = CirruData(kind: crDataFn, fnVal: nativeOr)
  coreFile.defs["not"] = CirruData(kind: crDataFn, fnVal: nativeNot)
  coreFile.defs["rest"] = CirruData(kind: crDataFn, fnVal: nativeRest)
  coreFile.defs["raise-at"] = CirruData(kind: crDataFn, fnVal: nativeRaiseAt)
  coreFile.defs["type-of"] = CirruData(kind: crDataFn, fnVal: nativeTypeOf)
  coreFile.defs["read-file"] = CirruData(kind: crDataFn, fnVal: nativeReadFile)
  coreFile.defs["write-file"] = CirruData(kind: crDataFn, fnVal: nativeWriteFile)
  coreFile.defs["load-json"] = CirruData(kind: crDataFn, fnVal: nativeLoadJson)

  # TODO, need more meaningful examples
  let codeOfAdd2 = (%* ["defn", "&+2", ["x"], ["&+", "x", "2"]]).toCirruCode(coreNs)
  coreFile.defs["&+2"] = interpret(codeOfAdd2, rootScope)

  let codeUnless = (%*
    ["defmacro", "unless", ["cond", "true-branch", "false-branch"],
      ["quote-replace", ["if", ["~", "cond"],
                               ["~", "false-branch"],
                               ["~", "true-branch"]]]
  ]).toCirruCode(coreNs)
  coreFile.defs["unless"] = interpret(codeUnless, rootScope)

  let codeNotEqual = (%* ["defmacro", "!=", ["x"], ["not", ["~", "x"]]] ).toCirruCode(coreNs)

  let codeLessEqual = (%*
    ["defmacro", "<=", ["a", "b"],
      ["&or", ["<", ["~", "a"], ["~", "b"]], ["=", ["~", "a"], ["~", "b"]]]]
  ).toCirruCode(coreNs)

  let codeGreaterEqual = (%*
    ["defmacro", "<=", ["a", "b"],
      ["&or", [">", ["~", "a"], ["~", "b"]], ["=", ["~", "a"], ["~", "b"]]]]
  ).toCirruCode(coreNs)

  let codeEmpty = (%*
    ["defmacro", "empty?", ["x"],
      ["quote-replace", ["=", "0", ["count", ["~", "x"]]]]]
  ).toCirruCode(coreNs)

  let codeFirst = (%*
    ["defmacro", "first", ["xs"],
      ["get", "xs", "0"]]
  ).toCirruCode(coreNs)

  let codeWhen = (%*
    ["defmacro", "when", ["cond", "&", "body"],
      ["quote-replace", ["if", ["do", ["~@", "body"]], "nil"]]]
  ).toCirruCode(coreNs)

  coreFile.defs["!="] = interpret(codeNotEqual, rootScope)
  coreFile.defs["<="] = interpret(codeLessEqual, rootScope)
  coreFile.defs[">="] = interpret(codeGreaterEqual, rootScope)
  coreFile.defs["empty?"] = interpret(codeEmpty, rootScope)
  coreFile.defs["first"] = interpret(codeFirst, rootScope)
  coreFile.defs["when"] = interpret(codeWhen, rootScope)

  programData[coreNs] = coreFile
