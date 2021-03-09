
import tables
import algorithm

import ternary_tree
import cirru_edn
import cirru_parser
import cirru_writer

import ../types
import ../data
import ../util/errors

proc nativeNewRecord*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 2:
    raiseEvalError("new-record expected >2 arguments", args)
  let name = args[0].getString()

  var fields = newSeq[string](args.len - 1)
  for idx, arg in args:
    if idx == 0:
      continue
    fields[idx - 1] = args[idx].getString()

  # mutable change
  fields.sort(cmp)

  var values = newSeq[CirruData](fields.len)
  for idx, field in fields:
    fields[idx] = field
    values[idx] = CirruData(kind: crDataNil)

  return CirruData(kind: crDataRecord, recordName: name, recordFields: fields, recordValues: values)

proc nativeRecord*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 2:
    raiseEvalError("&%{} expected >2 arguments", args)
  if args.len.mod(2) != 1:
    raiseEvalError("&%{} expected odd number of arguments", args)
  let prototype = args[0]
  if prototype.kind != crDataRecord:
    raiseEvalError("&%{} expected a record as prototype", args)
  let fields = prototype.recordFields
  if args.len - 1 != (fields.len * 2):
    raiseEvalError("&%{} expected " & $fields & " " & $fields.len & " fields", args)

  var values = newSeq[CirruData](fields.len)
  var pairs: seq[RecordInPair]
  for i in 0..<(args.len - 1) shr 1:
    let idx = (i shl 1) + 1
    pairs.add((args[idx].getString(), args[idx + 1]))

  # mutable change
  pairs.sort(recordFieldOrder)

  for idx, p in pairs:
    if p.k == fields[idx]:
      values[idx] = p.v
    else:
      raiseEvalError("expected field name `" & fields[idx] & "` but got `" & p.k & "`",args)
  return CirruData(kind: crDataRecord, recordName: prototype.recordName, recordFields: fields, recordValues: values)

proc getRecordName*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 2:
    raiseEvalError("get-record-name expected 1 argument", args)
  let base = args[0]
  if base.kind != crDataRecord:
    raiseEvalError("get-record-name expected a record", args)
  return CirruData(kind: crDataSymbol, symbolVal: base.recordName)

proc makeRecord*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len < 2:
    raiseEvalError("make-record expected 2 arguments", args)
  let prototype = args[0]
  if prototype.kind != crDataRecord:
    raiseEvalError("get-record-name expected a record", args)

  let fields = prototype.recordFields

  let data = args[1]
  case data.kind
  of crDataRecord:
    if data.recordFields == fields:
      return CirruData(kind: crDataRecord, recordName: prototype.recordName, recordFields: fields, recordValues: data.recordValues)
    else:
      var values = newSeq[CirruData](fields.len)
      for idx, field in fields:
        let pos = data.recordFields.find(field)
        if pos < 0:
          raiseEvalError("Failed to read from field `" & field & "`", args)
        values.add(data.recordValues[idx])
      return CirruData(kind: crDataRecord, recordName: prototype.recordName, recordFields: fields, recordValues: values)

  of crDataMap:
    var values = newSeq[CirruData](fields.len)
    var pairs: seq[RecordInPair]
    for k, v in data.mapVal:
      pairs.add((k.getString(), v))

    # mutable change
    pairs.sort(recordFieldOrder)
    for idx, p in pairs:
      if p.k == fields[idx]:
        values[idx] = p.v
      else:
        raiseEvalError("expected field name `" & fields[idx] & "` but got `" & p.k & "`",args)
    return CirruData(kind: crDataRecord, recordName: prototype.recordName, recordFields: fields, recordValues: values)
  else:
    raiseEvalError("Cannot create record from this value " & $data, args)


proc turnMap*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 1:
    raiseEvalError("turn-map expected 1 argument", args)
  case args[0].kind:
  of crDataRecord:
    var value = initTable[CirruData, CirruData]()
    for idx, field in args[0].recordFields:
      value[CirruData(kind: crDataKeyword, keywordVal: field)] = args[0].recordValues[idx]
    return CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(value))

  of crDataMap:
    return args[0]
  else:
    raiseEvalError("turn-map expected record", args)

proc relevantRecord*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2:
    raiseEvalError("turn-map expected 2 arguments", args)
  let a = args[0]
  let b = args[1]
  if a.kind != crDataRecord:
    raiseEvalError("relevant-record? expected record", args)
  if b.kind != crDataRecord:
    raiseEvalError("relevant-record? expected record", args)
  if a.recordName != b.recordName:
    return CirruData(kind: crDataBool, boolVal: false)
  return CirruData(kind: crDataBool, boolVal: a.recordFields == b.recordFields)

proc findInFields*(xs: seq[string], y: string): int =
  var lower = 0
  var upper = xs.len - 1

  while (upper - lower) > 1:
    let pos = (lower + upper) shr 1
    let v = xs[pos]
    if y < v:
      upper = pos - 1
    elif y > v:
      lower = pos + 1
    else:
      return pos

  if y == xs[lower]: return lower
  if y == xs[upper]: return upper
  return -1
