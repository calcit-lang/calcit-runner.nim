
import json
import options

import json_paint
import ternary_tree

import ./types
import ./errors
import ./to_json

proc nativeInitCanvas*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len == 0:
    initCanvas("DEMO", 400, 400)
  else:
    let options = args[0]
    if options.kind == crDataMap:
      let title = options.mapVal[CirruData(kind: crDataKeyword, keywordVal: loadKeyword("title"))]
      let width = options.mapVal[CirruData(kind: crDataKeyword, keywordVal: loadKeyword("width"))]
      let height = options.mapVal[CirruData(kind: crDataKeyword, keywordVal: loadKeyword("height"))]
      assert title.isSome and title.get.kind == crDataString, "Expects title to be a string"
      assert width.isSome and width.get.kind == crDataNumber, "Expects width to be a number"
      assert height.isSome and height.get.kind == crDataNumber, "Expects height to be a number"
      initCanvas(title.get.stringVal, width.get.numberVal.int, height.get.numberVal.int)
  return CirruData(kind: crDataBool, boolVal: true)

proc nativeDrawCanvas*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1: raiseEvalError("Expects 1 argument", args)
  let data = args[0]
  renderCanvas(data.toJson)

  return CirruData(kind: crDataBool, boolVal: true)

proc nativeDrawErrorMessage*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 1 or args[0].kind != crDataString: raiseEvalError("Expects a string message", args)
  renderCanvas(%* {
    "type": "text",
    "text": args[0].stringVal,
    "align": "left",
    "color": [0, 90, 60],
    "font-size": 16,
    "x": 20,
    "y": 20,
  })
  return CirruData(kind: crDataNil)
