
import sets

# these procs are ignored in checking during macro expansion
let jsSyntaxProcs*: HashSet[string] = toHashSet([
  "aget", "aset", "new", "set!", "exists?", "instance?",
  "to-calcit-data",
  "to-js-data",
  "to-cirru-edn",
  "extract-cirru-edn",
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
