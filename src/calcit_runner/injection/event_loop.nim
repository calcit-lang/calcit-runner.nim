
import os
import tables

import ternary_tree

import ../types
import ../util/errors

type EventTaskParams* = tuple[id: int, params: seq[CirruData]]
type EventTaskCallback* = tuple[ns: string, cb: CirruData]
type TimeoutTaskOptions = tuple[id: int, duration: int]

var eventsChan*: Channel[EventTaskParams]

# open by default, may not be best choice
eventsChan.open()

var eventCalls: Table[int, EventTaskCallback]
var eventCallerId = 0

# hold memories for threads, also creates dynamically
# might cause "illegal storage access" when threads are too many. temp fix is --gc:orc
var eventLoopTasks: Table[int, Thread[TimeoutTaskOptions]]

proc addTask*(f: CirruData, ns: string): int =
  if f.kind != crDataFn and f.kind != crDataProc:
    raiseEvalError("expects a function callback for task", f)

  var taskId = eventCallerId
  eventCallerId = eventCallerId + 1

  eventCalls[taskId] = (ns, f)

  return taskId

proc finishTask*(taskId: int, args: seq[CirruData]): void =
  if eventCalls.contains(taskId).not:
    raiseEvalError("no callback found", CirruData(kind: crDataString, stringVal: $taskId))
  let task = eventCalls[taskId]
  let f = task.cb
  if f.kind != crDataFn and f.kind != crDataProc:
    raiseEvalError("expects a function callback for task", f)

  discard f.fnVal(args)
  eventCalls.del(taskId)

proc timeoutCallTask*(info: TimeoutTaskOptions) {.thread.} =
  sleep info.duration

  eventsChan.send((info.id, @[]))

proc setupTimeoutTask*(duration: int, f: CirruData, ns: string): int =
  let taskId = addTask(f, ns)
  var mem: Thread[TimeoutTaskOptions]
  eventLoopTasks[taskId] = mem

  let info: TimeoutTaskOptions = (taskId, duration)
  createThread(eventLoopTasks[taskId], timeoutCallTask, info)

  return taskId

proc nativeTimeoutCall*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData =
  if args.len != 2: raiseEvalError("timeout-call expects 2 arguments", args)
  let duration = args[0]
  if duration.kind != crDataNumber: raiseEvalError("expects number value for timeout", args)
  let cb = args[1]
  if cb.kind != crDataFn and cb.kind != crDataProc: raiseEvalError("expects func value for timeout-call", args)

  let taskId = setupTimeoutTask(duration.numberVal.int, cb, ns)

  return CirruData(kind: crDataNumber, numberVal: taskId.float)
