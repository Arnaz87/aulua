
// TODO: Use 64 bit floats, when available in cobre

import cobre.core { type any; }

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

int, bool getNum (any a) {
  if (testInt(a)) {
    return getInt(a), 0<1;
  } else if (testStr(a)) {
    // TODO:
    // Actually parse numbers like lua does. Only whitespace is allowed before
    // or after the number, and it can be in any format lua accepts (integer,
    // decimal, scientific notation, hexadecimal and hexadecimal scientific)
    string str = getStr(a);
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
any nil () { return anyInt(0); }

any _int (int n) { return anyInt(n); }
any _true () { return anyBool(0<1); }
any _false () { return anyBool(1<0); }
any _string (string s) { return anyStr(s); }

string tostr (any a) {
  if (testStr(a)) return getStr(a);
  else if (testInt(a)) return itos(getInt(a));
  else if (testBool(a)) {
    if (getBool(a))
      return "true";
    else
      return "false";
  }
  else return "unknown";
}

void _print (any a) {
  print(tostr(a));
}
