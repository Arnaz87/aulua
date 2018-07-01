
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
  string add (string, char) as addch;
  char newchar (int);
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

  any first (Stack this) {
    if (this.more())
      return this.arr[this.pos];
    else return nil();
  }

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

  Stack copy (Stack this) { return new Stack(this.pos, this.arr); }
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

void table_append (any _t, any _n, Stack stack) {
  Table t = getTable(_t);
  int n = getInt(_n);
  while (stack.more()) {
    t.set(anyInt(n), stack.next());
    n = n+1;
  }
}

type MetaTable (Table);

private Table emptyTable () { return new Table(emptyPairArr(), new MetaTable?()); }
any newTable () { return anyTable(emptyTable()); }

Table? get_metatable (any a) {
  if (testTable(a)) {
    MetaTable? meta = getTable(a).meta;
    if (meta.isnull()) return new Table?();
    return (meta.get() as Table) as Table?;
  }
  if (testStr(a)) return State.string_meta as Table?;
  return new Table?();
}

any get (any a, any k) {
  Table? meta = get_metatable(a);
  if (!meta.isnull()) {
    any index = meta.get().get(anyStr("__index"));
    if (testTable(index)) return get(index, k);
    if (testFn(index)) {
      Function f = getFn(index);
      Stack args = newStack();
      args.push(a);
      args.push(k);
      Stack result = f.apply(args);
      return result.first();
    }
  }
  if (testTable(a)) return getTable(a).get(k);
  else error("Lua: tried to index a non-table value (" + tostr(a) + ")");
}

void set (any t, any k, any v) {
  if (testTable(t)) getTable(t).set(k, v);
  else error("Lua: tried to index a non-table value (" + tostr(t) + ")");
}

any length (any a) {
  if (testStr(a)) return anyInt(strlen(getStr(a)));
  if (testTable(a)) {
    Table t = getTable(a);
    if (!t.meta.isnull()) {
      any len_fn = (t.meta.get() as Table).get(anyStr("__len"));
      if (!testNil(len_fn))
        return call(len_fn, stackof(a)).first();
    }

    int i = 1;
    while (true) {
      any val = t.get(anyInt(i));
      if (testNil(val)) return anyInt(i-1);
      i = i+1;
    }
  }
  error("Lua: attempt to get length of a " + typestr(a) + " value");
}

//======= State =======//

struct StateT {
  bool ready;
  Table _G;
  Table string;
  Table string_meta;
  Table loaded;
}

StateT State = new StateT(false, emptyTable(), emptyTable(), emptyTable(), emptyTable());


//======= Core Library =======//

// Helpers
private string simple_string (any a, string n, string fname) {
  if (testStr(a)) return getStr(a);
  if (testInt(a)) return itos(getInt(a));
  error("Lua: bad argument #" + n + " to '" + fname + "' (string expected, got " + typestr(a) + ")");
}
private int simple_number (any a, string n, string fname) {
  int x; bool t;
  x, t = getNum(a);
  if (t) return x;
  error("Lua: bad argument #" + n + " to '" + fname + "' (number expected, got " + typestr(a) + ")");
}

private Stack stackof (any a) {
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
  Table? meta = get_metatable(v);
  if (!meta.isnull()) {
    return stackof(anyTable(meta.get()));
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


import lua_lib.table { Stack lua_main (any) as table_main; }


//======= String functions =======//

import lua_lib.pattern { Stack lua_main (any) as pattern_main; }
import lua_lib.string { Stack lua_main (any) as string_main; }

int valid_str_index (int i, int len) {
  if (i < 0) i = len+i; else i = i-1;
  if (i < 0) return 0;
  if (i >= len) return len-1;
  return i;
}

Stack _strsub (Stack args) {
  string s = simple_string(args.next(), "1", "string.sub");
  int len = strlen(s);

  int i = valid_str_index(simple_number(args.next(), "2", "string.sub"), len);

  int j = len; any _j = args.next();
  if (!testNil(_j)) j = valid_str_index(simple_number(_j, "3", "string.sub"), len);

  string s2 = "";
  while (i <= j) {
    char ch;
    ch, i = charat(s,i);
    s2 = addch(s2, ch);
  }

  return stackof(anyStr(s2));
}
import module newfn (_strsub) { Function `` () as __strsub; }

Stack _strbyte (Stack args) {
  string s = simple_string(args.next(), "1", "string.byte");
  int len = strlen(s);

  int i = 0; any _i = args.next();
  if (!testNil(_i)) i = valid_str_index(simple_number(_i, "2", "string.byte"), len);
  
  int j = i; any _j = args.next();
  if (!testNil(_j)) j = valid_str_index(simple_number(_j, "2", "string.byte"), len);

  Stack stack = newStack();
  while (i <= j) {
    char ch;
    ch, i = charat(s,i);
    stack.push(anyInt(codeof(ch)));
  }
  return stack;
}
import module newfn (_strbyte) { Function `` () as __strbyte; }

Stack _strchar (Stack args) {
  string s = "";
  int i = 1;
  while (args.more()) {
    int code = simple_number(args.next(), itos(i), "string.char");
    s = addch(s, newchar(code));
    i = i+1;
  }
  return stackof(anyStr(s));
}
import module newfn (_strchar) { Function `` () as __strchar; }

any get_global () {
  if (!State.ready) {
    // Do not attempt to initialize the state again
    State.ready = true;

    Table tbl = State._G;

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
    // Useless functions:
    // collectgarbage, dofile, load, loadfile

    table_main(anyTable(State._G));

    State.string_meta.set(anyStr("__index"), anyTable(State.string));
    tbl.set(anyStr("string"), anyTable(State.string));
    State.string.set(anyStr("sub"), anyFn(__strsub()));
    State.string.set(anyStr("byte"), anyFn(__strbyte()));
    State.string.set(anyStr("char"), anyFn(__strchar()));
    // These functions can be done in pure lua
    // string.lua: format, len, lower, rep, reverse, upper
    // pattern.lua: find, gmatch, gsub, match
    // pack.lua: pack, packsize, unpack
    string_main(anyTable(State._G));
    pattern_main(anyTable(State._G));

    // Missing libraries
    // io and os libraries, math
    // the table library can be made in pure lua

    // package is mostly useless in Cobre
    // I'm not sure if i'll implement coroutine, 
  }
  return anyTable(State._G);
}
