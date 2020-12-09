
import ./calcit_runner

var snapshotFile = "compact.cirru"

echo "Running calcit runner(" & commandLineVersion & ") in CI mode"

discard runProgram(snapshotFile)
