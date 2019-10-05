
import strutils
import sequtils, sugar
import tables
import hashes
import strformat

type CirruInterpretError* = ref object of Exception
  line*: int
  column*: int

type CirruCommandError* = Exception

type
  CirruValueKind* = enum
    crValueNil,
    crValueBool,
    crValueInt,
    crValueFloat,
    crValueString,
    crValueArray,
    crValueSeq,
    crValueTable,
    crValueFn

  CirruValue* = object
    case kind*: CirruValueKind
    of crValueNil: nilVal: bool
    of crValueBool: boolVal*: bool
    of crValueInt: intVal*: int
    of crValueFloat: floatVal*: float
    of crValueString: stringVal*: string
    of crValueFn: fnVal*: proc()
    of crValueArray: arrayVal*: seq[CirruValue]
    of crValueTable: tableVal*: Table[Hash, CirruValue]
    else: xVal*: string

proc toString*(val: CirruValue): string

proc fromArrayToString(children: seq[CirruValue]): string =
  return "[" & children.mapIt(toString(it)).join(" ") & "]"

proc fromTableToString(children: Table[Hash, CirruValue]): string =
  let size = children.len()
  if size > 20:
    return "{...(20)...}"
  var tableStr = "{"
  for k, child in pairs(children):
    # TODO, need a way to get original key
    tableStr = tableStr & $k & " " & toString(child) & ", "
  tableStr = tableStr & "}"
  return tableStr

proc toString*(val: CirruValue): string =
  case val.kind:
    of crValueInt: $(val.intVal)
    of crValueBool:
      if val.boolVal:
        "true"
      else:
        "false"
    of crValueFloat: $(val.floatVal)
    of crValueString: escape(val.stringVal)
    of crValueArray: fromArrayToString(val.arrayVal)
    of crValueTable: fromTableToString(val.tableVal)
    else: "CirruValue"

proc hashCirruValue*(value: CirruValue): Hash =
  case value.kind
    of crValueInt:
      return hash(value.intVal)
    of crValueFloat:
      return hash(value.floatVal)
    of crValueString:
      return hash(value.stringVal)
    of crValueNil:
      # TODO not safe enough
      return hash("")
    of crValueBool:
      # TODO not safe enough
      return hash(fmt"{value.boolVal}")
    of crValueArray:
      return hash("TODO")
    else:
      # TODO
      return hash("TODO")
