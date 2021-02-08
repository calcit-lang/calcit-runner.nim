
import os
import options
import tables

import json
import ternary_tree

import ../types
import ../compiler_configs

# mutual recursion
proc dumpCode(xs: CirruData): JsonNode

proc dumpCode(xs: seq[CirruData]): JsonNode =
  var ys: seq[JsonNode]
  for item in xs:
    ys.add dumpCode(item)

  %*ys

proc dumpCode(xs: TernaryTreeList[CirruData]): JsonNode =
  var ys: seq[JsonNode]
  for item in xs:
    ys.add dumpCode(item)

  %*ys

proc dumpCode(xs: CirruData): JsonNode =
  case xs.kind
  of crDataNumber:
    %xs.numberVal
  of crDataNil:
    newJNull()
  of crDataString:
    %xs.stringVal
  of crDataBool:
    %*xs.boolVal
  of crDataKeyword:
    %* {
      "kind": "keyword", "val": xs.keywordVal,
    }
  of crDataProc:
    %* {
      "kind": "proc",
    }
  of crDataSymbol:
    var resolvedData =
      if xs.resolved.isSome():
        let resolved = xs.resolved.get()
        %* {
          "ns": resolved.ns,
          "def": resolved.def,
          "nsInStr": resolved.nsInStr
        }
      else:
        newJNull()
    %* {
      "kind": "symbol",
      "val": xs.symbolVal,
      "ns": xs.ns,
      "dynamic": xs.dynamic,
      "resolved": resolvedData
    }
  of crDataFn:
    %* {
      "kind": "fn",
      "ns": xs.fnNs,
      "name": xs.fnName,
      "args": dumpCode(xs.fnArgs),
      "code": dumpCode(xs.fnCode),
    }
  of crDataThunk:
    dumpCode(xs.thunkCode[])
  of crDataList:
    dumpCode(xs.listVal)
  else:
    %*("...TODO")

proc emitIR*(programData: Table[string, ProgramFile], initFn, reloadFn: string): void =
  var files = newJObject()
  for ns, file in programData:

    var defsData = newJObject()
    for def, defCode in file.defs:
      defsData[def] = dumpCode(defCode)

    var nsData = newJObject()
    if file.ns.isSome():
      for target, importRule in file.ns.get():
        let importKind = if importRule.kind == importDef: %"def" else: %"ns"
        let importDef = if importRule.kind == importDef: %importRule.def else: newJNull()
        nsData[target] = %* {
          "ns": importRule.ns,
          "nsInStr": importRule.nsInStr,
          "kind": importKind,
          "def": importDef,
        }

    let fileData = %* {
      "import": nsData, "defs": defsData
    }
    files[ns] = fileData

  let data = %* {
    "configs": {
      "initFn": initFn, "reloadFn": reloadFn,
    },
    "files": files
  }

  let content = data.pretty()
  if dirExists(irEmitPath).not:
    createDir(irEmitPath)

  writeFile (irEmitPath & "/program-ir.json"), content
  echo "emitted to ", (irEmitPath & "/program-ir.json")
