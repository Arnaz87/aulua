
// TODO: Use 64 bit floats, when available in cobre

import cobre.system {
  void println (string);
  void error (string);
  void exit (int);
  int argc ();
  string argv (int);
}

import cobre.buffer { type buffer; }

import cobre.string {
  string itos (int);
  
  int length (string) as strlen;
  int codeof (char);
  char, int charat(string, int);
  string add (string, char) as addch;
  char newchar (int);
  string slice (string, int, int);

  string `new` (buffer) as newstr;
  buffer tobuffer (string);
}

any anyInt (int x) { return x as any; }
any anyStr (string x) { return x as any; }
any anyTable (Table x) { return x as any; }
any anyFn (Function x) { return x as any; }
any anyBool (bool x) { return x as any; }

bool testInt (any a) { return a is int; }
bool testStr (any a) { return a is string; }
bool testBool (any a) { return a is bool; }
bool testTable (any a) { return a is Table; }
bool testFn (any a) { return a is Function; }
bool testNil (any a) { return a is nil_t; }

int getInt (any a) { return a as int; }
string getStr (any a) { return a as string; }
bool getBool (any a) { return a as bool; }
Table getTable (any a) { return a as Table; }
Function getFn (any a) { return a as Function; }

import cobre.utils.arraylist (any) {
  type `` as Array {
    any get (int);
    void push (any);
    void set (int, any);
    int len ();
  }
  Array `new` () as newArray;
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

struct Stack {
  int pos;
  Array arr;

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

  int length (Stack this) {
    int l = this.arr.len() - this.pos;
    if (l < 0) return 0;
    return l;
  }

  Stack copy (Stack this) { return new Stack(this.pos, this.arr); }
}

Stack newStack () {
  return new Stack(0, newArray());
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

int, bool parseInt (string str) {
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
    value, b = parseInt(str);
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
  if (a is int) {
    if (b is int)
      return a as int, b as int, true;
    if (b is string) {

    }
  }
  return 0, 0, false;
}

any parseNum (string s) {
  int len = strlen(s);
  int i = 0;
  char ch;

  while (i < len) {
    ch, i = charat(s, i);
    if (!(codeof(ch) == 32)) // space
      goto digit;
  }

  int value = 0;

  while (i < len) {
    ch, i = charat(s, i);
    digit:
    if (codeof(ch) == 46) goto point;
    if ((codeof(ch) > 57) || (codeof(ch) < 48))
      goto endint;
    value = (value*10) + (codeof(ch)-48);
  }

  endint:
  while (i < len) {
    ch, i = charat(s, i);
    if (!(codeof(ch) == 32))
      return nil();
  }

  return value as any;

  point:

  int digits = 0;

  while (i < len) {
    ch, i = charat(s, i);
    if ((codeof(ch) > 57) || (codeof(ch) < 48))
      goto endflt;
    value = (value*10) + (codeof(ch)-48);
    digits = digits + 1;
  }
  
  endflt:
  while (i < len) {
    ch, i = charat(s, i);
    if (!(codeof(ch) == 32))
      return nil();
  }

  float fval = itof(value);
  while (digits > 0) {
    fval = fval / itof(10);
    digits = digits - 1;
  }

  return fval as any;
}

float, bool getFloat (any a) {
  if (a is float) return a as float, true;
  if (a is int) return itof(a as int), true;
  if (a is string) {
    any an = parseNum(a as string);
    if (an is float) return an as float, true;
    if (an is int) return itof(an as int), true;
  }
  return itof(0), false;
}

float, float, bool getFloats (any a, any b) {
  float af, bf; bool t;
  af, t = getFloat(a);
  if (!t) return af, af, false;
  bf, t = getFloat(b);
  return af, bf, t;
}

any add (any a, any b) {
  if ((a is int) && (b is int))
    return ((a as int) + (b as int)) as any;
  float fa, fb; bool t;
  fa, fb, t = getFloats(a, b);
  if (t) return (fa + fb) as any;
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

any sub (any a, any b) {
  if ((a is int) && (b is int))
    return ((a as int) - (b as int)) as any;
  float fa, fb; bool t;
  fa, fb, t = getFloats(a, b);
  if (t) return (fa - fb) as any;
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

any mul (any a, any b) {
  if ((a is int) && (b is int))
    return ((a as int) * (b as int)) as any;
  float fa, fb; bool t;
  fa, fb, t = getFloats(a, b);
  if (t) return (fa * fb) as any;
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

any div (any a, any b) {
  float fa, fb; bool t;
  fa, fb, t = getFloats(a, b);
  if (t) return (fa / fb) as any;
  error("Lua: attempt to perform arithmetic on a non-numeric value");
}

any concat (any a, any b) {
  return anyStr(tostr(a) + tostr(b));
}

// TODO: Real nil, not just 0
any nil () { return (new unit_t(true) as nil_t) as any; }
any `true` () { return true as any; }
any `false` () { return false as any; }

export anyStr as string;
export anyInt as int;
export anyFn as function;

string typestr (any a) {
  if (testTable(a)) return "table";
  else if (testStr(a)) return "string";
  else if ((a is float) || testInt(a)) return "number";
  else if (testNil(a)) return "nil";
  else if (testBool(a)) return "bool";
  else if (testFn(a)) return "function";
  else return "userdata";
}

string tostr (any a) {
  if (testStr(a)) return getStr(a);
  else if (a is float) return ftos(a as float);
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

  // TODO: iplmement equality for tables and userdata (using explicit ids)
  return false;
}

int cmp (any _a, any _b) {
  if (testInt(_a) && testInt(_b)) {
    int a = getInt(_a), b = getInt(_b);
    if (a < b) return 0-1;
    if (a == b) return 0;
    return 1;
  }
  if (testStr(_a) && testStr(_b)) {
    string a = getStr(_a), b = getStr(_b);
    int al = strlen(a), bl = strlen(b);
    int len = al; if (bl < al) len = bl;
    int i = 0;
    while (i < len) {
      int ca = codeof(charat(a, i));
      int cb = codeof(charat(b, i));
      if (ca < cb) return 0-1;
      if (ca > cb) return 1;
      i = i+1;
    }
    if (al < bl) return 0-1;
    if (al > bl) return 1;
    return 0;
  }
  error("Lua: attempt to compare " + typestr(_a) + " with " + typestr(_b));
}

any eq (any a, any b) { return equals(a, b) as any; }
any ne (any a, any b) { return anyBool(!equals(a, b)); }
any lt (any a, any b) { return anyBool(cmp(a, b) < 0); }
any le (any a, any b) { return anyBool(cmp(a, b) <= 0); }
any gt (any a, any b) { return anyBool(cmp(a, b) > 0); }
any ge (any a, any b) { return anyBool(cmp(a, b) >= 0); }

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

struct UserDataInner {
  any data;
  Table? meta;
}

type UserData (UserDataInner);


//======= Objects =======//

bool checkKey (any a) { return testStr(a) || testInt(a); }

struct Pair { any key; any val; }

import cobre.utils.arraylist (Pair) {
  type `` as PairArr {
    Pair get (int);
    void set (int, Pair);
    int len ();
    void push (Pair);
  }
  PairArr `new` () as emptyPairArr;
}

struct MapPair { string k; any v; }

import cobre.utils.stringmap (any) {
  type `` as Map {
    any? get (string);
    void set (string, any);
    void delete (string);
  }
  Map `new` () as newMap;

  type iterator {
    MapPair? next ();
  }
  iterator `new\x1diterator` (Map) as newIter;
}

struct Table {
  Map map;
  Array arr;
  PairArr pairs;

  MetaTable? meta;

  iterator? iter;
  string? lastKey;

  // Notes: All keys are valid, only that raw userdata (any type not defined
  // in this module) have no equality, so they can be set but not retrieved.

  // Every key assigned is never removed, only it's value replaced with nil.

  // Int keys greater than the length + 1 are assigned as generic keys, so
  // when the array part catches up, that key will be stored twice.

  // One iterator is mantained, so that for-in loops can run in hopefully
  // constant time, but performance will degrade if next is used arbitrarily.

  // TODO: When cobre gets hashmaps, use a single hashmap for everything non-int

  any get (Table this, any key) {
    if (key is int) {
      int k = key as int;
      if ((k > 0) && (k <= this.arr.len()))
        return this.arr[k-1];
    } else if (key is string) {
      any? v = this.map[key as string];
      if (v.isnull()) return nil();
      else return v.get();
    }

    // Fallback
    int i = 0;
    while (i < this.pairs.len()) {
      Pair pair = this.pairs[i];
      if (equals(key, pair.key)) return pair.val;
      i = i+1;
    }
    return nil();
  }

  void set (Table this, any key, any value) {
    if (key is int) {
      int k = key as int;
      if (k == (this.arr.len() + 1)) {
        this.arr.push(value);
      } else  if ((k > 0) && (k <= this.arr.len())) {
        this.arr[k-1] = value;
      } else goto fallback;
    } else if (key is string) {
      this.map[key as string] = value;
    } else {
      fallback:

      int i = 0;
      while (i < this.pairs.len()) {
        Pair pair = this.pairs[i];
        if (equals(key, pair.key)) {
          pair.val = value;
          return;
        }
        i = i+1;
      }
      Pair pair = new Pair(key, value);
      this.pairs.push(pair);
    }

  }

  // This is a complicated function...
  any nextKey (Table this, any key) {

    // If key is nil, just start iterating all keys
    if (testNil(key)) {

      // First integer key
      if (this.arr.len() > 0) return 1 as any;

      first_string_key:
      iterator iter = newIter(this.map);
      MapPair? pair = iter.next();

      // at least one pair, otherwise fallback
      if (!pair.isnull()) {
        string k = pair.get().k;
        this.iter = iter as iterator?;
        this.lastKey = k as string?;
        return k as any;
      }

      first_other_key:
      if (this.pairs.len() > 0)
        return this.pairs[0].key;
      else return nil();
    }

    if (key is int) {
      int k = key as int;
      int len = this.arr.len();
      if ((k > 0) && (k < len)) {
        return (k+1) as any;
      } else if ((k == len) && (len > 0)) {
        // was last integer key
        goto first_string_key;
      } else {
        // outside of array, probably stored as other or not here
        // but definitely not as a string
        goto fallback;
      }
    }

    if (key is string) {
      string k = key as string;

      // Doesn't match current iterator. Find pair that matches
      if (this.lastKey.isnull() || !(this.lastKey.get() == k)) {
        iterator iter = newIter(this.map);
        MapPair? pair = iter.next();

        while (!pair.isnull()) {
          // Found. Save the iterator and proceed
          if (pair.get().k == k) {
            this.iter = iter as iterator?;
            this.lastKey = k as string?;
            goto do_string;
          }
        }

        // Not found, table doesn't have that key
        return nil();
      }

      do_string:
      MapPair? pair = this.iter.get().next();

      if (pair.isnull()) {
        // Was last key, return first callback key or finish
        goto first_other_key;
      } else {
        string k = pair.get().k;
        this.lastKey = k as string?;
        return k as any;
      }
    }

    fallback:
    if (testNil(key) && (this.pairs.len() > 0))
      return this.pairs[0].key;
    int i = 0;
    while (i < this.pairs.len()) {
      Pair pair = this.pairs[i];
      if (equals(key, pair.key)) {
        if ((i+1) < this.pairs.len())
          return this.pairs[i+1].key;
        return nil();
      }
      i = i+1;
    }
    return nil();
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

private Table emptyTable () { return new Table(
  newMap(), newArray(), emptyPairArr(), new MetaTable?(), new iterator?(), new string?()
); }
any newTable () { return emptyTable() as any; }

Table? get_metatable (any a) {
  if (testTable(a)) {
    MetaTable? meta = getTable(a).meta;
    if (meta.isnull()) return new Table?();
    return (meta.get() as Table) as Table?;
  }
  if (a is UserData) return ((a as UserData) as UserDataInner).meta;
  if (testStr(a)) return State.string_meta as Table?;
  return new Table?();
}

any get (any a, any k) {
  if (testTable(a)) {
    any val = getTable(a).get(k);
    if (!testNil(val)) return val;
  }
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
  if (testTable(a)) return nil();
  error("Lua: tried to index a non-table value (" + tostr(a) + ")");
}

void set (any t, any k, any v) {
  if (t is Table) (t as Table).set(k, v);
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

    // Tentative limit (remember the array is 0-index while lua is 1-index)
    int i = t.arr.len() - 1;

    // TODO: Still needs logarithmic time, using binary search

    if ((i >= 0) && (t.arr[i] is nil_t)) {
      // False limit, must be lower
      while (i >= 0) {
        if (testNil(t.arr[i])) i = i-1;
        else return (i+1) as any;
      }
    } else if (t.get((i+2) as any) is nil_t) {
      return (i+1) as any;
    } else {
      // False limit, must be higher
      i = i+3;
      while (true) {
        if (t.get(anyInt(i)) is nil_t)
          return anyInt(i-1);
        i = i+1;
      }
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
  Table file_meta;
  Table loaded;
}

StateT State = new StateT(false, emptyTable(), emptyTable(), emptyTable(), emptyTable(), emptyTable());


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
private int simple_number_or (any a, int d, string n, string fname) {
  if (testNil(a)) return d;
  return simple_number(a, n, fname);
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
  any a = args.next();
  if ((a is int) || (a is float)) return stackof(a);
  if (a is string) return stackof(parseNum(a as string));
  return newStack();
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

Stack _next (Stack args) {
  any a = args.next();
  if (!testTable(a)) error("Lua: bad argument #1 to 'next' (table expected, got "+typestr(a)+")");
  any key = args.next();
  Table t = getTable(a);
  return stackof(t.nextKey(key));
}
import module newfn (_next) { Function `` () as __next; }

Stack _pack (Stack args) {
  Table t = emptyTable();
  int n = 0;
  while (args.more()) {
    n = n+1;
    t.set(anyInt(n), args.next());
  }
  t.set(anyStr("n"), anyInt(n));
  return stackof(anyTable(t));
}
import module newfn (_pack) { Function `` () as __pack; }

Stack _unpack (Stack args) {
  any a = args.next();
  if (!testTable(a)) error("Lua: bad argument #1 to 'table.unpack' (table expected, got "+typestr(a)+")");
  Table t = getTable(a);

  int i = simple_number_or(args.next(), 1, "2", "table.unpack");
  int j = simple_number_or(args.next(), getInt(length(a)), "3", "table.unpack");

  Stack stack = newStack();
  while (i <= j) {
    stack.push(t.get(anyInt(i)));
    i = i+1;
  }
  return stack;
}
import module newfn (_unpack) { Function `` () as __unpack; }

Stack _select (Stack args) {
  any a = args.next();
  if (testStr(a) && (getStr(a) == "#")) return stackof(anyInt(args.length()));
  int index = simple_number(a, "1", "select");
  if (index < 1) error("bad argument #1 to 'select' (index out of range)");
  args.pos = index;
  return args;
}
import module newfn (_select) { Function `` () as __select; }


import lua_lib.table { Stack lua_main (any) as table_main; }


//======= IO and OS =======//

import cobre.io {
  type file as File;
  type mode as FileMode;
  FileMode r() as r_mode;
  FileMode w() as w_mode;
  FileMode a() as a_mode;
  File open (string, FileMode);
  buffer read (File, int);
  bool eof (File);
  void write (File, buffer);
  void close (File);
}

File get_file (any a) {
  if (a is UserData) {
    UserDataInner ud = (a as UserData) as UserDataInner;
    if (ud.data is File) {
      return ud.data as File;
    } else error("bad argument #1 to 'read' (file expected)");
  } else error("bad argument #1 to 'read' (file expected, got "+typestr(a)+")");
}

Stack _open (Stack args) {
  string filename = simple_string(args.next(), "1", "io.open");
  any _s = args.next();
  string s = "";

  if (testNil(_s)) s = "r";
  else if (_s is string) s = _s as string;

  FileMode m;
  if      ((s == "r") || (s == "rb")) m = r_mode();
  else if ((s == "w") || (s == "wb")) m = w_mode();
  else if ((s == "a") || (s == "ab")) m = a_mode();
  else error("bad argument #2 to 'io.open' (invalid mode)");

  File file = open(filename, m);
  UserDataInner ud = new UserDataInner(file as any, State.file_meta as Table?);
  return stackof((ud as UserData) as any);
}
import module newfn (_open) { Function `` () as __open; }

Stack _read (Stack args) {
  File file = get_file(args.next());
  any b = args.next();

  string str;

  if (b is nil_t) b = "l" as any;

  if (b is string) {
    string fmt = b as string;
    if (fmt == "a") {
      str = "";
      repeat:
      buffer buf = read(file, 128);
      str = str + newstr(buf);
      if (!eof(file)) goto repeat;
    } else if (fmt == "n") {
      error("format 'n' not yet supported");
    } else if (fmt == "l") {
      error("format 'l' not yet supported");
    } else if (fmt == "L") {
      error("format 'L' not yet supported");
    } else error("bad argument #2 to 'read' (invalid format)");
  } else if (b is int) {
    str = newstr(read(file, b as int));
  } else error("bad argument #2 to 'read' (invalid format)");

  return stackof(str as any);
}
import module newfn (_read) { Function `` () as __read; }

Stack _write (Stack args) {
  File file = get_file(args.next());

  int i = 1;

  string str = "";
  while (args.more()) {
    str = str + simple_string(args.next(), itos(i), "write");
    i = i+1;
  }

  write(file, tobuffer(str));

  return newStack();
}
import module newfn (_write) { Function `` () as __write; }

Stack _close (Stack args) {
  File file = get_file(args.next());
  close(file);
  return newStack();
}
import module newfn (_close) { Function `` () as __close; }

Stack _exit (Stack args) {
  any a = args.next();
  int code = 0;
  if (a is bool) {
    if (a as bool) code = 0; else code = 1;
  } else {
    code = simple_number_or(a, 0, "1", "os.exit");
  }
  exit(code);
  return newStack();
}
import module newfn (_exit) { Function `` () as __exit; }



//======= String functions =======//

import lua_lib.pattern { Stack lua_main (any) as pattern_main; }
import lua_lib.string { Stack lua_main (any) as string_main; }

int valid_start_index (int i, int len) {
  if (i < 0) i = len+i; else i = i-1;
  if (i < 0) return 0;
  return i;
}

int valid_end_index (int i, int len) {
  if (i < 0) i = len+i; else i = i-1;
  if (i >= len) return len-1;
  return i;
}

Stack _strsub (Stack args) {
  string s = simple_string(args.next(), "1", "string.sub");
  int len = strlen(s);

  int i = valid_start_index(simple_number(args.next(), "2", "string.sub"), len);

  int j = len; any _j = args.next();
  if (!testNil(_j)) j = valid_end_index(simple_number(_j, "3", "string.sub"), len);

  string s2 = slice(s, i, j+1);

  return stackof(anyStr(s2));
}
import module newfn (_strsub) { Function `` () as __strsub; }

Stack _strbyte (Stack args) {
  string s = simple_string(args.next(), "1", "string.byte");
  int len = strlen(s);

  int i = 0; any _i = args.next();
  if (!testNil(_i)) i = valid_start_index(simple_number(_i, "2", "string.byte"), len);
  
  int j = i; any _j = args.next();
  if (!testNil(_j)) j = valid_end_index(simple_number(_j, "2", "string.byte"), len);
  if (j >= len) j = len-1;

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
    tbl.set(anyStr("_CU_VERSION"), anyStr("0.6"));
    tbl.set(anyStr("assert"), anyFn(__assert()));
    tbl.set(anyStr("error"), anyFn(__error()));
    tbl.set(anyStr("getmetatable"), anyFn(__getmeta()));
    tbl.set(anyStr("next"), anyFn(__next()));
    tbl.set(anyStr("print"), anyFn(__print()));
    // rawequal, rawget, rawlen, rawset
    tbl.set(anyStr("select"), anyFn(__select()));
    tbl.set(anyStr("setmetatable"), anyFn(__setmeta()));
    tbl.set(anyStr("tostring"), anyFn(__tostring()));
    tbl.set(anyStr("tonumber"), anyFn(__tonumber()));
    tbl.set(anyStr("type"), anyFn(__type()));
    // Useless functions:
    // collectgarbage, dofile, load, loadfile

    Table table_tbl = emptyTable();
    tbl.set(anyStr("table"), anyTable(table_tbl));
    table_tbl.set(anyStr("pack"), anyFn(__pack()));
    table_tbl.set(anyStr("unpack"), anyFn(__unpack()));
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

    Table io_tbl = emptyTable();
    tbl.set("io" as any, io_tbl as any);
    io_tbl.set("open" as any, __open() as any);

    State.file_meta.set("__index" as any, State.file_meta as any);
    State.file_meta.set("read" as any, __read() as any);
    State.file_meta.set("write" as any, __write() as any);
    State.file_meta.set("close" as any, __close() as any);

    Table os_tbl = emptyTable();
    tbl.set("os" as any, os_tbl as any);
    os_tbl.set("exit" as any, __exit() as any);


    // Missing libraries
    // io and os libraries, math
    // the table library can be made in pure lua

    // package is mostly useless in Cobre
    // I'm not sure if i'll implement coroutine, 

    Table arg_tbl = emptyTable();
    int i = 0;
    while (i < argc()) {
      arg_tbl[i as any] = argv(i) as any;
      i = i+1;
    }

    tbl["arg" as any] = arg_tbl as any;
  }
  return anyTable(State._G);
}
