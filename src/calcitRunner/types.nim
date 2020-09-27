
import tables
import options
import sets

import ternary_tree

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

type

  CirruDataScope* = ref object
    dict*: Table[string, CirruData]
    parent*: Option[CirruDataScope]

  CirruDataKind* = enum
    crDataNil,
    crDataBool,
    crDataNumber,
    crDataString,
    crDataKeyword,
    crDataList,
    crDataSet,
    crDataMap,
    crDataFn,
    crDataMacro,
    crDataSymbol,
    crDataSyntax,

  EdnEvalFn* = proc(expr: CirruData, scope: CirruDataScope): CirruData

  FnInData* = proc(exprList: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData

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
      fnVal*: FnInData
      fnCode*: RefCirruData
    of crDataMacro:
      macroVal*: FnInData
      macroCode*: RefCirruData
    of crDataSyntax:
      syntaxVal*: FnInData
      syntaxCode*: RefCirruData
    of crDataList: listVal*: TernaryTreeList[CirruData]
    of crDataSet: setVal*: HashSet[CirruData]
    of crDataMap: mapVal*: Table[CirruData, CirruData]
    of crDataSymbol:
      symbolVal*: string
      ns*: string
      scope*: Option[CirruDataScope]

  RefCirruData* = ref CirruData

  EdnEmptyError* = object of ValueError
  EdnInvalidError* = object of ValueError
  EdnOpError* = object of ValueError


type ProgramFile* = object
  ns*: Option[Table[string, ImportInfo]]
  defs*: Table[string, CirruData]
  states*: Table[string, CirruData]

type CodeConfigs* = object
  initFn*: string
  reloadFn*: string

type CirruEvalError* = ref object of ValueError
  code*: CirruData

type CirruCoreError* = ref object of ValueError
  data*: CirruData

type FileSource* = object
  ns*: CirruData
  run*: CirruData
  defs*: Table[string, CirruData]

type StackInfo* = object
  ns*: string
  def*: string
  code*: CirruData
  args*: seq[CirruData]

let coreNs* = "calcit.core"
