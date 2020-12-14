
import os
import tables
import json
import math
import strformat
import sequtils
import strutils
import options
import sets
import random
import nanoid
import times
import algorithm
import re

import ternary_tree
import cirru_edn
import dual_balanced_ternary

import ./types
import ./data
import ./errors
import ./to_json
import ./gen_data
import ./gen_code
import ./eval_util
import ./evaluate
import ./atoms
import ./stack

# init generator for rand
randomize()

proc nativeAdd(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native add", args)
  let a = args[0]
  let b = args[1]
  if a.kind == crDataTernary and b.kind == crDataTernary:
    return CirruData(kind: crDataTernary, ternaryVal: a.ternaryVal + b.ternaryVal)
  if a.kind != crDataNumber: raiseEvalError("Required number for adding", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for adding", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal + b.numberVal)

proc nativeMinus(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native minus", args)
  let a = args[0]
  let b = args[1]
  if a.kind == crDataTernary and b.kind == crDataTernary:
    return CirruData(kind: crDataTernary, ternaryVal: a.ternaryVal - b.ternaryVal)
  if a.kind != crDataNumber: raiseEvalError("Required number for minus", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for minus", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal - b.numberVal)

proc nativeMultiply(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native multiply", args)
  let a = args[0]
  let b = args[1]
  if a.kind == crDataTernary and b.kind == crDataTernary:
    return CirruData(kind: crDataTernary, ternaryVal: a.ternaryVal * b.ternaryVal)
  if a.kind != crDataNumber: raiseEvalError("Required number for multiply", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for multiply", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal * b.numberVal)

proc nativeDivide(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native divide", args)
  let a = args[0]
  let b = args[1]
  if a.kind == crDataTernary and b.kind == crDataTernary:
    return CirruData(kind: crDataTernary, ternaryVal: a.ternaryVal / b.ternaryVal)
  if a.kind != crDataNumber: raiseEvalError("Required number for divide", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for divide", b)
  if b.numberVal == 0.0: raiseEvalError("Cannot divide by 0", args)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal / b.numberVal)

proc nativeMod(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native mod", args)
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: raiseEvalError("Required number for mod", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for mod", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal.mod(b.numberVal))

proc nativeLessThan(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native <", args)
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: raiseEvalError("Required number for <", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for <", b)
  return CirruData(kind: crDataBool, boolVal: a.numberVal < b.numberVal)

proc nativeGreaterThan(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native >", args)
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: raiseEvalError("Required number for >", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for >", b)
  return CirruData(kind: crDataBool, boolVal: a.numberVal > b.numberVal)

# should be working for all data types
proc nativeEqual(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native =", args)
  let a = args[0]
  let b = args[1]
  return CirruData(kind: crDataBool, boolVal: a == b)

proc nativeAnd(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native &and", args)
  let a = args[0]
  let b = args[1]
  if a.kind != crDataBool: raiseEvalError("Required bool for &and", a)
  if b.kind != crDataBool: raiseEvalError("Required bool for &and", b)
  return CirruData(kind: crDataBool, boolVal: a.boolVal and b.boolVal)

proc nativeOr(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native &or", args)
  let a = args[0]
  let b = args[1]
  if a.kind != crDataBool: raiseEvalError("Required bool for &or, got: " & $a, a)
  if b.kind != crDataBool: raiseEvalError("Required bool for &or, got: " & $b, b)
  return CirruData(kind: crDataBool, boolVal: a.boolVal or b.boolVal)

proc nativeNot(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("Expected 1 arguments in native not", args)
  let a = args[0]
  if a.kind != crDataBool: raiseEvalError("Required bool for not", a)
  return CirruData(kind: crDataBool, boolVal: not a.boolVal)

proc nativeCount(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("Expected 1 arguments in native count", args)
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
  of crDataString:
    return CirruData(kind: crDataNumber, numberVal: a.stringVal.len.float)
  else:
    raiseEvalError("Cannot count data", a)

proc nativeGet(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native get", args)
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

proc nativeRest(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("Expected 1 arguments in native rest", args)
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

proc nativeRaise(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("Expected 1 argument1 in native raise", args)
  let a = args[0]
  if a.kind != crDataString:
    raiseEvalError("Expect message in string", a)
  raiseEvalError(a.stringVal, args)

proc nativeTypeOf(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("type gets 1 argument", args)
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
    of crDataAtom: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("atom"))
    of crDataTernary: CirruData(kind: crDataKeyword, keywordVal: loadKeyword("ternary"))

proc nativeReadFile(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeWriteFile(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2:
    raiseEvalError("Required 2 arguments for writing a file", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  let fileName = args[0]
  if fileName.kind != crDataString:
    raiseEvalError("Expected path name in string", args)
  let content = args[1]
  if content.kind != crDataString:
    raiseEvalError("Expected content in string", args)
  writeFile(fileName.stringVal, content.stringVal)

  echo "Wrote to file " & fileName.stringVal
  return CirruData(kind: crDataNil)

proc nativeParseJson(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeStringifyJson(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 1 or args.len > 2:
    raiseEvalError("format-json requires 1~2 argument", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)))

  var addColon = false
  if args.len >= 2:
    if args[1].kind != crDataBool: raiseEvalError("expects boolean for addColon option", args)
    addColon = args[1].boolVal

  let jsonString = args[0].toJson(addColon).pretty()
  return CirruData(kind: crDataString, stringVal: jsonString)

proc nativeMacroexpand(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("macroexpand requires 1 argument", args)

  let code = args[0]
  # echo "macroexpanding: ", code
  if code.isList.not or code.len == 0 or checkExprStructure(code).not:
    raiseEvalError(fmt"Unexpected structure from macroexpand", code)

  let value = interpret(code[0], scope, ns)
  if value.kind != crDataMacro:
    raiseEvalError("Expected a macro in the expression", code)

  let xs = code[1..^1]
  let quoted = evaluteMacroData(value, xs, interpret, ns)

  return quoted

proc nativeMacroexpandAll(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("macroexpand-all requires 1 argument", args)

  let code = args[0]
  # echo "macroexpanding: ", code
  if code.isList.not or code.len == 0 or checkExprStructure(code).not:
    raiseEvalError(fmt"Unexpected structure from macroexpand-all", code)

  let value = interpret(code[0], scope, ns)
  if value.kind != crDataMacro:
    raiseEvalError("Expected a macro in the expression", code)

  let xs = code[1..^1]
  let quoted = evaluteMacroData(value, xs, interpret, ns)

  return preprocess(quoted, HashSet[string](), ns)

proc nativePrint(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  stdout.write args.map(`$`).join(" ")
  stdout.flushFile
  return CirruData(kind: crDataNil)

proc nativePrStr(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  return CirruData(kind: crDataString, stringVal: args.mapIt(it.toString(true, true)).join(" "))

proc nativePrepend(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2:
    raiseEvalError("prepend requires 2 args", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataList:
    raiseEvalError("prepend requires a list", args)
  return CirruData(kind: crDataList, listVal: base.listVal.prepend(item))

proc nativeAppend(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2:
    raiseEvalError("append requires 2 args", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataList:
    raiseEvalError("append requires a list", args)
  return CirruData(kind: crDataList, listVal: base.listVal.append(item))

proc nativeFirst(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1:
    raiseEvalError("first requires 1 args", args)
  let base = args[0]
  case base.kind
  of crDataNil:
    return base
  of crDataList:
    if base.listVal.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return base.listVal.first
  of crDataString:
    if base.stringVal.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return CirruData(kind: crDataString, stringVal: $base.stringVal[0])
  else:
    raiseEvalError("first requires a list but got " & $base.kind, args)

proc nativeEmptyQuestion(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1:
    raiseEvalError("empty? requires 1 args", args)
  let base = args[0]
  case base.kind
  of crDataNil:
    return CirruData(kind: crDataBool, boolVal: true)
  of crDataString:
    return CirruData(kind: crDataBool, boolVal: base.stringVal.len == 0)
  of crDataList:
    return CirruData(kind: crDataBool, boolVal: base.listVal.len == 0)
  of crDataMap:
    return CirruData(kind: crDataBool, boolVal: base.mapVal.isEmpty)
  of crDataSet:
    return CirruData(kind: crDataBool, boolVal: base.setVal.len == 0)
  else:
    raiseEvalError("Cannot detect empty", args)

proc nativeLast(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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
  of crDataString:
    if base.stringVal.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return CirruData(kind: crDataString, stringVal: $base.stringVal[^1])
  else:
    raiseEvalError("last requires a list", args)

proc nativeButlast(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeReverse(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeIdenticalQuestion(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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
  of crDataNumber:
    return CirruData(kind: crDataBool, boolVal: a.numberVal == b.numberVal)
  of crDataTernary:
    return CirruData(kind: crDataBool, boolVal: a.ternaryVal == b.ternaryVal)
  else:
    # TODO hard to detect
    return CirruData(kind: crDataBool, boolVal: false)

proc nativeSlice(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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
    let i0 = startIdx.numberVal.int
    let i1 = endIdx.numberVal.int
    if i0 < 0: raiseEvalError("start index too small for slice", args)
    if i1 > base.listVal.len: raiseEvalError("end index too large for slice", args)
    if base.len == 0:
      return CirruData(kind: crDataNil)
    else:
      return CirruData(kind: crDataList, listVal: base.listVal.slice(i0, i1))
  else:
    raiseEvalError("slice requires a list", (args))

proc nativeConcat(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeFormatTernaryTree(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeMerge(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeContainsQuestion(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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
  of crDataString:
    if key.kind != crDataString: raiseEvalError("expects string for detecting", args)
    return CirruData(kind: crDataBool, boolVal: base.stringVal.contains(key.stringVal))
  else:
    raiseEvalError("contains requires a map", args)

proc nativeAssocBefore(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeAssocAfter(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeAssoc(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeDissoc(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeTurnKeyword(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeTurnSymbol(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1:
    raiseEvalError("turn-symbol requires 1 arg", (args))
  let x = args[0]
  case x.kind
  of crDataKeyword:
    return CirruData(kind: crDataSymbol, symbolVal: x.keywordVal[], ns: ns, dynamic: true)
  of crDataString:
    return CirruData(kind: crDataSymbol, symbolVal: x.stringVal, ns: ns, dynamic: true)
  of crDataSymbol:
    return x
  else:
    raiseEvalError("Cannot turn into symbol", (args))

proc nativeTurnString(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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
  of crDataTernary:
    return CirruData(kind: crDataString, stringVal: $(x.ternaryVal))
  else:
    raiseEvalError("Cannot turn into string", (args))

proc nativeRange(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  var base = 0.0
  var bound = 1.0
  var step = 1.0
  if args.len < 1 or args.len > 3: raiseEvalError("Expects 1~3 arguments for range", args)
  if args.len >= 1:
    let a0 = args[0]
    if a0.kind != crDataNumber: raiseEvalError("Expects a base number for range", args)
    bound = a0.numberVal
  if args.len >= 2:
    let a1 = args[1]
    if a1.kind != crDataNumber: raiseEvalError("Expects a bound number for range", args)
    base = bound
    bound = a1.numberVal
  if args.len >= 3:
    let a2 = args[2]
    if a2.kind != crDataNumber: raiseEvalError("Expects a step number for range", args)
    step = a2.numberVal
  var ys: seq[CirruData] = @[]
  while base < bound:
    ys.add CirruData(kind: crDataNumber, numberVal: base)
    base = base + step
  return CirruData(kind: crDataList, listVal: initTernaryTreeList(ys))

proc nativeStr(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1:
    raiseEvalError("&str requires 1 arg", args)
  return CirruData(kind: crDataString, stringVal: $args[0])

proc nativeEscape(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1:
    raiseEvalError("escape requires 1 arg", args)
  let item = args[0]
  if not item.isString:
    raiseEvalError("escape expects a string", args)
  return CirruData(kind: crDataString, stringVal: item.stringVal.escape)

proc nativeStrConcat(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2:
    raiseEvalError("&str-concat expects 2 args", args)
  let s1 = $args[0]
  let s2 = $args[1]
  return CirruData(kind: crDataString, stringVal: s1 & s2)

proc nativeParseCirruEdn(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1:
    raiseEvalError("parse-cirru-edn requires a string", args)

  let content = args[0]
  if content.kind != crDataString:
    raiseEvalError("parse-cirru-edn requires a string", content)
  let ednData = parseEdnFromStr(content.stringVal)
  return ednData.toCirruData(ns, some(scope))

proc nativeSqrt(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("sqrt requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("sqrt expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.sqrt)

proc nativeSin(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("sin requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("sin expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.sin)

proc nativeCos(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("cos requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("cos expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.cos)

proc nativeFloor(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("floor requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("floor expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.floor)

proc nativeCeil(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("ceil requires 1 arg", args)
  let item = args[0]
  if not item.isNumber: raiseEvalError("ceil expects a number", args)
  return CirruData(kind: crDataNumber, numberVal: item.numberVal.ceil)

proc nativeRound(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 1: raiseEvalError("round requires 1 arg", args)
  let item = args[0]
  if item.kind == crDataNumber:
    return CirruData(kind: crDataNumber, numberVal: item.numberVal.round)
  elif item.kind == crDataTernary:
    if args.len >= 2:
      let precision = args[1]
      if precision.kind != crDataNumber:
        raiseEvalError("expects a number for precision", args)
      return CirruData(kind: crDataTernary, ternaryVal: item.ternaryVal.round(precision.numberVal.int))
    else:
      return CirruData(kind: crDataTernary, ternaryVal: item.ternaryVal.round)
  else:
    raiseEvalError("round expects a number", args)

proc nativePow(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("pow requires 2 arg", args)
  let base = args[0]
  let times = args[1]
  if not base.isNumber: raiseEvalError("pow expects a number as base", args)
  if not times.isNumber: raiseEvalError("pow expects a number as times", args)
  return CirruData(kind: crDataNumber, numberVal: base.numberVal.pow(times.numberVal))

proc nativeHashSet(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  return CirruData(kind: crDataSet, setVal: args.toHashSet)

proc nativeInclude(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("include requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("include expects a set", base)
  var newSet: HashSet[CirruData] = base.setVal
  newSet.incl(item)
  return CirruData(kind: crDataSet, setVal: newSet)

proc nativeExclude(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("exclude requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("exclude expects a set", base)
  var newSet: HashSet[CirruData] = base.setVal
  newSet.excl(item)
  return CirruData(kind: crDataSet, setVal: newSet)

proc nativeDifference(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("difference requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("difference expects a set in first arg", base)
  if item.kind != crDataSet: raiseEvalError("difference expects a set in second arg", item)
  return CirruData(kind: crDataSet, setVal: base.setVal.difference(item.setVal))

proc nativeUnion(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("union requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("union expects a set in first arg", base)
  if item.kind != crDataSet: raiseEvalError("union expects a set in second arg", item)
  return CirruData(kind: crDataSet, setVal: base.setVal.union(item.setVal))

proc nativeIntersection(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("intersection requires 2 arg", args)
  let base = args[0]
  let item = args[1]
  if base.kind != crDataSet: raiseEvalError("intersection expects a set in first arg", base)
  if item.kind != crDataSet: raiseEvalError("intersection expects a set in second arg", item)
  return CirruData(kind: crDataSet, setVal: base.setVal.intersection(item.setVal))

proc nativeRecur(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  return CirruData(kind: crDataRecur, recurArgs: args)

proc nativeFoldl(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 3: raiseEvalError("foldl requires 3 arg", args)
  let f = args[0]
  if f.kind != crDataProc and f.kind != crDataFn: raiseEvalError("Expects f to be a proc or a function", args)
  let xs = args[1]
  var acc = args[2]
  if xs.kind == crDataNil:
    return acc

  if xs.kind != crDataList:
    raiseEvalError("Expects xs to be a list", args)

  for item in xs.listVal:
    case f.kind
    of crDataProc:
      acc = f.procVal(@[acc, item], interpret, scope, ns)
    of crDataFn:
      acc = evaluteFnData(f, @[acc, item], interpret, ns)
    else:
      raiseEvalError("Unexpected f to call in foldl", args)

  return acc

proc nativeRand(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeRandInt(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
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

proc nativeReplace(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 3: raiseEvalError("replace expects 3 arguments", args)
  let base = args[0]
  let target = args[1]
  let to = args[2]
  if base.kind != crDataString: raiseEvalError("replace expects a string", args)
  if target.kind != crDataString: raiseEvalError("replace expects a string", args)
  if to.kind != crDataString: raiseEvalError("replace expects a string", args)
  return CirruData(kind: crDataString, stringVal: base.stringVal.replace(target.stringVal, to.stringVal))

proc nativeSplit(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("replace expects 3 arguments", args)
  let base = args[0]
  let target = args[1]
  if base.kind != crDataString: raiseEvalError("replace expects a string", args)
  if target.kind != crDataString: raiseEvalError("replace expects a string", args)
  var list = initTernaryTreeList[CirruData](@[])
  # Nim splits with "" differently
  if target.stringVal == "":
    for c in base.stringVal:
      list = list.append CirruData(kind: crDataString, stringVal: $c)
  else:
    for item in base.stringVal.split(target.stringVal):
      list = list.append CirruData(kind: crDataString, stringVal: item)
  return CirruData(kind: crDataList, listVal: list)

proc nativeSplitLines(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("replace expects 1 argument", args)
  let base = args[0]
  if base.kind != crDataString: raiseEvalError("replace expects a string", args)
  var list = initTernaryTreeList[CirruData](@[])
  for item in base.stringVal.splitLines:
    list = list.append CirruData(kind: crDataString, stringVal: item)
  return CirruData(kind: crDataList, listVal: list)

proc nativeToPairs(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("to-pairs expects a map for argument", args)
  let base = args[0]
  if base.kind != crDataMap: raiseEvalError("to-pairs expects a map", args)
  var acc: seq[CirruData]
  for pair in base.mapVal.toPairs:
    let list = initTernaryTreeList[CirruData](@[pair.k, pair.v])
    acc.add CirruData(kind: crDataList, listVal: list)
  return CirruData(kind: crDataList, listVal: initTernaryTreeList(acc))

proc nativeMap(exprList: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  var value = initTable[CirruData, CirruData]()
  for pair in exprList:
    if pair.kind != crDataList:
      raiseEvalError("Map requires nested children pairs", pair)
    if pair.len() != 2:
      raiseEvalError("Each pair of table contains 2 elements", pair)
    value[pair[0]] = pair[1]
  return CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(value))

proc nativeDeref(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("deref expects 1 argument", args)
  let a = args[0]
  if a.kind != crDataAtom: raiseEvalError("expects an atom to deref", args)
  let attempt = getAtomByPath(a.atomNs, a.atomDef)
  if attempt.isNone:
    raiseEvalError("found no value for such atom", args)
  attempt.get.value

proc nativeResetBang(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("reset! expects 2 arguments", args)
  let a = args[0]
  if a.kind != crDataAtom: raiseEvalError("expects an atom to reset!", args)
  let v = args[1]

  let attempt = getAtomByPath(a.atomNs, a.atomDef)
  if attempt.isNone:
    raiseEvalError("found no value for such atom", args)

  let oldValue = attempt.get.value

  setAtomByPath(a.atomNs, a.atomDef, v)

  for k, listener in attempt.get.watchers:
    case listener.kind
    of crDataProc:
      discard listener.procVal(@[v, oldValue], interpret, scope, ns)
    of crDataFn:
      discard evaluteFnData(listener, @[v, oldValue], interpret, ns)
    else:
      raiseEvalError("Unexpected f to call as a listener", args)

  return CirruData(kind: crDataNil)

proc nativeAddWatch(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 3: raiseEvalError("reset! expects 3 arguments", args)
  let a = args[0]
  if a.kind != crDataAtom: raiseEvalError("expects an atom to reset!", args)
  let k = args[1]
  if k.kind != crDataKeyword: raiseEvalError("expects an keyword for add-watch", args)
  let f = args[2]
  if f.kind != crDataFn and a.kind != crDataProc: raiseEvalError("expects an function for add-watch", args)
  addAtomWatcher(a.atomNs, a.atomDef, k.keywordVal[], f)

proc nativeRemoveWatch(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("reset! expects 2 arguments", args)
  let a = args[0]
  if a.kind != crDataAtom: raiseEvalError("expects an atom to reset!", args)
  let k = args[1]
  if k.kind != crDataKeyword: raiseEvalError("expects an keyword for add-watch", args)
  removeAtomWatcher(a.atomNs, a.atomDef, k.keywordVal[])

proc nativeSubstr(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 2: raiseEvalError("substr expects 2~3 arguments", args)
  let origin = args[0]
  if origin.kind != crDataString: raiseEvalError("expects a string for substr", args)
  let startIdx = args[1]
  var endPos = origin.stringVal.len
  if startIdx.kind != crDataNumber: raiseEvalError("expects a number", args)
  if startIdx.numberVal.int >= endPos:
    return CirruData(kind: crDataString, stringVal: "")

  if args.len >= 3:
    let endIdx = args[2]
    endPos = endIdx.numberVal.int
  if endPos <= startIdx.numberVal.int:
    return CirruData(kind: crDataString, stringVal: "")

  return CirruData(kind: crDataString, stringVal: origin.stringVal[startIdx.numberVal.int..<endPos])

proc nativeStrFind(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("str-find expects 2 arguments", args)
  let origin = args[0]
  if origin.kind != crDataString: raiseEvalError("str-find expects string", args)
  let target = args[1]
  if target.kind != crDataString: raiseEvalError("str-find expects string", args)
  return CirruData(kind: crDataNumber, numberVal: origin.stringVal.find(target.stringVal).float)

proc nativeParseFloat(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("parse-float expects 1 argument", args)
  let origin = args[0]
  if origin.kind != crDataString: raiseEvalError("parse-float expects string", args)
  let v = origin.stringVal.parseFloat
  if v == NAN:
    return CirruData(kind: crDataNil)
  return CirruData(kind: crDataNumber, numberVal: v)

proc nativeTrim(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 1 or args.len > 2: raiseEvalError("trim expects 1~2 arguments", args)
  var spaceChars: set[char] = {' '}
  let origin = args[0]
  if origin.kind != crDataString: raiseEvalError("trim expects string", args)
  if args.len >= 2:
    let target = args[1]
    if target.kind != crDataString: raiseEvalError("trim expects string", args)
    for x in target.stringVal:
      spaceChars.incl(x)
  return CirruData(kind: crDataString, stringVal: origin.stringVal.strip(chars = spaceChars))

proc nativeSetTraceFnBang(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("set-trace-fn! expects 2 arguments", args)
  let nsPart = args[0]
  if nsPart.kind != crDataString: raiseEvalError("Expects string for ns", args)
  let defPart = args[1]
  if defPart.kind != crDataString: raiseEvalError("Expects string for ns", args)
  setTraceFn(nsPart.stringVal, defPart.stringVal)
  CirruData(kind: crDataNil)

proc nativeList(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  CirruData(kind: crDataList, listVal: initTernaryTreeList(args))

proc nativeGensym(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  genSymIndex = genSymIndex + 1
  case args.len
  of 0:
    return CirruData(kind: crDataSymbol, ns: ns, dynamic: true, symbolVal: "G__" & $genSymIndex)
  of 1:
    let item = args[0]
    case item.kind
    of crDataSymbol:
      return CirruData(kind: crDataSymbol, ns: ns, dynamic: false, symbolVal: item.symbolVal & "__" & $genSymIndex)
    of crDataString:
      return CirruData(kind: crDataSymbol, ns: ns, dynamic: false, symbolVal: item.stringVal & "__" & $genSymIndex)
    else:
      raiseEvalError("gensym expects a symbol or a string", args)
  else:
    raiseEvalError("gensym expects 0~1 argument", args)

# this should only be used for testing macros internally
proc nativeResetGensymIndexBang(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  genSymIndex = 0
  CirruData(kind: crDataNil)

# TODO nanoid has outdated file structure, should change in future
proc nativeGenerateIdBang(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len == 0:
    return CirruData(kind: crDataString, stringVal: generate())
  elif args.len == 1:
    if args[0].kind != crDataNumber:
      raiseEvalError("expects a number as length", args)
    let alphabet = "_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    return CirruData(kind: crDataString, stringVal: generate(alphabet, args[0].numberVal.int))
  elif args.len == 2:
    if args[0].kind != crDataNumber:
      raiseEvalError("expects a number as length", args)
    if args[1].kind != crDataString:
      raiseEvalError("expects a string for alphabet", args)
    return CirruData(kind: crDataString, stringVal: generate(args[1].stringVal, args[0].numberVal.int))
  else:
    raiseEvalError("nanoid! takes 0~2 arguments", args)

proc nativeParseTime(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 1: raiseEvalError("parse-time requires string", args)
  if args[0].kind != crDataString: raiseEvalError("parse-time requires string", args)
  var format = "yyyy-MM-dd"
  if args.len >= 2:
    if args[1].kind != crDataString: raiseEvalError("parse-time requires format in string", args)
    format = args[1].stringVal
  CirruData(kind: crDataNumber, numberVal: parse(args[0].stringVal, format.initTimeFormat).toTime.toUnixFloat)

proc nativeFormatTime(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("format-time expects 2 arguments", args)
  if args[0].kind != crDataNumber: raiseEvalError("format-time use number as time", args)
  if args[1].kind != crDataString: raiseEvalError("format-time use a string format", args)
  CirruData(kind: crDataString, stringVal: args[0].numberVal.fromUnixFloat.format(args[1].stringVal))

proc nativeNowBang(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  CirruData(kind: crDataNumber, numberVal: now().toTime.toUnixFloat)

proc nativeFormatNumber(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("format-number expects 2 arguments", args)
  if args[0].kind != crDataNumber: raiseEvalError("format-number expects number", args)
  if args[1].kind != crDataNumber: raiseEvalError("format-number expects length", args)
  CirruData(kind: crDataString, stringVal: args[0].numberVal.formatBiggestFloat(ffDecimal, args[1].numberVal.int))

proc nativeSort(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("sort expects 2 arguments", args)
  if args[0].kind != crDataFn: raiseEvalError("sort expects a function", args)
  if args[1].kind != crDataList: raiseEvalError("sort expects a list", args)
  var xs = args[1].listVal.toSeq()
  xs.sort(proc(a, b: CirruData): int =
    let ret = evaluteFnData(args[0], @[a, b], interpret, ns)
    if ret.kind != crDataNumber: raiseEvalError("expects a number returned as comparator", ret)
    echo "result:", a, " ", b, " ", ret
    return ret.numberVal.int
  )
  CirruData(kind: crDataList, listVal: initTernaryTreeList(xs))

proc nativeDualBalancedTernary(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("dual-balanced-ternary expects 2 arguments", args)
  if args[0].kind != crDataNumber: raiseEvalError("creating ternary expects numbers", args)
  if args[1].kind != crDataNumber: raiseEvalError("creating ternary expects numbers", args)
  CirruData(
    kind: crDataTernary,
    ternaryVal: createDualBalancedTernary(args[0].numberVal, args[1].numberVal)
  )

proc nativeTernaryToPoint(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("ternary->point expects 1 argument", args)
  if args[0].kind != crDataTernary: raiseEvalError("expects ternary value", args)
  let v = args[0].ternaryVal.toFloat()
  let xs = @[
    CirruData(kind: crDataNumber, numberVal: v.x),
    CirruData(kind: crDataNumber, numberVal: v.y),
  ]
  CirruData(kind: crDataList, listVal: initTernaryTreeList(xs))

proc nativeQuit(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("quit expects 1 argument", args)
  if args[0].kind != crDataNumber: raiseEvalError("quit expects a number", args)
  quit(args[0].numberVal.int)

proc nativeGetEnv(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("get-env expects 1 argument", args)
  if args[0].kind != crDataString: raiseEvalError("get-env expects a string", args)
  CirruData(kind: crDataString, stringVal: getEnv(args[0].stringVal))

proc nativeCpuTime(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  CirruData(kind: crDataNumber, numberVal: cpuTime()) # cpuTime returns in seconds

proc nativeGetCharCode(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("get-char-code expects 1 argument", args)
  if args[0].kind != crDataString: raiseEvalError("get-char-code expects a string", args)
  if args[0].stringVal.len != 1: raiseEvalError("get-char-code expects a string of a character", args)
  CirruData(kind: crDataNumber, numberVal: float(char(args[0].stringVal[0])))

# TODO Performance, creating regular expressions dynamically is slow.
# adding specific data type for regex may help in caching. not decided yet
proc nativerReMatches(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("re-matches expects 2 arguments", args)
  let regex = args[0]
  if regex.kind != crDataString: raiseEvalError("re-matches expects a string for regex", args)
  let operand = args[1]
  if operand.kind != crDataString: raiseEvalError("re-matches expects a string operand", args)
  return CirruData(kind: crDataBool, boolVal: operand.stringVal.match(re(regex.stringVal)))

proc nativerReFindIndex(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("re-find-index expects 2 arguments", args)
  let regex = args[0]
  if regex.kind != crDataString: raiseEvalError("re-find-index expects a string for regex", args)
  let operand = args[1]
  if operand.kind != crDataString: raiseEvalError("re-find-index expects a string operand", args)
  return CirruData(kind: crDataNumber, numberVal: operand.stringVal.find(re(regex.stringVal)).float)

proc nativerReFindAll(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("re-find expects 2 arguments", args)
  let regex = args[0]
  if regex.kind != crDataString: raiseEvalError("re-find expects a string for regex", args)
  let operand = args[1]
  if operand.kind != crDataString: raiseEvalError("re-find expects a string operand", args)
  let ys = operand.stringVal.findAll(re(regex.stringVal))
  var xs: seq[CirruData]
  for y in ys:
    xs.add CirruData(kind: crDataString, stringVal: y)
  return CirruData(kind: crDataList, listVal: initTernaryTreeList(xs))

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
  programData[coreNs].defs["raise"] = CirruData(kind: crDataProc, procVal: nativeRaise)
  programData[coreNs].defs["type-of"] = CirruData(kind: crDataProc, procVal: nativeTypeOf)
  programData[coreNs].defs["read-file"] = CirruData(kind: crDataProc, procVal: nativeReadFile)
  programData[coreNs].defs["write-file"] = CirruData(kind: crDataProc, procVal: nativeWriteFile)
  programData[coreNs].defs["parse-json"] = CirruData(kind: crDataProc, procVal: nativeParseJson)
  programData[coreNs].defs["stringify-json"] = CirruData(kind: crDataProc, procVal: nativeStringifyJson)
  programData[coreNs].defs["macroexpand"] = CirruData(kind: crDataProc, procVal: nativeMacroexpand)
  programData[coreNs].defs["macroexpand-all"] = CirruData(kind: crDataProc, procVal: nativeMacroexpandAll)
  programData[coreNs].defs["print"] = CirruData(kind: crDataProc, procVal: nativePrint)
  programData[coreNs].defs["pr-str"] = CirruData(kind: crDataProc, procVal: nativePrStr)
  programData[coreNs].defs["prepend"] = CirruData(kind: crDataProc, procVal: nativePrepend)
  programData[coreNs].defs["append"] = CirruData(kind: crDataProc, procVal: nativeAppend)
  programData[coreNs].defs["conj"] = CirruData(kind: crDataProc, procVal: nativeAppend) # an alias
  programData[coreNs].defs["first"] = CirruData(kind: crDataProc, procVal: nativeFirst)
  programData[coreNs].defs["empty?"] = CirruData(kind: crDataProc, procVal: nativeEmptyQuestion)
  programData[coreNs].defs["last"] = CirruData(kind: crDataProc, procVal: nativeLast)
  programData[coreNs].defs["butlast"] = CirruData(kind: crDataProc, procVal: nativeButlast)
  programData[coreNs].defs["reverse"] = CirruData(kind: crDataProc, procVal: nativeReverse)
  programData[coreNs].defs["turn-string"] = CirruData(kind: crDataProc, procVal: nativeTurnString)
  programData[coreNs].defs["turn-str"] = CirruData(kind: crDataProc, procVal: nativeTurnString) # alias, deprecating in future
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
  programData[coreNs].defs["foldl"] = CirruData(kind: crDataProc, procVal: nativeFoldl)
  programData[coreNs].defs["rand"] = CirruData(kind: crDataProc, procVal: nativeRand)
  programData[coreNs].defs["rand-int"] = CirruData(kind: crDataProc, procVal: nativeRandInt)
  programData[coreNs].defs["replace"] = CirruData(kind: crDataProc, procVal: nativeReplace)
  programData[coreNs].defs["split"] = CirruData(kind: crDataProc, procVal: nativeSplit)
  programData[coreNs].defs["split-lines"] = CirruData(kind: crDataProc, procVal: nativeSplitLines)
  programData[coreNs].defs["to-pairs"] = CirruData(kind: crDataProc, procVal: nativeToPairs)
  programData[coreNs].defs["&{}"] = CirruData(kind: crDataProc, procVal: nativeMap)
  programData[coreNs].defs["deref"] = CirruData(kind: crDataProc, procVal: nativeDeref)
  programData[coreNs].defs["reset!"] = CirruData(kind: crDataProc, procVal: nativeResetBang)
  programData[coreNs].defs["add-watch"] = CirruData(kind: crDataProc, procVal: nativeAddWatch)
  programData[coreNs].defs["remove-watch"] = CirruData(kind: crDataProc, procVal: nativeRemoveWatch)
  programData[coreNs].defs["substr"] = CirruData(kind: crDataProc, procVal: nativeSubstr)
  programData[coreNs].defs["str-find"] = CirruData(kind: crDataProc, procVal: nativeStrFind)
  programData[coreNs].defs["parse-float"] = CirruData(kind: crDataProc, procVal: nativeParseFloat)
  programData[coreNs].defs["trim"] = CirruData(kind: crDataProc, procVal: nativeTrim)
  programData[coreNs].defs["set-trace-fn!"] = CirruData(kind: crDataProc, procVal: nativeSetTraceFnBang)
  programData[coreNs].defs["[]"] = CirruData(kind: crDataProc, procVal: nativeList)
  programData[coreNs].defs["gensym"] = CirruData(kind: crDataProc, procVal: nativeGensym)
  programData[coreNs].defs["&reset-gensym-index!"] = CirruData(kind: crDataProc, procVal: nativeResetGensymIndexBang)
  programData[coreNs].defs["generate-id!"] = CirruData(kind: crDataProc, procVal: nativeGenerateIdBang)
  programData[coreNs].defs["parse-time"] = CirruData(kind: crDataProc, procVal: nativeParseTime)
  programData[coreNs].defs["format-time"] = CirruData(kind: crDataProc, procVal: nativeFormatTime)
  programData[coreNs].defs["now!"] = CirruData(kind: crDataProc, procVal: nativeNowBang)
  programData[coreNs].defs["format-number"] = CirruData(kind: crDataProc, procVal: nativeFormatNumber)
  programData[coreNs].defs["sort"] = CirruData(kind: crDataProc, procVal: nativeSort)
  programData[coreNs].defs["dual-balanced-ternary"] = CirruData(kind: crDataProc, procVal: nativeDualBalancedTernary)
  programData[coreNs].defs["ternary->point"] = CirruData(kind: crDataProc, procVal: nativeTernaryToPoint)
  programData[coreNs].defs["quit"] = CirruData(kind: crDataProc, procVal: nativeQuit)
  programData[coreNs].defs["get-env"] = CirruData(kind: crDataProc, procVal: nativeGetEnv)
  programData[coreNs].defs["cpu-time"] = CirruData(kind: crDataProc, procVal: nativeCpuTime)
  programData[coreNs].defs["get-char-code"] = CirruData(kind: crDataProc, procVal: nativeGetCharCode)
  programData[coreNs].defs["re-matches"] = CirruData(kind: crDataProc, procVal: nativerReMatches)
  programData[coreNs].defs["re-find-index"] = CirruData(kind: crDataProc, procVal: nativerReFindIndex)
  programData[coreNs].defs["re-find-all"] = CirruData(kind: crDataProc, procVal: nativerReFindAll)
