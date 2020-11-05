
import strutils
import strformat
import tables
import options
import sets

import cirru_parser
import cirru_edn
import ternary_tree

import ./types
import ./data
import ./errors
import ./loader
import ./stack
import ./preprocess
import ./gen_code
import ./eval_util

var programCode*: Table[string, FileSource]
var programData*: Table[string, ProgramFile]

proc hasNsAndDef(ns: string, def: string): bool =
  if not programCode.hasKey(ns):
    return false
  if not programCode[ns].defs.hasKey(def):
    return false
  return true

proc clearProgramDefs*(programData: var Table[string, ProgramFile]): void =
  for ns, f in programData:
    if not ns.startsWith("calcit."):
      programData[ns].ns = none(Table[string, ImportInfo])
      programData[ns].defs.clear

  # mutual recursion
proc getEvaluatedByPath*(ns: string, def: string, scope: CirruDataScope): CirruData
proc loadImportDictByNs(ns: string): Table[string, ImportInfo]
proc preprocess(code: CirruData, localDefs: Hashset[string], ns: string): CirruData
proc interpret*(xs: CirruData, scope: CirruDataScope, ns: string): CirruData

proc nativeEval(item: CirruData, interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  var code = interpret(item, scope, ns)
  code = preprocess(item, toHashset[string](@[]), ns)
  if not checkExprStructure(code):
    raiseEvalError("Expected cirru expr in eval(...)", code)
  dimEcho("eval: ", $code)
  interpret code, scope, ns

proc interpretSymbol(sym: CirruData, scope: CirruDataScope, ns: string): CirruData =
  if sym.kind != crDataSymbol:
    raiseEvalError("Expects a symbol", sym)

  if sym.dynamic:
    return sym

  if sym.resolved.isSome:
    let path = sym.resolved.get

    return programData[path.ns].defs[path.def]

  if sym.scope.isSome:
    let fromOriginalScope = sym.scope.get[sym.symbolVal]
    if fromOriginalScope.isSome:
      return fromOriginalScope.get
  elif scope.contains(sym.symbolVal):
    let fromScope = scope[sym.symbolVal]
    if fromScope.isSome:
      return fromScope.get

  let coreDefs = programData[coreNs].defs
  if coreDefs.contains(sym.symbolVal):
    return coreDefs[sym.symbolVal]
  let loadedSym = preprocess(sym, toHashset[string](@[]), ns)

  echo "[Warn] load unprocessed variable: ", sym
  if loadedSym.resolved.isSome:
    let path = loadedSym.resolved.get
    return programData[path.ns].defs[path.def]

  raiseEvalError(fmt"Symbol not initialized or recognized: {sym.symbolVal}", sym)

proc interpret*(xs: CirruData, scope: CirruDataScope, ns: string): CirruData =
  case xs.kind
  of crDataNil, crDataString, crDataKeyword, crDataNumber, crDataBool, crDataProc, crDataFn:
    return xs
  of crDataSymbol:
    return interpretSymbol(xs, scope, ns)
  else:
    discard

  if xs.len == 0:
    raiseEvalError("Cannot interpret empty expression", xs)

  # echo "interpret: ", xs

  let head = xs[0]

  if head.kind == crDataSymbol and head.symbolVal == "eval":
    pushDefStack(StackInfo(ns: ns, def: head.symbolVal, code: xs, args: xs[1..^1]))
    if xs.len < 2:
      raiseEvalError("eval expects 1 argument", xs)
    let ret = nativeEval(xs[1], interpret, scope, ns)
    popDefStack()
    return ret

  let value = interpret(head, scope, ns)
  case value.kind
  of crDataString:
    raiseEvalError("String is not a function", xs)

  of crDataProc:
    let f = value.procVal
    let args = spreadFuncArgs(xs[1..^1], interpret, scope, ns)

    # echo "HEAD: ", head, " ", xs
    # echo "calling: ", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)), " ", xs
    pushDefStack(head, CirruData(kind: crDataNil), args, ns)
    let ret = f(args, interpret, scope, ns)
    popDefStack()
    return ret

  of crDataFn:
    let args = spreadFuncArgs(xs[1..^1], interpret, scope, ns)

    # echo "HEAD: ", head, " ", xs
    pushDefStack(head, CirruData(kind: crDataList, listVal: initTernaryTreeList(value.fnCode)), args, ns)
    # echo "calling: ", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)), " ", xs

    let ret = evaluteFnData(value, args, interpret, ns)

    popDefStack()
    return ret

  of crDataKeyword:
    if xs.len != 2: raiseEvalError("keyword function expects 1 argument", xs)
    let base = interpret(xs[1], scope, ns)
    if base.kind == crDataNil:
      return base
    if base.kind != crDataMap: raiseEvalError("keyword function expects a map", xs)
    let ret = base.mapVal[value]
    if ret.isNone:
      return CirruData(kind: crDataNil)
    else:
      return ret.get

  of crDataMacro:
    echo "[warn] Found macros: ", xs
    raiseEvalError("Macros are supposed to be handled during preprocessing", xs)

  of crDataSyntax:
    let f = value.syntaxVal

    pushDefStack(StackInfo(ns: ns, def: head.symbolVal, code: CirruData(kind: crDataNil), args: xs[1..^1]))
    let quoted = f(xs[1..^1], interpret, scope, ns)
    popDefStack()
    return quoted

  else:
    raiseEvalError(fmt"Unknown head({head.kind}) for calling", head)

proc placeholderFunc(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  echo "[Warn] placeholder function for preprocessing"
  return CirruData(kind: crDataNil)

proc preprocessSymbolByPath*(ns: string, def: string): void =
  if not programData.hasKey(ns):
    var newFile = ProgramFile()
    programData[ns] = newFile

  if not programData[ns].defs.hasKey(def):
    var code = programCode[ns].defs[def]
    programData[ns].defs[def] = CirruData(kind: crDataProc, procVal: placeholderFunc)
    code = preprocess(code, toHashset[string](@[]), ns)
    # echo "setting: ", ns, "/", def
    # echo "processed code: ", code
    programData[ns].defs[def] = interpret(code, CirruDataScope(), ns)

proc preprocessHelper(code: CirruData, localDefs: Hashset[string], ns: string): CirruData =
  preprocess(code, localDefs, ns)

proc preprocess(code: CirruData, localDefs: Hashset[string], ns: string): CirruData =
  # echo "preprocess: ", code
  case code.kind
  of crDataSymbol:
    if localDefs.contains(code.symbolVal):
      return code
    elif code.symbolVal == "&" or code.symbolVal == "~" or code.symbolVal == "~@":
      return code
    else:
      var sym = code

      if sym.dynamic:
        return sym

      let coreDefs = programData[coreNs].defs
      if coreDefs.contains(sym.symbolVal):
        sym.resolved = some((coreNs, sym.symbolVal))
        return sym

      if hasNsAndDef(coreNs, sym.symbolVal):
        preprocessSymbolByPath(coreNs, sym.symbolVal)
        sym.resolved = some((coreNs, sym.symbolVal))
        return sym

      if hasNsAndDef(ns, sym.symbolVal):
        preprocessSymbolByPath(ns, sym.symbolVal)
        sym.resolved = some((ns, sym.symbolVal))
        return sym
      elif ns.startsWith("calcit."):
        raiseEvalError(fmt"Cannot find symbol in core lib: {sym}", sym)
      else:
        let importDict = loadImportDictByNs(ns)
        if sym.symbolVal[0] != '/' and sym.symbolVal.contains("/"):
          let pieces = sym.symbolVal.split('/')
          if pieces.len != 2:
            raiseEvalError("Expects token in ns/def", sym)
          let nsPart = pieces[0]
          let defPart = pieces[1]
          if importDict.hasKey(nsPart):
            let importTarget = importDict[nsPart]
            case importTarget.kind:
            of importNs:
              preprocessSymbolByPath(importTarget.ns, defPart)
              sym.resolved = some((importTarget.ns, defPart))
              return sym
            of importDef:
              raiseEvalError(fmt"Unknown ns ${sym.symbolVal}", sym)
        else:
          if importDict.hasKey(sym.symbolVal):
            let importTarget = importDict[sym.symbolVal]
            case importTarget.kind:
            of importDef:
              preprocessSymbolByPath(importTarget.ns, importTarget.def)
              sym.resolved = some((importTarget.ns, importTarget.def))
              return sym
            of importNs:
              raiseEvalError(fmt"Unknown def ${sym.symbolVal}", sym)

          # raiseEvalError(fmt"Unknown token {sym.symbolVal}", sym)
          return sym

  of crDataList:
    if code.listVal.len == 0:
      return code
    else:
      let head = code.listVal[0]
      let originalValue = preprocess(head, localDefs, ns)
      var value = originalValue

      if value.kind == crDataSymbol and value.resolved.isSome:
        let path = value.resolved.get
        value = programData[path.ns].defs[path.def]

      # echo "run into: ", code, " ", value

      case value.kind
      of crDataProc, crDataFn, crDataKeyword:
        var xs = initTernaryTreeList[CirruData](@[originalValue])
        for child in code.listVal.rest:
          xs = xs.append preprocess(child, localDefs, ns)
        return CirruData(kind: crDataList, listVal: xs)
      of crDataMacro:
        let xs = code[1..^1]
        pushDefStack(StackInfo(ns: ns, def: head.symbolVal, code: CirruData(kind: crDataList, listVal: initTernaryTreeList(value.macroCode)), args: xs))

        let quoted = evaluteMacroData(value, xs, interpret, ns)
        popDefStack()
        # echo "Expanded macro: ", code, "  ->  ", quoted
        return preprocess(quoted, localDefs, ns)
      of crDataSyntax:
        if head.kind != crDataSymbol:
          raiseEvalError("Expected syntax head", code)
        case head.symbolVal
        of ";":
          return code
        of "defn", "defmacro":
          return processDefn(code, localDefs, preprocessHelper, ns)
        of "let", "loop":
          return processBinding(code, localDefs, preprocessHelper, ns)
        of "[]", "if", "assert", "do", "quote-replace":
          return processAll(code, localDefs, preprocessHelper, ns)
        of "quote":
          return processQuote(code, localDefs, preprocessHelper, ns)
        else:
          raiseEvalError(fmt"Unknown syntax: ${head}", code)

        return code
      else:
        return code
  else:
    return code

proc getEvaluatedByPath*(ns: string, def: string, scope: CirruDataScope): CirruData =
  if not programData.hasKey(ns):
    raiseEvalError(fmt"Not initialized during preprocessing: {ns}/{def}", CirruData(kind: crDataNil))

  if not programData[ns].defs.hasKey(def):
    var code = programCode[ns].defs[def]
    code = preprocess(code, toHashset[string](@[]), ns)
    raiseEvalError(fmt"Not initialized during preprocessing: {ns}/{def}", CirruData(kind: crDataNil))
    programData[ns].defs[def] = interpret(code, scope, ns)

  return programData[ns].defs[def]

proc loadImportDictByNs(ns: string): Table[string, ImportInfo] =
  let dict = programData[ns].ns
  if dict.isSome:
    return dict.get
  else:
    let v = extractNsInfo(programCode[ns].ns)
    programData[ns].ns = some(v)
    return v
