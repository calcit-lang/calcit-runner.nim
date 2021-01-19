import os
import tables
import sets
import terminal
import options

import cirru_edn
import cirru_parser

import ./types
import ./data
import ./data/to_cirru
import ./data/to_edn
import ./util/errors
import ./util/color_echo

proc getSourceNode(v: CirruEdnValue, ns: string, scope: Option[CirruDataScope] = none(CirruDataScope)): CirruData =
  if v.kind != crEdnQuotedCirru:
    echo "current node: ", v.kind, " ", v
    raise newException(ValueError, "expected quoted cirru node")

  return v.quotedVal.nodesToCirruData(ns)

proc extractDefs(defs: CirruEdnValue, ns: string): Table[string, CirruData] =
  result = initTable[string, CirruData]()

  if defs.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  for name, def in defs.mapVal:
    if name.kind != crEdnString:
      raise newException(ValueError, "expects a string")
    result[name.stringVal] = getSourceNode(def, ns)

  return result

proc extractFile*(v: CirruEdnValue, ns: string): FileSource =
  if v.kind != crEdnMap:
    raise newException(ValueError, "expects a map")
  var file: FileSource

  if v.containsKwd("ns"):
    let nsCode = v.getKwd("ns")
    file.ns = getSourceNode(nsCode, ns)

  if v.containsKwd("proc"):
    let run = v.getKwd("proc")
    file.run = getSourceNode(run, ns)

  let defs = v.getKwd("defs")
  file.defs = extractDefs(defs, ns)

  return file

proc getCodeConfigs(initialData: CirruEdnValue): CodeConfigs =
  var codeConfigs = CodeConfigs()

  if not initialData.containsKwd("configs"):
    raise newException(ValueError, "expects configs field")
  let configs = initialData.getKwd("configs")
  if configs.kind != crEdnMap:
    raise newException(ValueError, "expects configs to be a map")

  if configs.containsKwd("init-fn"):
    let initFn = configs.getKwd("init-fn")
    if initFn.kind == crEdnString:
      codeConfigs.initFn = initFn.stringVal

  if configs.containsKwd("reload-fn"):
    let reloadFn = configs.getKwd("reload-fn",)
    if reloadFn.kind == crEdnString:
      codeConfigs.reloadFn = reloadFn.stringVal

  let package = initialData.getKwd("package",)
  if package.kind != crEdnString:
    raise newException(ValueError, "expects a string")

  if configs.containsKwd("modules"):
    let modulesList = configs.getKwd("modules")
    if modulesList.kind == crEdnVector:
      for item in modulesList.vectorVal:
        if item.kind != crEdnString:
          raise newException(ValueError, "expects string")
        codeConfigs.modules.add item.stringVal
    elif modulesList.kind == crEdnNil:
      discard
    else:
      raise newException(ValueError, "expects a vector for modules")


  codeConfigs.pkg = package.stringVal

  return codeConfigs

proc loadSnapshot*(snapshotFile: string): tuple[files: Table[string, FileSource], configs: CodeConfigs] =
  if not fileExists(snapshotFile):
    raise newException(ValueError, "snapshot is not found: " & snapshotFile)

  let content = readFile snapshotFile
  let initialData = parseCirruEdn content
  var compactFiles = initTable[string, FileSource]()

  if initialData.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  let files = initialData.getKwd("files")

  if files.kind != crEdnMap:
    raise newException(ValueError, "expects a map")
  for k, v in files.mapVal:
    if k.kind != crEdnString:
      raise newException(ValueError, "expects a string")
    compactFiles[k.stringVal] = extractFile(v, k.stringVal)

  (compactFiles, getCodeConfigs(initialData))

proc extractStringSet(xs: CirruEdnValue): HashSet[string] =
  if xs.kind != crEdnSet:
    echo "received value: ", xs.kind, " ", xs
    raise newException(ValueError, "parameter is not a EDN set, can't extract")

  let values = xs.map(proc (x: CirruEdnValue): string =
    if x.kind != crEdnString:
      raise newException(ValueError, "expects strings in set")
    return x.stringVal
  )

  return toHashSet(values)

proc extractFileChangeDetail(originalFile: var FileSource, ns: string, changedFile: CirruEdnValue): void =
  if changedFile.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  if changedFile.containsKwd("ns"):
    let data = changedFile.getKwd("ns")
    coloredEcho fgMagenta, "patching: ns changed"
    originalFile.ns = getSourceNode(data, ns)

  if changedFile.containsKwd("proc"):
    let data = changedFile.getKwd("proc")
    coloredEcho fgMagenta, "patching: proc changed"
    originalFile.run = getSourceNode(data, ns)

  if changedFile.containsKwd("removed-defs"):
    let data = changedFile.getKwd("removed-defs")
    let removedDefs = extractStringSet(data)
    for x in removedDefs:
      coloredEcho fgMagenta, "patching: removed def ", x
      originalFile.defs.del x

  if changedFile.containsKwd("added-defs"):
    let data = changedFile.getKwd("added-defs")
    for k, v in extractDefs(data, ns):
      coloredEcho fgMagenta, "patching: added def ", k
      originalFile.defs[k] = v

  if changedFile.containsKwd("changed-defs"):
    let data = changedFile.getKwd("changed-defs")
    for k, v in extractDefs(data, ns):
      coloredEcho fgMagenta, "patching: updated def ", k
      originalFile.defs[k] = v

proc loadChanges*(incrementFile: string, programData: var Table[string, FileSource]): void =
  let content = readFile incrementFile
  let changesInfo = parseCirruEdn content

  if changesInfo.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  if changesInfo.containsKwd("removed"):
    let namesInfo = changesInfo.getKwd("removed")
    let removedNs = extractStringSet(namesInfo)
    for x in removedNs:
      coloredEcho fgMagenta, "patching, removing ns: ", x
      programData.del x

  if changesInfo.containsKwd("added"):
    let added = changesInfo.getKwd("added")
    if added.kind != crEdnMap:
      raise newException(ValueError, "expects a map")
    for k, v in added.mapVal:
      if k.kind != crEdnString:
        raise newException(ValueError, "expects a string")
      coloredEcho fgMagenta, "patching, add ns: ", k.stringVal
      programData[k.stringVal] = extractFile(v, k.stringVal)

  if changesInfo.containsKwd("changed"):
    let changed = changesInfo.getKwd("changed")
    if changed.kind != crEdnMap:
      raise newException(ValueError, "expects a map")

    for k, v in changed.mapVal:
      if k.kind != crEdnString:
        raise newException(ValueError, "expects a string")
      extractFileChangeDetail(programData[k.stringVal], k.stringVal, v)

  coloredEcho fgMagenta, "code updated from inc files"


# originally from clojure `(ns app.lib (:require [a.b :as a] [a.c :refer [b]]))`
# not in Cirru vectors, a little different, but `:as` and `:refer` are used
proc extractNsInfo*(exprNode: CirruData): Table[string, ImportInfo] =
  var dict: Table[string, ImportInfo]

  if exprNode.kind == crDataNil:
    return dict

  if exprNode.kind != crDataList:
    raiseEvalError("Expects a list to extract", exprNode)
  let nsNode = exprNode[0]
  if nsNode.kind != crDataSymbol:
    raiseEvalError("Expects an ns form", exprNode)

  # requires nothing
  if exprNode.len < 3:
    return dict

  let requireArea = exprNode[2]
  if requireArea.kind != crDataList:
    raiseEvalError("Expects require list in ns form", exprNode)
  let requireNode = requireArea[0]
  let nodeText = requireNode.keywordVal
  if not requireNode.isKeyword or nodeText != "require":
    raiseEvalError("Expects :require", requireNode)
  let requireList = requireArea[1..^1]

  for importDec in requireList:
    if importDec.kind != crDataList:
      raiseEvalError("Expects import rule in list", exprNode)
    if importDec.len != 4:
      raiseEvalError("Expects import rule in length 4", exprNode)
    let vectorSymbol = importDec[0]
    if vectorSymbol.kind != crDataSymbol or vectorSymbol.symbolVal != "[]":
      raiseEvalError("Expects [] in import rule", importDec)

    let nsPart = importDec[1]
    var nsName: string
    var nsInStr = false
    case nsPart.kind
    of crDataSymbol:
      nsName = nsPart.symbolVal
    of crDataString:
      nsName = nsPart.stringVal
      nsInStr = true
    else:
      raiseEvalError("Expects ns field in symbol/string", importDec)

    let importOp = importDec[2]
    if not importOp.isKeyword:
      raiseEvalError("Expects import op in keyword", importOp)
    case importOp.keywordVal:
    of "as":
      let aliasName = importDec[3]
      if aliasName.kind != crDataSymbol:
        raiseEvalError("Expects alias name in symbol", aliasName)
      dict[aliasName.symbolVal] = ImportInfo(kind: importNs, ns: nsName, nsInStr: nsInStr)
    of "refer":
      let defsList = importDec[3]
      if defsList.kind != crDataList:
        raiseEvalError("Expects a list of defs", defsList)
      if defsList.len < 1:
        raiseEvalError("Import declaration too short", defsList)
      let vectorSymbol = defsList[0]
      if not vectorSymbol.isSymbol:
        raiseEvalError("Expects [] in import rule", defsList)
      for defName in defsList[1..^1]:
        if defName.kind != crDataSymbol:
          raiseEvalError("Expects a def string to refer", defName)
        dict[defName.symbolVal] = ImportInfo(kind: importDef, ns: nsName, nsInStr: nsInStr, def: defName.symbolVal)

  return dict

proc parseEvalMain*(code: string, ns: string): CirruData =
  let tree = parseCirru(code)
  tree.nodesToCirruData(ns)
