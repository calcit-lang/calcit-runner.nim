
import terminal

proc coloredEcho*(color: ForegroundColor, text: varargs[string]): void =
  var buffer = ""
  for x in text:
    buffer = buffer & x
  setForegroundColor(color)
  echo buffer
  resetAttributes()

proc dimEcho*(text: varargs[string]): void =
  var buffer = ""
  for x in text:
    buffer = buffer & x
  # setForegroundColor(0x555555)
  setStyle({styleDim})
  echo buffer
  resetAttributes()
