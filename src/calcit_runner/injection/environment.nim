
import ../types

import ../codegen/emit_js
import ../codegen/emit_ir

proc nativeGetCalcitRunningMode*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if jsMode:
    return CirruData(kind: crDataKeyword, keywordVal: loadKeyword("js"))
  if irMode:
    return CirruData(kind: crDataKeyword, keywordVal: loadKeyword("ir"))
  return CirruData(kind: crDataKeyword, keywordVal: loadKeyword("eval"))
