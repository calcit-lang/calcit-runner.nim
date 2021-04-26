
import os
import sets
import strutils
# import unicode
import tables
import options
import strformat
import algorithm
import sequtils

import ternary_tree

import ../types
import ../compiler_configs
import ../util/errors
import ../util/str_util
import ../util/set_util
import ../codegen/special_calls
import ../codegen/gen_code
import ../data/virtual_list

const cLine = "\n"
const cCurlyL = "{"
const cCurlyR = "}"
const cDbQuote = "\""

var firstCompilation = true # track if it's the first compilation

# caches program data for detecting incremental changes of libs
var previousProgramCaches: Table[string, HashSet[string]]

# TODO mutable way of collect things
type CollectedImportItem = tuple[ns: string, justNs: bool, nsInStr: bool]
var collectedImports: Table[string, CollectedImportItem]

proc toJsImportName(ns: string): string =
  if mjsMode:
    ("./" & ns & ".mjs").escape() # currently use `import "./ns.name"`
  else:
    ("./" & ns).escape() # currently use `import "./ns.name"`

proc toJsFileName(ns: string): string =
  if mjsMode:
    ns & ".mjs"
  else:
    ns & ".js"

proc escapeVar(name: string): string =
  if name.hasNsPart():
    raise newException(ValueError, "Invalid variable name `" & name & "`, use `escapeNsVar` instead")

  if name == "if": return "_IF_"
  if name == "do": return "_DO_"
  if name == "else": return "_ELSE_"
  if name == "let": return "_LET_"
  if name == "case": return "_CASE_"
  if name == "-": return "_SUB_"

  result = name
  .replace("-", "_")
  .replace(".", "_DOT_") # dot might be part of variable `\.`. not confused with syntax
  .replace("?", "_QUES_")
  .replace("+", "_ADD_")
  .replace("^", "_CRT_")
  .replace("*", "_STAR_")
  .replace("&", "_AND_")
  .replace("{}", "_MAP_")
  .replace("[]", "_LIST_")
  .replace("{", "_CURL_")
  .replace("}", "_CURR_")
  .replace("'", "_SQUO_")
  .replace("[", "_SQRL_")
  .replace("]", "_SQRR_")
  .replace("!", "_BANG_")
  .replace("%", "_PCT_")
  .replace("/", "_SLSH_")
  .replace("=", "_EQ_")
  .replace(">", "_GT_")
  .replace("<", "_LT_")
  .replace(":", "_COL_")
  .replace(";", "_SCOL_")
  .replace("#", "_SHA_")
  .replace("\\", "_BSL_")

proc escapeNs(name: string): string =
  # use `$` to tell namespace from normal variables, thus able to use same token like clj
  "$" & name.escapeVar()

proc escapeNsVar(name: string, ns: string): string =
  if not name.hasNsPart():
    raise newException(ValueError, "Invalid variable name `" & name & "`, lack of namespace part")
  let pieces = name.split("/")
  if pieces.len != 2:
    raiseEvalError("Expected format of ns/def", CirruData(kind: crDataString, stringVal: name))
  let nsPart = pieces[0]
  let defPart = pieces[1]
  if nsPart == "js":
    return defPart
  elif defPart == "@":
    # TODO special syntax for js, using module directly, need a better solution
    return ns.escapeNs()
  else:
    return ns.escapeNs() & "." & defPart.escapeVar()

# handle recursion
proc genJsFunc(name: string, args: CrVirtualList[CirruData], body: seq[CirruData], ns: string, exported: bool, outerDefs: HashSet[string]): string
proc genArgsCode(body: CrVirtualList[CirruData], ns: string, localDefs: HashSet[string]): string

# tell compiler to handle namespace code generation
let builtInJsProc = toHashSet([
  "aget", "aset",
  "extract-cirru-edn",
  "to-cirru-edn",
  "to-js-data",
  "to-calcit-data",
  "printable", "instance?",
  "timeout-call", "load-console-formatter!",
])

# code generated from calcit.core.cirru may not be faster enough,
# possible way to use code from calcit.procs.ts
let preferredJsProc = toHashSet([
  "number?", "keyword?",
  "map?", "nil?",
  "list?", "set?",
  "string?", "fn?",
  "bool?", "atom?", "record?",
  "starts-with?",
])

proc quoteToJs(xs: CirruData, varPrefix: string): string =
  case xs.kind
  of crDataSymbol:
    return "new " & varPrefix & "CrDataSymbol(" & escapeCirruStr($xs) & ")"
  of crDataString:
    return escapeCirruStr($xs)
  of crDataBool:
    return $xs
  of crDataNumber:
    return $xs
  of crDataNil:
    return "null"
  of crDataList:
    let toJsStr = proc (s: CirruData): string =
      quoteToJs(s, varPrefix)
    return "new " & varPrefix & "CrDataList([" & xs.listVal.toSeq.map(toJsStr).join(", ") & "])"
  of crDataKeyword:
    return varPrefix & "kwd(" & escapeCirruStr(xs.keywordVal) & ")"
  else:
    raise newException(ValueError, "Unpexpected data in quote for js: " & $xs)

proc makeLetWithBind(left: string, right: string, body: string): string =
  "(function __let__(" & left & "){\n" &
    body &
    "})(" & right & ")"

proc makeLetWithWrapper(left: string, right: string, body: string): string =
  "(function __let__(){\n" &
    "let " & left & " = " & right & ";\n" &
    body &
    "})()"

proc makeFnWrapper(body: string): string =
  "(function __fn__(){\n" & body & "\n})()"

proc toJsCode(xs: CirruData, ns: string, localDefs: HashSet[string]): string =
  let varPrefix = if ns == "calcit.core": "" else: "$calcit."
  case xs.kind
  of crDataSymbol:
    if xs.symbolVal.hasNsPart():
      let nsPart = xs.symbolVal.split("/")[0]
      if nsPart == "js":
        return xs.symbolVal.escapeNsVar("js")
      else:
        # TODO ditry code
        if xs.resolved.kind != resolvedDef:
          raiseEvalError("Expected symbol with ns being resolved", xs)
        let resolved = xs.resolved
        if collectedImports.contains(resolved.ns):
          let prev = collectedImports[resolved.ns]
          if (not prev.justNs) or prev.ns != resolved.ns:
            echo "conflicted imports: ", prev, resolved
            raiseEvalError("Conflicted implicit ns import", xs)
        else:
          collectedImports[resolved.ns] = (ns: resolved.ns, justNs: true, nsInStr: resolved.nsInStr)
        return xs.symbolVal.escapeNsVar(resolved.ns)
    elif builtInJsProc.contains(xs.symbolVal):
      return varPrefix & xs.symbolVal.escapeVar()
    elif xs.resolved.kind == resolvedLocal or localDefs.contains(xs.symbolVal):
      return xs.symbolVal.escapeVar()
    elif xs.resolved.kind == resolvedDef:
      if xs.resolved.ns == coreNs:
        # functions under core uses built $calcit module entry
        return varPrefix & xs.symbolVal.escapeVar()
      let resolved = xs.resolved
      # TODO ditry code
      if collectedImports.contains(xs.symbolVal):
        let prev = collectedImports[xs.symbolVal]
        if prev.ns != resolved.ns:
          echo collectedImports, " ", xs
          raiseEvalError("Conflicted implicit imports", xs)
      else:
        collectedImports[xs.symbolVal] = (ns: resolved.ns, justNs: false, nsInStr: resolved.nsInStr)
      return xs.symbolVal.escapeVar()
    elif xs.ns == coreNs:
      # local variales inside calcit.core also uses this ns
      echo "[Warn] detected variable inside core not resolved"
      return varPrefix & xs.symbolVal.escapeVar()
    elif xs.ns == "":
      raiseEvalError("Unpexpected ns at symbol", xs)
    elif xs.ns != ns: # probably via macro
      # TODO ditry code collecting imports
      if collectedImports.contains(xs.symbolVal):
        let prev = collectedImports[xs.symbolVal]
        if prev.ns != xs.ns:
          echo collectedImports, " ", xs
          raiseEvalError("Conflicted implicit imports, probably via macro", xs)
      else:
        collectedImports[xs.symbolVal] = (ns: xs.ns, justNs: false, nsInStr: false)
      return xs.symbolVal.escapeVar()
    elif xs.ns == ns:
      echo "[Warn] detected unresolved variable ", xs, " in ", ns
      return xs.symbolVal.escapeVar()
    else:
      echo "[Warn] Unpexpected case of code gen for ", xs, " in ", ns
      return varPrefix & xs.symbolVal.escapeVar()
  of crDataString:
    return xs.stringVal.escapeCirruStr()
  of crDataBool:
    return $xs.boolVal
  of crDataNumber:
    return $xs.numberVal
  of crDataTernary:
    return "initCrTernary(" & ($xs.ternaryVal).escape() & ")"
  of crDataNil:
    return "null"
  of crDataKeyword:
    return varPrefix & "kwd(" & xs.keywordVal.escape() & ")"
  of crDataList:
    if xs.listVal.len == 0:
      echo "[Warn] Unpexpected empty list"
      return "()"
    let head = xs.listVal[0]
    let body = xs.listVal.rest()
    if head.kind == crDataSymbol:
      case head.symbolVal
      of "if":
        if body.len < 2:
          raiseEvalError("need branches for if", xs)
        let falseBranch = if body.len >= 3: body[2].toJsCode(ns, localDefs) else: "null"
        return "(" & body[0].toJsCode(ns, localDefs) & "?" & body[1].toJsCode(ns, localDefs) & ":" & falseBranch & ")"
      of "&let":
        var letDefBody = body

        # defined new local variable
        var scopedDefs = localDefs
        var defsCode = ""
        var variableExisted = false
        var bodyPart = ""

        while true: # break unless nested &let is found

          if letDefBody.len <= 1:
            raiseEvalError("Unpexpected empty content in let", xs)
          let pair = letDefBody.first()
          let content = letDefBody.rest()
          if pair.kind != crDataList:
            raiseEvalError("Expected pair a list of length 2", pair)
          if pair.listVal.len != 2:
            raiseEvalError("Expected pair of length 2", pair)

          let defName = pair.listVal[0]
          let exprCode = pair.listVal[1]

          if defName.kind != crDataSymbol:
            raiseEvalError("Expected symbol behind let", pair)
          # TODO `let` inside expressions makes syntax error
          let left = escapeVar(defName.symbolVal)
          let right = exprCode.toJsCode(ns, scopedDefs)

          defsCode = defsCode & "let " & left & " = " & right & ";\n"

          if scopedDefs.contains(defName.symbolVal):
            variableExisted = true
          else:
            scopedDefs.incl(defName.symbolVal)

          if variableExisted:
            for idx, x in content:
              if idx == content.len - 1:
                bodyPart = bodyPart & "return " & x.toJsCode(ns, scopedDefs) & ";\n"
              else:
                bodyPart = bodyPart & x.toJsCode(ns, scopedDefs) & ";\n"

            # first variable is using conflicted name
            if localDefs.contains(defName.symbolVal):
              return makeLetWithBind(left, right, bodyPart)
            else:
              return makeLetWithWrapper(left, right, bodyPart)
          else:
            if content.len == 1:
              let child = content[0]
              if child.kind == crDataList and child.listVal.len >= 2 and child.listVal[0].kind == crDataSymbol and child.listVal[0].symbolVal == "&let":
                let nextPair = child.listVal[1]
                if nextPair.kind == crDataList and nextPair.listVal.len == 2:
                  if nextPair.listVal[0].kind == crDataSymbol and not scopedDefs.contains(nextPair.listVal[0].symbolVal):
                    letDefBody = child.listVal.rest()
                    continue

            for idx, x in content:
              if idx == content.len - 1:
                bodyPart = bodyPart & "return " & x.toJsCode(ns, scopedDefs) & ";\n"
              else:
                bodyPart = bodyPart & x.toJsCode(ns, scopedDefs) & ";\n"

            break

        return makeFnWrapper(defsCode & bodyPart)
      of ";":
        return "(/* " & $CirruData(kind: crDataList, listVal: body) & " */ null)"
      of "do":
        var bodyPart: string
        for idx, x in body:
          if idx > 0:
            bodyPart = bodyPart & ";\n"
          if idx == body.len - 1:
            bodyPart = bodyPart & "return " & x.toJsCode(ns, localDefs)
          else:
            bodyPart = bodyPart & x.toJsCode(ns, localDefs)
        return makeFnWrapper(bodyPart)

      of "quote":
        if body.len < 1:
          raiseEvalError("Unpexpected empty body", xs)
        return quoteToJs(body[0], varPrefix)
      of "defatom":
        if body.len != 2:
          raiseEvalError("defatom expects 2 nodes", xs)
        let atomName = body[0]
        let atomExpr = body[1]
        if atomName.kind != crDataSymbol:
          raiseEvalError("expects atomName in symbol", xs)
        let name = atomName.symbolVal.escapeVar()
        let atomPath = (ns & "/" & atomName.symbolVal).escape()
        return fmt"{cLine}({varPrefix}peekDefatom({atomPath}) ?? {varPrefix}defatom({atomPath}, {atomExpr.toJsCode(ns, localDefs)})){cLine}"

      of "defn":
        if body.len < 2:
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
        if body.len < 1 or body.len > 2:
          raiseEvalError("expected 1~2 arguments", body.toSeq())
        let message: string = body[0].toJsCode(ns, localDefs)
        var data = "null"
        if body.len >= 2:
          data = body[1].toJsCode(ns, localDefs)
        let errVar = jsGenSym("err")
        return makeFnWrapper(
          "let " & errVar & " = new Error(" & message & ");\n" &
          errVar & ".data = " & data & ";\n" &
          "throw " & errVar & ";"
        )
      of "try":
        if body.len != 2:
          raiseEvalError("expected 2 argument", body.toSeq())
        let code = body[0].toJsCode(ns, localDefs)
        let errVar = jsGenSym("errMsg")
        let handler = body[1].toJsCode(ns, localDefs)
        return makeFnWrapper("try {\nreturn " & code & "\n} catch (" & errVar & ") {\nreturn (" & handler & ")(" & errVar & ".toString())\n}")
      of "echo", "println":
        # not core syntax, but treat as macro for better debugging experience
        let args = xs.listVal.slice(1, xs.listVal.len)
        let argsCode = genArgsCode(args, ns, localDefs)
        return fmt"console.log({varPrefix}printable({argsCode}))"
      of "exists?":
        # not core syntax, but treat as macro for availability
        if body.len != 1: raiseEvalError("expected 1 argument", xs)
        let item = body[0]
        if item.kind != crDataSymbol: raiseEvalError("expected a symbol", xs)
        let target = item.toJsCode(ns, localDefs)
        return "(typeof " & target & " !== 'undefined')"
      of "new":
        if xs.listVal.len < 2:
          raiseEvalError("`new` takes at least an object constructor", xs)
        let ctor = xs.listVal[1]
        let args = xs.listVal.slice(2, xs.listVal.len)
        let argsCode = genArgsCode(args, ns, localDefs)
        return "new " & ctor.toJsCode(ns, localDefs) & "(" & argsCode & ")"
      of "instance?":
        if xs.listVal.len != 3:
          raiseEvalError("`instance?` takes a constructor and a value", xs)
        let ctor = xs.listVal[1]
        let v = xs.listVal[2]
        return "(" & v.toJsCode(ns, localDefs) & " instanceof " & ctor.toJsCode(ns, localDefs) & ")"
      of "set!":
        if xs.listVal.len != 3:
          raiseEvalError("set! takes a operand and a value", xs)
        return xs.listVal[1].toJsCode(ns, localDefs) & " = " & xs.listVal[2].toJsCode(ns, localDefs)
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
    raiseEvalError("[Warn] unknown kind to gen js code: " & $xs.kind, xs)

proc genArgsCode(body: CrVirtualList[CirruData], ns: string, localDefs: HashSet[string]): string =
  let varPrefix = if ns == "calcit.core": "" else: "$calcit."
  var spreading = false
  for x in body:
    if x.kind == crDataSymbol and x.symbolVal == "&":
      spreading = true
    else:
      if result != "":
        result = result & ", "
      if spreading:
        result = result & fmt"...{varPrefix}listToArray(" & x.toJsCode(ns, localDefs) & ")"
        spreading = false
      else:
        result = result & x.toJsCode(ns, localDefs)

proc toJsCode(xs: seq[CirruData], ns: string, localDefs: HashSet[string], returnLabel: string = "return "): string =
  for idx, x in xs:
    # result = result & "// " & $x & "\n"
    if idx == xs.len - 1:
      result = result & returnLabel & x.toJsCode(ns, localDefs) & ";\n"
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

proc genJsFunc(name: string, args: CrVirtualList[CirruData], body: seq[CirruData], ns: string, exported: bool, outerDefs: HashSet[string]): string =
  let varPrefix = if ns == "calcit.core": "" else: "$calcit."
  var localDefs = outerDefs
  var spreadingCode = "" # js list and calcit-js list are different, need to convert
  var argsCode = ""
  var spreading = false
  var hasOptional = false
  var argsCount = 0
  var optionalCount = 0
  for x in args:
    if x.kind != crDataSymbol:
      raiseEvalError("Expected symbol for arg", x)
    if spreading:
      if argsCode != "":
        argsCode = argsCode & ", "
      localDefs.incl(x.symbolVal)
      let argName = x.symbolVal.escapeVar()
      argsCode = argsCode & "..." & argName
      # js list and calcit-js are different in spreading
      spreadingCode = spreadingCode & fmt"{cLine}{argName} = {varPrefix}arrayToList({argName});"
      break # no more args after spreading argument
    elif hasOptional:
      if argsCode != "":
        argsCode = argsCode & ", "
      localDefs.incl(x.symbolVal)
      argsCode = argsCode & x.symbolVal.escapeVar
      optionalCount = optionalCount + 1
    else:
      if x.symbolVal == "&":
        spreading = true
        continue
      if x.symbolVal == "?":
        hasOptional = true
        continue
      if argsCode != "":
        argsCode = argsCode & ", "
      localDefs.incl(x.symbolVal)
      argsCode = argsCode & x.symbolVal.escapeVar
      argsCount = argsCount + 1

  let checkArgs = if spreading:
    cLine & "if (arguments.length < " & $argsCount & ") { throw new Error('Too few arguments') }"
  elif hasOptional:
    cLine & "if (arguments.length < " & $argsCount & ") { throw new Error('Too few arguments') }" &
      "\nif (arguments.length > " & $(argsCount + optionalCount) & ") { throw new Error('Too many arguments') }"
  else:
    cLine & "if (arguments.length !== " & $argsCount & ") { throw new Error('Args length mismatch') }"

  if body.len > 0 and body[^1].usesRecur():
    # ugliy code for inlining tail recursion template
    let retVar = jsGenSym("ret")
    let timesVar = jsGenSym("times")
    let fnDefinition = "function " & name.escapeVar & "(" & argsCode & ")" &
      "{" & checkArgs & spreadingCode &
      "\nlet " & retVar & " = null;\n" &
      "let " & timesVar & " = 0;\n" &
      "while(true) { /* Tail Recursion */\n" &
      "if (" & timesVar & " > 10000) { throw new Error('Expected tail recursion to exist quickly') }\n" &
      body.toJsCode(ns, localDefs, retVar & " =") &
      "if (" & retVar & " instanceof " & varPrefix & "CrDataRecur) {\n" &
      checkArgs.replace("arguments.length", retVar &  ".args.length") & "\n" &
      "[ " & argsCode & " ] = " & retVar &  ".args;\n" &
      spreadingCode &
      timesVar & " += 1;\ncontinue;\n" &
      "} else { return " & retVar & " } " &
      "}\n}"

    let exportMark = if exported: fmt"export let {name.escapeVar} = " else: ""
    return exportMark & fnDefinition & cLine
  else:
    let fnDefinition = fmt"function {name.escapeVar}({argsCode}) " &
      "{" & fmt"{checkArgs}{spreadingCode}{cLine}{body.toJsCode(ns, localDefs)}" & "}"
    let exportMark = if exported: "export " else: ""
    return exportMark & fnDefinition & cLine

proc containsSymbol(xs: CirruData, y: string): bool =
  case xs.kind
  of crDataSymbol:
    xs.symbolVal == y
  of crDataThunk:
    xs.thunkCode[].containsSymbol(y)
  of crDataFn:
    for x in xs.fnCode:
      if x.containsSymbol(y):
        return true
    false
  of crDataList:
    for x in xs.listVal:
      if x.containsSymbol(y):
        return true
    false
  else:
    false

proc sortByDeps(deps: Table[string, CirruData]): seq[string] =
  var depsGraph: Table[string, HashSet[string]]
  var defNames: seq[string]
  for k, v in deps:
    defNames.add(k)
    var depsInfo = initHashSet[string]()
    for k2, v2 in deps:
      if k2 == k:
        continue
      # echo "checking ", k, " -> ", k2, " .. ", v.containsSymbol(k2)
      if v.containsSymbol(k2):
        depsInfo.incl(k2)
    depsGraph[k] = depsInfo
  # echo depsGraph
  for x in defNames.sorted():
    var inserted = false
    for idx, y in result:
      if depsGraph.contains(y) and depsGraph[y].contains(x):
        result.insert(@[x], idx)
        inserted = true
        break
    if inserted:
      continue
    result.add x

proc writeFileIfChanged(filename: string, content: string): bool =
  if fileExists(filename) and readFile(filename) == content:
    return false
  writeFile filename, content
  return true

proc emitJs*(programData: Table[string, ProgramEvaledData], entryNs: string): void =
  if dirExists(codeEmitPath).not:
    createDir(codeEmitPath)

  var unchangedNs: HashSet[string]

  for ns, file in programData:

    # side-effects, reset tracking state
    collectedImports = initTable[string, CollectedImportItem]()
    let defsInCurrent = getTableKeys[CirruData](file.defs)

    if not firstCompilation:
      let appPkgName = entryNs.split('.')[0]
      let pkgName = ns.split('.')[0]
      if appPkgName != pkgName:
        if previousProgramCaches.contains(ns) and (previousProgramCaches[ns] == defsInCurrent):
          continue # since libraries do not have to be re-compiled
    # remember defs of each ns for comparing
    previousProgramCaches[ns] = defsInCurrent

    # reset index each file
    resetJsGenSymIndex()

    # let coreLib = "http://js.calcit-lang.org/calcit.core.js".escape()
    let coreLib = "calcit.core".toJsImportName()
    let procsLib = "@calcit/procs".escape()
    var importCode = ""

    var defsCode = "" # code generated by functions
    var valsCode = "" # code generated by thunks

    if ns == "calcit.core":
      importCode = importCode & fmt"{cLine}import {cCurlyL}kwd, arrayToList, listToArray, CrDataRecur{cCurlyR} from {procsLib};{cLine}"
      importCode = importCode & fmt"{cLine}import * as $calcit_procs from {procsLib};{cLine}"
      importCode = importCode & fmt"{cLine}export * from {procsLib};{cLine}"
    else:
      importCode = importCode & fmt"{cLine}import * as $calcit from {coreLib};{cLine}"

    var defNames: HashSet[string] # multiple parts of scoped defs need to be tracked

    # tracking top level scope definitions
    for def in file.defs.keys:
      defNames.incl(def)

    let depsInOrder = sortByDeps(file.defs)
    # echo "deps order: ", depsInOrder

    for def in depsInOrder:
      if ns == "calcit.core":
        # some defs from core can be replaced by calcit.procs
        if jsUnavailableProcs.contains(def):
          continue
        if preferredJsProc.contains(def):
          defsCode = defsCode & fmt"{cLine}var {def.escapeVar} = $calcit_procs.{def.escapeVar};{cLine}"
          continue

      let f = file.defs[def]

      case f.kind
      of crDataFn:
        if f.fnBuiltin:
          defsCode = defsCode & fmt"{cLine}var {def.escapeVar} = $calcit_procs.{def.escapeVar};{cLine}"
        else:
          defsCode = defsCode & genJsFunc(def, f.fnArgs, f.fnCode, ns, true, defNames)
      of crDataThunk:
        # TODO need topological sorting for accuracy
        # values are called directly, put them after fns
        valsCode = valsCode & fmt"{cLine}export var {def.escapeVar} = {f.thunkCode[].toJsCode(ns, defNames)};{cLine}"
      of crDataMacro:
        # macro should be handled during compilation, psuedo code
        defsCode = defsCode & fmt"{cLine}export var {def.escapeVar} = () => {cCurlyL}/* Macro */{cCurlyR}{cLine}"
        defsCode = defsCode & fmt"{cLine}{def.escapeVar}.isMacro = true;{cLine}"
      of crDataSyntax:
        # should he handled inside compiler
        discard
      else:
        echo "[Warn] strange case for generating a definition ", $f.kind

    if collectedImports.len > 0 and file.ns.isSome():
      # echo "imports: ", collectedImports
      for def, item in collectedImports:
        # echo "implicit import ", defNs, "/", def, " in ", ns
        if item.justNs:
          let importTarget = if item.nsInStr: item.ns.escape() else: item.ns.toJsImportName()
          importCode = importCode & fmt"{cLine}import * as {item.ns.escapeNs} from {importTarget};{cLine}"
        else:
          let importTarget = item.ns.toJsImportName()
          importCode = importCode & fmt"{cLine}import {cCurlyL}{def.escapeVar}{cCurlyR} from {importTarget};{cLine}"

    let jsFilePath = joinPath(codeEmitPath, ns.toJsFileName())
    let wroteNew = writeFileIfChanged(jsFilePath, importCode & cLine & defsCode & cLine & valsCode)
    if wroteNew:
      echo "Emitted js file: ", jsFilePath
    else:
      unchangedNs.incl(ns)

  if unchangedNs.len > 0:
    echo "\n... and " & $(unchangedNs.len) & " files not changed."

  firstCompilation = false
