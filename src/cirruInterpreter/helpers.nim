
import ./types

proc raiseInterpretException*(msg: string, line, column: int) =
  var e: CirruInterpretError
  new e
  e.msg = msg
  e.line = line
  e.column = column
  raise e
