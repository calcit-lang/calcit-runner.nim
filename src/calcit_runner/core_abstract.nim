
import tables

import ./types
import ./gen_code

proc loadCoreFuncs*(programCode: var Table[string, FileSource]) =

  let codeUnless = genCirru(
    ["defmacro", "unless", ["cond", "true-branch", "false-branch"],
      ["quote-replace", ["if", ["~", "cond"],
                               ["~", "false-branch"],
                               ["~", "true-branch"]]]
  ], coreNs)

  let codeNotEqual = genCirru(
    ["defn", "/=", ["x", "y"], ["not", ["&=", "x", "y"]]]
  , coreNs)

  let codeNativeLittlerEqual = genCirru(
    ["defn", "&<=", ["a", "b"],
      ["&or", ["&<", "a", "b"], ["&=", "a", "b"]]]
  , coreNs)

  let codeNativeLargerEqual = genCirru(
    ["defn", "&>=", ["a", "b"],
      ["&or", ["&>", "a", "b"], ["&=", "a", "b"]]]
  , coreNs)

  let codeFirst = genCirru(
    ["fn", "first", ["xs"],
      ["get", "xs", 0]]
  , coreNs)

  let codeWhen = genCirru(
    ["defmacro", "when", ["cond", "&", "body"],
      ["quote-replace", ["if", ["do", ["~@", "body"]], "nil"]]]
  , coreNs)

  # use native foldl for performance
  let codeFoldl = genCirru(
    ["defn", "foldl", ["f", "xs", "acc"],
      ["if", ["empty?", "xs"], "acc",
             ["recur", "f", ["rest", "xs"], ["f", "acc", ["first", "xs"]]]]]
  , coreNs)

  let codeAdd = genCirru(
    ["defn", "+", ["x", "&", "ys"],
      ["foldl", "&+", "ys", "x"]]
  , coreNs)

  let codeMinus = genCirru(
    ["defn", "-", ["x", "&", "ys"],
      ["foldl", "&-", "ys", "x"]]
  , coreNs)

  let codeMultiply = genCirru(
    ["defn", "*", ["x", "&", "ys"],
      ["foldl", "&*", "ys", "x"]]
  , coreNs)

  let codeDivide = genCirru(
    ["defn", "/", ["x", "&", "ys"],
      ["foldl", "&/", "ys", "x"]]
  , coreNs)

  let codeFoldlCompare = genCirru(
    ["defn", "foldl-compare", ["f", "xs", "acc"],
      ["if", ["empty?", "xs"], true,
             ["if", ["f", "acc", ["first", "xs"]],
                    ["recur", "f", ["rest", "xs"], ["first", "xs"]],
                    false]]]
  , coreNs)

  let codeLittlerThan = genCirru(
    ["defn", "<", ["x", "&", "ys"], ["foldl-compare", "&<", "ys", "x"]]
  , coreNs)

  let codeLargerThan = genCirru(
    ["defn", ">", ["x", "&", "ys"], ["foldl-compare", "&>", "ys", "x"]]
  , coreNs)

  let codeEqual = genCirru(
    ["defn", "=", ["x", "&", "ys"], ["foldl-compare", "&=", "ys", "x"]]
  , coreNs)

  let codeLargerEqual = genCirru(
    ["defn", ">=", ["x", "&", "ys"], ["foldl-compare", "&>=", "ys", "x"]]
  , coreNs)

  let codeLittlerEqual = genCirru(
    ["defn", "<=", ["x", "&", "ys"], ["foldl-compare", "&<=", "ys", "x"]]
  , coreNs)

  # TODO might be wrong at some cases, need research
  let codeApply = genCirru(
    ["defmacro", "apply", ["f", "args"],
      ["quote-replace", ["~", ["prepend", "args", "f"]]]]
  , coreNs)

  let codeListQuestion = genCirru(
    ["defn", "list?", ["x"], ["&=", ["type-of", "x"], ":list"]]
  , coreNs)

  let codeMapQuestion = genCirru(
    ["defn", "map?", ["x"], ["&=", ["type-of", "x"], ":map"]]
  , coreNs)

  let codeNumberQuestion = genCirru(
    ["defn", "number?", ["x"], ["&=", ["type-of", "x"], ":number"]]
  , coreNs)

  let codeStringQuestion = genCirru(
    ["defn", "string?", ["x"], ["&=", ["type-of", "x"], ":string"]]
  , coreNs)

  let codeSymbolQuestion = genCirru(
    ["defn", "symbol?", ["x"], ["&=", ["type-of", "x"], ":symbol"]]
  , coreNs)

  let codeKeywordQuestion = genCirru(
    ["defn", "keyword?", ["x"], ["&=", ["type-of", "x"], ":keyword"]]
  , coreNs)

  let codeBoolQuestion = genCirru(
    ["defn", "bool?", ["x"], ["&=", ["type-of", "x"], ":bool"]]
  , coreNs)

  let codeNilQuestion = genCirru(
    ["defn", "nil?", ["x"], ["&=", ["type-of", "x"], ":nil"]]
  , coreNs)

  let codeEach = genCirru(
    ["defn", "each", ["f", "xs"],
      ["if", ["not", ["empty?", "xs"]],
        ["do",
          ["f", ["first", "xs"]],
          ["recur", "f", ["rest", "xs"]]]]]
  , coreNs)

  let codeMap = genCirru(
    ["defn", "map", ["f", "xs"],
      ["foldl",
        ["fn", ["acc", "x"],
          ["append", "acc", ["f", "x"]]],
        "xs", ["[]"]]]
  , coreNs)

  let codeTake = genCirru(
    ["defn", "take", ["n", "xs"],
      ["slice", "xs", 0, "n"]]
  , coreNs)

  let codeDrop = genCirru(
    ["defn", "drop", ["n", "xs"],
      ["slice", "xs", "n", ["count", "xs"]]]
  , coreNs)

  let codeStr = genCirru(
    ["defn", "str", ["&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&str-concat", "acc", "item"]],
        "xs", "|"]]
  , coreNs)

  let codeInclude = genCirru(
    ["defn", "include", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&include", "acc", "item"]],
        "xs", "base"]]
  , coreNs)

  let codeExclude = genCirru(
    ["defn", "exclude", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&exclude", "acc", "item"]],
        "xs", "base"]]
  , coreNs)

  let codeDifference = genCirru(
    ["defn", "difference", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&difference", "acc", "item"]],
        "xs", "base"]]
  , coreNs)

  let codeUnion = genCirru(
    ["defn", "union", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&union", "acc", "item"]],
        "xs", "base"]]
  , coreNs)

  let codeIntersection = genCirru(
    ["defn", "intersection", ["base", "&", "xs"],
      ["foldl",
        ["fn", ["acc", "item"],
          ["&intersection", "acc", "item"]],
        "xs", "base"]]
  , coreNs)

  let codeNativeIndexOf = genCirru(
    ["defn", "&index-of", ["idx", "xs", "item"],
      ["if", ["empty?", "xs"], "nil",
        ["if", ["&=", "item", ["first", "xs"]], "idx",
          ["recur", ["&+", 1, "idx"], ["rest", "xs"], "item"]]]]
  , coreNs)

  let codeIndexOf = genCirru(
    ["defn", "index-of", ["xs", "item"],
      ["&index-of", 0, "xs", "item"]]
  , coreNs)

  let codeNativeFindIndex = genCirru(
    ["defn", "&find-index", ["idx", "f", "xs"],
      ["if", ["empty?", "xs"], "nil",
        ["if", ["f", ["first", "xs"]], "idx",
          ["recur", ["&+", 1, "idx"], "f", ["rest", "xs"]]]]]
  , coreNs)

  let codeFindIndex = genCirru(
    ["defn", "find-index", ["f", "xs"],
      ["let",
        [["idx", ["&find-index", 0, "f", "xs"]]],
        ["if", ["nil?", "idx"], "nil", "idx"]]]
  , coreNs)

  let codeFind = genCirru(
    ["defn", "find", ["f", "xs"],
      ["let",
        [["idx", ["&find-index", 0, "f", "xs"]]],
        ["if", ["nil?", "idx"], "nil", ["get", "xs", "idx"]]]]
  , coreNs)

  let codeThreadFirst = genCirru(
    ["defmacro", "->", ["base", "&", "xs"],
      ["if", ["empty?", "xs"], ["quote-replace", ["~", "base"]],
        ["let", [["x0", ["first", "xs"]]],
          ["if", ["list?", "x0"],
            ["recur", ["&concat", ["[]", ["first", "x0"], "base"], ["rest", "x0"]],
                      "&", ["rest", "xs"]],
            ["recur", ["[]", "x0", "base"], "&", ["rest", "xs"]]]]]]
  , coreNs)

  let codeThreadLast = genCirru(
    ["defmacro", "->>", ["base", "&", "xs"],
      ["if", ["empty?", "xs"], ["quote-replace", ["~", "base"]],
        ["let", [["x0", ["first", "xs"]]],
          ["if", ["list?", "x0"],
            ["recur", ["append", "x0", "base"], "&", ["rest", "xs"]],
            ["recur", ["[]", "x0", "base"], "&", ["rest", "xs"]]]]]]
  , coreNs)

  let codeCond = genCirru(
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
  , coreNs)

  let codeCase = genCirru(
    ["defmacro", "case", ["item", "pattern", "&", "else"],
      ["assert", "|pattern is a pair",
        ["&and", ["list?", "pattern"], ["&=", "2", ["count", "pattern"]]]],
      ["let", [["expr", ["first", "pattern"]],
               ["branch", ["last", "pattern"]]],
        ["quote-replace",
          ["if", ["&=", ["~", "item"], ["~", "expr"]], ["~", "branch"],
            ["~", ["if", ["empty?", "else"], "nil",
                    ["quote-replace", ["case", ["~", "item"], "&", ["~", "else"]]]]]]]]]
  , coreNs)

  let codeGetIn = genCirru(
    ["defn", "get-in", ["base", "path"],
      ["assert", "|path is a list", ["list?", "path"]],
      ["cond",
        [["nil?", "base"], "nil"],
        [["empty?", "path"], "base"],
        [true, ["recur", ["get", "base", ["first", "path"]], ["rest", "path"]]]]]
  , coreNs)

  let codeNativeMax = genCirru(
    ["defn", "&max", ["a", "b"],
      ["assert", "|find max from numbers", ["&and", ["number?", "a"], ["number?", "b"]]],
      ["if", ["&>", "a", "b"], "a", "b"]]
  , coreNs)

  let codeNativeMin = genCirru(
    ["defn", "&min", ["a", "b"],
      ["assert", "|find min from numbers", ["&and", ["number?", "a"], ["number?", "b"]]],
      ["if", ["&<", "a", "b"], "a", "b"]]
  , coreNs)

  let codeMax = genCirru(
    ["defn", "max", ["xs"],
      ["if", ["empty?", "xs"], "nil",
        ["foldl",
          ["fn", ["acc", "x"],
            ["&max", "acc", "x"]],
          ["rest", "xs"], ["first", "xs"]]]]
  , coreNs)

  let codeMin = genCirru(
    ["defn", "min", ["xs"],
      ["if", ["empty?", "xs"], "nil",
        ["foldl",
          ["fn", ["acc", "x"], ["&min", "acc", "x"]],
          ["rest", "xs"], ["first", "xs"]]]]
  , coreNs)

  let codeEveryQuestion = genCirru(
    [defn, "every?", [f, xs],
      ["if", ["empty?", xs], true,
        ["if", [f, [first, xs]], [recur, f, [rest, xs]], false]]]
  , coreNs)

  let codeAnyQuestion = genCirru(
    [defn, "any?", [f, xs],
      ["if", ["empty?", xs], false,
        ["if", [f, [first, xs]], true, [recur, f, [rest, xs]]]]]
  , coreNs)

  let codeConcat = genCirru(
    [defn, concat, [item, "&", xs],
      ["if", ["empty?", xs], item,
        [recur, ["&concat", item, [first, xs]], "&", [rest, xs]]]]
  , coreNs)

  let codeMapcat = genCirru(
    [defn, mapcat, [f, xs],
      [concat, "&", [map, f, xs]]]
  , coreNs)

  let codeMerge = genCirru(
    [defn, merge, [x0, "&", xs],
      [foldl, "&merge", xs, x0]]
  , coreNs)

  let codeIdentity = genCirru(
    [defn, identity, [x], x]
  , coreNs)

  let codeMapIndexed = genCirru(
    [defn, "map-indexed", [f, xs],
      [loop,
        [[acc, ["[]"]], [idx, 0], [ys, xs]],
        ["if", ["empty?", ys], acc,
             [recur, [append, acc, [f, idx, [first, ys]]],
                     ["&+", idx, 1],
                     [rest, ys]]]]]
  , coreNs)

  let codeFilter = genCirru(
    [defn, filter, [f, xs],
      [foldl,
        [fn, [acc, x],
             ["if", [f, x],
                  [append, acc, x],
                  acc]],
        xs,
        ["[]"]]]
  , coreNs)

  let codeFilterNot = genCirru(
    [defn, "filter-not", [f, xs],
      [foldl,
        [fn, [acc, x],
             [unless, [f, x],
                  [append, acc, x],
                  acc]],
        xs,
        ["[]"]]]
  , coreNs)

  let codePairMap = genCirru(
    [defn, "pair-map", [xs],
      [foldl, [fn, [acc, pair],
                   ["assert", "|expects a pair", ["&and", ["list?", pair], ["&=", 2, [count, pair]]]],
                   [assoc, acc, [first, pair], [last, pair]]],
              xs,
              ["{}"]]]
  , coreNs)

  let codeZipmap = genCirru(
    [defn, "zipmap", [xs0, ys0],
      [loop, [[acc, ["{}"]], [xs, xs0], [ys, ys0]],
        ["if", ["&or", ["empty?", xs], ["empty?", ys]], acc,
          [recur, [assoc, acc, [first, xs], [first, ys]],
                  [rest, xs], [rest, ys]]]]]
  , coreNs)

  let codeRandNth = genCirru(
    [defn, "rand-nth", [xs],
      ["if", ["empty?", xs], "nil",
        [get, xs, ["rand-int", [count, xs]]]]]
  , coreNs)

  let codeSomeQuestion = genCirru(
    [defn, "some?", [x],
      ["not", ["nil?", x]]]
  , coreNs)

  # TODO assoc-in
  # TODO dissoc-in
  # TODO update-in

  programCode[coreNs].defs["unless"] = codeUnless
  programCode[coreNs].defs["&<="] = codeNativeLittlerEqual
  programCode[coreNs].defs["&>="] = codeNativeLargerEqual
  programCode[coreNs].defs["first"] = codeFirst
  programCode[coreNs].defs["when"] = codeWhen

  # programCode[coreNs].defs["foldl"] = codeFoldl
  programCode[coreNs].defs["+"] = codeAdd
  programCode[coreNs].defs["-"] = codeMinus
  programCode[coreNs].defs["*"] = codeMultiply
  programCode[coreNs].defs["/"] = codeDivide
  programCode[coreNs].defs["foldl-compare"] = codeFoldlCompare
  programCode[coreNs].defs["<"] = codeLittlerThan
  programCode[coreNs].defs[">"] = codeLargerThan
  programCode[coreNs].defs["="] = codeEqual
  programCode[coreNs].defs["/="] = codeNotEqual
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
  programCode[coreNs].defs["every?"] = codeEveryQuestion
  programCode[coreNs].defs["any?"] = codeAnyQuestion
  programCode[coreNs].defs["concat"] = codeConcat
  programCode[coreNs].defs["mapcat"] = codeMapcat
  programCode[coreNs].defs["merge"] = codeMerge
  programCode[coreNs].defs["identity"] = codeIdentity
  programCode[coreNs].defs["map-indexed"] = codeMapIndexed
  programCode[coreNs].defs["filter"] = codeFilter
  programCode[coreNs].defs["filter-not"] = codeFilterNot
  programCode[coreNs].defs["pair-map"] = codePairMap
  programCode[coreNs].defs["zipmap"] = codeZipmap
  programCode[coreNs].defs["rand-nth"] = codeRandNth
  programCode[coreNs].defs["some?"] = codeSomeQuestion
