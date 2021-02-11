
import ternary_tree

type VirtualListKind* = enum
  vListSeq,
  vListTree,

type CrVirtualList*[T] = ref object
  start: int
  ending: int
  kind*: VirtualListKind
  seqData*: seq[T]
  treeData*: TernaryTreeList[T]

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
    var xs = list.seqData
    list.kind = vListTree
    list.seqData = @[]
    list.treeData = initTernaryTreeList(xs)

proc get*[T](list: CrVirtualList[T], idx: int): T =
  if list.kind == vListSeq:
    list.turnIntoTree()
  list.treeData.loopGet(list.start + idx)

proc `[]`*[T](list: CrVirtualList[T], idx: int): T =
  list.get(idx)

proc first*[T](list: CrVirtualList[T]): T =
  list.get(0)

proc len*[T](list: CrVirtualList[T]): int =
  list.ending - list.start

proc last*[T](list: CrVirtualList[T]): T =
  list.get(list.len - 1)

proc rest*[T](list: CrVirtualList[T]): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.rest())

proc prepend*[T](list: CrVirtualList[T], x: T): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.prepend(x))

proc append*[T](list: CrVirtualList[T], x: T): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.append(x))

proc butlast*[T](list: CrVirtualList[T]): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.butlast())

proc reverse*[T](list: CrVirtualList[T]): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.reverse())

proc slice*[T](list: CrVirtualList[T], start: int, ending: int): CrVirtualList[T] =
  list.turnIntoTree()
  initCrVirtualList(list.treeData.slice(start, ending))

proc indexOf*[T](list: CrVirtualList[T], v: T): int =
  list.turnIntoTree()
  list.treeData.indexOf(v)

proc findIndex*[T](list: CrVirtualList[T], f: proc(v: T): bool): int =
  list.turnIntoTree()
  list.treeData.findIndex(f)

proc each*[T](list: CrVirtualList[T], f: proc(v: T): void): void =
  list.turnIntoTree()
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
    list.treeData.slice(list.start, list.ending).toSeq()

proc map*[T](list: CrVirtualList[T], f: proc (x: T): T): CrVirtualList[T] =
  if list.kind == vListSeq:
    initCrVirtualList(list.seqData.map(f))
  else:
    initCrVirtualList(list.treeData.map(f))

proc identical*[T](xs: CrVirtualList[T], ys: CrVirtualList[T]): bool =
  cast[pointer](xs) == cast[pointer](ys)

iterator items*[T](list: CrVirtualList[T]): T =
  list.turnIntoTree()
  for item in list.treeData:
    yield item

iterator pairs*[T](list: CrVirtualList[T]): tuple[k: int, v: T] =
  list.turnIntoTree()
  for idx, item in list.treeData:
    yield (idx, item)
