
import os
import options

import ternary_tree

import ./types
import ./errors
import ./eval_util
import ./evaluate

type EventTaskParams* = tuple[id: int, params: seq[CirruData]]
type EventTaskCallback* = tuple[ns: string, cb: CirruData]

var eventsChan*: Channel[EventTaskParams]

# TODO open by default might be bad
eventsChan.open()

# TODO hold memory for 20 items, corresponding to threads below
var eventCalls: array[0..19, Option[EventTaskCallback]]

proc addTask*(f: CirruData, ns: string): int =
  if f.kind != crDataFn and f.kind != crDataProc:
    raiseEvalError("expects a function callback for task", f)

  var taskId = -1
  for idx in 0..<20:
    if eventCalls[idx].isNone:
      taskId = idx
      break
  if taskId == -1:
    raiseEvalError("20 threads max, all occupied", CirruData(kind: crDataNil))

  eventCalls[taskId] = some((ns, f))

  return taskId

proc finishTask*(taskId: int, args: seq[CirruData]): void =
  if taskId < 0 or taskId >= 20:
    raiseEvalError("no callback found", CirruData(kind: crDataString, stringVal: $taskId))
  let maybeTask = eventCalls[taskId]
  if maybeTask.isNone:
    raiseEvalError("no callback found", CirruData(kind: crDataString, stringVal: $taskId))
  let task = maybeTask.get
  let f = task.cb
  if f.kind != crDataFn and f.kind != crDataProc:
    raiseEvalError("expects a function callback for task", f)

  discard evaluteFnData(f, args, interpret, task.ns)
  eventCalls[taskId] = none(EventTaskCallback)

type TimeoutTaskOptions = tuple[id: int, duration: int]
proc timeoutCallTask*(info: TimeoutTaskOptions) {.thread.} =
  sleep info.duration

  eventsChan.send((info.id, @[]))

# TODO hold memory for 20 threads, could be too small
var eventLoopTaskList: array[0..19, Thread[TimeoutTaskOptions]]

proc setupTimeoutTask*(duration: int, f: CirruData, ns: string): int =
  let taskId = addTask(f, ns)

  let info: TimeoutTaskOptions = (taskId, duration)
  createThread(eventLoopTaskList[taskId], timeoutCallTask, info)

  return taskId
