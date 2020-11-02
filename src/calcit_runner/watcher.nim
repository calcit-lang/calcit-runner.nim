
import libfswatch
import libfswatch/fswatch

proc watchingTask*(params: tuple[incrementFile: string, watchingChan: ptr Channel[string]]) {.thread.} =
  let fileChangeCb = proc (event: fsw_cevent, event_num: cuint): void =
    params.watchingChan[].send("changed")

  var mon = newMonitor()
  discard mon.handle.fsw_set_latency 0.2
  mon.addPath(params.incrementFile)
  mon.setCallback(fileChangeCb)
  mon.start()
