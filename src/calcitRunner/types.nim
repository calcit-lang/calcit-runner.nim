
import tables

import cirruEdn

type CirruInterpretError* = ref object of ValueError
  line*: int
  column*: int

type CirruCommandError* = ValueError

type ImportKind = enum
  importNs, importDef
type ImportInfo* = object
  ns*: string
  case kind: ImportKind
  of importNs:
    discard
  of importDef:
    def: string

type ProgramFile* = object
  ns*: Table[string, ImportInfo]
  defs*: Table[string, CirruEdnValue]

type CodeConfigs* = object
  initFn*: string
  reloadFn*: string
