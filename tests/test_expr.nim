
import unittest

import ./calcit_runner
import ./calcit_runner/data/gen_data

test "Basic add":
  check (runProgram("tests/snapshots/add.cirru") == crData(3))

test "Cirru tests":
  check (runProgram("tests/snapshots/test.cirru") == crData(true))
