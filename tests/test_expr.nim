
import options
import unittest

import calcit_runner

test "Basic add":
  check (runProgram("tests/snapshots/add.cirru") == crData(3))

test "Basic gynienic":
  check (runProgram("tests/snapshots/test-gynienic.cirru", some("app.main/try-hygienic")) == crData(true))

test "Cirru tests":
  check (runProgram("tests/snapshots/test.cirru") == crData(true))

test "Math tests":
  check (runProgram("tests/snapshots/test-math.cirru") == crData(true))

test "List tests":
  check (runProgram("tests/snapshots/test-list.cirru") == crData(true))

test "Map tests":
  check (runProgram("tests/snapshots/test-map.cirru") == crData(true))

test "Macros tests":
  check (runProgram("tests/snapshots/test-macro.cirru") == crData(true))

test "Cond tests":
  check (runProgram("tests/snapshots/test-cond.cirru") == crData(true))

test "Recursion tests":
  check (runProgram("tests/snapshots/test-recursion.cirru") == crData(true))

test "Set tests":
  check (runProgram("tests/snapshots/test-set.cirru") == crData(true))

test "Lens tests":
  check (runProgram("tests/snapshots/test-lens.cirru") == crData(true))

test "String tests":
  check (runProgram("tests/snapshots/test-string.cirru") == crData(true))
