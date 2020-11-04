
import calcit_runner

import json_paint

import ./calcit_runner/canvas

registerCoreProc("init-canvas", nativeInitCanvas)
registerCoreProc("draw-canvas", nativeDrawCanvas)

taskDuringLoop = proc() =
  takeCanvasEvents()

main()
