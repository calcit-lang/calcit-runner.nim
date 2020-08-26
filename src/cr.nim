
import os
import re
import sequtils
from strutils import join, parseInt
import strformat
import osproc
import streams
import terminal
import tables
import sets

import cirruParser
import cirruEdn

import cirruInterpreter/types
import cirruInterpreter/operations
import cirruInterpreter/helpers


proc interpret(expr: CirruNode): CirruValue =
  if expr.kind == cirruString:
    if match(expr.text, re"\d+"):
      return CirruValue(kind: crValueInt, intVal: parseInt(expr.text))
    elif expr.text == "true":
      return CirruValue(kind: crValueBool, boolVal: true)
    elif expr.text == "false":
      return CirruValue(kind: crValueBool, boolVal: false)
    elif (expr.text.len > 0) and (expr.text[0] == '|' or expr.text[0] == '"'):
      return CirruValue(kind: crValueString, stringVal: expr.text[1..^1])
    else:
      return CirruValue(kind: crValueString, stringVal: expr.text)
  else:
    if expr.list.len == 0:
      return
    else:
      let head = expr.list[0]
      case head.kind
      of cirruString:
        case head.text
        of "println", "echo":
          echo expr.list[1..^1].map(interpret).map(toString).join(" ")
        of "+":
          return evalAdd(expr.list, interpret)
        of "-":
          return evalMinus(expr.list, interpret)
        of "if":
          return evalIf(expr.list, interpret)
        of "[]":
          return evalArray(expr.list, interpret)
        of "{}":
          return evalTable(expr.list, interpret)
        of "read-file":
          return evalReadFile(expr.list, interpret)
        of "write-file":
          return evalWriteFile(expr.list, interpret)
        of ";":
          return evalComment()
        of "load-json":
          return evalLoadJson(expr.list, interpret)
        of "type-of":
          return evalType(expr.list, interpret)
        else:
          let value = interpret(head)
          case value.kind
          of crValueString:
            var value = value.stringVal
            return callStringMethod(value, expr.list, interpret)
          else:
            raiseInterpretExceptionAtNode(fmt"Unknown head {head.text}", head)
      else:
        let headValue = interpret(expr.list[0])
        case headValue.kind:
        of crValueFn:
          echo "NOT implemented fn"
          quit 1
        of crValueArray:
          var value = headValue.arrayVal
          return callArrayMethod(value, expr.list, interpret)
        of crValueTable:
          var value = headValue.tableVal
          return callTableMethod(value, expr.list, interpret)
        else:
          echo "TODO"
          quit 1

proc evalFile(sourcePath: string): void =
  var source: string
  try:
    source = readFile sourcePath
    let program = parseCirru source
    case program.kind
    of cirruString:
      raise newException(CirruCommandError, "Call eval with code")
    of cirruSeq:
      # discard program.list.mapIt(interpret(it))
      echo "doing nothing"

  except CirruParseError as e:
    setForegroundColor(fgRed)
    echo "\nError: failed to parse"
    resetAttributes()
    echo formatParserFailure(source, e.msg, sourcePath, e.line, e.column)

  except CirruInterpretError as e:
    setForegroundColor(fgRed)
    echo "\nError: failed to interpret"
    resetAttributes()
    echo formatParserFailure(source, e.msg, sourcePath, e.line, e.column)

  except CirruCommandError as e:
    setForegroundColor(fgRed)
    echo "Failed to run command"
    raise e


type
  MaybeNilKind = enum
    beNil,
    beSomething
  MaybeNil[T] = ref object
    case kind: MaybeNilKind
    of beNil:
      discard
    of beSomething:
      value: T

type
  SourceKind* = enum
    sourceStr,
    sourceSeq

  SourceNode* = object
    case kind*: SourceKind
    of sourceStr:
      text*: string
    of sourceSeq:
      list*: seq[SourceNode]

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

var currentPackage: string
var compactFiles = initTable[string, FileSource]()

let snapshotFile = "example/compact.cirru"
let incrementFile = "example/.compact-inc.cirru"

var snapshot: int = 0

proc getSourceNode(v: CirruEdnValue): SourceNode =
  case v.kind:
  of crEdnString: return SourceNode(kind: sourceStr, text: v.stringVal)
  of crEdnVector:
    return SourceNode(kind: sourceSeq, list: v.vectorVal.map(getSourceNode))
  of crEdnList:
    return SourceNode(kind: sourceSeq, list: v.listVal.map(getSourceNode))
  else:
    raise newException(ValueError, "TODO")


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
  if defs.kind != crEdnMap:
    raise newException(ValueError, "TODO")

  for name, def in defs.mapVal:
    if name.kind != crEdnString:
      raise newException(ValueError, "TODO")
    file.defs[name.stringVal] = getSourceNode(def)

  return file

proc loadSnapshot(): void =
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


proc evalSnapshot(): void =
  echo "evaling", snapshot

proc extractFileChangeDetail(changedFile: CirruEdnValue): FileChangeDetail =
  echo "extracting... ", changedFile
  return FileChangeDetail()

proc loadChanges(): void =
  let content = readFile incrementFile
  let changesInfo = parseEdnFromStr content

  var changedData = FileChanges()

  if changesInfo.kind != crEdnMap:
    raise newException(ValueError, "TODO")

  if changesInfo.mapVal.hasKey(crEdn("removed", true)):
    let namesInfo = changesInfo.mapVal[crEdn("removed", true)]
    if namesInfo.kind != crEdnSet:
      raise newException(ValueError, "TODO")

    let names = namesInfo.map(proc (name: CirruEdnValue): string =
      if name.kind != crEdnString:
        raise newException(ValueError, "TODO")
      return name.stringVal
    )

    changedData.removed = MaybeNil[HashSet[string]](kind: beSomething, value: toHashSet(names))
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

proc watchFile(): void =
  if not existsFile(incrementFile):
    writeFile incrementFile, "{}"
  let child = startProcess("/usr/local/bin/fswatch", "", [incrementFile])
  let sub = outputStream(child)
  while true:
    let line = readLine(sub)

    setForegroundColor(fgCyan)
    echo "\n-------- file change --------\n"
    resetAttributes()

    loadChanges()

# https://rosettacode.org/wiki/Handle_a_signal#Nim
proc handleControl() {.noconv.} =
  echo "\nKilled with Control c."
  quit 0

proc main(): void =
  loadSnapshot()
  evalSnapshot()

  setControlCHook(handleControl)
  watchFile()

main()
