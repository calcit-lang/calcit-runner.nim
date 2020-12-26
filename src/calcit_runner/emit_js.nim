
import tables

import ./types

# TODO dirty states controlling js backend
var jsMode* = false
var jsEmitPath* = "js-out"

proc emitJs*(programData: Table[string, ProgramFile], entryNs, entryDef: string): void =
  for ns, file in programData:
    echo "ns: ", ns
    echo "imports: ", file.ns
    echo "defs"
    for def, f in file.defs:
      case f.kind
      of crDataProc:
        echo " proc: ", def
      of crDataFn:
        echo " fn: ", def, " ", f
      of crDataThunk:
        echo " thunk: ", def
      else:
        echo " ...well ", $f.kind
