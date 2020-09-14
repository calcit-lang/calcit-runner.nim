
import tables
import options

import cirruEdn

proc get*(scope: CirruEdnScope, name: string): Option[CirruEdnValue] =
  if scope.dict.hasKey(name):
    return some(scope.dict[name])
  else:
    if scope.parent.isSome:
      return get(scope.parent.get, name)
    else:
      return none(CirruEdnValue)
