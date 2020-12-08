
import ./calcit_runner

var snapshotFile = "compact.cirru"

echo "Running calcit runner in CI mode"

discard runProgram(snapshotFile)
