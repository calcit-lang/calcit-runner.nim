
import options
import unittest

import calcit_runner
import calcit_runner/data/gen_data

test "Basic gynienic":
  check (runProgram("tests/snapshots/gynienic.cirru", some("app.main/try-hygienic")) == crData(true))

# test "Macros tests":
#   check (runProgram("tests/snapshots/test-macro.cirru") == crData(true))
