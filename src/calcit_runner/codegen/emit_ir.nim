
import os
import options
import tables

import json
import ternary_tree

import ../types
import ../data/virtual_list
import ../compiler_configs

# mutual recursion
proc dumpCode(xs: CirruData): JsonNode

proc dumpCode(xs: seq[CirruData]): JsonNode =
  var ys: seq[JsonNode]
  for item in xs:
    ys.add dumpCode(item)

  %*ys

proc dumpCode(xs: CrVirtualList[CirruData]): JsonNode =
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
  of crDataSymbol:
    var resolvedData =
      if xs.resolved.kind == resolvedDef:
        let resolved = xs.resolved
        %* {
          "kind": $xs.resolved.kind,
          "ns": resolved.ns,
          "def": resolved.def,
          "nsInStr": resolved.nsInStr
        }
      else:
        %* {
          "kind": $xs.resolved.kind,
        }
    %* {
      "kind": "symbol",
      "val": xs.symbolVal,
      "ns": xs.ns,
      "resolved": resolvedData
    }
  of crDataFn:
    if xs.fnBuiltin:
      %* {
        "kind": "fn",
        "name": xs.fnName,
        "builtin": true,
      }
    else:
      %* {
        "kind": "fn",
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

proc emitIR*(programData: Table[string, ProgramEvaledData], initFn, reloadFn: string): void =
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
  if dirExists(codeEmitPath).not:
    createDir(codeEmitPath)

  writeFile (codeEmitPath & "/program-ir.json"), content
  echo "emitted to ", (codeEmitPath & "/program-ir.json")
