
import options
import unittest

import calcitRunner

test "Basic add":
  check (runProgram("tests/snapshots/add.cirru") == crData(3))

test "Basic gynienic":
  check (runProgram("tests/snapshots/gynienic.cirru", some("app.main/try-hygienic")) == crData(14))
