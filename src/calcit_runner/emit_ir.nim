
import os
import options
import tables

import cirru_edn
import ternary_tree

import ./types

var irMode* = false
var emitPath = "js-out"

# mutual recursion
proc dumpCode(xs: CirruData): CirruEdnValue

proc dumpCode(xs: seq[CirruData]): CirruEdnValue =
  var ys: seq[CirruEdnValue]
  for item in xs:
    ys.add dumpCode(item)

  CirruEdnValue(kind: crEdnList, listVal: ys)

proc dumpCode(xs: TernaryTreeList[CirruData]): CirruEdnValue =
  var ys: seq[CirruEdnValue]
  for item in xs:
    ys.add dumpCode(item)

  CirruEdnValue(kind: crEdnList, listVal: ys)

proc kwd(x: string): CirruEdnValue =
  genCrEdnKeyword(x)

proc dumpCode(xs: CirruData): CirruEdnValue =
  case xs.kind
  of crDataNumber:
    genCrEdn(xs.numberVal)
  of crDataNil:
    genCrEdn()
  of crDataString:
    genCrEdn(xs.stringVal)
  of crDataBool:
    genCrEdn(xs.boolVal)
  of crDataKeyword:
    kwd(xs.keywordVal)
  of crDataProc:
    genCrEdnMap(
      kwd("kind"), kwd("proc"),
    )
  of crDataSymbol:
    var resolvedData =
      if xs.resolved.isSome():
        let resolved = xs.resolved.get()
        genCrEdnMap(
          kwd("ns"), genCrEdn(resolved.ns),
          kwd("def"), genCrEdn(resolved.def),
          kwd("ns-in-str?"), genCrEdn(resolved.nsInStr),
        )
      else:
        genCrEdn()
    genCrEdnMap(
      kwd("kind"), kwd("symbol"),
      kwd("val"), genCrEdn(xs.symbolVal),
      kwd("ns"), genCrEdn(xs.ns),
      kwd("dynamic?"), genCrEdn(xs.dynamic),
      kwd("resolved"), resolvedData,
    )
  of crDataFn:
    genCrEdnMap(
      kwd("kind"), kwd("fn"),
      kwd("ns"), genCrEdn(xs.fnNs),
      kwd("name"), genCrEdn(xs.fnName),
      kwd("args"), dumpCode(xs.fnArgs),
      kwd("code"), dumpCode(xs.fnCode)
    )
  of crDataThunk:
    dumpCode(xs.thunkCode[])
  of crDataList:
    dumpCode(xs.listVal)
  else:
    genCrEdn("...TODO")

proc emitIR*(programData: Table[string, ProgramFile], initFn, reloadFn: string): void =
  var files = CirruEdnValue(kind: crEdnMap, mapVal: initTable[CirruEdnValue, CirruEdnValue]())
  let configs = genCrEdnMap(
    genCrEdn("init-fn"), genCrEdn(initFn),
    genCrEdn("reload-fn"), genCrEdn(reloadFn),
  )

  for ns, file in programData:

    var defsData = CirruEdnValue(kind: crEdnMap, mapVal: initTable[CirruEdnValue, CirruEdnValue]())
    for def, defCode in file.defs:
      defsData.mapVal[genCrEdn(def)] = dumpCode(defCode)

    var nsData = CirruEdnValue(kind: crEdnMap, mapVal: initTable[CirruEdnValue, CirruEdnValue]())
    if file.ns.isSome():
      for target, importRule in file.ns.get():
        nsData.mapVal[genCrEdn(target)] = genCrEdnMap(
          genCrEdn("ns"), genCrEdn(importRule.ns),
          genCrEdn("ns-in-str?"), genCrEdn(importRule.nsInStr),
          genCrEdn("def"), genCrEdn(),
        )

    let fileData = genCrEdnMap(
      genCrEdn("ns"), nsData,
      genCrEdn("defs"), defsData,
    )
    files.mapVal[genCrEdn(ns)] = fileData

  let data = genCrEdnMap(
    genCrEdn("configs"), configs,
    genCrEdn("files"), files,
  )

  let content = data.formatToCirru(true)
  if dirExists(emitPath).not:
    createDir(emitPath)

  writeFile (emitPath & "/program-ir.cirru"), content
  echo "emitted to ", (emitPath & "/program-ir.cirru")
