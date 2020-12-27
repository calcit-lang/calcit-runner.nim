
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

proc toJsCode(xs: CirruData): string =
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
        let falseBranch = if body.len >= 3: body[2].toJsCode() else: "null"
        return body[0].toJsCode() & "?" & body[1].toJsCode() & ":" & falseBranch
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
        result = result & fmt"let {defName.symbolVal.escapeVar} = {pair.listVal[1].toJsCode};{cLine}"
        for x in content:
          result = result & x.toJsCode() & "\n"
        return result & "})()"
      of ";":
        return "// " & $body & "\n"
      of "do":
        result = "(()=>{"
        for x in body:
          if result != "(":
            result = result & ";\n"
          result = result & x.toJsCode()
        result = result & "})()"
        return result

      of "quote":
        if body.len < 1:
          raiseEvalError("Unpexpected empty body", xs)
        return ($body[0]).escape()
      of "defatom":
        # TODO
        discard
      of "defn":
        # TODO
        discard
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
      argsCode = argsCode & x.toJsCode()
    result = result & head.toJsCode() & "(" & argsCode & ")"
  else:
    echo "[WARNING] unknown kind to gen js code: ", xs.kind

proc toJsCode(xs: seq[CirruData]): string =
  for x in xs:
    # result = result & "// " & $x & "\n"
    result = result & x.toJsCode() & ";\n"

proc emitJs*(programData: Table[string, ProgramFile], entryNs, entryDef: string): void =
  if dirExists(jsEmitPath).not:
    createDir(jsEmitPath)
  for ns, file in programData:
    let jsFilePath = joinPath(jsEmitPath, ns.toJsFileName())
    var content = fmt"{cLine}import calcit_core from {cDbQuote}http://js/calcit-lang.org/calcit.core.mjs{cDbQuote};{cLine}"
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
        var argsCode = ""
        var spreading = false
        for x in f.fnArgs:
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
        content = content & fmt"{cLine}let {def.escapeVar} = ({argsCode}) => {cCurlyL}{cLine}{f.fnCode.toJsCode}{cCurlyR}{cLine}"
      of crDataThunk:
        content = content & fmt"{cLine}let {def.escapeVar} = {f.thunkCode[].toJsCode};{cLine}"
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
