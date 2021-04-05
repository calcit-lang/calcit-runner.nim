
import edn_paint
import cirru_edn
import ternary_tree

import ../types
import ../util/errors
import ../data/to_edn

proc nativeInitCanvas*(args: seq[CirruData]): CirruData =
  if args.len == 0:
    initCanvas("DEMO", 400, 400)
  else:
    let options = args[0]
    if options.kind == crDataMap:
      let titleKey = CirruData(kind: crDataKeyword, keywordVal: loadKeyword("title"))
      let widthKey = CirruData(kind: crDataKeyword, keywordVal: loadKeyword("width"))
      let heightKey = CirruData(kind: crDataKeyword, keywordVal: loadKeyword("height"))
      let title = if options.mapVal.contains(titleKey): options.mapVal[titleKey] else: CirruData(kind: crDataNil)
      let width = if options.mapVal.contains(widthKey): options.mapVal[widthKey] else: CirruData(kind: crDataNil)
      let height = if options.mapVal.contains(heightKey): options.mapVal[heightKey] else: CirruData(kind: crDataNil)
      assert title.kind == crDataString, "Expects title to be a string"
      assert width.kind == crDataNumber, "Expects width to be a number"
      assert height.kind == crDataNumber, "Expects height to be a number"
      initCanvas(title.stringVal, width.numberVal.int, height.numberVal.int)
  return CirruData(kind: crDataBool, boolVal: true)

proc nativeDrawCanvas*(args: seq[CirruData]): CirruData =
  if args.len != 1: raiseEvalError("Expects 1 argument", args)
  let data = args[0]
  renderCanvas(data.toEdn)

  return CirruData(kind: crDataBool, boolVal: true)

proc nativeDrawErrorMessage*(args: seq[CirruData]): CirruData =
  if args.len < 1 or args[0].kind != crDataString: raiseEvalError("Expects a string message", args)
  renderCanvas(genCrEdnMap(
    genCrEdnKeyword("type"), genCrEdn("text"),
    genCrEdnKeyword("text"), genCrEdn(args[0].stringVal),
    genCrEdnKeyword("align"), genCrEdn("left"),
    genCrEdnKeyword("color"), genCrEdnVector(genCrEdn(0), genCrEdn(90), genCrEdn(60)),
    genCrEdnKeyword("font-size"), genCrEdn(16),
    genCrEdnKeyword("position"), genCrEdnVector(genCrEdn(20), genCrEdn(20)),
  ))
  return CirruData(kind: crDataNil)
