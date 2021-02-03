import { overwriteComparator, initTernaryTreeMap } from "@calcit/ternary-tree";

import {
  CrDataSymbol,
  CrDataValue,
  CrDataKeyword,
  CrDataList,
  CrDataMap,
  CrDataAtom,
  CrDataFn,
  CrDataRecur,
  kwd,
  atomsRegistry,
  toString,
  CrDataSet,
  cloneSet,
} from "./calcit-data";

export * from "./calcit-data";

let inNodeJs = typeof process !== "undefined" && process?.release?.name === "node";

export let type_of = (x: any): CrDataKeyword => {
  if (typeof x === "string") {
    return kwd("string");
  }
  if (typeof x === "number") {
    return kwd("number");
  }
  if (x instanceof CrDataKeyword) {
    return kwd("keyword");
  }
  if (x instanceof CrDataList) {
    return kwd("list");
  }
  if (x instanceof CrDataMap) {
    return kwd("map");
  }
  if (x == null) {
    return kwd("nil");
  }
  if (x instanceof CrDataAtom) {
    return kwd("atom");
  }
  if (x instanceof CrDataSymbol) {
    return kwd("symbol");
  }
  if (x instanceof CrDataSet) {
    return kwd("set");
  }
  if (x === true || x === false) {
    return kwd("bool");
  }
  if (typeof x === "function") {
    if (x.isMacro) {
      // this is faked...
      return kwd("macro");
    }
    return kwd("fn");
  }
  if (typeof x === "object") {
    return kwd("js-object");
  }
  throw new Error(`Unknown data ${x}`);
};

export let print = (...xs: CrDataValue[]): void => {
  // TODO stringify each values
  console.log(xs.map((x) => toString(x, false)).join(" "));
};

export let count = (x: CrDataValue): number => {
  if (x == null) {
    return 0;
  }
  if (typeof x === "string") {
    return x.length;
  }
  if (x instanceof CrDataList) {
    return x.len();
  }
  if (x instanceof CrDataMap) {
    return x.len();
  }
  if (x instanceof CrDataSet) {
    return x.len();
  }
  throw new Error(`Unknown data ${x}`);
};

export let _LIST_ = (...xs: CrDataValue[]): CrDataList => {
  return new CrDataList(xs);
};

export let _AND__MAP_ = (...xs: CrDataValue[]): CrDataMap => {
  if (xs.length % 2 !== 0) {
    throw new Error("&map expects even number of arguments");
  }
  var dict = new Map();
  for (let idx = 0; idx < xs.length >> 1; idx++) {
    dict = dict.set(xs[idx << 1], xs[(idx << 1) + 1]);
  }
  return new CrDataMap(initTernaryTreeMap(dict));
};

export let defatom = (path: string, x: CrDataValue): CrDataValue => {
  let v = new CrDataAtom(x, path);
  atomsRegistry.set(path, v);
  return v;
};

export let peekDefatom = (path: string): CrDataAtom => {
  return atomsRegistry.get(path);
};

export let deref = (x: CrDataAtom): CrDataValue => {
  let a = atomsRegistry.get(x.path);
  if (!(a instanceof CrDataAtom)) {
    console.warn("Can not find atom:", x);
  }
  return a.value;
};

export let foldl = function (f: CrDataFn, acc: CrDataValue, xs: CrDataValue): CrDataValue {
  if (arguments.length !== 3) {
    throw new Error("foldl takes 3 arguments");
  }

  if (f == null) {
    debugger;
    throw new Error("Expected function for folding");
  }
  if (xs instanceof CrDataList) {
    var result = acc;
    for (let idx = 0; idx < xs.len(); idx++) {
      let item = xs.get(idx);
      result = f(result, item);
    }
    return result;
  }
  if (xs instanceof CrDataSet) {
    let result = acc;
    xs.value.forEach((item) => {
      result = f(result, item);
    });
    return result;
  }
};

export let _AND__ADD_ = (x: number, y: number): number => {
  return x + y;
};

export let _AND__STAR_ = (x: number, y: number): number => {
  return x * y;
};

export let _AND__EQ_ = (x: CrDataValue, y: CrDataValue): boolean => {
  if (x === y) {
    return true;
  }
  if (x == null) {
    if (y == null) {
      return true;
    }
    return false;
  }

  let tx = typeof x;
  let ty = typeof y;

  if (tx !== ty) {
    return false;
  }

  if (tx === "string") {
    return (x as string) === (y as string);
  }
  if (tx === "boolean") {
    return (x as boolean) === (y as boolean);
  }
  if (tx === "number") {
    return x === y;
  }
  if (tx === "function") {
    // comparing functions by reference
    return x === y;
  }
  if (x instanceof CrDataKeyword) {
    if (y instanceof CrDataKeyword) {
      return x === y;
    }
    return false;
  }
  if (x instanceof CrDataList) {
    if (y instanceof CrDataList) {
      if (x.len() !== y.len()) {
        return false;
      }
      let size = x.len();
      for (let idx = 0; idx < size; idx++) {
        let xItem = x.get(idx);
        let yItem = y.get(idx);
        if (!_AND__EQ_(xItem, yItem)) {
          return false;
        }
      }
      return true;
    }
    return false;
  }
  if (x instanceof CrDataMap) {
    if (y instanceof CrDataMap) {
      if (x.len() !== y.len()) {
        return false;
      }
      for (let [k, v] of x.pairs()) {
        if (!y.contains(k)) {
          return false;
        }
        if (!_AND__EQ_(v, get(y, k))) {
          return false;
        }
      }
      return true;
    }
    return false;
  }
  if (x instanceof CrDataAtom) {
    if (y instanceof CrDataAtom) {
      return x === y;
    }
    return false;
  }
  if (x instanceof CrDataSet) {
    if (y instanceof CrDataSet) {
      if (x.len() !== y.len()) {
        return false;
      }
      for (let v in x.value.values()) {
        if (!y.contains(v)) {
          return false;
        }
      }
      return true;
    }
    return false;
  }
  if (x instanceof CrDataRecur) {
    if (y instanceof CrDataRecur) {
      console.warn("Do not compare Recur");
      return false;
    }
    return false;
  }
  throw new Error("Missing handler for this type");
  return false;
};

// overwrite internary comparator of ternary-tree
overwriteComparator(_AND__EQ_);

export let _AND_str = (x: CrDataValue): string => {
  return `${x}`;
};

export let raise = (x: string): void => {
  throw new Error(x);
};

export let contains_QUES_ = (xs: CrDataValue, x: CrDataValue): boolean => {
  if (typeof xs === "string") {
    if (typeof x !== "string") {
      throw new Error("Expected string");
    }
    return xs.includes(x as string);
  }
  if (xs instanceof CrDataList) {
    let size = xs.len();
    for (let v of xs.items()) {
      if (_AND__EQ_(v, x)) {
        return true;
      }
    }
    return false;
  }
  if (xs instanceof CrDataMap) {
    return xs.contains(x);
  }
  if (xs instanceof CrDataSet) {
    return xs.contains(x);
  }

  throw new Error("Does not support contains? on this type");
};

export let get = function (xs: CrDataValue, k: CrDataValue) {
  if (arguments.length !== 2) {
    throw new Error("get takes 2 arguments");
  }

  if (typeof xs === "string") {
    if (typeof k === "number") {
      return xs[k];
    } else {
      throw new Error("Expected number index for a string");
    }
  }
  if (xs instanceof CrDataList) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for a list");
    }
    return xs.get(k);
  }
  if (xs instanceof CrDataMap) {
    return xs.get(k);
  }

  throw new Error("Does not support `get` on this type");
};

export let assoc = function (xs: CrDataValue, k: CrDataValue, v: CrDataValue) {
  if (arguments.length !== 3) {
    throw new Error("assoc takes 3 arguments");
  }
  if (xs instanceof CrDataList) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for lists");
    }
    return xs.assoc(k, v);
  }

  if (xs instanceof CrDataMap) {
    return xs.assoc(k, v);
  }

  throw new Error("Does not support `assoc` on this type");
};

export let assoc_before = function (xs: CrDataList, k: number, v: CrDataValue): CrDataList {
  if (arguments.length !== 3) {
    throw new Error("assoc takes 3 arguments");
  }
  if (xs instanceof CrDataList) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for lists");
    }
    return xs.assocBefore(k, v);
  }

  throw new Error("Does not support `assoc-before` on this type");
};

export let assoc_after = function (xs: CrDataList, k: number, v: CrDataValue): CrDataList {
  if (arguments.length !== 3) {
    throw new Error("assoc takes 3 arguments");
  }
  if (xs instanceof CrDataList) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for lists");
    }
    return xs.assocAfter(k, v);
  }

  throw new Error("Does not support `assoc-after` on this type");
};

export let dissoc = function (xs: CrDataValue, k: CrDataValue) {
  if (arguments.length !== 2) {
    throw new Error("dissoc takes 2 arguments");
  }

  if (xs instanceof CrDataList) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for lists");
    }
    return xs.dissoc(k);
  }
  if (xs instanceof CrDataMap) {
    return xs.dissoc(k);
  }

  throw new Error("Does not support `dissoc` on this type");
};

export let reset_BANG_ = (a: CrDataAtom, v: CrDataValue): null => {
  if (!(a instanceof CrDataAtom)) {
    throw new Error("Expected atom for reset!");
  }
  let prev = a.value;
  a.value = v;
  for (let [k, f] of a.listeners) {
    f(v, prev);
  }
  return null;
};

export let add_watch = (a: CrDataAtom, k: CrDataKeyword, f: CrDataFn): null => {
  if (!(a instanceof CrDataAtom)) {
    throw new Error("Expected atom for add-watch!");
  }
  if (!(k instanceof CrDataKeyword)) {
    throw new Error("Expected watcher key in keyword");
  }
  if (!(typeof f === "function")) {
    throw new Error("Expected watcher function");
  }
  a.listeners.set(k, f);
  return null;
};

export let remove_watch = (a: CrDataAtom, k: CrDataKeyword): null => {
  a.listeners.delete(k);
  return null;
};

export let range = (n: number, m: number, m2: number): CrDataList => {
  var result = new CrDataList([]);
  if (m2 != null) {
    console.warn("TODO range with 3 arguments"); // TODO
  }
  if (m != null) {
    var idx = n;
    while (idx < m) {
      result = result.append(idx);
      idx = idx + 1;
    }
  } else {
    var idx = 0;
    while (idx < n) {
      result = result.append(idx);
      idx = idx + 1;
    }
  }
  return result;
};

export let empty_QUES_ = (xs: CrDataValue): boolean => {
  if (typeof xs == "string") {
    return xs.length == 0;
  }
  if (xs instanceof CrDataList) {
    return xs.isEmpty();
  }
  if (xs instanceof CrDataMap) {
    return xs.isEmpty();
  }
  if (xs instanceof CrDataSet) {
    return xs.len() === 0;
  }
  if (xs == null) {
    return true;
  }

  console.error(xs);
  throw new Error("Does not support `empty?` on this type");
};

export let wrapTailCall = (f: CrDataFn): CrDataFn => {
  return (...args: CrDataValue[]): CrDataValue => {
    if (typeof f !== "function") {
      debugger;
      throw new Error("Expected function to be called");
    }

    var result = f.apply(null, args);
    var times = 0;
    while (result instanceof CrDataRecur) {
      if (f === recur) {
        // do not recur on itself
        break;
      }
      if (times > 1000) {
        debugger;
        throw new Error("Expected tail recursion to exist quickly");
      }
      result = f.apply(null, result.args);
      times = times + 1;
    }
    if (result instanceof CrDataRecur) {
      throw new Error("Expected actual value to be returned");
    }
    return result;
  };
};

export let first = (xs: CrDataValue): CrDataValue => {
  if (xs == null) {
    return null;
  }
  if (xs instanceof CrDataList) {
    if (xs.isEmpty()) {
      return null;
    }
    return xs.first();
  }
  if (typeof xs === "string") {
    return xs[0];
  }
  if (xs instanceof CrDataSet) {
    return xs.first();
  }
  console.error(xs);
  throw new Error("Expects something sequential");
};

export let timeout_call = (duration: number, f: CrDataFn): null => {
  if (typeof duration !== "number") {
    throw new Error("Expected duration in number");
  }
  if (typeof f !== "function") {
    throw new Error("Expected callback in fn");
  }
  setTimeout(f, duration);
  return null;
};

export let rest = (xs: CrDataValue): CrDataValue => {
  if (xs instanceof CrDataList) {
    if (xs.len() === 0) {
      return null;
    }
    return xs.rest();
  }
  if (typeof xs === "string") {
    return xs.substr(1);
  }
  if (xs instanceof CrDataSet) {
    return xs.rest();
  }
  console.error(xs);

  throw new Error("Expects something sequential");
};

export let recur = (...xs: CrDataValue[]): CrDataRecur => {
  return new CrDataRecur(xs);
};

export let _AND_get_calcit_backend = () => {
  return kwd("js");
};

export let not = (x: boolean): boolean => {
  return !x;
};

export let prepend = (xs: CrDataValue, v: CrDataValue): CrDataList => {
  if (!(xs instanceof CrDataList)) {
    throw new Error("Expected array");
  }
  return xs.prepend(v);
};

export let append = (xs: CrDataValue, v: CrDataValue): CrDataList => {
  if (!(xs instanceof CrDataList)) {
    throw new Error("Expected array");
  }
  return xs.append(v);
};

export let last = (xs: CrDataValue): CrDataValue => {
  if (xs instanceof CrDataList) {
    if (xs.isEmpty()) {
      return null;
    }
    return xs.get(xs.len() - 1);
  }
  if (typeof xs === "string") {
    return xs[xs.length - 1];
  }
  console.error(xs);
  throw new Error("Data not ready for last");
};

export let butlast = (xs: CrDataValue): CrDataValue => {
  if (xs instanceof CrDataList) {
    if (xs.len() === 0) {
      return null;
    }
    return xs.slice(0, xs.len() - 1);
  }
  if (typeof xs === "string") {
    return xs.substr(0, xs.length - 1);
  }
  console.error(xs);
  throw new Error("Data not ready for butlast");
};

export let initCrTernary = (x: string): CrDataValue => {
  console.error("Ternary for js not implemented yet!");
  return null;
};

export let _AND_or = (x: boolean, y: boolean): boolean => {
  return x || y;
};
export let _AND_and = (x: boolean, y: boolean): boolean => {
  return x && y;
};

export let _SHA__MAP_ = (...xs: CrDataValue[]): CrDataValue => {
  var result = new Set<CrDataValue>();
  for (let idx in xs) {
    result.add(xs[idx]);
  }
  return new CrDataSet(result);
};

let idCounter = 0;

export let generate_id_BANG_ = (): string => {
  idCounter = idCounter + 1;
  return `gen_id_${idCounter}`;
};

export let display_stack = (): null => {
  console.trace();
  return null;
};

export let slice = (xs: CrDataList, from: number, to: number): CrDataList => {
  if (xs == null) {
    return null;
  }
  let size = xs.len();
  if (to == null) {
    to = size;
  } else if (to <= from) {
    return new CrDataList([]);
  } else if (to > size) {
    to = size;
  }
  return xs.slice(from, to);
};

export let _AND_concat = (...lists: CrDataList[]): CrDataList => {
  let result: CrDataList = new CrDataList([]);
  for (let item of lists) {
    if (item == null) {
      continue;
    }
    if (item instanceof CrDataList) {
      if (result.isEmpty()) {
        result = item;
      } else {
        result = result.concat(item);
      }
    } else {
      throw new Error("Expected list for concatenation");
    }
  }
  return result;
};

export let reverse = (xs: CrDataList): CrDataList => {
  if (xs == null) {
    return null;
  }
  return xs.reverse();
};

export let format_ternary_tree = (): null => {
  console.warn("No such function for js");
  return null;
};

export let _AND__GT_ = (a: number, b: number): boolean => {
  return a > b;
};
export let _AND__LT_ = (a: number, b: number): boolean => {
  return a < b;
};
export let _AND__ = (a: number, b: number): number => {
  return a - b;
};
export let _AND__SLSH_ = (a: number, b: number): number => {
  return a / b;
};
export let mod = (a: number, b: number): number => {
  return a % b;
};
export let _AND_str_concat = (a: string, b: string) => {
  return `${toString(a, false)}${toString(b, false)}`;
};
export let sort = (f: CrDataFn, xs: CrDataList): CrDataList => {
  if (xs == null) {
    return null;
  }
  if (xs instanceof CrDataList) {
    let ys = xs.toArray();
    return new CrDataList(ys.sort(f as any));
  }
  throw new Error("Expected list");
};

export let rand = (n: number, m: number): number => {
  if (m != null) {
    return n + (m - n) * Math.random();
  }
  if (n != null) {
    return Math.random() * n;
  }
  return Math.random() * 100;
};

export let rand_int = (n: number, m: number): number => {
  if (m != null) {
    return Math.round(n + Math.random() * (m - n));
  }
  if (n != null) {
    return Math.round(Math.random() * n);
  }
  return Math.round(Math.random() * 100);
};

export let floor = (n: number): number => {
  return Math.floor(n);
};

export let _AND_merge = (a: CrDataMap, b: CrDataMap): CrDataMap => {
  if (a == null) {
    return b;
  }
  if (b == null) {
    return a;
  }
  if (!(a instanceof CrDataMap)) {
    throw new Error("Expected map");
  }
  if (!(b instanceof CrDataMap)) {
    throw new Error("Expected map");
  }

  return a.merge(b);
};

export let _AND_merge_non_nil = (a: CrDataMap, b: CrDataMap): CrDataMap => {
  if (a == null) {
    return b;
  }
  if (b == null) {
    return a;
  }
  if (!(a instanceof CrDataMap)) {
    throw new Error("Expected map");
  }
  if (!(b instanceof CrDataMap)) {
    throw new Error("Expected map");
  }

  return a.mergeSkip(b, null);
};

export let to_pairs = (xs: CrDataMap): CrDataSet => {
  if (!(xs instanceof CrDataMap)) {
    throw new Error("Expected a map");
  }
  var result: Set<CrDataList> = new Set();
  for (let [k, v] of xs.pairs()) {
    result.add(new CrDataList([k, v]));
  }
  return new CrDataSet(result);
};

// Math functions

export let sin = (n: number) => {
  return Math.sin(n);
};
export let cos = (n: number) => {
  return Math.cos(n);
};
export let pow = (n: number, m: number) => {
  return Math.pow(n, m);
};
export let ceil = (n: number) => {
  return Math.ceil(n);
};
export let round = (n: number) => {
  return Math.round(n);
};
export let sqrt = (n: number) => {
  return Math.sqrt(n);
};

// Set functions

export let _AND_include = (xs: CrDataSet, y: CrDataValue): CrDataSet => {
  if (!(xs instanceof CrDataSet)) {
    throw new Error("Expected a set");
  }
  if (y == null) {
    return xs;
  }
  return xs.include(y);
};

export let _AND_exclude = (xs: CrDataSet, y: CrDataValue): CrDataSet => {
  if (!(xs instanceof CrDataSet)) {
    throw new Error("Expected a set");
  }
  if (y == null) {
    return xs;
  }
  return xs.exclude(y);
};

export let _AND_difference = (xs: CrDataSet, ys: CrDataSet): CrDataSet => {
  if (!(xs instanceof CrDataSet)) {
    throw new Error("Expected a set");
  }
  if (!(ys instanceof CrDataSet)) {
    throw new Error("Expected a set for ys");
  }
  return xs.difference(ys);
};

export let _AND_union = (xs: CrDataSet, ys: CrDataSet): CrDataSet => {
  if (!(xs instanceof CrDataSet)) {
    throw new Error("Expected a set");
  }
  if (!(ys instanceof CrDataSet)) {
    throw new Error("Expected a set for ys");
  }
  return xs.union(ys);
};

export let _AND_intersection = (xs: CrDataSet, ys: CrDataSet): CrDataSet => {
  if (!(xs instanceof CrDataSet)) {
    throw new Error("Expected a set");
  }
  if (!(ys instanceof CrDataSet)) {
    throw new Error("Expected a set for ys");
  }
  return xs.intersection(ys);
};

export let replace = (x: string, y: string, z: string): string => {
  var result = x;
  while (result.indexOf(y) >= 0) {
    result = result.replace(y, z);
  }
  return result;
};

export let split = (xs: string, x: string): CrDataList => {
  return new CrDataList(xs.split(x));
};
export let split_lines = (xs: string): CrDataList => {
  return new CrDataList(xs.split("\n"));
};
export let substr = (xs: string, m: number, n: number): string => {
  if (n <= m) {
    console.warn("endIndex too small");
    return "";
  }
  return xs.substring(m, n);
};

export let str_find = (x: string, y: string): number => {
  return x.indexOf(y);
};

export let parse_float = (x: string): number => {
  return parseFloat(x);
};
export let trim = (x: string, c: string): string => {
  if (c != null) {
    if (c.length !== 1) {
      throw new Error("Expceted c of a character");
    }
    var buffer = x;
    var size = buffer.length;
    var idx = 0;
    while (idx < size && buffer[idx] == c) {
      idx = idx + 1;
    }
    buffer = buffer.substring(idx);
    var size = buffer.length;
    var idx = size;
    while (idx > 1 && buffer[idx - 1] == c) {
      idx = idx - 1;
    }
    buffer = buffer.substring(0, idx);
    return buffer;
  }
  return x.trim();
};

export let format_number = (x: number, n: number): string => {
  return x.toFixed(n);
};

export let get_char_code = (c: string): number => {
  if (typeof c !== "string" || c.length !== 1) {
    throw new Error("Expected a character");
  }
  return c.charCodeAt(0);
};

export let re_matches = (re: string, content: string): boolean => {
  return new RegExp(re).test(content);
};

export let re_find_index = (re: string, content: string): number => {
  return content.search(new RegExp(re));
};

export let re_find_all = (re: string, content: string): CrDataList => {
  return new CrDataList(content.match(new RegExp(re, "g")));
};

export let to_js_data = (x: CrDataValue, addColon: boolean = false): any => {
  if (x == null) {
    return null;
  }
  if (x === true || x === false) {
    return x;
  }
  if (typeof x === "string") {
    return x;
  }
  if (typeof x === "number") {
    return x;
  }
  if (x instanceof CrDataKeyword) {
    if (addColon) {
      return `:${x.value}`;
    }
    return x.value;
  }
  if (x instanceof CrDataList) {
    var result: any[] = [];
    for (let item of x.items()) {
      result.push(to_js_data(item), addColon);
    }
    return result;
  }
  if (x instanceof CrDataMap) {
    let result: Record<string, CrDataValue> = {};
    for (let [k, v] of x.pairs()) {
      var key = to_js_data(k, addColon);
      result[key] = to_js_data(v, addColon);
    }
    return result;
  }
  if (x instanceof Set) {
    let result = new Set();
    x.forEach((v) => {
      result.add(to_js_data(v, addColon));
    });
    return result;
  }
  console.error(x);
  throw new Error("Unknown data to js");
};

export let to_calcit_data = (x: any, noKeyword: boolean = false): CrDataValue => {
  if (x == null) {
    return null;
  }
  if (typeof x === "number") {
    return x;
  }
  if (typeof x === "string") {
    if (!noKeyword && x[0] === ":" && x.slice(1).match(/^[\w\d_\?\!\-]+$/)) {
      return kwd(x.slice(1));
    }
    return x;
  }
  if (x === true || x === false) {
    return x;
  }
  if (Array.isArray(x)) {
    var result: any[] = [];
    x.forEach((v) => {
      result.push(to_calcit_data(v, noKeyword));
    });
    return new CrDataList(result);
  }
  if (x instanceof Set) {
    let result: Set<CrDataValue> = new Set();
    x.forEach((v) => {
      result.add(to_calcit_data(v, noKeyword));
    });
    return new CrDataSet(result);
  }
  // detects object
  if (x === Object(x)) {
    let result: Map<CrDataValue, CrDataValue> = new Map();
    Object.keys(x).forEach((k) => {
      result.set(to_calcit_data(k, noKeyword), to_calcit_data(x[k], noKeyword));
    });
    return new CrDataMap(initTernaryTreeMap(result));
  }

  console.error(x);
  throw new Error("Unexpected data for converting");
};

export let parse_json = (x: string): CrDataValue => {
  return to_calcit_data(JSON.parse(x), false);
};

export let stringify_json = (x: CrDataValue, addColon: boolean = false): string => {
  return JSON.stringify(to_js_data(x, addColon));
};

export let set__GT_list = (x: CrDataSet): CrDataList => {
  var result: CrDataValue[] = [];
  x.value.forEach((item) => {
    result.push(item);
  });
  return new CrDataList(result);
};

export let aget = (x: any, name: string): any => {
  return x[name];
};
export let aset = (x: any, name: string, v: any): any => {
  return (x[name] = v);
};

export let get_env = (name: string): string => {
  if (inNodeJs) {
    // only available for Node.js
    return process.env[name];
  }
  if (typeof URLSearchParams != null) {
    return new URLSearchParams(location.search).get("env");
  }
  return null;
};

export let turn_keyword = (x: CrDataValue): CrDataKeyword => {
  if (typeof x === "string") {
    return kwd(x);
  }
  if (x instanceof CrDataKeyword) {
    return x;
  }
  if (x instanceof CrDataSymbol) {
    return kwd(x.value);
  }
  console.error(x);
  throw new Error("Unexpected data for keyword");
};

export let turn_symbol = (x: CrDataValue): CrDataKeyword => {
  if (typeof x === "string") {
    return new CrDataSymbol(x);
  }
  if (x instanceof CrDataSymbol) {
    return x;
  }
  if (x instanceof CrDataKeyword) {
    return new CrDataSymbol(x.value);
  }
  console.error(x);
  throw new Error("Unexpected data for symbol");
};

export let pr_str = (...args: CrDataValue[]): string => {
  return args.map((x) => toString(x, true)).join(" ");
};

// time from app start
export let cpu_time = (): number => {
  if (inNodeJs) {
    return process.uptime();
  }
  return performance.now();
};

export let quit = (): void => {
  if (inNodeJs) {
    process.exit(1);
  } else {
    throw new Error("quit()");
  }
};

export let turn_string = (x: CrDataValue): string => {
  if (x == null) {
    return "";
  }
  if (typeof x === "string") {
    return x;
  }
  if (x instanceof CrDataKeyword) {
    return x.value;
  }
  if (x instanceof CrDataSymbol) {
    return x.value;
  }
  if (typeof x === "number") {
    return x.toString();
  }
  if (typeof x === "boolean") {
    return x.toString();
  }
  console.error(x);
  throw new Error("Unexpected data to turn string");
};

export let identical_QUES_ = (x: CrDataValue, y: CrDataValue): boolean => {
  return x === y;
};

export let starts_with_QUES_ = (xs: string, y: string): boolean => {
  return xs.startsWith(y);
};

type CirruEdnFormat = string | CirruEdnFormat[];

export let to_cirru_edn = (x: CrDataValue): CirruEdnFormat => {
  if (x == null) {
    return "nil";
  }
  if (typeof x === "string") {
    return `|${x}`;
  }
  if (typeof x === "number") {
    return x.toString();
  }
  if (typeof x === "boolean") {
    return x.toString();
  }
  if (x instanceof CrDataKeyword) {
    return x.toString();
  }
  if (x instanceof CrDataSymbol) {
    return x.toString();
  }
  if (x instanceof CrDataList) {
    // TODO can be faster
    return (["[]"] as CirruEdnFormat[]).concat(x.toArray().map(to_cirru_edn));
  }
  if (x instanceof CrDataMap) {
    let buffer: CirruEdnFormat = ["{}"];
    for (let [k, v] of x.pairs()) {
      buffer.push([to_cirru_edn(k), to_cirru_edn(v)]);
    }
    return buffer;
  }
  if (x instanceof Set) {
    let buffer: CirruEdnFormat = ["#{}"];
    for (let y of x) {
      buffer.push(to_cirru_edn(y));
    }
    return buffer;
  }
  console.error(x);
  throw new Error("Unexpected data to to-cirru-edn");
};

export let extract_cirru_edn = (x: CirruEdnFormat): CrDataValue => {
  if (typeof x === "string") {
    if (x === "nil") {
      return null;
    }
    if (x === "true") {
      return true;
    }
    if (x === "false") {
      return false;
    }
    if (x == "") {
      throw new Error("cannot be empty");
    }
    if (x[0] === "|" || x[0] === '"') {
      return x.slice(1);
    }
    if (x[0] === ":") {
      return kwd(x.substr(1));
    }
    if (x[0] === "'") {
      return new CrDataSymbol(x.substr(1));
    }
    if (x.match(/^(-?)\d+(\.\d*$)?/)) {
      return parseFloat(x);
    }
    // allow things cannot be parsed accepted as raw strings
    // turned on since Cirru nodes passed from macros uses this
    return x;
  }
  if (x instanceof Array) {
    if (x.length === 0) {
      throw new Error("Cannot be empty");
    }
    if (x[0] === "{}") {
      let result = new Map<CrDataValue, CrDataValue>();
      x.slice(1).forEach((pair) => {
        if (pair instanceof Array && pair.length == 2) {
          result.set(extract_cirru_edn(pair[0]), extract_cirru_edn(pair[1]));
        } else {
          throw new Error("Expected pairs for map");
        }
      });
      return new CrDataMap(initTernaryTreeMap(result));
    }
    if (x[0] === "[]") {
      return new CrDataList(x.slice(1).map(extract_cirru_edn));
    }
    if (x[0] === "#{}") {
      return new CrDataSet(new Set(x.slice(1).map(extract_cirru_edn)));
    }
    if (x[0] === "do" && x.length === 2) {
      return extract_cirru_edn(x[1]);
    }
    if (x[0] === "quote") {
      if (x.length !== 2) {
        throw new Error("quote expects 1 argument");
      }
      return to_calcit_data(x[1], true);
    }
  }
  console.error(x);
  throw new Error("Unexpected data from cirru-edn");
};

export let blank_QUES_ = (x: string): boolean => {
  if (x == null) {
    return true;
  }
  if (typeof x === "string") {
    return x.trim() === "";
  } else {
    throw new Error("Expected a string");
  }
};

export let compare_string = (x: string, y: string) => {
  if (x < y) {
    return -1;
  }
  if (x > y) {
    return 1;
  }
  return 0;
};

export let arrayToList = (xs: Array<CrDataValue>): CrDataList => {
  return new CrDataList(xs ?? []);
};

export let listToArray = (xs: CrDataList): Array<CrDataValue> => {
  if (xs == null) {
    return null;
  }
  if (xs instanceof CrDataList) {
    return xs.toArray();
  } else {
    throw new Error("Expected list");
  }
};

export let number_QUES_ = (x: CrDataValue): boolean => {
  return typeof x === "number";
};
export let string_QUES_ = (x: CrDataValue): boolean => {
  return typeof x === "string";
};
export let bool_QUES_ = (x: CrDataValue): boolean => {
  return typeof x === "boolean";
};
export let nil_QUES_ = (x: CrDataValue): boolean => {
  return x == null;
};
export let keyword_QUES_ = (x: CrDataValue): boolean => {
  return x instanceof CrDataKeyword;
};
export let map_QUES_ = (x: CrDataValue): boolean => {
  return x instanceof CrDataMap;
};
export let list_QUES_ = (x: CrDataValue): boolean => {
  return x instanceof CrDataList;
};
export let set_QUES_ = (x: CrDataValue): boolean => {
  return x instanceof CrDataSet;
};
export let fn_QUES_ = (x: CrDataValue): boolean => {
  return typeof x === "function";
};
export let atom_QUES_ = (x: CrDataValue): boolean => {
  return x instanceof CrDataAtom;
};

export let escape = (x: string) => JSON.stringify(x);

export let read_file = (path: string): string => {
  if (inNodeJs) {
    // TODO
    (globalThis as any)["__calcit_injections__"].read_file(path);
  } else {
    // no actual File API in browser
    return localStorage.get(path) ?? "";
  }
};
export let write_file = (path: string, content: string): void => {
  if (inNodeJs) {
    // TODO
    (globalThis as any)["__calcit_injections__"].write_file(path, content);
  } else {
    // no actual File API in browser
    localStorage.setItem(path, content);
  }
};

// special procs have to be defined manually
export let reduce = foldl;
export let conj = append;

let unavailableProc = (...xs: []) => {
  console.warn("NOT available for calcit-js");
};

export let format_time = unavailableProc; // TODO
export let now_BANG_ = unavailableProc; // TODO
export let parse_time = unavailableProc; // TODO

export let parse_cirru = unavailableProc; // TODO
export let parse_cirru_edn = unavailableProc; // TODO

// not available for calcit-js
export let _AND_reset_gensym_index_BANG_ = unavailableProc;
export let dbt__GT_point = unavailableProc;
export let dbt_digits = unavailableProc;
export let dual_balanced_ternary = unavailableProc;
export let gensym = unavailableProc;
export let macroexpand = unavailableProc;
export let macroexpand_all = unavailableProc;
