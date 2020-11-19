
import lists
import strutils

import ternary_tree

import ./types
import ./errors

type StackInfo* = object
  ns*: string
  def*: string
  code*: CirruData
  args*: seq[CirruData]

var defStack*: DoublyLinkedList[StackInfo]

proc reversed*[T](s: seq[T]): seq[T] =
  result = newSeq[T](s.len)
  for i in 0 .. s.high: result[s.high - i] = s[i]

proc reversed*[T](s: DoublyLinkedList[T]): DoublyLinkedList[T] =
  for i in s:
    result.prepend i

proc pushDefStack*(x: StackInfo): void =
  defStack.append x

proc pushDefStack*(node: CirruData, code: CirruData, args: seq[CirruData]): void =
  if node.kind == crDataSymbol:
    pushDefStack(StackInfo(ns: node.ns, def: node.symbolVal, code: code, args: args))
  else:
    pushDefStack(StackInfo(ns: "??", def: "??", code: code, args: args))

proc popDefStack*(): void =
  defStack.remove defStack.tail

proc showStack*(): void =
  # let errorStack = reversed(defStack)
  for item in defStack:
    echo item.ns, "/", item.def
    dimEcho $item.code
    dimEcho "args: ", $CirruData(kind: crDataList, listVal: initTernaryTreeList(item.args))

var traceFnNs: string
var traceFnName: string
var traceStackSize* = 0

proc matchesTraceFn*(ns: string, def: string): bool =
  traceFnNs == ns and traceFnName == def

proc setTraceFn*(ns: string, def: string) =
  traceFnNs = ns
  traceFnName = def

proc getTraceIndentation*(): string =
  repeat("  ", traceStackSize)
