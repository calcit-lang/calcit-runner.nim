
import os
import tables

import ternary_tree

import ../types
import ../util/errors

type EventTaskParams* = tuple[id: int, params: seq[CirruData]]
type EventTaskCallback* = CirruData
type TimeoutTaskOptions = tuple[id: int, duration: int]

var eventsChan*: Channel[EventTaskParams]

# open by default, may not be best choice
eventsChan.open()

var eventCalls: Table[int, EventTaskCallback]
var eventCallerId = 0

# hold memories for threads, also creates dynamically
# might cause "illegal storage access" when threads are too many. temp fix is --gc:orc
var eventLoopTasks: Table[int, Thread[TimeoutTaskOptions]]

proc addTask*(f: CirruData): int =
  if f.kind != crDataFn:
    raiseEvalError("expects a function callback for task", f)

  var taskId = eventCallerId
  eventCallerId = eventCallerId + 1

  eventCalls[taskId] = f

  return taskId

proc finishTask*(taskId: int, args: seq[CirruData]): void =
  if eventCalls.contains(taskId).not:
    raiseEvalError("no callback found", CirruData(kind: crDataString, stringVal: $taskId))
  let f = eventCalls[taskId]
  if f.kind != crDataFn:
    raiseEvalError("expects a function callback for task", f)

  discard f.fnVal(args)
  eventCalls.del(taskId)

proc timeoutCallTask*(info: TimeoutTaskOptions) {.thread.} =
  sleep info.duration

  eventsChan.send((info.id, @[]))

proc setupTimeoutTask*(duration: int, f: CirruData): int =
  let taskId = addTask(f)
  var mem: Thread[TimeoutTaskOptions]
  eventLoopTasks[taskId] = mem

  let info: TimeoutTaskOptions = (taskId, duration)
  createThread(eventLoopTasks[taskId], timeoutCallTask, info)

  return taskId

proc nativeTimeoutCall*(args: seq[CirruData]): CirruData =
  if args.len != 2: raiseEvalError("timeout-call expects 2 arguments", args)
  let duration = args[0]
  if duration.kind != crDataNumber: raiseEvalError("expects number value for timeout", args)
  let cb = args[1]
  if cb.kind != crDataFn: raiseEvalError("expects func value for timeout-call", args)

  let taskId = setupTimeoutTask(duration.numberVal.int, cb)

  return CirruData(kind: crDataNumber, numberVal: taskId.float)
