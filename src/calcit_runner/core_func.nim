
import tables
import json
import math
import strformat
import sequtils
import strutils
import options

import ternary_tree
import cirru_edn

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

proc nativeMod(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native mod")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for mod", a)
  if b.kind != crDataNumber: coreFnError("Required number for mod", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal.mod(b.numberVal))

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
  if a.kind != crDataString:
    raiseEvalError("Expect message in string", a)
  raiseEvalError(a.stringVal, b)

proc nativeTypeOf(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeReadFile(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("Required 1 argument for file name!", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let node = args[1]
  let fileName = interpret(node, scope)
  if fileName.kind != crDataString:
    raiseEvalError("Expected path name in string", node)
  let content = readFile(fileName.stringVal)
  return CirruData(kind: crDataString, stringVal: content)

proc nativeWriteFile(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeLoadJson(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeMacroexpand(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("load-json requires relative path to json file", args)

  let code = args[0]
  if code.kind != crDataList or not checkExprStructure(code) or code.len == 0:
    raiseEvalError("Unexpected structure from macroexpand", code)

  let value = interpret(code[0], scope)
  if value.kind != crDataMacro:
    raiseEvalError("Expected a macro in the expression", code)
  let f = value.macroVal
  let quoted = f(code[1..^1], interpret, scope)
  return quoted

proc nativePrintln(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  echo args.map(`$`).join(" ")
  return CirruData(kind: crDataNil)

proc nativePrStr(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  echo args.map(proc (x: CirruData): string =
    if x.kind == crDataSymbol:
      return escape(x.symbolVal)
    else:
      return $x
  ).join(" ")
  return CirruData(kind: crDataNil)

proc nativePrepend(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("prepend requires 2 args", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataList:
    raiseEvalError("prepend requires a list", args)
  return CirruData(kind: crDataList, listVal: base.listVal.prepend(item))

proc nativeAppend(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("append requires 2 args", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataList:
    raiseEvalError("append requires a list", args)
  return CirruData(kind: crDataList, listVal: base.listVal.append(item))

proc nativeFirst(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeLast(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeButlast(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeIdentical(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeSlice(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeConcat(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("concat requires 2 args", args)
  let base = args[0]
  let another = args[1]

  if base.isNil and base.isNil:
    return base

  if base.isNil:
    return another

  if another.isNil:
    return base

  if not base.isList or not another.isList:
    raiseEvalError("concat requires two lists", args)

  return CirruData(kind: crDataList, listVal: base.listVal.concat(another.listVal))

proc nativeFormatTernaryTree(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeMerge(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeContains(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("contains requires 2 args", args)
  let base = args[0]
  let key = args[1]

  if base.isNil:
    return base

  if key.isNil:
    return key

  case base.kind
  of crDataMap:
    return CirruData(kind: crDataBool, boolVal: base.mapVal.contains(key))
  of crDataSet:
    raise newException(ValueError, "TODO sets")
  else:
    raiseEvalError("contains requires a map", args)

proc nativeAssocBefore(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeAssocAfter(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeKeys(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("keys requires 1 arg", args)
  let base = args[0]
  if base.isNil:
    return base
  if not base.isMap:
    raiseEvalError("keys requires a map", args)
  return CirruData(kind: crDataList, listVal: initTernaryTreeList(base.mapVal.keys))

proc nativeAssoc(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeDissoc(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeTurnKeyword(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("turn-keyword requires 1 arg", (args))
  let x = args[0]
  case x.kind
  of crDataKeyword:
    return x
  of crDataString:
    return CirruData(kind: crDataKeyword, keywordVal: x.stringVal)
  of crDataSymbol:
    return CirruData(kind: crDataKeyword, keywordVal: x.symbolVal)
  else:
    raiseEvalError("Cannot turn into keyword", (args))

proc nativeTurnSymbol(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("turn-symbol requires 1 arg", (args))
  let x = args[0]
  case x.kind
  of crDataKeyword:
    return CirruData(kind: crDataSymbol, symbolVal: x.keywordVal, ns: "", scope: some(scope))
  of crDataString:
    return CirruData(kind: crDataSymbol, symbolVal: x.stringVal, ns: "", scope: some(scope))
  of crDataSymbol:
    return x
  else:
    raiseEvalError("Cannot turn into symbol", (args))

proc nativeTurnString(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("turn-string requires 1 arg", (args))
  let x = args[0]
  case x.kind
  of crDataKeyword:
    return CirruData(kind: crDataString, stringVal: x.keywordVal)
  of crDataString:
    return x
  of crDataSymbol:
    return CirruData(kind: crDataString, stringVal: x.symbolVal)
  of crDataNumber:
    return CirruData(kind: crDataString, stringVal: $(x.numberVal))
  else:
    raiseEvalError("Cannot turn into string", (args))

proc nativeRange(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
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

proc nativeStr(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("&str requires 1 arg", args)
  return CirruData(kind: crDataString, stringVal: $args[0])

proc nativeEscape(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("escape requires 1 arg", args)
  let item = args[0]
  if not item.isString:
    raiseEvalError("escape expects a string", args)
  return CirruData(kind: crDataString, stringVal: item.stringVal.escape)

proc nativeStrConcat(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2:
    raiseEvalError("&str-concat expects 2 args", args)
  let s1 = $args[0]
  let s2 = $args[1]
  return CirruData(kind: crDataString, stringVal: s1 & s2)

proc nativeLoadCirruEdn(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1:
    raiseEvalError("load-json requires relative path to json file", args)

  let filePath = interpret(args[0], scope)
  if filePath.kind != crDataString:
    raiseEvalError("load-json requires path in string", args[0])
  let content = readFile(filePath.stringVal)
  try:
    let ednData = parseEdnFromStr(content)
    return ednData.toCirruData("", some(scope))
  except JsonParsingError as e:
    echo "Failed to parse"
    raiseEvalError("Failed to parse file", args[0])

proc nativeSqrt(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("sqrt requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("sqrt expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.sqrt)

proc nativeSin(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("sin requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("sin expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.sin)

proc nativeCos(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("cos requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("cos expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.cos)

proc nativeFloor(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("floor requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("floor expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.floor)

proc nativeCeil(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("ceil requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("ceil expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.ceil)

proc nativeRound(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("round requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("round expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.round)

proc nativePow(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: raiseEvalError("pow requires 2 arg", args)
  let base = args[0]
  let times = args[1]
  if not base.isNumber: raiseEvalError("pow expects a number as base", args)
  if not times.isNumber: raiseEvalError("pow expects a number as times", args)
  return CirruData(kind: crDataNumber, numberVal: base.numberVal.pow(times.numberVal))

# TODO reduce-find

# injecting functions to calcit.core directly
proc loadCoreDefs*(programData: var Table[string, ProgramFile], interpret: EdnEvalFn): void =
  programData[coreNs].defs["&+"] = CirruData(kind: crDataFn, fnVal: nativeAdd, fnCode: fakeNativeCode("&+"))
  programData[coreNs].defs["&-"] = CirruData(kind: crDataFn, fnVal: nativeMinus, fnCode: fakeNativeCode("&-"))
  programData[coreNs].defs["&*"] = CirruData(kind: crDataFn, fnVal: nativeMultiply, fnCode: fakeNativeCode("&*"))
  programData[coreNs].defs["&/"] = CirruData(kind: crDataFn, fnVal: nativeDivide, fnCode: fakeNativeCode("&/"))
  programData[coreNs].defs["mod"] = CirruData(kind: crDataFn, fnVal: nativeMod, fnCode: fakeNativeCode("mod"))
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
  programData[coreNs].defs["turn-string"] = CirruData(kind: crDataFn, fnVal: nativeTurnString, fnCode: fakeNativeCode("turn-string"))
  programData[coreNs].defs["turn-symbol"] = CirruData(kind: crDataFn, fnVal: nativeTurnSymbol, fnCode: fakeNativeCode("turn-symbol"))
  programData[coreNs].defs["turn-keyword"] = CirruData(kind: crDataFn, fnVal: nativeTurnKeyword, fnCode: fakeNativeCode("turn-keyword"))
  programData[coreNs].defs["identical"] = CirruData(kind: crDataFn, fnVal: nativeIdentical, fnCode: fakeNativeCode("identical"))
  programData[coreNs].defs["range"] = CirruData(kind: crDataFn, fnVal: nativeRange, fnCode: fakeNativeCode("range"))
  programData[coreNs].defs["slice"] = CirruData(kind: crDataFn, fnVal: nativeSlice, fnCode: fakeNativeCode("slice"))
  programData[coreNs].defs["concat"] = CirruData(kind: crDataFn, fnVal: nativeConcat, fnCode: fakeNativeCode("concat"))
  programData[coreNs].defs["format-ternary-tree"] = CirruData(kind: crDataFn, fnVal: nativeFormatTernaryTree, fnCode: fakeNativeCode("format-ternary-tree"))
  programData[coreNs].defs["merge"] = CirruData(kind: crDataFn, fnVal: nativeMerge, fnCode: fakeNativeCode("merge"))
  programData[coreNs].defs["contains"] = CirruData(kind: crDataFn, fnVal: nativeContains, fnCode: fakeNativeCode("contains"))
  programData[coreNs].defs["assoc-before"] = CirruData(kind: crDataFn, fnVal: nativeAssocBefore, fnCode: fakeNativeCode("assoc-before"))
  programData[coreNs].defs["assoc-after"] = CirruData(kind: crDataFn, fnVal: nativeAssocAfter, fnCode: fakeNativeCode("assoc-after"))
  programData[coreNs].defs["keys"] = CirruData(kind: crDataFn, fnVal: nativeKeys, fnCode: fakeNativeCode("keys"))
  programData[coreNs].defs["assoc"] = CirruData(kind: crDataFn, fnVal: nativeAssoc, fnCode: fakeNativeCode("assoc"))
  programData[coreNs].defs["dissoc"] = CirruData(kind: crDataFn, fnVal: nativeDissoc, fnCode: fakeNativeCode("dissoc"))
  programData[coreNs].defs["&str"] = CirruData(kind: crDataFn, fnVal: nativeStr, fnCode: fakeNativeCode("&str"))
  programData[coreNs].defs["escape"] = CirruData(kind: crDataFn, fnVal: nativeEscape, fnCode: fakeNativeCode("escape"))
  programData[coreNs].defs["&str-concat"] = CirruData(kind: crDataFn, fnVal: nativeStrConcat, fnCode: fakeNativeCode("&str-concat"))
  programData[coreNs].defs["load-cirru-edn"] = CirruData(kind: crDataFn, fnVal: nativeLoadCirruEdn, fnCode: fakeNativeCode("load-cirru-edn"))
  programData[coreNs].defs["sqrt"] = CirruData(kind: crDataFn, fnVal: nativeSqrt, fnCode: fakeNativeCode("sqrt"))
  programData[coreNs].defs["ceil"] = CirruData(kind: crDataFn, fnVal: nativeCeil, fnCode: fakeNativeCode("ceil"))
  programData[coreNs].defs["floor"] = CirruData(kind: crDataFn, fnVal: nativeFloor, fnCode: fakeNativeCode("floor"))
  programData[coreNs].defs["sin"] = CirruData(kind: crDataFn, fnVal: nativeSin, fnCode: fakeNativeCode("sin"))
  programData[coreNs].defs["cos"] = CirruData(kind: crDataFn, fnVal: nativeCos, fnCode: fakeNativeCode("cos"))
  programData[coreNs].defs["round"] = CirruData(kind: crDataFn, fnVal: nativeRound, fnCode: fakeNativeCode("round"))
  programData[coreNs].defs["pow"] = CirruData(kind: crDataFn, fnVal: nativePow, fnCode: fakeNativeCode("pow"))
