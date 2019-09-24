
import strutils

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
    crValueVector,
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
    else: xVal*: string

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
    else: "CirruValue"
