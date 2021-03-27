
import algorithm
import sequtils

import ternary_tree

type VirtualListKind* = enum
  vListSeq,
  vListTree,

type CrVirtualList*[T] = ref object
  start: int
  ending: int
  kind*: VirtualListKind
  seqData*: seq[T] # for seq, track list range with start/ending
  treeData*: TernaryTreeList[T] # for tree, ignore start/ending, just use tree

proc initCrVirtualList*[T](xs: TernaryTreeList[T]): CrVirtualList[T] =
  CrVirtualList[T](
    start: 0,
    ending: xs.len,
    kind: vListTree,
    seqData: @[],
    treeData: xs,
  )

proc initCrVirtualList*[T](xs: seq[T]): CrVirtualList[T] =
  CrVirtualList[T](
    start: 0,
    ending: xs.len,
    kind: vListSeq,
    seqData: xs,
    treeData: nil,
  )

proc turnIntoTree*[T](list: CrVirtualList[T]): void =
  if list.kind == vListSeq:
    var xs = list.seqData[list.start..<list.ending]
    list.kind = vListTree
    list.seqData = @[]
    list.treeData = initTernaryTreeList(xs)

proc get*[T](list: CrVirtualList[T], idx: int): T =
  if list.kind == vListSeq:
    list.seqData[list.start + idx]
  else:
    list.treeData.loopGet(idx)

proc `[]`*[T](list: CrVirtualList[T], idx: int): T =
  list.get(idx)

proc first*[T](list: CrVirtualList[T]): T =
  list.get(0)

proc len*[T](list: CrVirtualList[T]): int =
  if list.kind == vListSeq:
    list.ending - list.start
  else:
    list.treeData.len()

proc last*[T](list: CrVirtualList[T]): T =
  list.get(list.len - 1)

proc rest*[T](list: CrVirtualList[T]): CrVirtualList[T] =
  if list.kind == vListSeq:
    if list.len() > 0:
      var ret = initCrVirtualList(list.seqData)
      ret.start = list.start + 1
      ret.ending = list.ending
      ret
    else:
      initCrVirtualList[T](@[])
  else:
    initCrVirtualList(list.treeData.rest())

proc prepend*[T](list: CrVirtualList[T], x: T): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.prepend(x))

proc append*[T](list: CrVirtualList[T], x: T): CrVirtualList[T] =
  if list.kind == vListSeq:
    if list.ending == list.seqData.len():
      # dirty trick, if there's empty space, store value there
      list.seqData.add(x)
      # in the new reference to data, track with new ending index
      var ret = initCrVirtualList(list.seqData)
      ret.start = list.start
      ret.ending = list.ending + 1
      ret
    else:
      list.turnIntoTree()
      initCrVirtualList(list.treeData.append(x))
  else:
    initCrVirtualList(list.treeData.append(x))

proc butlast*[T](list: CrVirtualList[T]): CrVirtualList[T] =
  if list.kind == vListSeq:
    if list.len > 0:
      var ret = initCrVirtualList(list.seqData)
      ret.start = list.start
      ret.ending = list.ending - 1
      ret
    else:
      initCrVirtualList[T](@[])
  else:
    initCrVirtualList(list.treeData.butlast())

proc reverse*[T](list: CrVirtualList[T]): CrVirtualList[T] =
  if list.kind == vListSeq:
    initCrVirtualList(list.seqData.reversed())
  else:
    initCrVirtualList(list.treeData.reverse())

proc slice*[T](list: CrVirtualList[T], start: int, ending: int): CrVirtualList[T] =
  if list.kind == vListSeq:
    initCrVirtualList(list.seqData[(list.start + start)..<(list.start + ending)])
  else:
    initCrVirtualList(list.treeData.slice(start, ending))

proc indexOf*[T](list: CrVirtualList[T], v: T): int =
  if list.kind == vListSeq:
    for i in list.start..<list.ending:
      if list.seqData[i] == v:
        return i
    -1
  else:
    list.treeData.indexOf(v)

proc findIndex*[T](list: CrVirtualList[T], f: proc(v: T): bool): int =
  if list.kind == vListSeq:
    for i in list.start..<list.ending:
      if f(list.seqData[i]):
        return i
    -1
  else:
    list.treeData.findIndex(f)

proc each*[T](list: CrVirtualList[T], f: proc(v: T): void): void =
  if list.kind == vListSeq:
    for i in list.start..<list.ending:
      f(list.seqData[i])
  else:
    list.treeData.each(f)

proc assocBefore*[T](list: CrVirtualList[T], idx: int, v: T): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.assocBefore(idx, v))

proc assocAfter*[T](list: CrVirtualList[T], idx: int, v: T): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.assocAfter(idx, v))

proc assoc*[T](list: CrVirtualList[T], idx: int, v: T): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.assoc(idx, v))

proc dissoc*[T](list: CrVirtualList[T], idx: int): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.dissoc(idx))

proc toSeq*[T](list: CrVirtualList[T]): seq[T] =
  if list.kind == vListSeq:
    list.seqData[list.start..<list.ending]
  else:
    list.treeData.toSeq()

proc map*[T](list: CrVirtualList[T], f: proc (x: T): T): CrVirtualList[T] =
  if list.kind == vListSeq:
    initCrVirtualList(list.seqData[list.start..<list.ending].map(f))
  else:
    initCrVirtualList(list.treeData.mapValues(f))

proc identical*[T](xs: CrVirtualList[T], ys: CrVirtualList[T]): bool =
  cast[pointer](xs) == cast[pointer](ys)

proc concat*[T](args: varargs[CrVirtualList[T]]): CrVirtualList[T] =
  var xs: seq[TernaryTreeList[T]]
  for item in args:
    if item.len == 0:
      continue
    item.turnIntoTree() # TODO need checking
    xs.add item.treeData
  return initCrVirtualList(initTernaryTreeList(xs.len, 0, xs))

iterator items*[T](list: CrVirtualList[T]): T =
  if list.kind == vListSeq:
    for idx in list.start..<list.ending:
      yield list.seqData[idx]
  else:
    for item in list.treeData:
      yield item

iterator pairs*[T](list: CrVirtualList[T]): tuple[k: int, v: T] =
  if list.kind == vListSeq:
    for idx in list.start..<list.ending:
      yield (idx - list.start, list.seqData[idx])
  else:
    for idx, item in list.treeData:
      yield (idx, item)
