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
  listeners: Map<CrDataValue, CrDataFn>;
  constructor(x: CrDataValue) {
    this.value = x;
    this.listeners = new Map();
  }
}

type CrDataFn = (...xs: CrDataValue[]) => CrDataValue;

type CrDataValue =
  | string
  | number
  | boolean
  | Map<CrDataValue, CrDataValue>
  | Array<CrDataValue>
  // TODO set
  | CrDataKeyword
  | CrDataAtom
  | CrDataFn
  | CrDataRecur // should not be exposed to function
  | null;

var keywordRegistery = new Map();

export let initCrKeyword = (content: string) => {
  if (keywordRegistery.has(content)) {
    return keywordRegistery.get(content);
  } else {
    let v = new CrDataKeyword(content);
    keywordRegistery.set(content, v);
    return v;
  }
};

var atomsRegistry = new Map();

let kwd = initCrKeyword;

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
  if (typeof x === "function") {
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
  let v = new CrDataAtom(x);
  atomsRegistry.set(path, v);
  return v;
};

export let deref = (x: CrDataAtom): CrDataValue => {
  return x.value;
};

export let foldl = (
  f: CrDataFn,
  acc: CrDataValue,
  xs: CrDataValue[]
): CrDataValue => {
  if (f == null) {
    debugger;
    throw new Error("Expected function for folding");
  }
  var result = acc;
  for (let idx in xs) {
    let item = xs[idx];
    result = f(result, item);
  }
  return result;
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

export let contains_QUES_ = (xs: CrDataValue, x: CrDataValue) => {
  if (xs instanceof Array) {
    for (let idx in xs) {
      let v = xs[idx];
      if (!_AND__EQ_(v, x)) {
        return false;
      }
    }
    return false;
  }
  if (xs instanceof Map) {
    return xs.has(x);
  }

  // TODO set not handled
  throw new Error("Does not support contains? on this type");
};

export let get = (xs: CrDataValue, x: CrDataValue) => {
  if (xs instanceof Array) {
    for (let idx in xs) {
      return xs[idx];
    }
    return false;
  }
  if (xs instanceof Map) {
    if (xs.has(x)) {
      return null;
    }
    return xs.get(x);
  }

  throw new Error("Does not support `get` on this type");
};

export let assoc = (xs: CrDataValue, k: CrDataValue, v: CrDataValue) => {
  if (xs instanceof Array) {
    if (typeof k !== "number") {
      throw new Error("Expected number index for lists");
    }
    var ys: CrDataValue[] = new Array(xs.length);
    for (let idx in xs) {
      ys[idx] = xs[idx];
    }
    ys[k] = v;
    return ys;
  }
  if (xs instanceof Map) {
    return xs.set(k, v);
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

// TODO, variadic args
export let range = (n: number): number[] => {
  var result: number[] = [];
  var idx = 0;
  while (idx < n) {
    result.push(idx);
    idx = idx + 1;
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
  if (xs == null) {
    return true;
  }

  // TODO set not handled
  throw new Error("Does not support empty? on this type");
};

// recur has to be handled, so need to wrap functions
export let callFunction = (
  f: CrDataFn,
  ...args: CrDataValue[]
): CrDataValue => {
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
    return xs.slice(1);
  }
  if (typeof xs === "string") {
    return xs.substr(1);
  }
  throw new Error("Expects something sequential");
};

export let recur = (...xs: CrDataValue[]): CrDataRecur => {
  return new CrDataRecur(xs);
};

export let _AND_get_DASH_calcit_DASH_backend = () => {
  return kwd("js");
};

// TODO not handled correct in generated js
export let reduce = foldl;
