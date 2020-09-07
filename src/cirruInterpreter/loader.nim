import tables
import sets
import json

import cirruEdn
import cirruParser

import ./types


type FileSource* = object
  ns*: MaybeNil[CirruNode]
  run: MaybeNil[CirruNode]
  defs*: Table[string, CirruNode]

type FileChangeDetail = object
  ns*: MaybeNil[CirruNode]
  run: MaybeNil[CirruNode]
  removedDefs*: MaybeNil[HashSet[string]]
  addedDefs*: MaybeNil[Table[string, CirruNode]]
  changedDefs*: MaybeNil[Table[string, CirruNode]]

type FileChanges = object
  removed*: MaybeNil[HashSet[string]]
  added*: MaybeNil[Table[string, FileSource]]
  changed*: MaybeNil[Table[string, FileChangeDetail]]

var currentPackage*: string

let snapshotFile* = "example/compact.cirru"
let incrementFile* = "example/.compact-inc.cirru"

proc `%`*(xs: HashSet[string]): JsonNode =
  var list: seq[JsonNode] = @[]
  for x in xs:
    list.add JsonNode(kind: JString, str: x)
  JsonNode(kind: JArray, elems: list)

proc getSourceNode(v: CirruEdnValue): CirruNode =
  if v.kind != crEdnQuotedCirru:
    echo "current node: ", v
    raise newException(ValueError, "Unexpected quoted cirru node")

  return v.quotedVal

proc extractDefs(defs: CirruEdnValue): Table[string, CirruNode] =
  result = initTable[string, CirruNode]()

  if defs.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  for name, def in defs.mapVal:
    if name.kind != crEdnString:
      raise newException(ValueError, "expects a string")
    result[name.stringVal] = getSourceNode(def)

  return result

proc extractFile(v: CirruEdnValue): FileSource =
  if v.kind != crEdnMap:
    raise newException(ValueError, "expects a map")
  var file: FileSource

  if v.contains(crEdn("ns", true)):
    let ns = v.get(crEdn("ns", true))
    file.ns = MaybeNil[CirruNode](kind: beSomething, value: getSourceNode(ns))
  else:
    file.ns = MaybeNil[CirruNode](kind: beNil)

  if v.contains(crEdn("proc", true)):
    let run = v.get(crEdn("proc", true))
    file.run = MaybeNil[CirruNode](kind: beSomething, value: getSourceNode(run))
  else:
    file.run = MaybeNil[CirruNode](kind: beNil)

  let defs = v.get(crEdn("defs", true))
  file.defs = extractDefs(defs)

  return file

proc loadSnapshot*(): Table[string, FileSource] =
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
    compactFiles[k.stringVal] = extractFile(v)

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

proc extractFileChangeDetail(changedFile: CirruEdnValue): FileChangeDetail =
  if changedFile.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  var changesDetail: FileChangeDetail

  if changedFile.contains(crEdn("ns", true)):
    let data = changedFile.get(crEdn("ns", true))
    changesDetail.ns = MaybeNil[CirruNode](kind: beSomething, value: getSourceNode(data))
  else:
    changesDetail.ns = MaybeNil[CirruNode](kind: beNil)

  if changedFile.contains(crEdn("proc", true)):
    let data = changedFile.get(crEdn("proc", true))
    changesDetail.run = MaybeNil[CirruNode](kind: beSomething, value: getSourceNode(data))
  else:
    changesDetail.run = MaybeNil[CirruNode](kind: beNil)

  if changedFile.contains(crEdn("removed-defs", true)):
    let data = changedFile.get(crEdn("removed-defs", true))
    changesDetail.removedDefs = MaybeNil[HashSet[string]](kind: beSomething, value: extractStringSet(data))
  else:
    changesDetail.removedDefs = MaybeNil[HashSet[string]](kind: beNil)

  if changedFile.contains(crEdn("added-defs", true)):
    let data = changedFile.get(crEdn("added-defs", true))
    changesDetail.addedDefs = MaybeNil[Table[string, CirruNode]](kind: beSomething, value: extractDefs(data))
  else:
    changesDetail.addedDefs = MaybeNil[Table[string, CirruNode]](kind: beNil)

  if changedFile.contains(crEdn("changed-defs", true)):
    let data = changedFile.get(crEdn("changed-defs", true))
    changesDetail.changedDefs = MaybeNil[Table[string, CirruNode]](kind: beSomething, value: extractDefs(data))
  else:
    changesDetail.changedDefs = MaybeNil[Table[string, CirruNode]](kind: beNil)

  return changesDetail

proc loadChanges*(programData: var Table[string, FileSource]): void =
  let content = readFile incrementFile
  let changesInfo = parseEdnFromStr content

  var changedData = FileChanges()

  if changesInfo.kind != crEdnMap:
    raise newException(ValueError, "expects a map")

  if changesInfo.contains(crEdn("removed", true)):
    let namesInfo = changesInfo.get(crEdn("removed", true))
    changedData.removed = MaybeNil[HashSet[string]](kind: beSomething, value: extractStringSet(namesInfo))
  else:
    changedData.removed = MaybeNil[HashSet[string]](kind: beNil)

  if changesInfo.contains(crEdn("added", true)):
    var newFiles = Table[string, FileSource]()
    let added = changesInfo.get(crEdn("added", true))
    if added.kind != crEdnMap:
      raise newException(ValueError, "expects a map")
    for k, v in added.mapVal:
      if k.kind != crEdnString:
        raise newException(ValueError, "expects a string")
      newFiles[k.stringVal] = extractFile(v)
    changedData.added = MaybeNil[Table[string, FileSource]](kind: beSomething, value: newFiles)
  else:
    changedData.added = MaybeNil[Table[string, FileSource]](kind: beNil)

  if changesInfo.contains(crEdn("changed", true)):
    let changed = changesInfo.get(crEdn("changed", true))
    if changed.kind != crEdnMap:
      raise newException(ValueError, "expects a map")

    var dict = Table[string, FileChangeDetail]()
    for k, v in changed.mapVal:
      if k.kind != crEdnString:
        raise newException(ValueError, "expects a string")
      dict[k.stringVal] = extractFileChangeDetail(v)
    changedData.changed = MaybeNil[Table[string, FileChangeDetail]](kind: beSomething, value: dict)
  else:
    changedData.changed = MaybeNil[Table[string, FileChangeDetail]](kind: beNil)


  discard changedData
