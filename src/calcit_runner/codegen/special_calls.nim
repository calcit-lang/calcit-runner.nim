

import sets

# these procs are ignored in checking during macro expansion
let jsSyntaxProcs*: HashSet[string] = toHashSet([
  "aget", "aset", "new", "to-js-data", "set!", "exists?", "instance?",
])

let jsUnavailableProcs* = toHashSet([
  "&reset-gensym-index!",
  "dbt->point",
  "dbt-digits",
  "dbt-balanced-ternary",
  "gensym",
  "macroexpand",
  "macroexpand-all",
  "to-cirru-edn",
  "extract-cirru-edn",
])
