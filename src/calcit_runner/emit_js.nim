
import os
import strutils
import tables
import options
import strformat

import ternary_tree

import ./types
import ./errors

const cLine = "\n"
const cCurlyL = "{"
const cCurlyR = "}"
const cDbQuote = "\""

# TODO dirty states controlling js backend
var jsMode* = false
var jsEmitPath* = "js-out"

proc toJsFileName(ns: string): string =
  ns & ".mjs"

proc escapeVar(name: string): string =
  name
  .replace("-", "_SUBS_")
  .replace("?", "_QUES_")
  .replace("+", "_ADD_")
  .replace(">", "_SHR_")
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

# handle recursion
proc genJsFunc(name: string, args: TernaryTreeList[CirruData], body: seq[CirruData], ns: string): string

proc toJsCode(xs: CirruData, ns: string): string =
  case xs.kind
  of crDataSymbol:
    result = result & "caclit.core." & xs.symbolVal.escapeVar() & " "
  of crDataString:
    result = result & xs.stringVal.escape() & " "
  of crDataBool:
    result = result & $xs.boolVal & " "
  of crDataNumber:
    result = result & $xs.numberVal & " "
  of crDataNil:
    result = result & "null "
  of crDataKeyword:
    result = result & "calcit.core.turn_keyword(" & xs.keywordVal[].escape() & ")"
  of crDataList:
    if xs.listVal.len == 0:
      return "()"
    let head = xs.listVal[0]
    let body = xs.listVal.rest()
    if head.kind == crDataSymbol:
      case head.symbolVal
      of "if":
        if body.len < 2:
          raiseEvalError("need branches for if", xs)
        let falseBranch = if body.len >= 3: body[2].toJsCode(ns) else: "null"
        return body[0].toJsCode(ns) & "?" & body[1].toJsCode(ns) & ":" & falseBranch
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
        result = result & fmt"let {defName.symbolVal.escapeVar} = {pair.listVal[1].toJsCode(ns)};{cLine}"
        for x in content:
          result = result & x.toJsCode(ns) & "\n"
        return result & "})()"
      of ";":
        return "// " & $body & "\n"
      of "do":
        result = "(()=>{"
        for x in body:
          if result != "(":
            result = result & ";\n"
          result = result & x.toJsCode(ns)
        result = result & "})()"
        return result

      of "quote":
        if body.len < 1:
          raiseEvalError("Unpexpected empty body", xs)
        return ($body[0]).escape()
      of "defatom":
        if body.len != 2:
          raiseEvalError("defatom expects 2 nodes", xs)
        let atomName = body[0]
        let atomExpr = body[1]
        if atomName.kind != crDataSymbol:
          raiseEvalError("expects atomName in symbol", xs)
        let name = atomName.symbolVal.escapeVar()
        let nsStates = "calcit_states:" & ns
        let varCode = fmt"window[{nsStates.escape}]"
        return fmt"{cLine}({varCode}!=null) ? {varCode} = calcit_core.defatom({atomExpr.toJsCode(ns)}) : null {cLine}"

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
        return genJsFunc(funcName.symbolVal, funcArgs.listVal, funcBody.toSeq(), ns)

      of "defmacro":
        return "/* Unpexpected macro " & $xs & " */"
      of "quote-replace":
        return "/* Unpexpected quote-replace " & $xs & " */"
      else:
        discard
    var argsCode = ""
    for x in body:
      if argsCode != "":
        argsCode = argsCode & ", "
      argsCode = argsCode & x.toJsCode(ns)
    result = result & head.toJsCode(ns) & "(" & argsCode & ")"
  else:
    echo "[WARNING] unknown kind to gen js code: ", xs.kind

proc toJsCode(xs: seq[CirruData], ns: string): string =
  for x in xs:
    # result = result & "// " & $x & "\n"
    result = result & x.toJsCode(ns) & ";\n"

proc genJsFunc(name: string, args: TernaryTreeList[CirruData], body: seq[CirruData], ns: string): string =
  var argsCode = ""
  var spreading = false
  for x in args:
    if spreading:
      if argsCode != "":
        argsCode = argsCode & ", "
      argsCode = argsCode & "..." & $x
      spreading = false
    else:
      if x.kind == crDataSymbol and x.symbolVal == "&":
        spreading = true
        continue
      if argsCode != "":
        argsCode = argsCode & ", "
      argsCode = argsCode & ($x).escapeVar
  fmt"{cLine}function {name.escapeVar}({argsCode}) {cCurlyL}{cLine}{body.toJsCode(ns)}{cCurlyR}{cLine}"

proc emitJs*(programData: Table[string, ProgramFile], entryNs, entryDef: string): void =
  if dirExists(jsEmitPath).not:
    createDir(jsEmitPath)
  for ns, file in programData:
    let jsFilePath = joinPath(jsEmitPath, ns.toJsFileName())
    let nsStates = "calcit_states:" & ns
    var content = fmt"{cLine}import calcit_core from {cDbQuote}http://js.calcit-lang.org/calcit.core.mjs{cDbQuote};{cLine}"
    content = content & fmt"window[{nsStates.escape}] = {cCurlyL}{cCurlyR};{cLine}"
    echo ""
    echo ""
    if file.ns.isSome():
      let importsInfo = file.ns.get()
      for importName, importRule in importsInfo:
        let importTarget = importRule.ns.toJsFileName()
        case importRule.kind
        of importDef:
          content = content & fmt"{cLine}import {cCurlyL}{importName.escapeVar}{cCurlyR} from {cDbQuote}./{importTarget}{cDbQuote};{cLine}"
        of importNs:
          content = content & fmt"{cLine}import {importName.escapeVar} from {cDbQuote}./{importTarget}{cDbQuote};{cLine}"
    else:
      echo "[WARNING] no imports information for ", ns
    for def, f in file.defs:
      case f.kind
      of crDataProc:
        # core proc are provided via lib
        discard
      of crDataFn:
        content = content & genJsFunc(def, f.fnArgs, f.fnCode, ns)
      of crDataThunk:
        content = content & fmt"{cLine}let {def.escapeVar} = {f.thunkCode[].toJsCode(ns)};{cLine}"
      of crDataMacro:
        # macro should be handled during compilation
        discard
      of crDataSyntax:
        # should he handled inside compiler
        discard
      else:
        echo " ...well ", $f.kind
    writeFile jsFilePath, content
    echo "Emitted mjs file: ", jsFilePath
