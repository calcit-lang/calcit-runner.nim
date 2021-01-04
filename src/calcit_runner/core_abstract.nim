
import tables

import cirru_edn

import ./types
import ./loader

const coreSource = staticRead"../includes/calcit-core.cirru"

proc loadCoreFuncs*(programCode: var Table[string, FileSource]) =
  let initialData = parseCirruEdn coreSource

  if initialData.kind != crEdnMap: raise newException(ValueError, "expects a map from calcit-core.cirru")
  let files = initialData.get(genCrEdnKeyword("files"))

  if files.kind != crEdnMap: raise newException(ValueError, "expects a map in :files of calcit-core.cirru")
  for k, v in files.mapVal:
    if k.kind != crEdnString:
      raise newException(ValueError, "expects a string")
    for defName, defCode in extractFile(v, k.stringVal).defs:
      programCode[k.stringVal].defs[defName] = defCode
