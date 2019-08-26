
type InterpretError* = Exception

type
  CirruValueKind* = enum
    crValueInt,
    crValueFloat,
    crValueString,
    crValueVector,
    crValueSeq,
    crValueMap,
    crValueFn

  CirruValue* = object
    case kind*: CirruValueKind
    of crValueInt: intVal*: int
    of crValueFloat: floatVal*: float
    of crValueString: stringVal*: string
    of crValueFn: fnVal*: proc()
    else: xVal*: string

proc toString*(val: CirruValue): string =
  case val.kind:
    of crValueInt: $(val.intVal)
    of crValueFloat: $(val.floatVal)
    of crValueString: val.stringVal
    else: "CirruValue"
