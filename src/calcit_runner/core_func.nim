
import json
import tables

import ./data
import ./types

let codeUnless = (%*
  ["defmacro", "unless", ["cond", "true-branch", "false-branch"],
    ["quote-replace", ["if", ["~", "cond"],
                             ["~", "false-branch"],
                             ["~", "true-branch"]]]
]).toCirruCode(coreNs)

let codeNativeNotEqual = (%*
  ["defn", "&!=", ["x", "y"], ["not", ["&=", "x", "y"]]]
).toCirruCode(coreNs)

let codeNativeLittlerEqual = (%*
  ["defn", "&<=", ["a", "b"],
    ["&or", ["&<", "a", "b"], ["&=", "a", "b"]]]
).toCirruCode(coreNs)

let codeNativeLargerEqual = (%*
  ["defn", "&>=", ["a", "b"],
    ["&or", ["&>", "a", "b"], ["&=", "a", "b"]]]
).toCirruCode(coreNs)

let codeEmpty = (%*
  ["defmacro", "empty?", ["x"],
    ["quote-replace", ["&=", "0", ["count", ["~", "x"]]]]]
).toCirruCode(coreNs)

let codeFirst = (%*
  ["defmacro", "first", ["xs"],
    ["quote-replace", ["get", ["~", "xs"], "0"]]]
).toCirruCode(coreNs)

let codeWhen = (%*
  ["defmacro", "when", ["cond", "&", "body"],
    ["quote-replace", ["if", ["do", ["~@", "body"]], "nil"]]]
).toCirruCode(coreNs)

let codeFoldl = (%*
  ["defn", "foldl", ["f", "xs", "acc"],
    ["if", ["empty?", "xs"], "acc",
           ["foldl", "f", ["rest", "xs"], ["f", "acc", ["first", "xs"]]]]]
).toCirruCode(coreNs)

let codeAdd = (%*
  ["defn", "+", ["x", "&", "ys"],
    ["foldl", "&+", "ys", "x"]]
).toCirruCode(coreNs)

let codeMinus = (%*
  ["defn", "-", ["x", "&", "ys"],
    ["foldl", "&-", "ys", "x"]]
).toCirruCode(coreNs)

let codeMultiply = (%*
  ["defn", "*", ["x", "&", "ys"],
    ["foldl", "&*", "ys", "x"]]
).toCirruCode(coreNs)

let codeDivide = (%*
  ["defn", "/", ["x", "&", "ys"],
    ["foldl", "&/", "ys", "x"]]
).toCirruCode(coreNs)

let codeFoldlCompare = (%*
  ["defn", "foldl-compare", ["f", "xs", "acc"],
    ["if", ["empty?", "xs"], "true",
           ["if", ["f", "acc", ["first", "xs"]],
                  ["foldl-compare", "f", ["rest", "xs"], ["first", "xs"]],
                  "false"]]]
).toCirruCode(coreNs)

let codeLittlerThan = (%*
  ["defn", "<", ["x", "&", "ys"], ["foldl-compare", "&<", "ys", "x"]]
).toCirruCode(coreNs)

let codeLargerThan = (%*
  ["defn", ">", ["x", "&", "ys"], ["foldl-compare", "&>", "ys", "x"]]
).toCirruCode(coreNs)

let codeEqual = (%*
  ["defn", "=", ["x", "&", "ys"], ["foldl-compare", "&=", "ys", "x"]]
).toCirruCode(coreNs)

let codeNotEqual = (%*
  ["defn", "!=", ["x", "&", "ys"], ["foldl-compare", "&!=", "ys", "x"]]
).toCirruCode(coreNs)

let codeLargerEqual = (%*
  ["defn", ">=", ["x", "&", "ys"], ["foldl-compare", "&>=", "ys", "x"]]
).toCirruCode(coreNs)

let codeLittlerEqual = (%*
  ["defn", "<=", ["x", "&", "ys"], ["foldl-compare", "&<=", "ys", "x"]]
).toCirruCode(coreNs)

let codeApply = (%*
  ["defmacro", "apply", ["f", "args"],
    ["quote-replace", ["~", ["prepend", "args", "f"]]]]
).toCirruCode(coreNs)

# todo list?
# todo map?
# todo number?
# todo string?
# todo symbol?
# todo keyword?
# todo bool?

proc loadCoreFuncs*(programCode: var Table[string, FileSource]) =
  programCode[coreNs].defs["unless"] = codeUnless
  programCode[coreNs].defs["&!="] = codeNativeNotEqual
  programCode[coreNs].defs["&<="] = codeNativeLittlerEqual
  programCode[coreNs].defs["&>="] = codeNativeLargerEqual
  programCode[coreNs].defs["empty?"] = codeEmpty
  programCode[coreNs].defs["first"] = codeFirst
  programCode[coreNs].defs["when"] = codeWhen
  programCode[coreNs].defs["foldl"] = codeFoldl
  programCode[coreNs].defs["+"] = codeAdd
  programCode[coreNs].defs["-"] = codeMinus
  programCode[coreNs].defs["*"] = codeMultiply
  programCode[coreNs].defs["/"] = codeDivide
  programCode[coreNs].defs["foldl-compare"] = codeFoldlCompare
  programCode[coreNs].defs["<"] = codeLittlerThan
  programCode[coreNs].defs[">"] = codeLargerThan
  programCode[coreNs].defs["="] = codeEqual
  programCode[coreNs].defs["!="] = codeNotEqual
  programCode[coreNs].defs[">="] = codeLargerEqual
  programCode[coreNs].defs["<="] = codeLittlerEqual
  programCode[coreNs].defs["apply"] = codeApply
