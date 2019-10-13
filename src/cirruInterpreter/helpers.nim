
import cirruParser
import tables
import json
import hashes
import ./types

proc raiseInterpretException*(msg: string, line, column: int) =
  var e: CirruInterpretError
  new e
  e.msg = msg
  e.line = line
  e.column = column
  raise e


proc raiseInterpretExceptionAtNode*(msg: string, node: CirruNode) =
  raiseInterpretException(msg, node.line, node.column)

proc valueFromJson*(v: JsonNode): CirruValue =
  case v.kind
  of JString:
    return CirruValue(kind: crValueString, stringVal: v.str)
  of JInt:
    let value: int = v.to(int)
    return CirruValue(kind: crValueInt, intVal: value)
  of JFloat:
    return CirruValue(kind: crValueFloat, floatVal: v.fnum)
  of JBool:
    return CirruValue(kind: crValueBool, boolVal: v.bval)
  of JNull:
    return CirruValue(kind: crValueNil)
  of JArray:
    var arr: seq[CirruValue]
    for v in v.elems:
      arr.add valueFromJson(v)
    return CirruValue(kind: crValueArray, arrayVal: arr)
  of JObject:
    var table = initTable[Hash, TablePair]()
    for key, value in v:
      let keyContent = CirruValue(kind: crValueString, stringVal: key)
      let valuePair: TablePair = (keyContent, valueFromJson(value))
      table.add(hashCirruValue(keyContent), valuePair)
    return CirruValue(kind: crValueTable, tableVal: table)
