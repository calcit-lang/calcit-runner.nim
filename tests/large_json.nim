
import nimprof
import times

import ./calcit_runner
import ./calcit_runner/emit_js

jsMode = true

let t1 = now()

discard runProgram("tests/snapshots/large-json.cirru")

let t2 = now()

echo "Cost: ", t2 - t1
