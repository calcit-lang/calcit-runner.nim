class CrDataKeyword {
  content: string;
  constructor(x: string) {
    this.content = x;
  }
  toString() {
    return `:${this.content}`;
  }
  // get [Symbol.toStringTag]() {
  //   return `:${this.content}`;
  // }
  [Symbol.toPrimitive]() {
    return `:${this.content}`;
  }
}

class CrDataRecur {
  args: CrDataValue[];
  constructor(xs: CrDataValue[]) {
    this.args = xs;
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
}

type CrDataFn = (...xs: CrDataValue[]) => CrDataValue;

type CrDataValue =
  | string
  | number
  | boolean
  | Map<CrDataValue, CrDataValue>
  | Set<CrDataValue>
  | Array<CrDataValue>
  // TODO set
  | CrDataKeyword
  | CrDataAtom
  | CrDataFn
  | CrDataRecur // should not be exposed to function
  | null;

var keywordRegistery = new Map();

export let kwd = (content: string) => {
  if (keywordRegistery.has(content)) {
    return keywordRegistery.get(content);
  } else {
    let v = new CrDataKeyword(content);
    keywordRegistery.set(content, v);
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
  if (x instanceof Array) {
    return kwd("list");
  }
  if (x instanceof Map) {
    return kwd("map");
  }
  if (x == null) {
    return kwd("nil");
  }
  if (x instanceof CrDataAtom) {
    return kwd("atom");
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
  throw new Error(`Unknown data ${x}`);
};

export let print = (...xs: string[]): any => {
  // TODO stringify each values
  console.log(...xs);
};

export let count = (x: CrDataValue): number => {
  let t = type_DASH_of(x);
  if (t === kwd("string")) {
    return (x as string).length;
  }
  if (t === kwd("list")) {
    return (x as CrDataValue[]).length;
  }
  if (t === kwd("map")) {
    return (x as Map<CrDataValue, CrDataValue>).size;
  }
  if (t === kwd("set")) {
    return (x as Set<CrDataValue>).size;
  }
  throw new Error(`Unknown data ${x}`);
};

export let _LIST_ = (...xs: CrDataValue[]): CrDataValue[] => {
  return xs;
};

export let _AND__MAP_ = (
  ...xs: CrDataValue[]
): Map<CrDataValue, CrDataValue> => {
  var result = new Map();
  for (let idx in xs) {
    let pair = xs[idx] as CrDataValue[];
    if (!Array.isArray(pair)) {
      throw new Error("Expected pairs");
    }
    if (pair.length != 2) {
      throw new Error("Expected a pair in length 2");
    }
    let [k, v] = pair;
    result.set(k, v);
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

export let foldl = (
  f: CrDataFn,
  acc: CrDataValue,
  xs: CrDataValue
): CrDataValue => {
  if (f == null) {
    debugger;
    throw new Error("Expected function for folding");
  }
  if (xs instanceof Array) {
    var result = acc;
    for (let idx in xs) {
      let item = xs[idx];
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
  let tx = type_DASH_of(x);
  let ty = type_DASH_of(y);
  if (tx === ty) {
    if (tx === kwd("keyword")) {
      return x === y;
    }
    if (tx === kwd("string")) {
      return (x as string) === (y as string);
    }
    if (tx === kwd("bool")) {
      return (x as boolean) === (y as boolean);
    }
    if (tx === kwd("number")) {
      return (x as number) === (y as number);
    }
    if (tx === kwd("nil")) {
      return true;
    }
    if (tx === kwd("map")) {
      let x2 = x as Map<CrDataValue, CrDataValue>;
      let y2 = y as Map<CrDataValue, CrDataValue>;
      if (x2.size !== y2.size) {
        return false;
      }
      for (let k in x2) {
        if (!y2.has(k)) {
          return false;
        }
        if (!_AND__EQ_(x2.get(k), y2.get(k))) {
          return false;
        }
      }
      return true;
    }
    if (tx === kwd("list")) {
      let x2 = x as CrDataValue[];
      let y2 = y as CrDataValue[];
      if (x2.length !== y2.length) {
        return false;
      }
      for (let idx in x2) {
        let xItem = x2[idx];
        let yItem = y2[idx];
        if (!_AND__EQ_(xItem, yItem)) {
          return false;
        }
      }
      return true;
    }
    if (tx === kwd("atom")) {
      return x === y;
    }
    if (tx === kwd("fn")) {
      console.warn("Do not compare functions");
      return false;
    }
    if (tx === kwd("recur")) {
      console.warn("Do not compare Recur");
      return false;
    }
    if (tx === kwd("set")) {
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
    throw new Error("Missing handler for this type");
  } else {
    return false;
  }
};

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
  if (xs instanceof Array) {
    for (let idx in xs) {
      let v = xs[idx];
      if (_AND__EQ_(v, x)) {
        return true;
      }
    }
    return false;
  }
  if (xs instanceof Map) {
    return xs.has(x);
  }
  if (xs instanceof Set) {
    return xs.has(x);
  }

  // TODO set not handled
  throw new Error("Does not support contains? on this type");
};

export let get = (xs: CrDataValue, k: CrDataValue) => {
  if (xs instanceof Array) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for lists");
    }
    return xs[k];
  }
  if (xs instanceof Map) {
    if (xs.has(k)) {
      return xs.get(k);
    }
    return null;
  }

  throw new Error("Does not support `get` on this type");
};

let cloneMap = (
  xs: Map<CrDataValue, CrDataValue>
): Map<CrDataValue, CrDataValue> => {
  var result: Map<CrDataValue, CrDataValue> = new Map();
  xs.forEach((v, i) => {
    result.set(i, v);
  });
  return result;
};

export let assoc = (xs: CrDataValue, k: CrDataValue, v: CrDataValue) => {
  if (xs instanceof Array) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for lists");
    }
    var ys: CrDataValue[] = cloneArray(xs);
    ys[k] = v;
    return ys;
  }
  if (xs instanceof Map) {
    var result = cloneMap(xs);
    result.set(k, v);
    return result;
  }

  throw new Error("Does not support `get` on this type");
};

export let dissoc = (xs: CrDataValue, k: CrDataValue) => {
  if (xs instanceof Array) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for lists");
    }
    var ys: CrDataValue[] = cloneArray(xs);
    ys.splice(k, 1);
    return ys;
  }
  if (xs instanceof Map) {
    var result = cloneMap(xs);
    result.delete(k);
    return result;
  }

  throw new Error("Does not support `get` on this type");
};

export let reset_BANG_ = (a: CrDataAtom, v: CrDataValue): null => {
  if (!(a instanceof CrDataAtom)) {
    throw new Error("Expected atom for reset!");
  }
  a.value = v;
  for (let k in a.listeners) {
    let f = a.listeners.get(k);
    f(v);
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

export let range = (n: number, m: number, m2: number): number[] => {
  var result: number[] = [];
  if (m2 != null) {
    // TODO
  }
  if (m != null) {
    var idx = n;
    while (idx < m) {
      result.push(idx);
      idx = idx + 1;
    }
  } else {
    var idx = 0;
    while (idx < n) {
      result.push(idx);
      idx = idx + 1;
    }
  }
  return result;
};

export let empty_QUES_ = (xs: CrDataValue): boolean => {
  if (xs instanceof Array) {
    return xs.length == 0;
  }
  if (xs instanceof Map) {
    return xs.size === 0;
  }
  if (xs instanceof Set) {
    return xs.size === 0;
  }
  if (xs == null) {
    return true;
  }

  // TODO set not handled
  throw new Error("Does not support empty? on this type");
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
    return result;
  };
};

export let first = (xs: CrDataValue): CrDataValue => {
  if (xs == null) {
    return null;
  }
  if (xs instanceof Array) {
    return xs[0];
  }
  if (typeof xs === "string") {
    return xs[0];
  }
  if (xs instanceof Set) {
    if (xs.size === 0) {
      return null;
    }
    let it = xs.values();
    return it.next().value;
  }
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
  if (xs instanceof Array) {
    if (xs.length === 0) {
      return null;
    }
    return xs.slice(1);
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

let cloneArray = (xs: CrDataValue[]): CrDataValue[] => {
  let ys: CrDataValue[] = new Array(xs.length);
  for (let idx in xs) {
    ys[idx] = xs[idx];
  }
  return ys;
};

export let prepend = (xs: CrDataValue[], v: CrDataValue): CrDataValue[] => {
  if (!(xs instanceof Array)) {
    throw new Error("Expected array");
  }
  let ys = cloneArray(xs);
  ys.unshift(v);
  return ys;
};

export let append = (xs: CrDataValue[], v: CrDataValue): CrDataValue[] => {
  if (!(xs instanceof Array)) {
    throw new Error("Expected array");
  }
  let ys = cloneArray(xs);
  ys.push(v);
  return ys;
};

export let last = (xs: CrDataValue): CrDataValue => {
  if (xs instanceof Array) {
    return xs[xs.length - 1];
  }
  if (typeof xs === "string") {
    return xs[xs.length - 1];
  }
  throw new Error("Data not ready for last");
};

export let butlast = (xs: CrDataValue): CrDataValue => {
  if (xs instanceof Array) {
    if (xs.length === 0) {
      return null;
    }
    return xs.slice(0, xs.length - 1);
  }
  if (typeof xs === "string") {
    return xs.substr(0, xs.length - 1);
  }
  throw new Error("Data not ready for butlast");
};

export let initCrTernary = (x: string): CrDataValue => {
  console.warn("Ternary for js not implemented yet!");
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

export let slice = (
  xs: CrDataValue[],
  from: number,
  to: number
): CrDataValue => {
  return xs.slice(from, to);
};

export let _AND_concat = (
  xs: CrDataValue[],
  ys: CrDataValue[]
): CrDataValue[] => {
  return xs.concat(ys);
};

export let reverse = (xs: CrDataValue[]): CrDataValue[] => {
  if (xs == null) {
    return null;
  }
  var result = new Array(xs.length);
  for (let idx = 0; idx < xs.length; idx++) {
    result[xs.length - idx - 1] = xs[idx];
  }
  return result;
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

export let _AND_merge = (
  a: Map<CrDataValue, CrDataValue>,
  b: Map<CrDataValue, CrDataValue>
): Map<CrDataValue, CrDataValue> => {
  var result = cloneMap(a);
  b.forEach((v, k) => {
    result.set(k, v);
  });
  return result;
};

export let _AND_merge_DASH_non_DASH_nil = (
  a: Map<CrDataValue, CrDataValue>,
  b: Map<CrDataValue, CrDataValue>
): Map<CrDataValue, CrDataValue> => {
  var result = cloneMap(a);
  b.forEach((v, k) => {
    if (v != null) {
      result.set(k, v);
    }
  });
  return result;
};

export let to_DASH_pairs = (
  xs: Map<CrDataValue, CrDataValue>
): Set<[CrDataValue, CrDataValue]> => {
  var result: Set<[CrDataValue, CrDataValue]> = new Set();
  xs.forEach((v, k) => {
    result.add([k, v]);
  });
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
  let result: Set<CrDataValue> = new Set();
  xs.forEach((x) => {
    result.add(x);
  });
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

export let to_DASH_js_DASH_data = (x: CrDataValue): any => {
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
    return x.content;
  }
  if (Array.isArray(x)) {
    var result: any[] = [];
    for (let idx in x) {
      result.push(to_DASH_js_DASH_data(x[idx]));
    }
    return result;
  }
  if (x instanceof Map) {
    let result: any = {};
    x.forEach((v, k) => {
      var key = to_DASH_js_DASH_data(k);
      if (typeof key === "string") {
        // ok
      } else if (key instanceof CrDataKeyword) {
        key = key.content;
      } else if (typeof key === "number") {
        // ok
      } else {
        throw new Error("Does not support key");
      }
      result[key] = to_DASH_js_DASH_data(v);
    });
    return result;
  }
  if (x instanceof Set) {
    let result = new Set();
    x.forEach((v) => {
      result.add(to_DASH_js_DASH_data(v));
    });
    return result;
  }
  throw new Error("Unknown data to js");
};

export let to_DASH_calcit_DASH_data = (x: any) => {
  if (typeof x === "number") {
    return x;
  }
  if (typeof x === "string") {
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
    return result;
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
    return result;
  }

  throw new Error("Unexpected data for converting");
};

export let parse_DASH_json = (x: string): CrDataValue => {
  return to_DASH_calcit_DASH_data(JSON.parse(x));
};

export let stringify_DASH_json = (x: CrDataValue): string => {
  return JSON.stringify(to_DASH_js_DASH_data(x));
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
  if ((globalThis as any)["process"] != null) {
    // only available for Node.js
    return (globalThis as any)["process"].env[name];
  }
  return null;
};

// TODO not handled correct in generated js
export let reduce = foldl;
export let conj = append;
