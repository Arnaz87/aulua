
// TODO: Use 64 bit floats, when available in cobre

import cobre.any { type any; }

import cobre.system {
  void println (string);
  void error (string);
}

import cobre.string {
  string itos (int);
  
  int length (string) as strlen;
  int codeof (char);
  char, int charat(string, int);
}

import cobre.any (int) {
  any `new` (int) as anyInt;
  int get (any) as getInt;
  bool test (any) as testInt;
}

import cobre.any (string) {
  any `new` (string) as anyStr;
  string get (any) as getStr;
  bool test (any) as testStr;
}

import cobre.any (bool) {
  any `new` (bool) as anyBool;
  bool get (any) as getBool;
  bool test (any) as testBool;
}

import cobre.any (Table) {
  any `new` (Table) as anyTable;
  Table get (any) as getTable;
  bool test (any) as testTable;
}

import cobre.any (Function) {
  any `new` (Function) as anyFn;
  Function get (any) as getFn;
  bool test (any) as testFn;
}

import cobre.array (any) {
  type `` as AnyArr {
    any get (int);
    void push (any);
    int len ();
  }
  AnyArr empty () as emptyAnyArr;
}

import cobre.function (Stack as in0, Stack as out0) {
  type `` as Function {
    Stack apply (Stack);
  }
  module `new` as newfn;
  module closure;
}

export Function;
export closure;

struct unit_t {bool dummy;}
type nil_t (unit_t);

import cobre.any (nil_t) {
  any `new` (nil_t) as anyNil;
  nil_t get (any) as getNil;
  bool test (any) as testNil;
}

struct Stack {
  int pos;
  AnyArr arr;

  any next (Stack this) {
    if (this.more()) {
      any a = this.arr[this.pos];
      this.pos = this.pos + 1;
      return a;
    } else return nil();
  }

  void push (Stack this, any a) {
    this.arr.push(a);
  }

  bool more (Stack this) {
    return this.pos < this.arr.len();
  }

  void append (Stack this, Stack that) {
    int i = that.pos;
    while (i < that.arr.len()) {
      this.push(that.arr[i]);
      i = i+1;
    }
  }

  any get (Stack this, int i) {
    int j = i + this.pos;
    if (j <= this.arr.len())
      return this.arr[j];
    else return nil();
  }
}

Stack newStack () {
  return new Stack(0, emptyAnyArr());
}

int atoi (string str) {
  int value = 0;
  int pos = 0;
  while (pos < strlen(str)) {
    char ch;
    ch, pos = charat(str, pos);
    int code = codeof(ch);
    value = (value*10) + (code-48);
  }
  return value;
}

bool isDigit (int code) {
  if (code >= 48) { // 0
    if (code <= 57) { // 9
      return true; // true
    }
  }
  return 0<0; // false
}

bool isSpace (int code) {
  if (code == 9)  { return true; } // \t
  if (code == 10) { return true; } // \n
  if (code == 32) { return true; } // ' '
  return 0<0; // false
}

int, bool parseNum (string str) {
  // TODO:
  // Actually parse numbers like lua does. Whitespace is allowed before and
  // after the number, and it can be in any format lua accepts (integer,
  // decimal, scientific notation, hexadecimal and hexadecimal scientific)
  int value = 0;
  int pos = 0;
  int state = 0;
  while (pos < strlen(str)) {
    char ch;
    ch, pos = charat(str, pos);
    int code = codeof(ch);
    value = (value*10) + (code-48);
  }
  return value, true;
}

int, bool getNum (any a) {
  if (testInt(a)) {
    return getInt(a), true;
  } else if (testStr(a)) {
    string str = getStr(a);
    int value; bool b;
    value, b = parseNum(str);
    return value, b;
  }
  return 0, false;
}

int, int, bool getNums (any a, any b) {
  int ia, ib; bool t;
  ia, t = getNum(a);
  if (t) {
    ib, t = getNum(b);
    if (t) {
      return ia, ib, true;
    }
  }
  return 0, 0, false;
}

int, int, bool getInts (any a, any b) {
  if (testInt(a)) if (testInt(b)) {
    return getInt(a), getInt(b), 1>0;
  }
  return 0, 0, false;
}

any add (any a, any b) {
  bool it; int ia, ib;
  ia, ib, it = getInts(a, b);
  if (it) return anyInt(ia + ib);
  ia, ib, it = getNums(a, b);
  if (it) return anyInt(ia + ib);
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

any sub (any a, any b) {
  bool it; int ia, ib;
  ia, ib, it = getInts(a, b);
  if (it) return anyInt(ia - ib);
  ia, ib, it = getNums(a, b);
  if (it) return anyInt(ia - ib);
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

any mul (any a, any b) {
  bool it; int ia, ib;
  ia, ib, it = getInts(a, b);
  if (it) return anyInt(ia * ib);
  ia, ib, it = getNums(a, b);
  if (it) return anyInt(ia * ib);
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

any div (any a, any b) {
  bool it; int ia, ib;
  ia, ib, it = getInts(a, b);
  if (it) return anyInt(ia / ib);
  ia, ib, it = getNums(a, b);
  if (it) return anyInt(ia / ib);
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

any concat (any a, any b) {
  return anyStr(tostr(a) + tostr(b));
}

// TODO: Real nil, not just 0
any nil () { return anyNil(new unit_t(true) as nil_t); }
any `true` () { return anyBool(true); }
any `false` () { return anyBool(false); }

export anyStr as string;
export anyInt as int;
export anyFn as function;

string typestr (any a) {
  if (testTable(a)) return "table";
  else if (testStr(a)) return "string";
  else if (testInt(a)) return "number";
  else if (testNil(a)) return "nil";
  else if (testBool(a)) return "bool";
  else if (testFn(a)) return "function";
  else return "unknown";
}

string tostr (any a) {
  if (testStr(a)) return getStr(a);
  else if (testInt(a)) return itos(getInt(a));
  else if (testBool(a)) {
    if (getBool(a))
      return "true";
    else
      return "false";
  } else return typestr(a);
}

bool tobool (any a) {
  if (testBool(a)) return getBool(a);
  else if (testNil(a)) return false;
  else return true;
}

bool equals (any a, any b) {
  if (testInt(a) && testInt(b)) return getInt(a) == getInt(b);
  if (testStr(a) && testStr(b)) return getStr(a) == getStr(b);
  if (testBool(a) && testBool(b)) {
    bool _a = getBool(a), _b = getBool(b);
    return (_a && _b) || (!_a && !_b);
  }
  if (testNil(a) && testNil(b)) return true;
  /*if (testTable(a) && testTable(b)) {
    Table ta = getTable(a);
    Table tb = getTable(b);
  }*/
  return false;
}

bool _lt (any a, any b) {
  if (testInt(a) && testInt(b)) return getInt(a) < getInt(b);
  error("Lua: attempt to compare " + typestr(a) + " with " + typestr(b));
}

bool _le (any a, any b) {
  if (testInt(a) && testInt(b)) return getInt(a) <= getInt(b);
  error("Lua: attempt to compare " + typestr(a) + " with " + typestr(b));
}

any eq (any a, any b) { return anyBool(equals(a, b)); }
any ne (any a, any b) { return anyBool(!equals(a, b)); }
any lt (any a, any b) { return anyBool(_lt(a, b)); }
any le (any a, any b) { return anyBool(_le(a, b)); }
any gt (any a, any b) { return anyBool(!_le(a, b)); }
any ge (any a, any b) { return anyBool(!_lt(a, b)); }

any not (any a) { return anyBool(!tobool(a)); }
any neg (any a) {
  int n; bool t;
  n, t = getNum(a);
  if (t) { return anyInt(0-n); }
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

Stack call (any _f, Stack args) {
  if (testFn(_f)) {
    Function f = getFn(_f);
    Stack r = f.apply(args);
    return r;
  } else {
    error("Lua: attempt to call a non-function value");
  }
}


//======= Objects =======//

void checkKey (any a) {
  if (testStr(a)) return;
  if (testInt(a)) return;
  error("Lua: " + tostr(a) + " is not a valid key");
}

struct Pair { any key; any val; }

import cobre.array (Pair) {
  type `` as PairArr {
    Pair get (int);
    void set (int, Pair);
    int len ();
    void push (Pair);
  }
  PairArr empty () as emptyPairArr;
}

struct Table {
  PairArr arr;
  MetaTable? meta;

  any get (Table this, any key) {
    checkKey(key);
    int i = this.arr.len();
    // Look from the last inserted pair to the first
    while (i > 0) {
      i = i-1;
      Pair pair = this.arr[i];
      if (equals(key, pair.key)) return pair.val;
    }
    return nil();
  }

  void set (Table this, any key, any value) {
    checkKey(key);
    Pair pair = new Pair(key, value);
    this.arr.push(pair);
  }
}

type MetaTable (Table);

any newTable () { return anyTable(new Table(emptyPairArr(), new MetaTable?())); }

any get (any t, any k) {
  if (testTable(t)) return getTable(t).get(k);
  else error("Lua: tried to index a non-table value (" + tostr(t) + ")");
}

void set (any t, any k, any v) {
  if (testTable(t)) getTable(t).set(k, v);
  else error("Lua: tried to index a non-table value (" + tostr(t) + ")");
}

any length (any a) {
  if (testStr(a)) return anyInt(strlen(getStr(a)));
  error("Lua: attempt to get length of a " + typestr(a) + " value");
}

//======= Builtins =======//

Stack stackof (any a) {
  Stack stack = newStack();
  stack.push(a);
  return stack;
}

Stack _print (Stack args) {
  bool first = true;
  string str = "";
  while (args.more()) {
    any a = args.next();
    if (first) first = false;
    else str = str + "\t";
    str = str + tostr(a);
  }
  println(str);
  return newStack();
} import module newfn (_print) { Function `` () as __print; }

Stack _assert (Stack args) {
  any val = args.next();
  if (tobool(val)) {
    Stack ret = newStack();
    ret.push(val);
    return ret;
  } else {
    any amsg = args.next();
    string msg = tostr(amsg);
    if (testNil(amsg)) msg = "assertion failed!";
    error(msg);
  }
} import module newfn (_assert) { Function `` () as __assert; }

Stack _error (Stack args) { error(tostr(args.next())); }
import module newfn (_error) { Function `` () as __error; }

Stack _tostring (Stack args) { return stackof(anyStr(tostr(args.next()))); }
import module newfn (_tostring) { Function `` () as __tostring; }

Stack _tonumber (Stack args) {
  int n; bool b;
  n, b = getNum(args.next());
  if (b) return stackof(anyInt(n));
  else return stackof(nil());
}
import module newfn (_tonumber) { Function `` () as __tonumber; }

Stack _type (Stack args) { return stackof(anyStr(typestr(args.next()))); }
import module newfn (_type) { Function `` () as __type; }

Stack _getmeta (Stack args) {
  int v = args.next();
  if (testNil(v)) error("Lua: bad argument #1 to 'getmetatable' (value expected)");
  if (testTable(v)) {
    Table t = getTable(v);
    if (!t.meta.isnull())
      return stackof(anyTable(t.meta.get() as Table));
  }
  return stackof(nil());
}
import module newfn (_getmeta) { Function `` () as __getmeta; }

Stack _setmeta (Stack args) {
  any a = args.next(), b = args.next();
  if (!testTable(a)) error("Lua: bad argument #1 to 'getmetatable' (table expected, got "+typestr(a)+")");
  if (!testTable(b)) error("Lua: bad argument #2 to 'getmetatable' (table expected, got "+typestr(b)+")");

  Table t = getTable(a);
  Table meta = getTable(b);
  t.meta = (meta as MetaTable) as MetaTable?;

  return stackof(a);
}
import module newfn (_setmeta) { Function `` () as __setmeta; }

any create_global () {
  Table tbl = new Table(emptyPairArr(), new MetaTable?());

  tbl.set(anyStr("_G"), anyTable(tbl));
  tbl.set(anyStr("_VERSION"), anyStr("Lua 5.3"));
  tbl.set(anyStr("assert"), anyFn(__assert()));
  tbl.set(anyStr("error"), anyFn(__error()));
  tbl.set(anyStr("getmetatable"), anyFn(__getmeta()));
  tbl.set(anyStr("print"), anyFn(__print()));
  // rawequal, rawget, rawlen, rawset
  tbl.set(anyStr("setmetatable"), anyFn(__setmeta()));
  tbl.set(anyStr("tostring"), anyFn(__tostring()));
  tbl.set(anyStr("tonumber"), anyFn(__tonumber()));
  tbl.set(anyStr("type"), anyFn(__type()));

  //Table table_tbl = new Table(emptyPairArr(), new MetaTable?());

  return anyTable(tbl);
}
