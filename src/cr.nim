
import calcit_runner

import ./calcit_runner/data
import ./calcit_runner/canvas

registerCoreProc("init-canvas", nativeInitCanvas)
registerCoreProc("draw-canvas", nativeDrawCanvas)

main()
