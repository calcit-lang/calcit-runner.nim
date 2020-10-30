
import tables
import json
import math
import strformat
import sequtils
import strutils
import options
import sets
import random

import ternary_tree
import cirru_edn

import ./types
import ./data
import ./errors
import ./to_json
import ./gen_data
import ./gen_code

# init generator for rand
randomize()

proc nativeAdd(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native add")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for adding", a)
  if b.kind != crDataNumber: coreFnError("Required number for adding", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal + b.numberVal)

proc nativeMinus(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native minus")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for minus", a)
  if b.kind != crDataNumber: coreFnError("Required number for minus", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal - b.numberVal)

proc nativeMultiply(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native multiply")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for multiply", a)
  if b.kind != crDataNumber: coreFnError("Required number for multiply", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal * b.numberVal)

proc nativeDivide(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native divide")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for divide", a)
  if b.kind != crDataNumber: coreFnError("Required number for divide", b)
  if b.numberVal == 0.0: coreFnError("Cannot divide by 0", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))
  return CirruData(kind: crDataNumber, numberVal: a.numberVal / b.numberVal)

proc nativeMod(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native mod")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for mod", a)
  if b.kind != crDataNumber: coreFnError("Required number for mod", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal.mod(b.numberVal))

proc nativeLessThan(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native <")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for <", a)
  if b.kind != crDataNumber: coreFnError("Required number for <", b)
  return CirruData(kind: crDataBool, boolVal: a.numberVal < b.numberVal)

proc nativeGreaterThan(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native >")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for >", a)
  if b.kind != crDataNumber: coreFnError("Required number for >", b)
  return CirruData(kind: crDataBool, boolVal: a.numberVal > b.numberVal)

# should be working for all data types
proc nativeEqual(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native =")
  let a = args[0]
  let b = args[1]
  return CirruData(kind: crDataBool, boolVal: a == b)

proc nativeAnd(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native &and")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataBool: coreFnError("Required bool for &and", a)
  if b.kind != crDataBool: coreFnError("Required bool for &and", b)
  return CirruData(kind: crDataBool, boolVal: a.boolVal and b.boolVal)

proc nativeOr(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native &or")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataBool: coreFnError("Required bool for &or", a)
  if b.kind != crDataBool: coreFnError("Required bool for &or", b)
  return CirruData(kind: crDataBool, boolVal: a.boolVal or b.boolVal)

proc nativeNot(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: coreFnError("Expected 1 arguments in native not")
  let a = args[0]
  if a.kind != crDataBool: coreFnError("Required bool for not", a)
  return CirruData(kind: crDataBool, boolVal: not a.boolVal)

proc nativeCount(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: coreFnError("Expected 1 arguments in native count")
  let a = args[0]
  case a.kind
  of crDataNil:
    return CirruData(kind: crDataNumber, numberVal: 0.0)
  of crDataList:
    return CirruData(kind: crDataNumber, numberVal: a.len.float)
  of crDataMap:
    return CirruData(kind: crDataNumber, numberVal: a.len.float)
  of crDataSet:
    return CirruData(kind: crDataNumber, numberVal: a.setVal.len.float)
  else:
    raiseEvalError("Cannot count data", a)

proc nativeGet(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
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
    let ret = a.mapVal[b]
    if ret.isNone:
      return CirruData(kind: crDataNil)
    else:
      return ret.get
  else:
    raiseEvalError("Cannot get from data of this type", a)

proc nativeRest(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
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
    raiseEvalError(fmt"Cannot rest from data of this type: {a.kind}", a)

proc nativeRaiseAt(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native raise-at")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataString:
    raiseEvalError("Expect message in string", a)
  raiseEvalError(a.stringVal, b)

proc nativeTypeOf(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: coreFnError("type gets 1 argument")
  let v = args[0]
  case v.kind
    of crDataNil: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("nil"))
    of crDataNumber: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("number"))
    of crDataString: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("string"))
    of crDataBool: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("bool"))
    of crDataMap: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("map"))
    of crDataProc: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("proc"))
    of crDataFn: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("fn"))
    of crDataMacro: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("macro"))
    of crDataKeyword: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("keyword"))
    of crDataSyntax: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("syntax"))
    of crDataList: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("list"))
    of crDataSet: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("set"))
    of crDataRecur: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("recur"))
    of crDataSymbol: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("symbol"))

proc nativeReadFile(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("Required 1 argument for file name!", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let fileName = args[0]
  if fileName.kind != crDataString:
    raiseEvalError("Expected path name in string", args)
  try:
    let content = readFile(fileName.stringVal)
    return CirruData(kind: crDataString, stringVal: content)
  except IOError as e:
    raiseEvalError(fmt"Failed to read file, {e.msg}", args)

proc nativeWriteFile(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("Required 2 arguments for writing a file", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let fileName = args[0]
  if fileName.kind != crDataString:
    raiseEvalError("Expected path name in string", args)
  let content = args[1]
  if content.kind != crDataString:
    raiseEvalError("Expected content in string", args)
  writeFile(fileName.stringVal, content.stringVal)

  dimEcho fmt"Wrote to file {fileName.stringVal}"
  return CirruData(kind: crDataNil)

proc nativeParseJson(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("parse-json requires a string", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let content = args[0]
  if content.kind != crDataString:
    raiseEvalError("parse-json requires a string", content)
  try:
    let jsonData = parseJson(content.stringVal)
    return jsonData.toCirruData()
  except JsonParsingError:
    echo "Failed to parse JSON", content
    raiseEvalError("Failed to parse file", args[0])

proc nativeStringifyJson(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("formar-json requires 1 argument", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let jsonString = args[0].toJson().pretty()
  return CirruData(kind: crDataString, stringVal: jsonString)

proc nativeMacroexpand(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("load-json requires relative path to json file", args)

  let code = args[0]
  # echo "macroexpanding: ", code
  if code.isList.not or checkExprStructure(code).not or code.len == 0:
    raiseEvalError(fmt"Unexpected structure from macroexpand", code)

  let value = interpret(code[0], scope)
  if value.kind != crDataMacro:
    raiseEvalError("Expected a macro in the expression", code)

  let xs = spreadArgs(code[1..^1])
  let innerScope = scope.merge(processArguments(value.macroArgs, xs))

  var quoted = CirruData(kind: crDataNil)
  for child in value.macroCode:
    quoted = interpret(child, innerScope)

  while quoted.isRecur:
    let loopScope = scope.merge(processArguments(value.macroArgs, spreadArgs(quoted.recurArgs)))
    for child in value.macroCode:
      quoted = interpret(child, loopScope)

  return quoted

proc nativePrintln(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  echo args.map(`$`).join(" ")
  return CirruData(kind: crDataNil)

proc nativePrStr(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  echo args.map(proc (x: CirruData): string =
    if x.kind == crDataSymbol:
      return escape(x.symbolVal)
    else:
      return $x
  ).join(" ")
  return CirruData(kind: crDataNil)

proc nativePrepend(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("prepend requires 2 args", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataList:
    raiseEvalError("prepend requires a list", args)
  return CirruData(kind: crDataList, listVal: base.listVal.prepend(item))

proc nativeAppend(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("append requires 2 args", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataList:
    raiseEvalError("append requires a list", args)
  return CirruData(kind: crDataList, listVal: base.listVal.append(item))

proc nativeFirst(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("first requires 1 args", args)
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
    raiseEvalError("first requires a list", args)

proc nativeEmptyQuestion(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("empty? requires 1 args", args)
  let base = args[0]
  case base.kind
  of crDataNil:
    return CirruData(kind: crDataBool, boolVal: true)
  of crDataList:
    return CirruData(kind: crDataBool, boolVal: base.listVal.len == 0)
  of crDataMap:
    return CirruData(kind: crDataBool, boolVal: base.mapVal.isEmpty)
  of crDataSet:
    return CirruData(kind: crDataBool, boolVal: base.setVal.len == 0)
  else:
    raiseEvalError("Cannot detect empty", args)

proc nativeLast(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("last requires 1 args", args)
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
    raiseEvalError("last requires a list", args)

proc nativeButlast(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("butlast requires 1 args", args)
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
    raiseEvalError("butlast requires a list", args)

proc nativeReverse(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("reverse requires 1 args", args)
  let base = args[0]
  case base.kind
  of crDataNil:
    return base
  of crDataList:
    if base.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return CirruData(kind: crDataList, listVal: base.listVal.reverse)
  else:
    raiseEvalError("reverse requires a list", args)

proc nativeIdenticalQuestion(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("identical expects 2 args", args)
  let a = args[0]
  let b = args[1]
  if a.kind != b.kind:
    return CirruData(kind: crDataBool, boolVal: false)

  case a.kind
  of crDataList:
    return CirruData(kind: crDataBool, boolVal: a.listVal.identical(b.listVal))
  of crDataMap:
    return CirruData(kind: crDataBool, boolVal: a.mapVal.identical(b.mapVal))
  of crDataKeyword:
    # keyword are designed to be reused
    return CirruData(kind: crDataBool, boolVal: a.keywordVal == b.keywordVal)
  of crDataNil:
    return CirruData(kind: crDataBool, boolVal: true)
  of crDataString:
    return CirruData(kind: crDataBool, boolVal: cast[pointer](a.stringVal) == cast[pointer](b.stringVal))
  of crDataSymbol:
    return CirruData(kind: crDataBool, boolVal: cast[pointer](a.symbolVal) == cast[pointer](b.symbolVal))
  of crDataBool:
    return CirruData(kind: crDataBool, boolVal: a.boolVal == b.boolVal)
  else:
    # TODO hard to detect
    return CirruData(kind: crDataBool, boolVal: false)

proc nativeSlice(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 3:
    raiseEvalError("slice requires 3 args", args)
  let base = args[0]
  let startIdx = args[1]
  let endIdx = args[2]

  if not startIdx.isNumber or not endIdx.isNumber:
    raiseEvalError("slice requires startIdx and endIdx in number", args)

  case base.kind
  of crDataNil:
    return base
  of crDataList:
    if base.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return CirruData(kind: crDataList, listVal: base.listVal.slice(startIdx.numberVal.int, endIdx.numberVal.int))
  else:
    raiseEvalError("slice requires a list", (args))

proc nativeConcat(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("&concat requires 2 args", args)
  let base = args[0]
  let another = args[1]

  if base.isNil and base.isNil:
    return base

  if base.isNil:
    return another

  if another.isNil:
    return base

  if not base.isList or not another.isList:
    raiseEvalError("&concat requires two lists", args)

  return CirruData(kind: crDataList, listVal: base.listVal.concat(another.listVal))

proc nativeFormatTernaryTree(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("format-ternary-tree requires 1 arg", args)
  let item = args[0]
  case item.kind
  of crDataNil:
    return CirruData(kind: crDataString, stringVal: "nil")
  of crDataList:
    return CirruData(kind: crDataString, stringVal: item.listVal.formatInline)
  of crDataMap:
    return CirruData(kind: crDataString, stringVal: item.mapVal.formatInline)
  else:
    return CirruData(kind: crDataString, stringVal: $item)

proc nativeMerge(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("merge requires 2 args", args)
  let base = args[0]
  let another = args[1]

  if base.isNil and base.isNil:
    return base

  if base.isNil:
    return another

  if another.isNil:
    return base

  if not base.isMap or not another.isMap:
    raiseEvalError("merge requires two maps", args)

  return CirruData(kind: crDataMap, mapVal: base.mapVal.merge(another.mapVal))

proc nativeContainsQuestion(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("contains requires 2 args", args)
  let base = args[0]
  let key = args[1]

  if base.isNil:
    return CirruData(kind: crDataBool, boolVal: false)

  case base.kind
  of crDataMap:
    return CirruData(kind: crDataBool, boolVal: base.mapVal.contains(key))
  of crDataList:
    return CirruData(kind: crDataBool, boolVal: base.listVal.indexOf(key) >= 0)
  of crDataSet:
    return CirruData(kind: crDataBool, boolVal: base.setVal.contains(key))
  else:
    raiseEvalError("contains requires a map", args)

proc nativeAssocBefore(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 3:
    raiseEvalError("assoc-before requires 3 args", args)
  let base = args[0]
  let key = args[1]
  let item = args[2]
  if not base.isList:
    raiseEvalError("assoc-before requires a list", args)
  if not key.isNumber:
    raiseEvalError("assoc-before requires a number index", args)
  return CirruData(kind: crDataList, listVal: base.listVal.assocBefore(key.numberVal.int, item))

proc nativeAssocAfter(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 3:
    raiseEvalError("assoc-after requires 3 args", args)
  let base = args[0]
  let key = args[1]
  let item = args[2]
  if not base.isList:
    raiseEvalError("assoc-after requires a list", args)
  if not key.isNumber:
    raiseEvalError("assoc-after requires a number index", args)
  return CirruData(kind: crDataList, listVal: base.listVal.assocAfter(key.numberVal.int, item))

proc nativeKeys(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("keys requires 1 arg", args)
  let base = args[0]
  if base.isNil:
    return base
  if not base.isMap:
    raiseEvalError("keys requires a map", args)
  return CirruData(kind: crDataList, listVal: initTernaryTreeList(base.mapVal.keys))

proc nativeAssoc(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 3:
    raiseEvalError("assoc requires 3 arg", args)

  let base = args[0]
  if base.isNil:
    raiseEvalError("assoc does not accept nil target", args)

  case base.kind
  of crDataList:
    let idx = args[1]
    if not idx.isNumber:
      raiseEvalError("assoc expects a number index for list", args)
    return CirruData(kind: crDataList, listVal: base.listVal.assoc(idx.numberVal.int, args[2]))
  of crDataMap:
    return CirruData(kind: crDataMap, mapVal: base.mapVal.assoc(args[1], args[2]))
  else:
    raiseEvalError("assoc expects a list or a map", args)

proc nativeDissoc(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("dissoc requires 2 arg", args)

  let base = args[0]
  if base.isNil:
    return base

  case base.kind
  of crDataList:
    let idx = args[1]
    if not idx.isNumber:
      raiseEvalError("assoc expects a number index for list", args)
    return CirruData(kind: crDataList, listVal: base.listVal.dissoc(idx.numberVal.int))
  of crDataMap:
    return CirruData(kind: crDataMap, mapVal: base.mapVal.dissoc(args[1]))
  else:
    raiseEvalError("assoc expects a list or a map", args)

proc nativeTurnKeyword(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("turn-keyword requires 1 arg", (args))
  let x = args[0]
  case x.kind
  of crDataKeyword:
    return x
  of crDataString:
    return CirruData(kind: crDataKeyword, keywordVal: loadKeyword(x.stringVal))
  of crDataSymbol:
    return CirruData(kind: crDataKeyword, keywordVal: loadKeyword(x.symbolVal))
  else:
    raiseEvalError("Cannot turn into keyword", (args))

proc nativeTurnSymbol(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("turn-symbol requires 1 arg", (args))
  let x = args[0]
  case x.kind
  of crDataKeyword:
    return CirruData(kind: crDataSymbol, symbolVal: x.keywordVal[], ns: "", scope: some(scope), dynamic: true)
  of crDataString:
    return CirruData(kind: crDataSymbol, symbolVal: x.stringVal, ns: "", scope: some(scope), dynamic: true)
  of crDataSymbol:
    return x
  else:
    raiseEvalError("Cannot turn into symbol", (args))

proc nativeTurnString(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("turn-string requires 1 arg", (args))
  let x = args[0]
  case x.kind
  of crDataKeyword:
    return CirruData(kind: crDataString, stringVal: x.keywordVal[])
  of crDataString:
    return x
  of crDataSymbol:
    return CirruData(kind: crDataString, stringVal: x.symbolVal)
  of crDataNumber:
    return CirruData(kind: crDataString, stringVal: $(x.numberVal))
  else:
    raiseEvalError("Cannot turn into string", (args))

proc nativeRange(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len == 1:
    let x = args[0]
    if not x.isNumber:
      raiseEvalError("Expects a number for range", args)
    if x.numberVal <= 0:
      let empty: seq[CirruData] = @[]
      return CirruData(kind: crDataList, listVal: initTernaryTreeList(empty))
    else:
      var ys: seq[CirruData] = @[]
      var i: float = 0
      while i < x.numberVal:
        ys.add CirruData(kind: crDataNumber, numberVal: i)
        i = i + 1
      return CirruData(kind: crDataList, listVal: initTernaryTreeList(ys))
  elif args.len == 2:
    let base = args[0]
    if not base.isNumber:
      raiseEvalError("Expects a base number for range", args)
    let maxValue = args[1]
    if not maxValue.isNumber:
      raiseEvalError("Expects a max number for range", args)
    if base.numberVal >= maxValue.numberVal:
      let empty: seq[CirruData] = @[]
      return CirruData(kind: crDataList, listVal: initTernaryTreeList(empty))
    else:
      var ys: seq[CirruData] = @[]
      var i = base.numberVal
      while i < maxValue.numberVal:
        ys.add CirruData(kind: crDataNumber, numberVal: i)
        i = i + 1
      return CirruData(kind: crDataList, listVal: initTernaryTreeList(ys))

proc nativeStr(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("&str requires 1 arg", args)
  return CirruData(kind: crDataString, stringVal: $args[0])

proc nativeEscape(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("escape requires 1 arg", args)
  let item = args[0]
  if not item.isString:
    raiseEvalError("escape expects a string", args)
  return CirruData(kind: crDataString, stringVal: item.stringVal.escape)

proc nativeStrConcat(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("&str-concat expects 2 args", args)
  let s1 = $args[0]
  let s2 = $args[1]
  return CirruData(kind: crDataString, stringVal: s1 & s2)

proc nativeParseCirruEdn(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("parse-cirru-edn requires a string", args)

  let content = args[0]
  if content.kind != crDataString:
    raiseEvalError("parse-cirru-edn requires a string", content)
  let ednData = parseEdnFromStr(content.stringVal)
  return ednData.toCirruData("user", some(scope))

proc nativeSqrt(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("sqrt requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("sqrt expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.sqrt)

proc nativeSin(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("sin requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("sin expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.sin)

proc nativeCos(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("cos requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("cos expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.cos)

proc nativeFloor(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("floor requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("floor expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.floor)

proc nativeCeil(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("ceil requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("ceil expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.ceil)

proc nativeRound(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("round requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("round expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.round)

proc nativePow(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: raiseEvalError("pow requires 2 arg", args)
  let base = args[0]
  let times = args[1]
  if not base.isNumber: raiseEvalError("pow expects a number as base", args)
  if not times.isNumber: raiseEvalError("pow expects a number as times", args)
  return CirruData(kind: crDataNumber, numberVal: base.numberVal.pow(times.numberVal))

proc nativeHashSet(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  return CirruData(kind: crDataSet, setVal: args.toHashSet)

proc nativeInclude(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: raiseEvalError("include requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("include expects a set", base)
  var newSet: HashSet[CirruData] = base.setVal
  newSet.incl(item)
  return CirruData(kind: crDataSet, setVal: newSet)

proc nativeExclude(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: raiseEvalError("exclude requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("exclude expects a set", base)
  var newSet: HashSet[CirruData] = base.setVal
  newSet.excl(item)
  return CirruData(kind: crDataSet, setVal: newSet)

proc nativeDifference(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: raiseEvalError("difference requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("difference expects a set in first arg", base)
  if item.kind != crDataSet: raiseEvalError("difference expects a set in second arg", item)
  return CirruData(kind: crDataSet, setVal: base.setVal.difference(item.setVal))

proc nativeUnion(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: raiseEvalError("union requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("union expects a set in first arg", base)
  if item.kind != crDataSet: raiseEvalError("union expects a set in second arg", item)
  return CirruData(kind: crDataSet, setVal: base.setVal.union(item.setVal))

proc nativeIntersection(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: raiseEvalError("intersection requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("intersection expects a set in first arg", base)
  if item.kind != crDataSet: raiseEvalError("intersection expects a set in second arg", item)
  return CirruData(kind: crDataSet, setVal: base.setVal.intersection(item.setVal))

proc nativeRecur(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  return CirruData(kind: crDataRecur, recurArgs: args)

# TODO no longer works in current function solution
# proc nativeFoldl(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
#   if args.len != 3: raiseEvalError("foldl requires 3 arg", args)
#   let f = args[0]
#   if f.kind != crDataProc and f.kind != crDataFn: raiseEvalError("Expects f to be a proc or a function", args)
#   let xs = args[1]
#   var acc = args[2]
#   if xs.kind == crDataNil:
#     return acc

#   if xs.kind != crDataList:
#     raiseEvalError("Expects xs to be a list", args)

#   for item in xs.listVal:
#     let list = @[f, acc, item]
#     acc = interpret(CirruData(kind: crDataList, listVal: initTernaryTreeList(list)) , scope)

#   return acc

proc nativeRand(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  case args.len
  of 0:
    return CirruData(kind: crDataNumber, numberVal: rand(100.0))
  of 1:
    let n = args[0]
    if n.kind != crDataNumber: raiseEvalError("rand expects a number", args)
    return CirruData(kind: crDataNumber, numberVal: rand(n.numberVal))
  of 2:
    let minN = args[0]
    let maxN = args[1]
    if minN.kind != crDataNumber: raiseEvalError("rand expects numbers", args)
    if maxN.kind != crDataNumber: raiseEvalError("rand expects numbers", args)
    let rangeN = maxN.numberVal - minN.numberVal
    return CirruData(kind: crDataNumber, numberVal: minN.numberVal + rand(rangeN))
  else:
    raiseEvalError("rand expects 0~2 arguments", args)

proc nativeRandInt(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  case args.len
  of 0:
    return CirruData(kind: crDataNumber, numberVal: rand(100).float)
  of 1:
    let n = args[0]
    if n.kind != crDataNumber: raiseEvalError("rand-int expects a number", args)
    return CirruData(kind: crDataNumber, numberVal: rand(n.numberVal.int).float)
  of 2:
    let minN = args[0]
    let maxN = args[1]
    if minN.kind != crDataNumber: raiseEvalError("rand-int expects numbers", args)
    if maxN.kind != crDataNumber: raiseEvalError("rand-int expects numbers", args)
    let rangeN = maxN.numberVal - minN.numberVal
    return CirruData(kind: crDataNumber, numberVal: (minN.numberVal.int + rand(rangeN).int).float)
  else:
    raiseEvalError("rand-int expects 0~2 arguments", args)

proc nativeReplace(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 3: raiseEvalError("replace expects 3 arguments", args)
  let base = args[0]
  let target = args[1]
  let to = args[2]
  if base.kind != crDataString: raiseEvalError("replace expects a string", args)
  if target.kind != crDataString: raiseEvalError("replace expects a string", args)
  if to.kind != crDataString: raiseEvalError("replace expects a string", args)
  return CirruData(kind: crDataString, stringVal: base.stringVal.replace(target.stringVal, to.stringVal))

proc nativeSplit(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 2: raiseEvalError("replace expects 3 arguments", args)
  let base = args[0]
  let target = args[1]
  if base.kind != crDataString: raiseEvalError("replace expects a string", args)
  if target.kind != crDataString: raiseEvalError("replace expects a string", args)
  var list = initTernaryTreeList[CirruData](@[])
  for item in base.stringVal.split(target.stringVal):
    list = list.append CirruData(kind: crDataString, stringVal: item)
  return CirruData(kind: crDataList, listVal: list)

proc nativeSplitLines(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("replace expects 3 arguments", args)
  let base = args[0]
  if base.kind != crDataString: raiseEvalError("replace expects a string", args)
  var list = initTernaryTreeList[CirruData](@[])
  for item in base.stringVal.splitLines:
    list = list.append CirruData(kind: crDataString, stringVal: item)
  return CirruData(kind: crDataList, listVal: list)

# injecting functions to calcit.core directly
proc loadCoreDefs*(programData: var Table[string, ProgramFile], interpret: FnInterpret): void =
  programData[coreNs].defs["&+"] = CirruData(kind: crDataProc, procVal: nativeAdd)
  programData[coreNs].defs["&-"] = CirruData(kind: crDataProc, procVal: nativeMinus)
  programData[coreNs].defs["&*"] = CirruData(kind: crDataProc, procVal: nativeMultiply)
  programData[coreNs].defs["&/"] = CirruData(kind: crDataProc, procVal: nativeDivide)
  programData[coreNs].defs["mod"] = CirruData(kind: crDataProc, procVal: nativeMod)
  programData[coreNs].defs["&<"] = CirruData(kind: crDataProc, procVal: nativeLessThan)
  programData[coreNs].defs["&>"] = CirruData(kind: crDataProc, procVal: nativeGreaterThan)
  programData[coreNs].defs["&="] = CirruData(kind: crDataProc, procVal: nativeEqual)
  programData[coreNs].defs["&and"] = CirruData(kind: crDataProc, procVal: nativeAnd)
  programData[coreNs].defs["&or"] = CirruData(kind: crDataProc, procVal: nativeOr)
  programData[coreNs].defs["not"] = CirruData(kind: crDataProc, procVal: nativeNot)
  programData[coreNs].defs["count"] = CirruData(kind: crDataProc, procVal: nativeCount)
  programData[coreNs].defs["get"] = CirruData(kind: crDataProc, procVal: nativeGet)
  programData[coreNs].defs["rest"] = CirruData(kind: crDataProc, procVal: nativeRest)
  programData[coreNs].defs["raise-at"] = CirruData(kind: crDataProc, procVal: nativeRaiseAt)
  programData[coreNs].defs["type-of"] = CirruData(kind: crDataProc, procVal: nativeTypeOf)
  programData[coreNs].defs["read-file"] = CirruData(kind: crDataProc, procVal: nativeReadFile)
  programData[coreNs].defs["write-file"] = CirruData(kind: crDataProc, procVal: nativeWriteFile)
  programData[coreNs].defs["parse-json"] = CirruData(kind: crDataProc, procVal: nativeParseJson)
  programData[coreNs].defs["stringify-json"] = CirruData(kind: crDataProc, procVal: nativeStringifyJson)
  programData[coreNs].defs["macroexpand"] = CirruData(kind: crDataProc, procVal: nativeMacroexpand)
  programData[coreNs].defs["println"] = CirruData(kind: crDataProc, procVal: nativePrintln)
  programData[coreNs].defs["echo"] = CirruData(kind: crDataProc, procVal: nativePrintln)
  programData[coreNs].defs["pr-str"] = CirruData(kind: crDataProc, procVal: nativePrStr)
  programData[coreNs].defs["prepend"] = CirruData(kind: crDataProc, procVal: nativePrepend)
  programData[coreNs].defs["append"] = CirruData(kind: crDataProc, procVal: nativeAppend)
  programData[coreNs].defs["first"] = CirruData(kind: crDataProc, procVal: nativeFirst)
  programData[coreNs].defs["empty?"] = CirruData(kind: crDataProc, procVal: nativeEmptyQuestion)
  programData[coreNs].defs["last"] = CirruData(kind: crDataProc, procVal: nativeLast)
  programData[coreNs].defs["butlast"] = CirruData(kind: crDataProc, procVal: nativeButlast)
  programData[coreNs].defs["reverse"] = CirruData(kind: crDataProc, procVal: nativeReverse)
  programData[coreNs].defs["turn-string"] = CirruData(kind: crDataProc, procVal: nativeTurnString)
  programData[coreNs].defs["turn-symbol"] = CirruData(kind: crDataProc, procVal: nativeTurnSymbol)
  programData[coreNs].defs["turn-keyword"] = CirruData(kind: crDataProc, procVal: nativeTurnKeyword)
  programData[coreNs].defs["identical?"] = CirruData(kind: crDataProc, procVal: nativeIdenticalQuestion)
  programData[coreNs].defs["range"] = CirruData(kind: crDataProc, procVal: nativeRange)
  programData[coreNs].defs["slice"] = CirruData(kind: crDataProc, procVal: nativeSlice)
  programData[coreNs].defs["&concat"] = CirruData(kind: crDataProc, procVal: nativeConcat)
  programData[coreNs].defs["format-ternary-tree"] = CirruData(kind: crDataProc, procVal: nativeFormatTernaryTree)
  programData[coreNs].defs["&merge"] = CirruData(kind: crDataProc, procVal: nativeMerge)
  programData[coreNs].defs["contains?"] = CirruData(kind: crDataProc, procVal: nativeContainsQuestion)
  programData[coreNs].defs["assoc-before"] = CirruData(kind: crDataProc, procVal: nativeAssocBefore)
  programData[coreNs].defs["assoc-after"] = CirruData(kind: crDataProc, procVal: nativeAssocAfter)
  programData[coreNs].defs["keys"] = CirruData(kind: crDataProc, procVal: nativeKeys)
  programData[coreNs].defs["assoc"] = CirruData(kind: crDataProc, procVal: nativeAssoc)
  programData[coreNs].defs["dissoc"] = CirruData(kind: crDataProc, procVal: nativeDissoc)
  programData[coreNs].defs["&str"] = CirruData(kind: crDataProc, procVal: nativeStr)
  programData[coreNs].defs["escape"] = CirruData(kind: crDataProc, procVal: nativeEscape)
  programData[coreNs].defs["&str-concat"] = CirruData(kind: crDataProc, procVal: nativeStrConcat)
  programData[coreNs].defs["parse-cirru-edn"] = CirruData(kind: crDataProc, procVal: nativeParseCirruEdn)
  programData[coreNs].defs["sqrt"] = CirruData(kind: crDataProc, procVal: nativeSqrt)
  programData[coreNs].defs["ceil"] = CirruData(kind: crDataProc, procVal: nativeCeil)
  programData[coreNs].defs["floor"] = CirruData(kind: crDataProc, procVal: nativeFloor)
  programData[coreNs].defs["sin"] = CirruData(kind: crDataProc, procVal: nativeSin)
  programData[coreNs].defs["cos"] = CirruData(kind: crDataProc, procVal: nativeCos)
  programData[coreNs].defs["round"] = CirruData(kind: crDataProc, procVal: nativeRound)
  programData[coreNs].defs["pow"] = CirruData(kind: crDataProc, procVal: nativePow)
  programData[coreNs].defs["#{}"] = CirruData(kind: crDataProc, procVal: nativeHashSet)
  programData[coreNs].defs["&include"] = CirruData(kind: crDataProc, procVal: nativeInclude)
  programData[coreNs].defs["&exclude"] = CirruData(kind: crDataProc, procVal: nativeExclude)
  programData[coreNs].defs["&difference"] = CirruData(kind: crDataProc, procVal: nativeDifference)
  programData[coreNs].defs["&union"] = CirruData(kind: crDataProc, procVal: nativeUnion)
  programData[coreNs].defs["&intersection"] = CirruData(kind: crDataProc, procVal: nativeIntersection)
  programData[coreNs].defs["recur"] = CirruData(kind: crDataProc, procVal: nativeRecur)
  # programData[coreNs].defs["foldl"] = CirruData(kind: crDataProc, procVal: nativeFoldl)
  programData[coreNs].defs["rand"] = CirruData(kind: crDataProc, procVal: nativeRand)
  programData[coreNs].defs["rand-int"] = CirruData(kind: crDataProc, procVal: nativeRandInt)
  programData[coreNs].defs["replace"] = CirruData(kind: crDataProc, procVal: nativeReplace)
  programData[coreNs].defs["split"] = CirruData(kind: crDataProc, procVal: nativeSplit)
  programData[coreNs].defs["split-lines"] = CirruData(kind: crDataProc, procVal: nativeSplitLines)
