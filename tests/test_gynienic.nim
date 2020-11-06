
import options
import unittest

import calcit_runner

test "Basic gynienic":
  check (runProgram("tests/snapshots/gynienic.cirru", some("app.main/try-hygienic")) == crData(14))

# test "Macros tests":
#   check (runProgram("tests/snapshots/test-macro.cirru") == crData(true))
