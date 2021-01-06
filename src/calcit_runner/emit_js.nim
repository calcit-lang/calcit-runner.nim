
import os
import sets
import strutils
import unicode
import tables
import options
import strformat

import ternary_tree

import ./types
import ./errors
import ./str_util

const cLine = "\n"
const cCurlyL = "{"
const cCurlyR = "}"
const cDbQuote = "\""

# TODO dirty states controlling js backend
var jsMode* = false
var jsEmitPath* = "js-out"

proc toJsFileName(ns: string): string =
  ns & ".mjs"

proc hasNsPart(x: string): bool =
  let trySlashPos = x.find('/')
  return trySlashPos >= 1 and trySlashPos < x.len - 1

proc escapeVar(name: string): string =
  if name.hasNsPart():
    let pieces = name.split("/")
    if pieces.len != 2:
      raiseEvalError("Expected format of ns/def", CirruData(kind: crDataString, stringVal: name))
    let nsPart = pieces[0]
    let defPart = pieces[1]
    if nsPart == "js":
      return defPart
    else:
      return nsPart.escapeVar() & "." & defPart.escapeVar()

  result = name
  .replace("-", "_DASH_")
  .replace("?", "_QUES_")
  .replace("+", "_ADD_")
  # .replace(">", "_SHR_")
  .replace("*", "_STAR_")
  .replace("&", "_AND_")
  .replace("{}", "_MAP_")
  .replace("[]", "_LIST_")
  .replace("{", "_CURL_")
  .replace("}", "_CURR_")
  .replace("[", "_SQRL_")
  .replace("]", "_SQRR_")
  .replace("!", "_BANG_")
  .replace("%", "_PCT_")
  .replace("/", "_SLSH_")
  .replace("=", "_EQ_")
  .replace(">", "_GT_")
  .replace("<", "_LT_")
  .replace(";", "_SCOL_")
  .replace("#", "_SHA_")
  .replace("\\", "_BSL_")
  .replace(".", "_DOT_")
  if result == "if": result = "_IF_"
  if result == "do": result = "_DO_"
  if result == "else": result = "_ELSE_"
  if result == "let": result = "_LET_"
  if result == "case": result = "_CASE_"

# handle recursion
proc genJsFunc(name: string, args: TernaryTreeList[CirruData], body: seq[CirruData], ns: string, exported: bool, outerDefs: HashSet[string]): string
proc genArgsCode(body: TernaryTreeList[CirruData], ns: string, localDefs: HashSet[string]): string

# based on https://github.com/nim-lang/Nim/blob/version-1-4/lib/pure/strutils.nim#L2322
# strutils.escape turns Chinese into longer something "\xE6\xB1\x89",
# so... this is a simplified one according to Cirru Parser
proc escapeCirruStr*(s: string): string =
  result = newStringOfCap(s.len + s.len shr 2)
  result.add('"')
  for idx in 0..<s.runeLen():
    let c = $s.runeAtPos(idx)
    case c
    of "\\": result.add("\\\\")
    of "\"": result.add("\\\"")
    of "\t": result.add("\\t")
    of "\n": result.add("\\n")
    else: result.add(c)
  result.add('"')

proc toJsCode(xs: CirruData, ns: string, localDefs: HashSet[string]): string =
  let varPrefix = if ns == "calcit.core": "" else: "_calcit_."
  case xs.kind
  of crDataSymbol:
    if localDefs.contains(xs.symbolVal):
      result = result & xs.symbolVal.escapeVar()
    elif xs.symbolVal.hasNsPart():
      result = result & xs.symbolVal.escapeVar()
    else:
      result = result & varPrefix & xs.symbolVal.escapeVar()
  of crDataString:
    result = result & xs.stringVal.escapeCirruStr()
  of crDataBool:
    result = result & $xs.boolVal
  of crDataNumber:
    result = result & $xs.numberVal
  of crDataTernary:
    result = result & "initCrTernary(" & ($xs.ternaryVal).escape() & ")"
  of crDataNil:
    result = result & "null"
  of crDataKeyword:
    result = result & varPrefix & "kwd(" & xs.keywordVal.escape() & ")"
  of crDataList:
    if xs.listVal.len == 0:
      echo "[WARNING] Unpexpected empty list"
      return "()"
    let head = xs.listVal[0]
    let body = xs.listVal.rest()
    if head.kind == crDataSymbol:
      case head.symbolVal
      of "if":
        if body.len < 2:
          raiseEvalError("need branches for if", xs)
        let falseBranch = if body.len >= 3: body[2].toJsCode(ns, localDefs) else: "null"
        return body[0].toJsCode(ns, localDefs) & "?" & body[1].toJsCode(ns, localDefs) & ":" & falseBranch
      of "&let":
        result = result & "(()=>{"
        if body.len <= 1:
          raiseEvalError("Unpexpected empty content in let", xs)
        let pair = body.first()
        let content = body.rest()
        if pair.kind != crDataList:
          raiseEvalError("Expected pair a list of length 2", pair)
        if pair.listVal.len != 2:
          raiseEvalError("Expected pair of length 2", pair)
        let defName = pair.listVal[0]
        if defName.kind != crDataSymbol:
          raiseEvalError("Expected symbol behind let", pair)
        # TODO `let` inside expressions makes syntax error
        result = result & fmt"{cLine}let {defName.symbolVal.escapeVar} = {pair.listVal[1].toJsCode(ns, localDefs)};{cLine}"
        # defined new local variable
        var scopedDefs = localDefs
        scopedDefs.incl(defName.symbolVal)
        for idx, x in content:
          if idx == content.len - 1:
            result = result & "return " & x.toJsCode(ns, scopedDefs) & ";\n"
          else:
            result = result & x.toJsCode(ns, scopedDefs) & ";\n"
        return result & "})()"
      of ";":
        return "/* " & $CirruData(kind: crDataList, listVal: body) & " */"
      of "do":
        result = "(()=>{" & cLine
        for idx, x in body:
          if idx > 0:
            result = result & ";\n"
          if idx == body.len - 1:
            result = result & "return " & x.toJsCode(ns, localDefs)
          else:
            result = result & x.toJsCode(ns, localDefs)
        result = result & cLine & "})()"
        return result

      of "quote":
        if body.len < 1:
          raiseEvalError("Unpexpected empty body", xs)
        return ($body[0]).escapeCirruStr()
      of "defatom":
        if body.len != 2:
          raiseEvalError("defatom expects 2 nodes", xs)
        let atomName = body[0]
        let atomExpr = body[1]
        if atomName.kind != crDataSymbol:
          raiseEvalError("expects atomName in symbol", xs)
        let name = atomName.symbolVal.escapeVar()
        let nsStates = "calcit_states:" & ns
        let varCode = fmt"globalThis[{nsStates.escape}]"
        let atomPath = (ns & "/" & atomName.symbolVal).escape()
        return fmt"{cLine}({varCode}!=null) ? {varCode} = {varPrefix}defatom({atomPath}, {atomExpr.toJsCode(ns, localDefs)}) : null {cLine}"

      of "defn":
        if body.len < 3:
          raiseEvalError("Expected name, args, code for gennerating func, too short", xs)
        let funcName = body[0]
        let funcArgs = body[1]
        let funcBody = body.rest().rest()
        if funcName.kind != crDataSymbol:
          raiseEvalError("Expected function name in a symbol", xs)
        if funcArgs.kind != crDataList:
          raiseEvalError("Expected function args in a list", xs)
        return genJsFunc(funcName.symbolVal, funcArgs.listVal, funcBody.toSeq(), ns, false, localDefs)

      of "defmacro":
        return "/* Unpexpected macro " & $xs & " */"
      of "quote-replace":
        return "/* Unpexpected quote-replace " & $xs & " */"
      of "raise":
        # not core syntax, but treat as macro for better debugging experience
        if body.len != 1:
          raiseEvalError("expected a single argument", body.toSeq())
        let message: string = $body[0]
        return fmt"(()=> {cCurlyL} throw new Error({message.escape}) {cCurlyR})() "

      else:
        let token = head.symbolVal
        if token.len > 2 and token[0..1] == ".-" and token[2..^1].matchesJsVar():
          let name = token[2..^1]
          if xs.listVal.len != 2:
            raiseEvalError("property accessor takes only 1 argument", xs)
          let obj = xs.listVal[1]
          return obj.toJsCode(ns, localDefs) & "." & name
        elif token.len > 1 and token[0] == '.' and token[1..^1].matchesJsVar():
          let name = token[1..^1]
          if xs.listVal.len < 2:
            raiseEvalError("property accessor takes at least 1 argument", xs)
          let obj = xs.listVal[1]
          let args = xs.listVal.slice(2, xs.listVal.len)
          let argsCode = genArgsCode(args, ns, localDefs)
          return obj.toJsCode(ns, localDefs) & "." & name & "(" & argsCode & ")"
        else:
          discard
    var argsCode = genArgsCode(body, ns, localDefs)
    return head.toJsCode(ns, localDefs) & "(" & argsCode & ")"
  else:
    raiseEvalError("[WARNING] unknown kind to gen js code: " & $xs.kind, xs)

proc genArgsCode(body: TernaryTreeList[CirruData], ns: string, localDefs: HashSet[string]): string =
  var spreading = false
  for x in body:
    if x.kind == crDataSymbol and x.symbolVal == "&":
      spreading = true
    else:
      if result != "":
        result = result & ", "
      if spreading:
        result = result & "..."
      result = result & x.toJsCode(ns, localDefs)

proc toJsCode(xs: seq[CirruData], ns: string, localDefs: HashSet[string]): string =
  for idx, x in xs:
    # result = result & "// " & $x & "\n"
    if idx == xs.len - 1:
      result = result & "return " & x.toJsCode(ns, localDefs) & ";\n"
    else:
      result = result & x.toJsCode(ns, localDefs) & ";\n"

proc usesRecur(xs: CirruData): bool =
  case xs.kind
  of crDataSymbol:
    if xs.symbolVal == "recur":
      return true
    return false
  of crDataList:
    for x in xs.listVal:
      if x.usesRecur():
        return true
    return false
  else:
    return false

proc genJsFunc(name: string, args: TernaryTreeList[CirruData], body: seq[CirruData], ns: string, exported: bool, outerDefs: HashSet[string]): string =
  var localDefs = outerDefs
  var argsCode = ""
  var spreading = false
  for x in args:
    if x.kind != crDataSymbol:
      raiseEvalError("Expected symbol for arg", x)
    if spreading:
      if argsCode != "":
        argsCode = argsCode & ", "
      localDefs.incl(x.symbolVal)
      argsCode = argsCode & "..." & x.symbolVal.escapeVar()
      spreading = false
    else:
      if x.symbolVal == "&":
        spreading = true
        continue
      if argsCode != "":
        argsCode = argsCode & ", "
      localDefs.incl(x.symbolVal)
      argsCode = argsCode & x.symbolVal.escapeVar

  var fnDefinition = fmt"function {name.escapeVar}({argsCode}) {cCurlyL}{cLine}{body.toJsCode(ns, localDefs)}{cCurlyR}"
  if body.len > 0 and body[^1].usesRecur():
    let varPrefix = if ns == "calcit.core": "" else: "_calcit_."
    let exportMark = if exported: fmt"export let {name.escapeVar} = " else: ""
    return fmt"{cLine}{exportMark}{varPrefix}wrapTailCall({fnDefinition}){cLine}"
  else:
    let exportMark = if exported: "export " else: ""
    return fmt"{cLine}{exportMark}{fnDefinition}{cLine}"

proc emitJs*(programData: Table[string, ProgramFile], entryNs, entryDef: string): void =
  if dirExists(jsEmitPath).not:
    createDir(jsEmitPath)
  for ns, file in programData:
    let jsFilePath = joinPath(jsEmitPath, ns.toJsFileName())
    let nsStates = "calcit_states:" & ns
    # let coreLib = "http://js.calcit-lang.org/calcit.core.mjs".escape()
    let coreLib = "./calcit.core.mjs".escape()
    let procsLib = "./calcit.procs.mjs".escape()
    var content = ""
    if ns == "calcit.core":
      content = content & fmt"{cLine}import {cCurlyL}kwd, wrapTailCall{cCurlyR} from {procsLib};{cLine}"
      content = content & fmt"{cLine}import * as _calcit_procs_ from {procsLib};{cLine}"
      content = content & fmt"{cLine}export * from {procsLib};{cLine}"
    else:
      content = content & fmt"{cLine}import * as _calcit_ from {coreLib};{cLine}"
    content = content & fmt"globalThis[{nsStates.escape}] = {cCurlyL}{cCurlyR};{cLine}"
    if file.ns.isSome():
      let importsInfo = file.ns.get()
      for importName, importRule in importsInfo:
        let importTarget = if importRule.nsInStr: importRule.ns else: "./" & importRule.ns.toJsFileName()
        case importRule.kind
        of importDef:
          content = content & fmt"{cLine}import {cCurlyL}{importName.escapeVar}{cCurlyR} from {cDbQuote}{importTarget}{cDbQuote};{cLine}"
        of importNs:
          content = content & fmt"{cLine}import * as {importName.escapeVar} from {cDbQuote}{importTarget}{cDbQuote};{cLine}"
    else:
      # echo "[WARNING] no imports information for ", ns
      discard

    var defNames: HashSet[string]
    for def in file.defs.keys:
      defNames.incl(def)

    for def, f in file.defs:

      case f.kind
      of crDataProc:
        content = content & fmt"{cLine}var {def.escapeVar} = _calcit_procs_.{def.escapeVar};{cLine}"
      of crDataFn:
        content = content & genJsFunc(def, f.fnArgs, f.fnCode, ns, true, defNames)
      of crDataThunk:
        content = content & fmt"{cLine}export var {def.escapeVar} = {f.thunkCode[].toJsCode(ns, defNames)};{cLine}"
      of crDataMacro:
        # macro should be handled during compilation, psuedo code
        content = content & fmt"{cLine}export var {def.escapeVar} = () => {cCurlyL}/* Macro */{cCurlyR};{cLine}"
        content = content & fmt"{cLine}{def.escapeVar}.isMacro = true;{cLine}"
      of crDataSyntax:
        # should he handled inside compiler
        discard
      else:
        echo " ...well ", $f.kind
    writeFile jsFilePath, content
    echo "Emitted mjs file: ", jsFilePath
