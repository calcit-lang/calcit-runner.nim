
type CirruInterpretError* = ref object of ValueError
  line*: int
  column*: int

type CirruCommandError* = ValueError
