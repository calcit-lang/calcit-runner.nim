
import json
import tables

import ./data
import ./types

proc loadCoreFuncs*(programCode: var Table[string, FileSource]) =

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
      ["quote-replace", ["&=", 0, ["count", ["~", "x"]]]]]
  ).toCirruCode(coreNs)

  let codeFirst = (%*
    ["defmacro", "first", ["xs"],
      ["quote-replace", ["get", ["~", "xs"], 0]]]
  ).toCirruCode(coreNs)

  let codeWhen = (%*
    ["defmacro", "when", ["cond", "&", "body"],
      ["quote-replace", ["if", ["do", ["~@", "body"]], "nil"]]]
  ).toCirruCode(coreNs)

  let codeFoldl = (%*
    ["defn", "foldl", ["f", "xs", "acc"],
      ["if", ["empty?", "xs"], "acc",
             ["recur", "f", ["rest", "xs"], ["f", "acc", ["first", "xs"]]]]]
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
      ["if", ["empty?", "xs"], true,
             ["if", ["f", "acc", ["first", "xs"]],
                    ["recur", "f", ["rest", "xs"], ["first", "xs"]],
                    false]]]
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

  # TODO might be wrong at some cases, need research
  let codeApply = (%*
    ["defmacro", "apply", ["f", "args"],
      ["quote-replace", ["~", ["prepend", "args", "f"]]]]
  ).toCirruCode(coreNs)

  let codeListQuestion = (%*
    ["defn", "list?", ["x"], ["&=", ["type-of", "x"], ":list"]]
  ).toCirruCode(coreNs)

  let codeMapQuestion = (%*
    ["defn", "map?", ["x"], ["&=", ["type-of", "x"], ":map"]]
  ).toCirruCode(coreNs)

  let codeNumberQuestion = (%*
    ["defn", "number?", ["x"], ["&=", ["type-of", "x"], ":number"]]
  ).toCirruCode(coreNs)

  let codeStringQuestion = (%*
    ["defn", "string?", ["x"], ["&=", ["type-of", "x"], ":string"]]
  ).toCirruCode(coreNs)

  let codeSymbolQuestion = (%*
    ["defn", "symbol?", ["x"], ["&=", ["type-of", "x"], ":symbol"]]
  ).toCirruCode(coreNs)

  let codeKeywordQuestion = (%*
    ["defn", "keyword?", ["x"], ["&=", ["type-of", "x"], ":keyword"]]
  ).toCirruCode(coreNs)

  let codeBoolQuestion = (%*
    ["defn", "bool?", ["x"], ["&=", ["type-of", "x"], ":bool"]]
  ).toCirruCode(coreNs)

  let codeNilQuestion = (%*
    ["defn", "nil?", ["x"], ["&=", ["type-of", "x"], ":nil"]]
  ).toCirruCode(coreNs)

  let codeEach = (%*
    ["defn", "each", ["f", "xs"],
      ["if", ["not", ["empty?", "xs"]],
        ["do",
          ["f", ["first", "xs"]],
          ["recur", "f", ["rest", "xs"]]]]]
  ).toCirruCode(coreNs)

  let codeMap = (%*
    ["defn", "map", ["f", "xs"],
      ["foldl",
        ["fn", ["acc", "x"],
          ["append", "acc", ["f", "x"]]],
        "xs", ["[]"]]]
  ).toCirruCode(coreNs)

  let codeTake = (%*
    ["defn", "take", ["n", "xs"],
      ["slice", "xs", 0, "n"]]
  ).toCirruCode(coreNs)

  let codeDrop = (%*
    ["defn", "drop", ["n", "xs"],
      ["slice", "xs", "n", ["count", "xs"]]]
  ).toCirruCode(coreNs)

  let codeStr = (%*
    ["defn", "str", ["&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&str-concat", "acc", "item"]],
        "xs", "|"]]
  ).toCirruCode(coreNs)

  let codeInclude = (%*
    ["defn", "include", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&include", "acc", "item"]],
        "xs", "base"]]
  ).toCirruCode(coreNs)

  let codeExclude = (%*
    ["defn", "exclude", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&exclude", "acc", "item"]],
        "xs", "base"]]
  ).toCirruCode(coreNs)

  let codeDifference = (%*
    ["defn", "difference", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&difference", "acc", "item"]],
        "xs", "base"]]
  ).toCirruCode(coreNs)

  let codeUnion = (%*
    ["defn", "union", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&union", "acc", "item"]],
        "xs", "base"]]
  ).toCirruCode(coreNs)

  let codeIntersection = (%*
    ["defn", "intersection", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&intersection", "acc", "item"]],
        "xs", "base"]]
  ).toCirruCode(coreNs)

  let codeNativeIndexOf = (%*
    ["defn", "&index-of", ["idx", "xs", "item"],
      ["if", ["empty?", "xs"], "nil",
        ["if", ["&=", "item", ["first", "xs"]], "idx",
          ["recur", ["&+", 1, "idx"], ["rest", "xs"], "item"]]]]
  ).toCirruCode(coreNs)

  let codeIndexOf = (%*
    ["defn", "index-of", ["xs", "item"],
      ["&index-of", 0, "xs", "item"]]
  ).toCirruCode(coreNs)

  let codeNativeFindIndex = (%*
    ["defn", "&find-index", ["idx", "f", "xs"],
      ["if", ["empty?", "xs"], "nil",
        ["if", ["f", ["first", "xs"]], "idx",
          ["recur", ["&+", 1, "idx"], "f", ["rest", "xs"]]]]]
  ).toCirruCode(coreNs)

  let codeFindIndex = (%*
    ["defn", "find-index", ["f", "xs"],
      ["let",
        [["idx", ["&find-index", 0, "f", "xs"]]],
        ["if", ["nil?", "idx"], "nil", "idx"]]]
  ).toCirruCode(coreNs)

  let codeFind = (%*
    ["defn", "find", ["f", "xs"],
      ["let",
        [["idx", ["&find-index", 0, "f", "xs"]]],
        ["if", ["nil?", "idx"], "nil", ["get", "xs", "idx"]]]]
  ).toCirruCode(coreNs)

  let codeThreadFirst = (%*
    ["defmacro", "->", ["base", "&", "xs"],
      ["if", ["empty?", "xs"], ["quote-replace", ["~", "base"]],
        ["let", [["x0", ["first", "xs"]]],
          ["if", ["list?", "x0"],
            ["recur", ["concat", ["[]", ["first", "x0"], "base"], ["rest", "x0"]],
                      "&", ["rest", "xs"]],
            ["recur", ["[]", "x0", "base"], "&", ["rest", "xs"]]]]]]
  ).toCirruCode(coreNs)

  let codeThreadLast = (%*
    ["defmacro", "->>", ["base", "&", "xs"],
      ["if", ["empty?", "xs"], ["quote-replace", ["~", "base"]],
        ["let", [["x0", ["first", "xs"]]],
          ["if", ["list?", "x0"],
            ["recur", ["append", "x0", "base"], "&", ["rest", "xs"]],
            ["recur", ["[]", "x0", "base"], "&", ["rest", "xs"]]]]]]
  ).toCirruCode(coreNs)

  let codeCond = (%*
    ["defmacro", "cond", ["pair", "&", "else"],
      ["assert", "|expects a pair",
        ["&and", ["list?", "pair"], ["&=", 2, ["count", "pair"]]]],
      ["let", [["expr", ["first", "pair"]],
               ["branch", ["last", "pair"]]],
        ["quote-replace",
          ["if", ["~", "expr"], ["~", "branch"],
            ["~", ["if", ["empty?", "else"], "nil",
              ["quote-replace",
                ["cond", ["~", ["first", "else"]],
                  "&", ["~", ["rest", "else"]]]]]]]]]
      ]
  ).toCirruCode(coreNs)

  let codeCase = (%*
    ["defmacro", "case", ["item", "pattern", "&", "else"],
      ["assert", "|pattern is a pair",
        ["&and", ["list?", "pattern"], ["&=", "2", ["count", "pattern"]]]],
      ["let", [["expr", ["first", "pattern"]],
               ["branch", ["last", "pattern"]]],
        ["quote-replace",
          ["if", ["&=", ["~", "item"], ["~", "expr"]], ["~", "branch"],
            ["~", ["if", ["empty?", "else"], "nil",
                    ["quote-replace", ["case", ["~", "item"], "&", ["~", "else"]]]]]]]]]
  ).toCirruCode(coreNs)

  let codeGetIn = (%*
    ["defn", "get-in", ["base", "path"],
      ["assert", "|path is a list", ["list?", "path"]],
      ["cond",
        [["nil?", "base"], "nil"],
        [["empty?", "path"], "base"],
        [true, ["recur", ["get", "base", ["first", "path"]], ["rest", "path"]]]]]
  ).toCirruCode(coreNs)

  let codeNativeMax = (%*
    ["defn", "&max", ["a", "b"],
      ["assert", "|find max from numbers", ["&and", ["number?", "a"], ["number?", "b"]]],
      ["if", ["&>", "a", "b"], "a", "b"]]
  ).toCirruCode(coreNs)

  let codeNativeMin = (%*
    ["defn", "&min", ["a", "b"],
      ["assert", "|find min from numbers", ["&and", ["number?", "a"], ["number?", "b"]]],
      ["if", ["&<", "a", "b"], "a", "b"]]
  ).toCirruCode(coreNs)

  let codeMax = (%*
    ["defn", "max", ["xs"],
      ["if", ["empty?", "xs"], "nil",
        ["foldl",
          ["fn", ["acc", "x"],
            ["&max", "acc", "x"]],
          ["rest", "xs"], ["first", "xs"]]]]
  ).toCirruCode(coreNs)

  let codeMin = (%*
    ["defn", "min", ["xs"],
      ["if", ["empty?", "xs"], "nil",
        ["foldl",
          ["fn", ["acc", "x"], ["&min", "acc", "x"]],
          ["rest", "xs"], ["first", "xs"]]]]
  ).toCirruCode(coreNs)

  # TODO assoc-in
  # TODO dissoc-in
  # TODO update-in

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
  programCode[coreNs].defs["list?"] = codeListQuestion
  programCode[coreNs].defs["map?"] = codeMapQuestion
  programCode[coreNs].defs["number?"] = codeNumberQuestion
  programCode[coreNs].defs["string?"] = codeStringQuestion
  programCode[coreNs].defs["keyword?"] = codeKeywordQuestion
  programCode[coreNs].defs["symbol?"] = codeSymbolQuestion
  programCode[coreNs].defs["bool?"] = codeBoolQuestion
  programCode[coreNs].defs["nil?"] = codeNilQuestion
  programCode[coreNs].defs["each"] = codeEach
  programCode[coreNs].defs["map"] = codeMap
  programCode[coreNs].defs["take"] = codeTake
  programCode[coreNs].defs["drop"] = codeDrop
  programCode[coreNs].defs["str"] = codeStr
  programCode[coreNs].defs["include"] = codeInclude
  programCode[coreNs].defs["exclude"] = codeExclude
  programCode[coreNs].defs["difference"] = codeDifference
  programCode[coreNs].defs["union"] = codeUnion
  programCode[coreNs].defs["intersection"] = codeIntersection
  programCode[coreNs].defs["&index-of"] = codeNativeIndexOf
  programCode[coreNs].defs["index-of"] = codeIndexOf
  programCode[coreNs].defs["&find-index"] = codeNativeFindIndex
  programCode[coreNs].defs["find-index"] = codeFindIndex
  programCode[coreNs].defs["find"] = codeFind
  programCode[coreNs].defs["->"] = codeThreadFirst
  programCode[coreNs].defs["->>"] = codeThreadLast
  programCode[coreNs].defs["cond"] = codeCond
  programCode[coreNs].defs["case"] = codeCase
  programCode[coreNs].defs["get-in"] = codeGetIn
  programCode[coreNs].defs["&max"] = codeNativeMax
  programCode[coreNs].defs["&min"] = codeNativeMin
  programCode[coreNs].defs["max"] = codeMax
  programCode[coreNs].defs["min"] = codeMin
