
import tables
import options

import ./types

type AtomDetails = object
  value*: CirruData
  watchers*: Table[string, CirruData]

var atomsTable: Table[string, Table[string, AtomDetails]]

proc getAtomByPath*(ns: string, def: string): Option[AtomDetails] =
  if atomsTable.contains(ns).not:
    return none(AtomDetails)
  if atomsTable[ns].contains(def).not:
    return none(AtomDetails)
  return some(atomsTable[ns][def])

proc setAtomByPath*(ns: string, def: string, value: CirruData) =
  if atomsTable.contains(ns).not:
    var file: Table[string, AtomDetails]
    atomsTable[ns] = file
  if atomsTable[ns].contains(def).not:
    let details = AtomDetails(value: value)
    atomsTable[ns][def] = details
  else:
    atomsTable[ns][def].value = value

proc addAtomWatcher*(ns: string, def: string, k: string, f: CirruData) =
  if f.kind != crDataFn and f.kind != crDataProc:
    raise newException(ValueError, "expects an function for add-watch")
  if atomsTable.contains(ns).not:
    raise newException(ValueError, "no such atom")
  if atomsTable[ns].contains(def).not:
    raise newException(ValueError, "no such atom")
  atomsTable[ns][def].watchers[k] = f

proc removeAtomWatcher*(ns: string, def: string, k: string) =
  if atomsTable.contains(ns).not:
    raise newException(ValueError, "no such atom")
  if atomsTable[ns].contains(def).not:
    raise newException(ValueError, "no such atom")
  atomsTable[ns][def].watchers.del k
