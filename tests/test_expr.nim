
import options
import unittest

import calcit_runner

test "Basic add":
  check (runProgram("tests/snapshots/add.cirru") == crData(3))

test "Basic gynienic":
  check (runProgram("tests/snapshots/gynienic.cirru", some("app.main/try-hygienic")) == crData(true))

test "Cirru tests":
  check (runProgram("tests/snapshots/test.cirru") == crData(true))

test "List tests":
  check (runProgram("tests/snapshots/test-list.cirru") == crData(true))

test "Map tests":
  check (runProgram("tests/snapshots/test-map.cirru") == crData(true))

test "Macros tests":
  check (runProgram("tests/snapshots/test-macro.cirru") == crData(true))
