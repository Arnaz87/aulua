
// TODO: Use 64 bit floats, when available in cobre

import cobre.core { type any; }

import cobre.system {
  void print (string);
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
      return 0<1; // true
    }
  }
  return 0<0; // false
}

bool isSpace (int code) {
  if (code == 9)  { return 0<1; } // \t
  if (code == 10) { return 0<1; } // \n
  if (code == 32) { return 0<1; } // ' '
  return 0<0; // false
}

int, bool parseNum (string str) {
  // TODO:
  // Actually parse numbers like lua does. Only whitespace is allowed before
  // or after the number, and it can be in any format lua accepts (integer,
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
  return value, 0<1;
}

int, bool getNum (any a) {
  if (testInt(a)) {
    return getInt(a), 0<1;
  } else if (testStr(a)) {
    string str = getStr(a);
    int value; bool b;
    value, b = parseNum(str);
    return value, b;
  }
  return 0, 1<0;
}

int, int, bool getNums (any a, any b) {
  int ia, ib; bool t;
  ia, t = getNum(a);
  if (t) {
    ib, t = getNum(b);
    if (t) {
      return ia, ib, 0<1;
    }
  }
  return 0, 0, 1<0;
}

int, int, bool getInts (any a, any b) {
  if (testInt(a)) if (testInt(b)) {
    return getInt(a), getInt(b), 1>0;
  }
  return 0, 0, 1<0;
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
any nil () { return anyNil(new unit_t(0<1) as nil_t); }

any _int (int n) { return anyInt(n); }
any _true () { return anyBool(0<1); }
any _false () { return anyBool(1<0); }
any _string (string s) { return anyStr(s); }
any _function (Function s) { return anyFn(s); }

string tostr (any a) {
  if (testStr(a)) return getStr(a);
  else if (testInt(a)) return itos(getInt(a));
  else if (testNil(a)) return "nil";
  else if (testBool(a)) {
    if (getBool(a))
      return "true";
    else
      return "false";
  }
  else if (testTable(a)) return "table";
  else if (testFn(a)) return "function";
  else return "unknown";
}

bool tobool (any a) {
  if (testBool(a)) return getBool(a);
  else if (testNil(a)) return 1<0;
  else return 0<1;
}

Stack _print (Stack args) {
  bool first = 0<1;
  string str = "";
  while (args.more()) {
    any a = args.next();
    if (first) first = 1<0;
    else str = str + " ";
    str = str + tostr(a);
  }
  print(str);
  return newStack();
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

bool equals (any a, any b) {
  if (testInt(a)) if (testInt(b)) return getInt(a) == getInt(b);
  if (testStr(a)) if (testStr(b)) return getStr(a) == getStr(b);
  return 1 < 0;
}

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

any newTable () { return anyTable(new Table(emptyPairArr())); }

any get (any t, any k) {
  if (testTable(t)) return getTable(t).get(k);
  else error("Lua: tried to index a non-table value (" + tostr(t) + ")");
}

void set (any t, any k, any v) {
  if (testTable(t)) getTable(t).set(k, v);
  else error("Lua: tried to index a non-table value (" + tostr(t) + ")");
}
