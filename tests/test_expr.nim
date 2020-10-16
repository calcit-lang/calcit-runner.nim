
import options
import unittest

import calcit_runner

test "Basic add":
  check (runProgram("tests/snapshots/add.cirru") == crData(3))

test "Basic gynienic":
  check (runProgram("tests/snapshots/gynienic.cirru", some("app.main/try-hygienic")) == crData(14))

test "Cirru tests":
  check (runProgram("tests/snapshots/test.cirru") == crData(true))
