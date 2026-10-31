# The text form

A module and its text are interchangeable. The text form is the printed form of a module, written for people and for tests, and a front end may write it instead of calling the builder. It is spelled as mach is wherever the two mean the same thing: declarations, signatures, types, decorators, literals and comments are mach's, and only what mach has no word for is mirl's own.

`mirl.ir.text.print(w, m)` writes a module to any `std.io.writer.Writer`, and `mirl.ir.text.same(a, b)` compares two modules for structural equality. `mirl.ir.text.parse.parse(a, text)` reads a text that begins with its version statement into a module, and `mirl.ir.text.parse.parse_body(a, text)` reads a text that has none, as the IR text files under `test/ir` do. `mirl.ir.text.parse.parse_into(m, a, text)` reads a text that has neither a version nor a target statement into a module that already holds other items, as legalisation delivers a helper written in the text form: its names resolve among the module's symbols and its own, and a name the module already holds is refused. A refusal names the line, the column and the reason, and `mirl.ir.text.describe` spells it.

## Version and stability

The text begins with a version statement that names the version of mirl that wrote it, and only that version reads it. A reader refuses any other version.

The text form has no stability or backward compatibility promise. A text written by one version of mirl may not be read by another, and its grammar may change between versions. A tool that must keep IR across versions keeps it in the form of the source that produced it and regenerates the text.

## Comments

A comment is no part of the module, so `parse` drops it and two texts that differ only in comments read as the same module. `mirl.ir.text.parse.parse_noted` keeps them in a `mirl.ir.text.Notes` beside the module, and `mirl.ir.text.print_noted` writes them back, which is how `mirl fmt` keeps a file's comments. Each comment is given to the statement it was written beside: a comment on a line of its own to the first statement after it, and one after code to the statement its line belongs to. A statement is an item, a typedef's member, a debug entry, a block's label, an instruction, a binding record, a closing brace or the version, target and language statements, and a comment after the last of them stays at the end of the text. The printer writes each comment on its own line before its statement, at the statement's indent, or after the statement on its line, so a comment moves with what it was written beside when the printer reorders items. A typedef printed on one line is spread over one line per member when a comment stands beside a member or its closing brace.

## Names

A function or global prints by its symbol name, which is unique and means the same in every module. A value, a block, a debug entry, a structure or union type and a member of one print by a name that carries no meaning beyond the text. The printer gives each a name unique among its kind, and a reader takes any name and gives it to what it names. Two modules that differ only in such names are the same module.

## Equality

Two modules are equal when they say the same thing, up to the naming and ordering that carry no meaning.

Equality is **insensitive** to

- the order of functions and of globals, each paired with the one of the same symbol name in the other module,
- the order and repetition of exports, compared as a set of symbols,
- the order of a symbol's attributes, compared as a multiset,
- type ids and the names of types and their members, since a type is compared by its structure, and an interned type that nothing names is not compared,
- constant ids, their order and repetition, since a constant is compared by what it is,
- the names of values and blocks,
- value, instruction and block ids, the order in which blocks were made, and the order of a block's predecessors and of a value's uses,
- debug table ids and order, since a file, location, site or variable is compared by what it holds wherever it is named and the debug types are compared as a set keyed by their keys.

Equality is **sensitive** to

- the instructions of a block, in order, and its value binding records, in order and each at the same position among the instructions,
- the entry block, and every other block as the same edge reaches it from the entry,
- a block's parameters, an instruction's operands, immediates, edges, edge arguments and results, aggregate elements, structure members and signature lists, each in order.

Only instructions placed in a block are compared. A detached or erased instruction is in no block and is not part of what the function does, and an erased block is not compared either.

## An example

```mach
mirl "0.1.0";
target { arch: "riscv64", sys: "linux", env: "gnu", abi: "lp64d", isa: "rv64gc" };
language { name: "mach", code: 0x804d };

rec Weight { id: i32; w: i64; }

val weights: [3]Weight = {{1, 10}, {2, 20}, {3, 30}};

#[align(64)] #[tls(initial_exec)]
pub var counter: i64 = 0;

ext fun printf(ptr) i32;

# sum the second member of n records
pub fun total(items: ptr, n: i64) i64 {
    br head(0, 0);
head(i: i64, acc: i64):
    val more: i1 = lt.u(i, n);
    cbr(more) body, done;
body:
    val item: ptr = ptr.index[[3]Weight](items, i);
    val field: ptr = ptr.member[Weight, member: w](item);
    val w: i64 = load[i64](field);
    val acc_1: i64 = add(acc, w);
    val i_1: i64 = add(i, 1);
    br head(i_1, acc_1);
done:
    ret(acc);
}

#[oblivious]
pub fun pick(a: ^i64, b: ^i64, c: ^i1) i64 {
    val r: ^i64 = select(c, a, b);
    ret(r);
}

#[export]
pub fun main() i64 {
    val t: i64 = call total(?weights, 3);
    val old: i64 = atomic.add[i64, ordering: seq_cst](?counter, 1);
    ret(t);
}
```

## The grammar

The grammar below is the single statement of the text form. `mirl.ir.text.parse` reads every construct of it, and `mirl.ir.text.print` writes nothing outside it.

```text
grammar

the grammar is ebnf: `{ x }` repeats x zero or more times, `[ x ]` takes it
at most once, `|` separates alternatives and a quoted literal is spelled as
written.

tokens

  ident    = ( letter | "_" ) { letter | digit | "_" } ;
  path     = ident { "." ident } ;
  uint     = digit { digit | "_" } | "0x" hexdigit { hexdigit | "_" } ;  ; `_` only groups digits
  string   = '"' { char | escape } '"' ;
  char     = any byte from 0x20 to 0x7e but '"' and "\" ;
  escape   = "\\" | '\"' | "\x" hexdigit hexdigit ;
  name     = path | string ;

  letter is a-z or A-Z, digit is 0-9 and hexdigit is 0-9, a-f or A-F. a
  `.` joins idents only with no space around it. spaces, tabs, carriage
  returns and newlines between tokens are skipped, and `#` starts a comment
  that runs to the end of its line, but `#[`, which opens a decorator. the
  other tokens are = , : ; ( ) { } [ ] + - ? ^ :: and #[ .

names

  a function or global is named by its symbol name, a path when the name
  is one and a string otherwise. a value, a block, a debug entry, a type
  and a member are named by an ident. the five are named apart, so a value
  and a block of one name are two names, as are a type and a symbol, and a
  value is read as a value wherever an operand stands.

  a value or block prints by the name the module gives it, unique within
  its function: values in the order they are first printed and blocks in
  body order. one takes its own name when nothing named before it took that
  name, and otherwise its name, `_` and the least number from 1 that makes
  it unique, so a second `x` prints `x_1`. one with no name takes `_` and
  the least number not taken, counting on from the last number taken that
  way, so unnamed values print `_0`, `_1` ... and unnamed blocks the same.
  a value never prints by the name of a symbol of its module, so a callee
  written bare is never a value and a symbol. a name that is no ident is
  printed as one: each byte that is not a letter, digit or `_` becomes `_`,
  and a name that starts with a digit takes a leading `_`. debug entries
  print by kind and position: `f` files, `l` locations, `s` sites, `t` debug
  types and `v` variables, as `f0`, `l3`. a structure or union type prints
  by its own name, or `T` and a number when it has none, and a member by its
  own name, or `_` and its position.

module

  module      = version target [ language ] { item } ;
  file        = target [ language ] { item } ;
  items       = { item } ;
  version     = "mirl" string ";" ;
  target      = "target" "{" field { "," field } "}" ";" ;
  field       = ident ":" string ;
  language    = "language" "{" "name" ":" string "," "code" ":" uint "}" ";" ;
  item        = typedef | debug | global | function ;

  `parse` reads a module, `parse_body` a file and `parse_into` items. the
  target states every part of the target's tuple, each once and in any
  order, by the keys mach.toml spells a target with: `arch` the
  architecture, `sys` the system, `env` the environment (`none` for a system
  run under none), `abi` the member of the architecture's convention axis and
  `isa` the instruction set every machine of the target has, as masc spells
  the selection. a reader refuses an empty part, a missing one and one it
  does not know. the language statement spells the source language's name
  and its DW_LANG code: a pair one of mirl's rows in `mirl.ir.language`
  states is that row, any other the module holds as a row of its own, and a
  name of one of mirl's rows with another code is refused. the version is
  the first statement, and a reader refuses a version other than its own,
  and refuses one in a file. a reader takes items in any order, and a name
  may be used before what it names is declared. a name nothing declares is
  refused, naming it. the printer writes the types first, then the debug
  table, the globals and the functions, a blank line before each function.

types

  type        = integer | float | pointer | vector | array | named
              | signature | handle ;
  integer     = ident ;                ; `i` and a legal width: i1 i8 ... i512
  float       = ident ;                ; f16 f32 f64, or a number format row's name
  pointer     = "ptr" [ "[" uint "]" ] ;               ; its address space, 0 when left out
  vector      = "vec" "[" uint "," type "]" ;          ; lanes, lane type
  array       = "[" uint [ "," "stride" uint ] "]" type ;  ; count, stated stride, element type
  named       = ident ;                ; a structure or union a typedef declares
  signature   = "fun" [ "[" name "]" ] "(" [ param { "," param } ] ")" [ results ] ;
  param       = type [ "sext" | "zext" ] ;
  results     = param | "(" param { "," param } ")" ;
  handle      = "handle" "[" name { "," ( uint | type ) } "]" ;  ; the target's kind, then its operands

  typedef     = ( "rec" | "uni" ) ident "{" { member } "}" ;
  member      = ident ":" type [ "at" uint ] ";" ;

  f16, f32 and f64 are the binary16, binary32 and binary64 number formats,
  and any other format is spelled by its row's name. a structure and a
  union are declared once by a typedef and named by it everywhere else. a
  structure states every member's byte offset with `at`, or none and leaves
  them to the data layout, and a union states none. two typedefs of one
  structure are refused, since a type is its structure. an array with
  `stride` states the bytes from one element to the next. a signature's
  bracketed name is its calling convention, none when left out, and it has
  no results when it states none. a parameter or result may state how an
  integer is extended, `sext` or `zext`, and it is part of the type:
  `fun(i8 sext)` and `fun(i8)` are different types.

literals

  literal     = number | "-" number | "zero" | aggregate | address | spec ;
  number      = uint ;
  aggregate   = [ type ] "{" [ literal { "," literal } ] "}" ;
  address     = "?" name [ ( "+" | "-" ) uint ] ;
  spec        = "spec" "(" uint "," [ "-" ] uint ")" ;
  typed       = literal [ "::" type ] ;

  a literal has the type the place it stands in gives it, and states one
  with `::` where the place gives none. the places that give one are an
  operand a row's rules tie to the type of another operand or of an
  immediate, an argument of a direct call, a returned value, a branch
  argument, an aggregate's member, a global's initial value and a step of a
  binding record, and the printer writes `::` everywhere else. an aggregate
  literal written with its type, as `Weight{1, 10}` or `[2]i8{1, 2}`, states
  it so.

  a number of an integer type is its bits read unsigned, and a number of a
  float type is the bits of its encoding, never a decimal value. `-` gives
  the two's complement of those bits at the type's width. the printer writes
  an integer of at most 64 bits in decimal, negative when its top bit is set
  and it is wider than one bit, and any other number in hex. `zero` is every
  bit zero. braces hold an aggregate's members, elements or lanes in order.
  `?` and a symbol is the address of a function or global plus a byte
  offset, of a pointer type, `ptr` when nothing states another. `spec` is a
  specialization constant of an integer or float type: its id, at most 32
  bits, and its default.

decorators

  decorator   = "#[" path [ "(" [ argument { "," argument } ] ")" ] "]" ;
  argument    = uint | string | name | type | literal | "[" [ argument { "," argument } ] "]"
              | ident ":" argument ;

  a decorator states one fact of the item or instruction after it, and a
  run of them may share a line. the decorators below are mirl's. any other
  path with a `.` in it is an attribute record of a target family: its first
  ident is the family, the rest its name, and its one argument the datum, a
  number, a list of numbers or a string: `#[spirv.execution_mode(17)]`.

  #[export]                 the module exports the symbol
  #[weak] #[unique]         its binding, which `pub` states global and no
                            word states local
  #[visibility(name)]       its visibility, by the name of mink's row:
                            protected, hidden, internal. default when left out
  #[align(n)]               a global's alignment
  #[section(string, name)]  a global's section, its name and its kind by the
                            name of mink's section kind row
  #[tls(model)]             a global is thread-local under the model:
                            general_dynamic, local_dynamic, initial_exec,
                            local_exec
  #[secret([o, n], ...)]    the byte ranges of a global that are secret, each
                            its offset and length, at least one, ascending and
                            none overlapping or touching the one before it
  #[oblivious]              the function must run in time independent of its
                            secret values
  #[convention(name)]       the calling convention of a function's signature,
                            the default when left out
  #[placed(type, places)]   the abi legalisation has put the body in pieces:
                            the signature the function keeps, then one place
                            per entry parameter
  #[volatile] #[kept]       an instruction's flags
  #[bounded] #[checked]
  #[secret]                 an instruction's metadata states its results
                            secret where its row's secrecy does not, or it has
                            none

  `kept` marks a store or a fill whose write no pass may take away (see the
  specification's memory section). `bounded` marks a shift whose count is
  below its operand's width. `checked` marks a division whose zero divisor,
  signed overflow and quotient that does not fit are tested before it. a
  reader refuses a decorator mirl does not know on an item it does not
  apply to.

globals

  global      = { decorator } [ "pub" ] ( "val" | "var" ) name ":" [ "^" ] type "=" typed ";"
              | { decorator } "ext" ( "val" | "var" ) name ":" [ "^" ] type ";" ;

  `val` states that the program never writes the global and `var` that it
  may. `ext` declares a global another module defines, which has no initial
  value, so its binding is one other objects may refer to: global, or weak
  or unique by its decorator. `^` states the whole global secret, and
  `#[secret]` the byte ranges of it that are, never both. its initial value
  is public, as every constant is.

functions

  function    = { decorator } [ "pub" ] "fun" name "(" [ entry { "," entry } ] ")"
                [ results ] "{" { line } "}"
              | { decorator } "ext" "fun" name "(" [ param { "," param } ] ")" [ results ] ";" ;
  entry       = ident ":" [ "^" ] param ;
  line        = label | binding | instruction ;
  label       = ident [ "(" entry { "," entry } ")" ] ":" ;
  binding     = "bind" ident [ "[" uint "," uint "]" ] "=" ( step | "unavailable" ) ";" ;
  step        = path [ "[" type "]" ] "(" step [ "," typed ] ")" | operand ;
  instruction = { decorator } [ "val" results_of "=" ] operation ";" ;
  results_of  = result | "(" result { "," result } ")" ;
  result      = ident ":" [ "^" ] type ;
  operation   = path [ "[" [ immediate { "," immediate } ] "]" ] [ callee ]
                [ "(" [ operand { "," operand } ] ")" ] [ target { "," target } ]
                [ "at" ident ] [ "in" ident ] [ "holds" "[" [ ident { "," ident } ] "]" ] ;
  callee      = name ;
  operand     = ident | typed ;
  immediate   = [ ident ":" ] spelled ;
  target      = [ uint ":" ] ident [ "(" [ operand { "," operand } ] ")" ] ;

  a function with a body is defined here, and an `ext` one is declared here
  and defined by another module. its signature is mach's: the entry
  parameters with their types, then its results. its body starts in its
  entry block, whose parameters are the function's, and every other block
  starts at its label. a `^` marks a value secret. no edge leads to the
  entry block, which only the call enters, so the printer writes no label for
  it, a reader refuses a branch to it and the verifier refuses an edge to it.

  a binding is a value binding record: from its point on, the variable is
  the operand, read through each step, innermost first. a step is a salvage
  step row's name, then the type it gives for a row that takes one, or its
  constant for a row that takes one: `bind v0 = ext.s[i64](add(x, 4));`.
  the bracketed pair is the piece of the variable the record gives, the
  offset of its lowest bit and its size, the whole variable when left out.
  `unavailable` gives the variable no value from the point on. a record
  stands just before the instruction after it, or at its block's end when
  none follows, so the records after a block's label stand at its entry,
  and records print in the order they stand.

  an operation is spelled from its opcode's row alone. its path is the row's
  name. the brackets hold one immediate per slot of the row, in order: the
  first bare and every other led by its slot's name. a slot whose value is
  the one the text leaves out is left out, and an empty bracket is left out
  with it. the text leaves out an alignment that is the byte size of the
  type accessed when that type is an integer, a float or a vector of either
  and the size is a power of two, a named count of `all`, a signature a
  direct call's callee states, and a case list, which its targets write. an
  operand whose role is `callee` is written before the parentheses, bare
  when it is a function of the module and as its value otherwise. the
  parentheses hold the other operands in order, the fixed ones then the
  tail, and are left out when there are none and the operation has
  targets. then come the targets in order, each with its arguments, and a
  target after the first of an operation with a case list leads with its
  case value. results are typed, and a reader refuses a type other than the
  one the row derives. after the operation come its location, its inlining
  site and the debug bindings whose storage its result addresses, each left
  out when empty.

  how an immediate is spelled follows what it holds:

  spelled     = type | uint | ordering | "all" | "[" [ uint { "," uint } ] "]"
              | places | name | ident | block | op ;
  ordering    = "relaxed" | "acquire" | "release" | "acq_rel" | "seq_cst" ;
  places      = "[" [ place { "," place } ] "]" ;
  place       = "{" location "," scale "," fill "}" ;
  location    = "reg" "(" uint "," uint ")" | "stack" "(" uint [ "," "scaled" uint ] ")"
              | "operand" "(" uint ")" ;
  scale       = "fixed" | "scaled" "(" uint ")" ;
  fill        = "exact" | "undefined" | "boxed"
              | ( "sign" | "zero" | "declared" ) "(" uint ")" ;
  block       = string "{" [ bound { "," bound } ] "}" { "reads" | "writes" } ;
  bound       = ident ":" ( "in" | "out" | "inout" | "none" ) constraint type ;
  constraint  = "reg" "(" uint ")" | "mem"
              | "imm" "(" uint "," ( "signed" | "unsigned" ) [ "," "symbolic" ] ")" ;
  op          = "op" "(" string "," string "," "[" [ type { "," type } ] "]"
                { "," ( "reads" | "writes" ) } ")" ;

  a member index is the name its aggregate's typedef gives the member, which
  is `_` and its position for a member with no name of its own, and a reader
  also takes `_` and the position for a type no typedef of the text writes. a function is its
  symbol. a place is where its piece travels, how its size scales and how
  the place is filled past the piece: a register place is masc's class and
  number, a stack place a byte offset in the argument area and an operand
  place a position in the target's own call form.

  an inline assembly item is the `asm` operation, whose block is the
  block's text in the set's source dialect, its operands in order, each its
  name, role, constraint and the type of the value it binds, and `reads`
  and `writes` where it declares it touches memory beyond its memory
  operands. a class is masc's handle of a class of the set's register file.
  the item's operands are the values the block binds:
  `val d: i64 = asm["addi {d}, {a}, {k}" {d: out reg(0) i64, a: in reg(0) i64, k: in imm(12, signed) i64}](x, 7);`.

  a target op is the `target.op` operation, or `target.op.memory` where it
  touches memory, whose op is the instruction set as its target's catalog
  names it, the op as the set names it, the types of its results, and
  `reads` and `writes` where it declares it touches memory. the item's
  operands are the op's own:
  `val r: f32 = target.op[op("GLSL.std.450", "Sqrt", [f32])](x);`.

debug table

  debug       = "debug" "{" { entry_of } "}" ;
  entry_of    = "file" ident "=" string ";"
              | "loc" ident "=" ident ":" uint ":" uint ";"
              | "site" ident "=" string "at" ident [ "in" ident ] ";"
              | "type" ident "=" string string shape ";"
              | "var" ident "=" string ":" ident "at" ident [ "parameter" uint ] ";" ;
  shape       = "base" "(" encoding "," uint ")"
              | ( "structure" | "union" ) "(" type ")" members
              | "tagged" "(" type ")" ( "open" | "discriminant" dmember "payload" uint
                "{" [ case { "," case } ] "}" )
              | "enumeration" ( "open" | "(" ident ")" "{" [ enumerator { "," enumerator } ] "}" )
              | "array" ( "open" | "(" ident "," uint ")" )
              | "pointer" "(" string ")"
              | "function" ( "open" | "(" [ idents ] ")" "(" [ idents ] ")" ) ;
  encoding    = "signed" | "unsigned" | "float" | "boolean" | "character" | "address" ;
  members     = "open" | "{" [ dmember { "," dmember } ] "}" ;
  dmember     = string ":" ident "field" uint ;
  case        = string ":" uint [ "payload" dmember ] ;
  enumerator  = string ":" uint ;
  idents      = ident { "," ident } ;

  a location is a file, a line and a column. a site is the inlined
  function's symbol name, the location of the call and the site the call
  was itself inlined at. a type is its key, its source name ("" when
  anonymous) and its shape: a structure or union is the ir type it is laid
  out as and its members, each a source name, a debug type and the field of
  the layout it is laid out as, a tagged union its layout, discriminant,
  payload field and cases, an enumeration its base type and values, an
  array its element and count, a pointer the key of its pointee and a
  function its parameters and results. `open` is an entry declared and not
  yet defined. a variable is its source name, debug type, declaring
  location and its position among the parameters when it is one. every
  file is printed, then every location, site, type and variable, each in
  order.
```
