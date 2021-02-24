
import ./calcit_runner
import ./calcit_runner/compiler_configs

echo "Running calcit runner(" & commandLineVersion & ") in CI mode"

parseCliArgs()

if programEvalOnce:
  discard evalSnippet(programEvalOnceCode)
else:
  echo "Calcit runner version: ", commandLineVersion
  discard runProgram(programSnapshotFile, programInitFn)
