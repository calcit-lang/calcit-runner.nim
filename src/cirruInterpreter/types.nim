
import strutils
import sequtils
import tables
import hashes
import strformat

type CirruInterpretError* = ref object of ValueError
  line*: int
  column*: int

type CirruCommandError* = ValueError

type
  MaybeNilKind* = enum
    beNil,
    beSomething

  MaybeNil*[T] = ref object
    case kind*: MaybeNilKind
    of beNil:
      discard
    of beSomething:
      value*: T
