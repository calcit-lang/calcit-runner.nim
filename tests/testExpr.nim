
import unittest

import calcitRunner

test "Basic add":
  check (runProgram("tests/snapshots/add.cirru") == CirruData(kind: crDataNumber, numberVal: 3))
