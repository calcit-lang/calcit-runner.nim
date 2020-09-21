
import tables
import options
import strutils

import ./types
import ./data
import ./helpers

proc get*(scope: CirruDataScope, name: string): Option[CirruData] =
  if scope.dict.hasKey(name):
    return some(scope.dict[name])
  else:
    if scope.parent.isSome:
      return get(scope.parent.get, name)
    else:
      return none(CirruData)

# originally from clojure `(ns app.lib (:require [a.b :as a] [a.c :refer [b]]))`
# not in Cirru vectors, a little different, but `:as` and `:refer` are copied
proc extractNsInfo*(exprNode: CirruData): Table[string, ImportInfo] =
  var dict: Table[string, ImportInfo]

  if exprNode.kind != crDataList:
    raiseEvalError("Expects a list to extract", exprNode)
  let nsNode = exprNode[0]
  if nsNode.kind != crDataSymbol:
    raiseEvalError("Expects an ns form", exprNode)
  if exprNode.len != 3:
    raiseEvalError("Expects ns form in length 3, currently...", exprNode)
  let requireArea = exprNode[2]
  if requireArea.kind != crDataList:
    raiseEvalError("Expects require list in ns form", exprNode)
  let requireNode = requireArea[0]
  if requireNode.kind != crDataSymbol or requireNode.symbolVal != ":require":
    raiseEvalError("Expects :require", exprNode)
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
    if nsPart.kind != crDataSymbol:
      raiseEvalError("Expects ns field in string", importDec)
    let importOp = importDec[2]
    if importOp.kind != crDataSymbol:
      raiseEvalError("Expects import op in string", importOp)
    case importOp.symbolVal:
    of ":as":
      let aliasName = importDec[3]
      if aliasName.kind != crDataSymbol:
        raiseEvalError("Expects alias name in string", aliasName)
      dict[aliasName.symbolVal] = ImportInfo(kind: importNs, ns: nsPart.symbolVal)
    of ":refer":
      let defsList = importDec[3]
      if defsList.kind != crDataList:
        raiseEvalError("Expects a list of defs", defsList)
      if defsList.len < 1:
        raiseEvalError("Import declaration too short", defsList)
      let vectorSymbol = defsList[0]
      if vectorSymbol.kind != crDataSymbol:
        raiseEvalError("Expects [] in import rule", defsList)
      for defName in defsList[1..^1]:
        if defName.kind != crDataSymbol:
          raiseEvalError("Expects a def string to refer", defName)
        dict[defName.symbolVal] = ImportInfo(kind: importDef, ns: nsPart.symbolVal, def: defName.symbolVal)

  return dict

proc clearProgramDefs*(programData: var Table[string, ProgramFile]): void =
  for ns, f in programData:
    var file = programData[ns]
    if not ns.startsWith("calcit."):
      file.ns = none(Table[string, ImportInfo])
      file.defs.clear
