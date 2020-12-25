
import libfswatch
import libfswatch/fswatch

var watchingChan*: Channel[string]

proc watchingTask*(incrementFile: string) {.thread.} =
  echo "watching..."
  let fileChangeCb = proc (event: fsw_cevent, event_num: cuint): void =
    watchingChan.send("changed")

  var mon = newMonitor()
  discard mon.handle.fsw_set_latency 0.2
  mon.addPath(incrementFile)
  mon.setCallback(fileChangeCb)
  mon.start()
