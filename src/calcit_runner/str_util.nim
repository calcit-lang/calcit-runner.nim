
proc isDigit(c: char): bool =
  let n = ord(c)
  # ascii table https://tool.oschina.net/commons?type=4
  n >= 48 and n <= 57

proc isLetter(c: char): bool =
  let n = ord(c)
  if n >= 65 and n <= 90:
    return true
  if n >= 97 and n <= 122:
    return true
  return false

proc matchesFloat*(xs: string): bool =
  if xs.len == 0:
    return false

  var buffer = xs
  if xs[0] == '-':
    buffer = xs[1..^1]

  if buffer.len == 0:
    return false

  var countDigits = 0
  var countDot = 0
  for x in buffer:
    if x.isDigit():
      countDigits += 1
    elif x == '.':
      countDot += 1
    else:
      return false

  if countDigits < 1:
    return false
  if countDot > 1:
    return false

  return true

proc matchesTernary*(xs: string): bool =
  if xs.len == 0:
    return false

  if xs[0] != '&':
    return false

  var buffer = xs[1..^1]

  if buffer.len == 0:
    return false

  var countDigits = 0
  var countDot = 0
  for x in buffer:
    if x.isDigit():
      if x == '0':
        # ternary does not use '0'
        return false
      countDigits += 1
    elif x == '.':
      countDot += 1
    else:
      return false

  if countDigits < 1:
    return false
  if countDot > 1:
    return false

  return true

proc matchesSimpleVar*(xs: string): bool =
  if xs.len == 0:
    return false
  for x in xs:
    if x.isLetter():
      continue
    elif x.isDigit():
      continue
    elif x == '-':
      continue
    elif x == '!':
      continue
    elif x == '*':
      continue
    elif x == '?':
      continue
    return false
  return true

proc matchesJsVar*(xs: string): bool =
  if xs.len == 0:
    return false
  for idx, x in xs:
    if x.isLetter():
      continue
    if idx > 0:
      if x.isDigit():
        continue
      elif x == '_':
        continue
      elif x == '$':
        continue
    return false
  return true
