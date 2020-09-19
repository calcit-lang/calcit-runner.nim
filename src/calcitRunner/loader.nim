import tables
import sets
import json
import terminal

import cirruEdn
import cirruParser

import ./types
import ./data
import ./helpers

var currentPackage*: string

proc `%`*(xs: HashSet[string]): JsonNode =
  var list: seq[JsonNode] = @[]
  for x in xs:
    list.add JsonNode(kind: JString, str: x)
  JsonNode(kind: JArray, elems: list)

proc getSourceNode(v: CirruEdnValue, ns: string): CirruData =
  if v.kind != crEdnQuotedCirru:
    echo "current node: ", v
    raise newException(ValueError, "Unexpected quoted cirru node")

  return v.quotedVal.toCirruData(ns)

proc extractDefs(defs: CirruEdnValue, ns: string): Table[string, CirruData] =
  result = initTable[string, CirruData]()

  if defs.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  for name, def in defs.mapVal:
    if name.kind != crEdnString:
      raise newException(ValueError, "expects a string")
    result[name.stringVal] = getSourceNode(def, ns)

  return result

proc extractFile(v: CirruEdnValue, ns: string): FileSource =
  if v.kind != crEdnMap:
    raise newException(ValueError, "expects a map")
  var file: FileSource

  if v.contains(crEdn("ns", true)):
    let nsCode = v.get(crEdn("ns", true))
    file.ns = getSourceNode(nsCode, ns)

  if v.contains(crEdn("proc", true)):
    let run = v.get(crEdn("proc", true))
    file.run = getSourceNode(run, ns)

  let defs = v.get(crEdn("defs", true))
  file.defs = extractDefs(defs, ns)

  return file

proc loadSnapshot*(snapshotFile: string): Table[string, FileSource] =
  let content = readFile snapshotFile
  let initialData = parseEdnFromStr content
  var compactFiles = initTable[string, FileSource]()

  if initialData.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  let package = initialData.get(crEdn("package", true))
  if package.kind != crEdnString:
    raise newException(ValueError, "expects a string")
  currentPackage = package.stringVal

  let files = initialData.get(crEdn("files", true))

  if files.kind != crEdnMap:
    raise newException(ValueError, "expects a map")
  for k, v in files.mapVal:
    if k.kind != crEdnString:
      raise newException(ValueError, "expects a string")
    compactFiles[k.stringVal] = extractFile(v, k.stringVal)

  return compactFiles


proc extractStringSet(xs: CirruEdnValue): HashSet[string] =
  if xs.kind != crEdnSet:
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

  if changedFile.contains(crEdn("ns", true)):
    let data = changedFile.get(crEdn("ns", true))
    coloredEcho fgMagenta, "patching: ns changed"
    originalFile.ns = getSourceNode(data, ns)

  if changedFile.contains(crEdn("proc", true)):
    let data = changedFile.get(crEdn("proc", true))
    coloredEcho fgMagenta, "patching: proc changed"
    originalFile.run = getSourceNode(data, ns)

  if changedFile.contains(crEdn("removed-defs", true)):
    let data = changedFile.get(crEdn("removed-defs", true))
    let removedDefs = extractStringSet(data)
    for x in removedDefs:
      coloredEcho fgMagenta, "patching: removed def ", x
      originalFile.defs.del x

  if changedFile.contains(crEdn("added-defs", true)):
    let data = changedFile.get(crEdn("added-defs", true))
    for k, v in extractDefs(data, ns):
      coloredEcho fgMagenta, "patching: added def ", k
      originalFile.defs[k] = v

  if changedFile.contains(crEdn("changed-defs", true)):
    let data = changedFile.get(crEdn("changed-defs", true))
    for k, v in extractDefs(data, ns):
      coloredEcho fgMagenta, "patching: updated def ", k
      originalFile.defs[k] = v

proc loadChanges*(incrementFile: string, programData: var Table[string, FileSource]): void =
  let content = readFile incrementFile
  let changesInfo = parseEdnFromStr content

  if changesInfo.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  if changesInfo.contains(crEdn("removed", true)):
    let namesInfo = changesInfo.get(crEdn("removed", true))
    let removedNs = extractStringSet(namesInfo)
    for x in removedNs:
      coloredEcho fgMagenta, "patching, removing ns: ", x
      programData.del x

  if changesInfo.contains(crEdn("added", true)):
    let added = changesInfo.get(crEdn("added", true))
    if added.kind != crEdnMap:
      raise newException(ValueError, "expects a map")
    for k, v in added.mapVal:
      if k.kind != crEdnString:
        raise newException(ValueError, "expects a string")
      coloredEcho fgMagenta, "patching, add ns: ", k.stringVal
      programData[k.stringVal] = extractFile(v, k.stringVal)

  if changesInfo.contains(crEdn("changed", true)):
    let changed = changesInfo.get(crEdn("changed", true))
    if changed.kind != crEdnMap:
      raise newException(ValueError, "expects a map")

    for k, v in changed.mapVal:
      if k.kind != crEdnString:
        raise newException(ValueError, "expects a string")
      extractFileChangeDetail(programData[k.stringVal], k.stringVal, v)

  coloredEcho fgMagenta, "code updated from inc files"

proc loadCodeConfigs*(snapshotFile: string): CodeConfigs =
  let content = readFile snapshotFile
  let initialData = parseEdnFromStr content

  var codeConfigs = CodeConfigs()

  if not initialData.contains(crEdn("configs", true)):
    raise newException(ValueError, "expects configs field")
  let configs = initialData.get(crEdn("configs", true))
  if configs.kind != crEdnMap:
    raise newException(ValueError, "expects configs to be a map")

  if configs.contains(crEdn("init-fn", true)):
    let initFn = configs.get(crEdn("init-fn", true))
    if initFn.kind == crEdnString:
      codeConfigs.initFn = initFn.stringVal

  if configs.contains(crEdn("reload-fn", true)):
    let reloadFn = configs.get(crEdn("reload-fn", true))
    if reloadFn.kind == crEdnString:
      codeConfigs.reloadFn = reloadFn.stringVal

  return codeConfigs
