
import unittest

import calcitRunner

test "Basic add":
  check (runProgram("tests/snapshots/add.cirru") == crData(3))

test "Basic gynienic":
  check (runProgram("tests/snapshots/gynienic.cirru") == crData(14))
