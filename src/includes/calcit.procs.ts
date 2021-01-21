import {
  TernaryTreeList,
  TernaryTreeMap,
  overwriteComparator,
  initTernaryTreeList,
  initTernaryTreeMap,
  listLen,
  mapLen,
  loopGetList,
  mapLoopGet,
  assocMap,
  assocList,
  dissocMap,
  isMapEmpty,
  toPairsIterator,
  contains,
  listItems,
  dissocList,
} from "@calcit/ternary-tree";

import * as ternaryTree from "@calcit/ternary-tree";

let inNodeJs =
  typeof process !== "undefined" && process?.release?.name === "node";

class CrDataKeyword {
  value: string;
  constructor(x: string) {
    this.value = x;
  }
  toString() {
    return `:${this.value}`;
  }
}
export class CrDataSymbol {
  value: string;
  constructor(x: string) {
    this.value = x;
  }
  toString() {
    return `'${this.value}`;
  }
}

class CrDataRecur {
  args: CrDataValue[];
  constructor(xs: CrDataValue[]) {
    this.args = xs;
  }

  toString() {
    return `(&recur ...)`;
  }
}

class CrDataAtom {
  value: CrDataValue;
  path: string;
  listeners: Map<CrDataValue, CrDataFn>;
  constructor(x: CrDataValue, path: string) {
    this.value = x;
    this.path = path;
    this.listeners = new Map();
  }
  toString(): string {
    return `(&atom ${this.value.toString()})`;
  }
}

type CrDataFn = (...xs: CrDataValue[]) => CrDataValue;

class CrDataList {
  value: TernaryTreeList<CrDataValue>;
  constructor(value: TernaryTreeList<CrDataValue>) {
    this.value = value;
  }
  len() {
    return listLen(this.value);
  }
  get(idx: number) {
    return loopGetList(this.value, idx);
  }
  assoc(idx: number, v: CrDataValue) {
    return new CrDataList(assocList(this.value, idx, v));
  }
  dissoc(idx: number) {
    return new CrDataList(dissocList(this.value, idx));
  }
  slice(from: number, to: number) {
    return new CrDataList(ternaryTree.slice(this.value, from, to));
  }
  toString() {
    return "TODO list";
  }
  isEmpty() {
    return listLen(this.value) == 0;
  }
  items() {
    return listItems(this.value);
  }
  append(v: CrDataValue) {
    return new CrDataList(ternaryTree.append(this.value, v));
  }
  prepend(v: CrDataValue) {
    return new CrDataList(ternaryTree.prepend(this.value, v));
  }
  first() {
    return ternaryTree.first(this.value);
  }
  rest() {
    return new CrDataList(ternaryTree.rest(this.value));
  }
  concat(ys: CrDataList) {
    if (!(ys instanceof CrDataList)) {
      throw new Error("Expected list");
    }
    return new CrDataList(ternaryTree.concat(this.value, ys.value));
  }
  map(f: (v: CrDataValue) => CrDataValue) {
    let result: Array<CrDataValue> = [];
    for (let item of this.items()) {
      result.push(f(item));
    }
    return new CrDataList(initTernaryTreeList(result));
  }
  toArray(): CrDataValue[] {
    return ternaryTree.listToSeq(this.value);
  }
}

class CrDataMap {
  value: TernaryTreeMap<CrDataValue, CrDataValue>;
  constructor(value: TernaryTreeMap<CrDataValue, CrDataValue>) {
    this.value = value;
  }
  len() {
    return mapLen(this.value);
  }
  get(k: CrDataValue) {
    return mapLoopGet(this.value, k);
  }
  assoc(k: CrDataValue, v: CrDataValue) {
    return new CrDataMap(assocMap(this.value, k, v));
  }
  dissoc(k: CrDataValue) {
    return new CrDataMap(dissocMap(this.value, k));
  }
  toString() {
    return "TODO map";
  }
  isEmpty() {
    return isMapEmpty(this.value);
  }
  pairs() {
    return toPairsIterator(this.value);
  }
  contains(k: CrDataValue) {
    return contains(this.value, k);
  }
  merge(ys: CrDataMap) {
    if (!(ys instanceof CrDataMap)) {
      throw new Error("Expected map");
    }
    return ternaryTree.merge(this.value, ys.value);
  }
  mergeSkip(ys: CrDataMap, v: CrDataValue) {
    if (!(ys instanceof CrDataMap)) {
      throw new Error("Expected map");
    }
    return ternaryTree.mergeSkip(this.value, ys.value, v);
  }
}

type CrDataValue =
  | string
  | number
  | boolean
  | CrDataMap
  | CrDataList
  // TODO set
  | Set<CrDataValue>
  | CrDataKeyword
  | CrDataSymbol
  | CrDataAtom
  | CrDataFn
  | CrDataRecur // should not be exposed to function
  | null;

var keywordRegistery: Record<string, CrDataKeyword> = {};

export let kwd = (content: string) => {
  if (keywordRegistery[content] != null) {
    return keywordRegistery[content];
  } else {
    let v = new CrDataKeyword(content);
    keywordRegistery[content] = v;
    return v;
  }
};

var atomsRegistry = new Map<string, CrDataAtom>();

export let type_DASH_of = (x: any): CrDataKeyword => {
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
  if (x instanceof Set) {
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

export let print = (...xs: string[]): void => {
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
    return listLen(x.value);
  }
  if (x instanceof CrDataMap) {
    return mapLen(x.value);
  }
  if (x instanceof Set) {
    return (x as Set<CrDataValue>).size;
  }
  throw new Error(`Unknown data ${x}`);
};

export let _LIST_ = (...xs: CrDataValue[]): CrDataList => {
  return new CrDataList(initTernaryTreeList(xs));
};

export let _AND__MAP_ = (...xs: CrDataValue[]): CrDataMap => {
  var result = new CrDataMap(initTernaryTreeMap(new Map()));
  for (let idx in xs) {
    let pair = xs[idx];
    if (pair instanceof CrDataList) {
      if (pair.len() === 2) {
      } else {
        throw new Error("Expected pairs of 2");
      }
      let k = pair.get(0);
      let v = pair.get(1);
      result = result.assoc(k, v);
    } else {
      throw new Error("Expected a pair in list");
    }
  }
  return result;
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

export let foldl = function (
  f: CrDataFn,
  acc: CrDataValue,
  xs: CrDataValue
): CrDataValue {
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
  if (xs instanceof Set) {
    let result = acc;
    xs.forEach((item) => {
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
  if (x instanceof Set) {
    if (y instanceof Set) {
      let x2 = x as Set<CrDataValue>;
      let y2 = y as Set<CrDataValue>;
      if (x2.size !== y2.size) {
        return false;
      }
      for (let v in x2.values()) {
        if (!y2.has(v)) {
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
    for (let [k, v] of xs.pairs()) {
      if (_AND__EQ_(k, x)) {
        return true;
      }
    }
    return false;
  }
  if (xs instanceof Set) {
    // TODO structure inside set
    return xs.has(x);
  }

  // TODO set not handled
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
    for (let [mk, v] of xs.pairs()) {
      if (_AND__EQ_(mk, k)) {
        return v;
      }
    }

    return null;
  }

  throw new Error("Does not support `get` on this type");
};

// TODO
// shallow copy
let cloneMap = (
  xs: Map<CrDataValue, CrDataValue>
): Map<CrDataValue, CrDataValue> => {
  if (!(xs instanceof Map)) {
    throw new Error("Expected a map");
  }
  var result: Map<CrDataValue, CrDataValue> = new Map();
  for (let [k, v] of xs) {
    result.set(k, v);
  }
  return result;
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

  throw new Error("Does not support `get` on this type");
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

export let add_DASH_watch = (
  a: CrDataAtom,
  k: CrDataKeyword,
  f: CrDataFn
): null => {
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

export let remove_DASH_watch = (a: CrDataAtom, k: CrDataKeyword): null => {
  a.listeners.delete(k);
  return null;
};

export let range = (n: number, m: number, m2: number): CrDataList => {
  var result = new CrDataList(initTernaryTreeList([]));
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
  if (xs instanceof Set) {
    return xs.size === 0;
  }
  if (xs == null) {
    return true;
  }

  console.error(xs);
  throw new Error("Does not support `empty?` on this type");
};

export let wrapTailCall = (f: CrDataFn): CrDataFn => {
  return (...args: CrDataFn[]): CrDataValue => {
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
    return xs.first();
  }
  if (typeof xs === "string") {
    return xs[0];
  }
  if (xs instanceof Set) {
    if (xs.size === 0) {
      return null;
    }
    for (let x of xs) {
      return x;
    }
  }
  console.error(xs);
  throw new Error("Expects something sequential");
};

export let timeout_DASH_call = (duration: number, f: CrDataFn): null => {
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
  if (xs instanceof Set) {
    if (xs.size == 0) {
      return null;
    }
    let it = xs.values();
    let x0 = it.next().value;
    let ys = cloneSet(xs);
    ys.delete(x0);
    return ys;
  }
  console.error(xs);

  throw new Error("Expects something sequential");
};

export let recur = (...xs: CrDataValue[]): CrDataRecur => {
  return new CrDataRecur(xs);
};

export let _AND_get_DASH_calcit_DASH_backend = () => {
  return kwd("js");
};

export let not = (x: boolean): boolean => {
  return !x;
};

// TODO
let cloneArray = (xs: CrDataValue[]): CrDataValue[] => {
  if (!(xs instanceof Array)) {
    throw new Error("Expected an array");
  }
  let ys: CrDataValue[] = new Array(xs.length);
  for (let idx in xs) {
    ys[idx] = xs[idx];
  }
  return ys;
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
  return result;
};

let idCounter = 0;

export let generate_DASH_id_BANG_ = (): string => {
  idCounter = idCounter + 1;
  return `gen_id_${idCounter}`;
};

export let display_DASH_stack = (): null => {
  console.trace();
  return null;
};

export let slice = (xs: CrDataList, from: number, to: number): CrDataList => {
  return xs.slice(from, to);
};

export let _AND_concat = (xs: CrDataList, ys: CrDataList): CrDataList => {
  return xs.concat(ys);
};

export let reverse = (xs: CrDataList): CrDataList => {
  if (xs == null) {
    return null;
  }
  var result = initTernaryTreeList([]);
  for (let x of xs.items()) {
    result = ternaryTree.prepend(result, x);
  }
  return new CrDataList(result);
};

export let format_DASH_ternary_DASH_tree = (): null => {
  console.warn("No such function for js");
  return null;
};

export let _AND__GT_ = (a: number, b: number): boolean => {
  return a > b;
};
export let _AND__LT_ = (a: number, b: number): boolean => {
  return a < b;
};
export let _AND__DASH_ = (a: number, b: number): number => {
  return a - b;
};
export let _AND__SLSH_ = (a: number, b: number): number => {
  return a / b;
};
export let mod = (a: number, b: number): number => {
  return a % b;
};
export let _AND_str_DASH_concat = (a: string, b: string) => {
  return `${a}${b}`;
};
export let sort = (f: CrDataFn, xs: CrDataValue[]) => {
  let ys = cloneArray(xs);
  return ys.sort(f as any); // TODO need check tests
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

export let rand_DASH_int = (n: number, m: number): number => {
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

  return new CrDataMap(a.merge(b));
};

export let _AND_merge_DASH_non_DASH_nil = (
  a: CrDataMap,
  b: CrDataMap
): CrDataMap => {
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

  return new CrDataMap(a.mergeSkip(b, null));
};

export let to_DASH_pairs = (xs: CrDataMap): Set<[CrDataValue, CrDataValue]> => {
  if (!(xs instanceof Map)) {
    throw new Error("Expected a map");
  }
  var result: Set<[CrDataValue, CrDataValue]> = new Set();
  for (let [k, v] of xs.pairs()) {
    result.add([k, v]);
  }
  return result;
};

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

export let cloneSet = (xs: Set<CrDataValue>): Set<CrDataValue> => {
  if (!(xs instanceof Set)) {
    throw new Error("Expected a set");
  }
  var result: Set<CrDataValue> = new Set();
  for (let v of xs) {
    result.add(v);
  }
  return result;
};

export let _AND_include = (
  xs: Set<CrDataValue>,
  y: CrDataValue
): Set<CrDataValue> => {
  var result = cloneSet(xs);
  result.add(y);
  return result;
};

export let _AND_exclude = (
  xs: Set<CrDataValue>,
  y: CrDataValue
): Set<CrDataValue> => {
  var result = cloneSet(xs);
  result.delete(y);
  return result;
};

export let _AND_difference = (
  xs: Set<CrDataValue>,
  ys: Set<CrDataValue>
): Set<CrDataValue> => {
  var result = cloneSet(xs);
  ys.forEach((y) => {
    if (result.has(y)) {
      result.delete(y);
    }
  });
  return result;
};
export let _AND_union = (
  xs: Set<CrDataValue>,
  ys: Set<CrDataValue>
): Set<CrDataValue> => {
  var result = cloneSet(xs);
  ys.forEach((y) => {
    if (!result.has(y)) {
      result.add(y);
    }
  });
  return result;
};
export let _AND_intersection = (
  xs: Set<CrDataValue>,
  ys: Set<CrDataValue>
): Set<CrDataValue> => {
  var result: Set<CrDataValue> = new Set();
  ys.forEach((y) => {
    if (xs.has(y)) {
      result.add(y);
    }
  });
  return result;
};

export let replace = (x: string, y: string, z: string): string => {
  var result = x;
  while (result.indexOf(y) >= 0) {
    result = result.replace(y, z);
  }
  return result;
};

export let split = (xs: string, x: string): string[] => {
  return xs.split(x);
};
export let split_DASH_lines = (xs: string): string[] => {
  return xs.split("\n");
};
export let substr = (xs: string, m: number, n: number): string => {
  if (n <= m) {
    console.warn("endIndex too small");
    return "";
  }
  return xs.substring(m, n);
};

export let str_DASH_find = (x: string, y: string): number => {
  return x.indexOf(y);
};

export let parse_DASH_float = (x: string): number => {
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

export let format_DASH_number = (x: number, n: number): string => {
  return x.toFixed(n);
};

export let get_DASH_char_DASH_code = (c: string): number => {
  if (typeof c !== "string" || c.length !== 1) {
    throw new Error("Expected a character");
  }
  return c.charCodeAt(0);
};

export let re_DASH_matches = (re: string, content: string): boolean => {
  return new RegExp(re).test(content);
};

export let re_DASH_find_DASH_index = (re: string, content: string): number => {
  return content.search(new RegExp(re));
};

export let re_DASH_find_DASH_all = (re: string, content: string): string[] => {
  return content.match(new RegExp(re, "g"));
};

export let to_DASH_js_DASH_data = (
  x: CrDataValue,
  addColon: boolean = false
): any => {
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
      result.push(to_DASH_js_DASH_data(item), addColon);
    }
    return result;
  }
  if (x instanceof CrDataMap) {
    for (let [k, v] of x.pairs()) {
      var key = to_DASH_js_DASH_data(k, addColon);
      result[key] = to_DASH_js_DASH_data(v, addColon);
    }
    return result;
  }
  if (x instanceof Set) {
    let result = new Set();
    x.forEach((v) => {
      result.add(to_DASH_js_DASH_data(v, addColon));
    });
    return result;
  }
  console.error(x);
  throw new Error("Unknown data to js");
};

export let to_DASH_calcit_DASH_data = (x: any) => {
  if (typeof x === "number") {
    return x;
  }
  if (typeof x === "string") {
    if (x[0] === ":" && x.slice(1).match(/^[\w\d_\?\!\-]+$/)) {
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
      result.push(to_DASH_calcit_DASH_data(v));
    });
    return new CrDataList(initTernaryTreeList(result));
  }
  if (x instanceof Set) {
    let result: Set<CrDataValue> = new Set();
    x.forEach((v) => {
      result.add(to_DASH_calcit_DASH_data(v));
    });
    return result;
  }
  // detects object
  if (x === Object(x)) {
    let result: Map<CrDataValue, CrDataValue> = new Map();
    Object.keys(x).forEach((k) => {
      result.set(to_DASH_calcit_DASH_data(k), to_DASH_calcit_DASH_data(x[k]));
    });
    return new CrDataMap(initTernaryTreeMap(result));
  }

  console.error(x);
  throw new Error("Unexpected data for converting");
};

export let parse_DASH_json = (x: string): CrDataValue => {
  return to_DASH_calcit_DASH_data(JSON.parse(x));
};

export let stringify_DASH_json = (
  x: CrDataValue,
  addColon: boolean = false
): string => {
  return JSON.stringify(to_DASH_js_DASH_data(x, addColon));
};

export let set_DASH__GT_list = (x: Set<CrDataValue>): CrDataValue[] => {
  var result: CrDataValue[] = [];
  x.forEach((item) => {
    result.push(item);
  });
  return result;
};

export let aget = (x: any, name: string): any => {
  return x[name];
};
export let aset = (x: any, name: string, v: any): any => {
  return (x[name] = v);
};

export let get_DASH_env = (name: string): string => {
  if (inNodeJs) {
    // only available for Node.js
    return process.env[name];
  }
  if (typeof URLSearchParams != null) {
    return new URLSearchParams(location.search).get("env");
  }
  return null;
};

export let turn_DASH_keyword = (x: CrDataValue): CrDataKeyword => {
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

export let turn_DASH_symbol = (x: CrDataValue): CrDataKeyword => {
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

let toString = (x: CrDataValue, escaped: boolean): string => {
  if (x == null) {
    return "nil";
  }
  if (typeof x === "string") {
    if (escaped) {
      return JSON.stringify(x);
    } else {
      return x;
    }
  }
  if (typeof x === "number") {
    return x.toString();
  }
  if (typeof x === "boolean") {
    return x.toString();
  }
  if (x instanceof CrDataSymbol) {
    return x.toString();
  }
  if (x instanceof CrDataKeyword) {
    return x.toString();
  }
  if (x instanceof CrDataList) {
    // TODO
    return `[${x
      .map((x) => toString(x, true))
      .toArray()
      .join(" ")}]`;
  }
  if (x instanceof Set) {
    let itemsCode = "";
    x.forEach((child, idx) => {
      if (idx > 0) {
        itemsCode = `${itemsCode} `;
      }
      itemsCode = `${itemsCode}${toString(child, true)}`;
    });
    return `#{${itemsCode}}`;
  }
  if (x instanceof CrDataMap) {
    let itemsCode = "";
    for (let [k, v] of x.pairs()) {
      if (itemsCode !== "") {
        itemsCode = `${itemsCode}, `;
      }
      itemsCode = `${itemsCode}${toString(k, true)} ${toString(v, true)}`;
    }
    return `{${itemsCode}}`;
  }
  if (typeof x === "function") {
    return `(&fn ...)`;
  }

  console.error(x);
  throw new Error("Unexpected data for toString");
};

export let pr_DASH_str = (...args: CrDataValue[]): string => {
  return args.map((x) => toString(x, true)).join(" ");
};

// time from app start
export let cpu_DASH_time = (): number => {
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

export let turn_DASH_string = (x: CrDataValue): string => {
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

export let starts_DASH_with_QUES_ = (xs: string, y: string): boolean => {
  return xs.startsWith(y);
};

type CirruEdnFormat = string | CirruEdnFormat[];

export let to_DASH_cirru_DASH_edn = (x: CrDataValue): CirruEdnFormat => {
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
    return (["[]"] as CirruEdnFormat[]).concat(
      x.toArray().map(to_DASH_cirru_DASH_edn)
    );
  }
  if (x instanceof CrDataMap) {
    let buffer: CirruEdnFormat = ["{}"];
    for (let [k, v] of x.pairs()) {
      buffer.push([to_DASH_cirru_DASH_edn(k), to_DASH_cirru_DASH_edn(v)]);
    }
    return buffer;
  }
  if (x instanceof Set) {
    let buffer: CirruEdnFormat = ["#{}"];
    for (let y of x) {
      buffer.push(to_DASH_cirru_DASH_edn(y));
    }
    return buffer;
  }
  console.error(x);
  throw new Error("Unexpected data to to-cirru-edn");
};

export let extract_DASH_cirru_DASH_edn = (x: CirruEdnFormat): CrDataValue => {
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
          result.set(
            extract_DASH_cirru_DASH_edn(pair[0]),
            extract_DASH_cirru_DASH_edn(pair[1])
          );
        } else {
          throw new Error("Expected pairs for map");
        }
      });
      return new CrDataMap(initTernaryTreeMap(result));
    }
    if (x[0] === "[]") {
      return new CrDataList(
        initTernaryTreeList(x.slice(1).map(extract_DASH_cirru_DASH_edn))
      );
    }
    if (x[0] === "#{}") {
      return new Set(x.slice(1).map(extract_DASH_cirru_DASH_edn));
    }
    if (x[0] === "do" && x.length === 2) {
      return extract_DASH_cirru_DASH_edn(x[1]);
    }
    if (x[0] === "quote") {
      if (x.length !== 2) {
        throw new Error("quote expects 1 argument");
      }
      return to_DASH_calcit_DASH_data(x[1]);
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

export let compare_DASH_string = (x: string, y: string) => {
  if (x < y) {
    return -1;
  }
  if (x > y) {
    return 1;
  }
  return 0;
};

// special procs have to be defined manually
export let reduce = foldl;
export let conj = append;
