
import cirruParser

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
