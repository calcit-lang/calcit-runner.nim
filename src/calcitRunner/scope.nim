
import tables
import options

import cirruParser
import cirruEdn

import ./types
import ./helpers

proc get*(scope: CirruEdnScope, name: string): Option[CirruEdnValue] =
  if scope.dict.hasKey(name):
    return some(scope.dict[name])
  else:
    if scope.parent.isSome:
      return get(scope.parent.get, name)
    else:
      return none(CirruEdnValue)

# originally from clojure `(ns app.lib (:require [a.b :as a] [a.c :refer [b]]))`
# not in Cirru vectors, a little different, but `:as` and `:refer` are copied
proc extractNsInfo*(exprNode: CirruNode): Table[string, ImportInfo] =
  var dict: Table[string, ImportInfo]

  if exprNode.kind != cirruSeq:
    raiseInterpretExceptionAtNode("Expects a list to extract", exprNode)
  let nsNode = exprNode[0]
  if nsNode.kind != cirruString:
    raiseInterpretExceptionAtNode("Expects an ns form", exprNode)
  if exprNode.len != 3:
    raiseInterpretExceptionAtNode("Expects ns form in length 3, currently...", exprNode)
  let requireArea = exprNode[2]
  if requireArea.kind != cirruSeq:
    raiseInterpretExceptionAtNode("Expects require list in ns form", exprNode)
  let requireNode = requireArea[0]
  if requireNode.kind != cirruString or requireNode.text != ":require":
    raiseInterpretExceptionAtNode("Expects :require", exprNode)
  let requireList = requireArea[1..^1]

  for importDec in requireList:
    if importDec.kind != cirruSeq:
      raiseInterpretExceptionAtNode("Expects import rule in list", exprNode)
    if importDec.len != 4:
      raiseInterpretExceptionAtNode("Expects import rule in length 4", exprNode)
    let vectorSymbol = importDec[0]
    if vectorSymbol.kind != cirruString or vectorSymbol.text != "[]":
      raiseInterpretExceptionAtNode("Expects [] in import rule", importDec)
    let nsPart = importDec[1]
    if nsPart.kind != cirruString:
      raiseInterpretExceptionAtNode("Expects ns field in string", importDec)
    let importOp = importDec[2]
    if importOp.kind != cirruString:
      raiseInterpretExceptionAtNode("Expects import op in string", importOp)
    case importOp.text:
    of ":as":
      let aliasName = importDec[3]
      if aliasName.kind != cirruString:
        raiseInterpretExceptionAtNode("Expects alias name in string", aliasName)
      dict[aliasName.text] = ImportInfo(kind: importNs, ns: nsPart.text)
    of ":refer":
      let defsList = importDec[3]
      if defsList.kind != cirruSeq:
        raiseInterpretExceptionAtNode("Expects a list of defs", defsList)
      if defsList.len < 1:
        raiseInterpretExceptionAtNode("Import declaration too short", defsList)
      let vectorSymbol = defsList[0]
      if vectorSymbol.kind != cirruString:
        raiseInterpretExceptionAtNode("Expects [] in import rule", defsList)
      for defName in defsList[1..^1]:
        if defName.kind != cirruString:
          raiseInterpretExceptionAtNode("Expects a def string to refer", defName)
        dict[defName.text] = ImportInfo(kind: importDef, ns: nsPart.text, def: defName.text)

  return dict
