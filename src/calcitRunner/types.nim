
import tables
import options

import cirruParser
import cirruEdn

type CirruInterpretError* = ref object of ValueError
  line*: int
  column*: int

type CirruCommandError* = ValueError

type ImportKind* = enum
  importNs, importDef
type ImportInfo* = object
  ns*: string
  case kind*: ImportKind
  of importNs:
    discard
  of importDef:
    def*: string

type FileSource* = object
  ns*: CirruNode
  run*: CirruNode
  defs*: Table[string, CirruNode]

type ProgramFile* = object
  ns*: Option[Table[string, ImportInfo]]
  defs*: Table[string, CirruEdnValue]

type CodeConfigs* = object
  initFn*: string
  reloadFn*: string
