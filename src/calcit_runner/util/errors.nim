
import cirru_parser
import ternary_tree

import ../types
import ../data/virtual_list

type CirruEvalError* = ref object of ValueError
  code*: CirruData

proc raiseEvalError*(msg: string, code: CirruData): void =
  var e: CirruEvalError
  new e
  e.msg = msg
  e.code = code

  raise e

proc raiseEvalError*(msg: string, xs: seq[CirruData]): void =
  let code = CirruData(kind: crDataList, listVal: initCrVirtualList(xs))
  raiseEvalError(msg, code)
