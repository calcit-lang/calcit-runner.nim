
import strutils
import sequtils, sugar

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
    crValueMap,
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
    else: xVal*: string

proc toString*(val: CirruValue): string

proc fromArrayToString(children: seq[CirruValue]): string =
  return "[" & children.mapIt(toString(it)).join(" ") & "]"

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
    else: "CirruValue"
