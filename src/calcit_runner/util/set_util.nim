
import tables
import sets

proc getTableKeys*[T](x: Table[string, T]): HashSet[string] =
  for k in x.keys:
    result.incl(k)
