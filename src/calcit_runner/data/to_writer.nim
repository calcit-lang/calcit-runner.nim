
import cirru_writer
import ternary_tree

import ../types
import ../util/errors
import ../data/virtual_list

proc toWriterNode*(xs: CirruData): CirruWriterNode =
  case xs.kind:
  of crDataString:
    return CirruWriterNode(kind: writerItem, item: xs.stringVal)
  of crDataList:
    var ys: seq[CirruWriterNode]
    for x in xs.listVal:
      ys.add x.toWriterNode()
    return CirruWriterNode(kind: writerList, list: ys)
  else:
    raiseEvalError("Unexpected type for writer node:" & $xs.kind, xs)
