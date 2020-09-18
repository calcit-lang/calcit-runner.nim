
import tables
import options
import sets

import cirruParser

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

type

  CirruDataScope* = ref object
    dict*: Table[string, CirruData]
    parent*: Option[CirruDataScope]

  EdnEvalFn* = proc(expr: CirruNode, ns: string, scope: CirruDataScope): CirruData

  CirruDataKind* = enum
    crDataNil,
    crDataBool,
    crDataNumber,
    crDataString,
    crDataKeyword,
    crDataVector,
    crDataList,
    crDataSet,
    crDataMap,
    crDataFn,
    crDataSymbol,

  CirruData* = object
    line*: int
    column*: int
    case kind*: CirruDataKind
    of crDataNil: discard
    of crDataBool: boolVal*: bool
    of crDataNumber: numberVal*: float
    of crDataString: stringVal*: string
    of crDataKeyword: keywordVal*: string
    of crDataFn:
      fnVal*: proc(exprList: seq[CirruData], interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData
    of crDataVector: vectorVal*: seq[CirruData]
    of crDataList: listVal*: seq[CirruData]
    of crDataSet: setVal*: HashSet[CirruData]
    of crDataMap: mapVal*: Table[CirruData, CirruData]
    of crDataSymbol: symbolVal*: string

  EdnEmptyError* = object of ValueError
  EdnInvalidError* = object of ValueError
  EdnOpError* = object of ValueError


type ProgramFile* = object
  ns*: Option[Table[string, ImportInfo]]
  defs*: Table[string, CirruData]

type CodeConfigs* = object
  initFn*: string
  reloadFn*: string
