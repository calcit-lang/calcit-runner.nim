import tables
import sets

import cirruEdn

import ./types


type FileSource = object
  ns: MaybeNil[SourceNode]
  run: MaybeNil[SourceNode]
  defs: Table[string, SourceNode]

type FileChangeDetail = object
  ns: MaybeNil[SourceNode]
  run: MaybeNil[SourceNode]
  removedDefs: MaybeNil[HashSet[string]]
  addedDefs: MaybeNil[Table[string, SourceNode]]
  changedDefs: MaybeNil[Table[string, SourceNode]]

type FileChanges = object
  removed: MaybeNil[HashSet[string]]
  added: MaybeNil[Table[string, FileSource]]
  changed: MaybeNil[Table[string, FileChangeDetail]]

var currentPackage*: string
var compactFiles* = initTable[string, FileSource]()

let snapshotFile* = "example/compact.cirru"
let incrementFile* = "example/.compact-inc.cirru"


proc getSourceNode(v: CirruEdnValue): SourceNode =
  case v.kind:
  of crEdnString: return SourceNode(kind: sourceStr, text: v.stringVal)
  of crEdnVector:
    return SourceNode(kind: sourceSeq, list: v.vectorVal.map(getSourceNode))
  of crEdnList:
    return SourceNode(kind: sourceSeq, list: v.listVal.map(getSourceNode))
  else:
    raise newException(ValueError, "TODO")

proc extractDefs(defs: CirruEdnValue): Table[string, SourceNode] =
  result = initTable[string, SourceNode]()

  if defs.kind != crEdnMap:
    raise newException(ValueError, "TODO")

  for name, def in defs.mapVal:
    if name.kind != crEdnString:
      raise newException(ValueError, "TODO")
    result[name.stringVal] = getSourceNode(def)

  return result

proc extractFile(v: CirruEdnValue): FileSource =
  if v.kind != crEdnMap:
    raise newException(ValueError, "TODO")
  var file: FileSource

  if v.mapVal.hasKey(crEdn("ns", true)):
    let ns = v.mapVal[crEdn("ns", true)]
    file.ns = MaybeNil[SourceNode](kind: beSomething, value: getSourceNode(ns))
  else:
    file.ns = MaybeNil[SourceNode](kind: beNil)

  if v.mapVal.hasKey(crEdn("proc", true)):
    let run = v.mapVal[crEdn("proc", true)]
    file.run = MaybeNil[SourceNode](kind: beSomething, value: getSourceNode(run))
  else:
    file.run = MaybeNil[SourceNode](kind: beNil)

  let defs = v.mapVal[crEdn("defs", true)]
  file.defs = extractDefs(defs)

  return file

proc loadSnapshot*(): void =
  let content = readFile snapshotFile
  let initialData = parseEdnFromStr content

  if initialData.kind != crEdnMap:
    raise newException(ValueError, "TODO")

  let package = initialData.mapVal[crEdn("package", true)]
  if package.kind != crEdnString:
    raise newException(ValueError, "TODO")
  currentPackage = package.stringVal

  let files = initialData.mapVal[crEdn("files", true)]

  if files.kind != crEdnMap:
    raise newException(ValueError, "TODO")
  for k, v in files.mapVal:
    if k.kind != crEdnString:
      raise newException(ValueError, "TODO")
    compactFiles[k.stringVal] = extractFile(v)

  echo "loaded"
  echo compactFiles
  echo ""


proc extractStringSet(xs: CirruEdnValue): HashSet[string] =
  if xs.kind != crEdnSet:
    raise newException(ValueError, "parameter is not a EDN set, can't extract")

  let values = xs.map(proc (x: CirruEdnValue): string =
    if x.kind != crEdnString:
      raise newException(ValueError, "expects strings in set")
    return x.stringVal
  )

  return toHashSet(values)

proc extractFileChangeDetail(changedFile: CirruEdnValue): FileChangeDetail =
  if changedFile.kind != crEdnMap:
    raise newException(ValueError, "TODO")

  var changesDetail: FileChangeDetail

  if changedFile.mapVal.hasKey(crEdn("ns", true)):
    let data = changedFile.mapVal[crEdn("ns", true)]
    changesDetail.ns = MaybeNil[SourceNode](kind: beSomething, value: getSourceNode(data))
  else:
    changesDetail.ns = MaybeNil[SourceNode](kind: beNil)

  if changedFile.mapVal.hasKey(crEdn("proc", true)):
    let data = changedFile.mapVal[crEdn("proc", true)]
    changesDetail.run = MaybeNil[SourceNode](kind: beSomething, value: getSourceNode(data))
  else:
    changesDetail.run = MaybeNil[SourceNode](kind: beNil)

  if changedFile.mapVal.hasKey(crEdn("removed-defs", true)):
    let data = changedFile.mapVal[crEdn("removed-defs", true)]
    changesDetail.removedDefs = MaybeNil[HashSet[string]](kind: beSomething, value: extractStringSet(data))
  else:
    changesDetail.removedDefs = MaybeNil[HashSet[string]](kind: beNil)

  if changedFile.mapVal.hasKey(crEdn("added-defs", true)):
    let data = changedFile.mapVal[crEdn("added-defs", true)]
    changesDetail.addedDefs = MaybeNil[Table[string, SourceNode]](kind: beSomething, value: extractDefs(data))
  else:
    changesDetail.addedDefs = MaybeNil[Table[string, SourceNode]](kind: beNil)

  if changedFile.mapVal.hasKey(crEdn("changed-defs", true)):
    let data = changedFile.mapVal[crEdn("changed-defs", true)]
    changesDetail.changedDefs = MaybeNil[Table[string, SourceNode]](kind: beSomething, value: extractDefs(data))
  else:
    changesDetail.changedDefs = MaybeNil[Table[string, SourceNode]](kind: beNil)

  return changesDetail

proc loadChanges*(): void =
  let content = readFile incrementFile
  let changesInfo = parseEdnFromStr content

  var changedData = FileChanges()

  if changesInfo.kind != crEdnMap:
    raise newException(ValueError, "TODO")

  if changesInfo.mapVal.hasKey(crEdn("removed", true)):
    let namesInfo = changesInfo.mapVal[crEdn("removed", true)]
    changedData.removed = MaybeNil[HashSet[string]](kind: beSomething, value: extractStringSet(namesInfo))
  else:
    changedData.removed = MaybeNil[HashSet[string]](kind: beNil)

  if changesInfo.mapVal.hasKey(crEdn("added", true)):
    var newFiles = Table[string, FileSource]()
    let added = changesInfo.mapVal[crEdn("added", true)]
    if added.kind != crEdnMap:
      raise newException(ValueError, "TODO")
    for k, v in added.mapVal:
      if k.kind != crEdnString:
        raise newException(ValueError, "TODO")
      newFiles[k.stringVal] = extractFile(v)
    changedData.added = MaybeNil[Table[string, FileSource]](kind: beSomething, value: newFiles)
  else:
    changedData.added = MaybeNil[Table[string, FileSource]](kind: beNil)

  if changesInfo.mapVal.hasKey(crEdn("changed", true)):
    let changed = changesInfo.mapVal[crEdn("changed", true)]
    if changed.kind != crEdnMap:
      raise newException(ValueError, "TODO")

    var dict = Table[string, FileChangeDetail]()
    for k, v in changed.mapVal:
      if k.kind != crEdnString:
        raise newException(ValueError, "TODO")
      dict[k.stringVal] = extractFileChangeDetail(v)
    changedData.changed = MaybeNil[Table[string, FileChangeDetail]](kind: beSomething, value: dict)
  else:
    changedData.changed = MaybeNil[Table[string, FileChangeDetail]](kind: beNil)

  echo "TODO changes", changedData
