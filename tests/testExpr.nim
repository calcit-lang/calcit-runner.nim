
import unittest

import calcitRunner

test "Basic add":
  check (runProgram("tests/snapshots/add.cirru") == crData(3))
