# The text form

A module and its text are interchangeable. The text form is the printed form of a module, written for people and for tests, and a front end may write it instead of calling the builder. `mirl.ir.text.print(w, m)` writes a module to any `std.io.writer.Writer`, and `mirl.ir.text.same(a, b)` compares two modules for structural equality. `mirl.ir.text.print` writes the grammar below. `mirl.ir.text.parse.parse(a, text)` reads a text that begins with its version line into a module, and `mirl.ir.text.parse.parse_body(a, text)` reads a text that has no version line, as the IR text files under `test/ir` do. `mirl.ir.text.parse.parse_into(m, a, text)` reads a text that has neither a version line nor a target line into a module that already holds other items, as the helpers legalisation delivers a helper written in the text form: its names resolve among the module's symbols and its own, and a name the module already holds is refused. A refusal names the line and the reason, and `mirl.ir.text.describe` spells it.

## Version and stability

The text begins with a version line that names the version of mirl that wrote it, and only that version reads it. A reader refuses any other version.

The text form has no stability or backward compatibility promise. A text written by one version of mirl may not be read by another, and its grammar may change between versions. A tool that must keep IR across versions keeps it in the form of the source that produced it and regenerates the text.

## Names

A function or global prints by its symbol name, which is unique and means the same in every module. A value, a block and a debug entry print by a name that carries no meaning beyond the text. The printer gives each a name unique within its function, and a reader takes any name and gives it to the value or block it names. Two modules that differ only in such names are the same module.

## Equality

Two modules are equal when they say the same thing, up to the naming and ordering that carry no meaning.

Equality is **insensitive** to

- the order of functions and of globals, each paired with the one of the same symbol name in the other module,
- the order and repetition of exports, compared as a set of symbols,
- the order of a symbol's attributes, compared as a multiset,
- type ids, since a type is compared by its structure, and an interned type that nothing names is not compared,
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

This is the text of a module with one global and one function. The version line shows the version of the library when this was written. Each line of the function is an instruction spelled from its opcode's row. The word is the row's name, then each operand, then each immediate led by its slot's name, then each target. Results are not typed in the text, since the row derives their types.

```text
mirl "0.1.0"
target "riscv64"
global @counter: i32 linkage global visibility default = i32 7

function @f.main_1: fun(i32) -> (i32) linkage global visibility default {
^entry(%x: i32):
    %x.1 = add %x, i32 1
    %0 = add %x.1, i32 1
    ret %0
}
```

## The grammar

The grammar below is the single statement of the text form. `mirl.ir.text.parse` reads every construct of it but the inline assembly item, which it refuses as not supported yet, and `mirl.ir.text.print` writes nothing outside it.

```text
grammar

the grammar is ebnf: `{ x }` repeats x zero or more times, `[ x ]` takes it
at most once, `|` separates alternatives and a quoted literal is spelled as
written. it is LL(1) over the tokens below.

tokens

  newline  = lf ;
  uint     = digit { digit } | "0x" hexdigit { hexdigit } ;
  word     = plain ;                   ; any plain run that is not a uint
  string   = '"' { char | escape } '"' ;
  char     = any byte from 0x20 to 0x7e but '"' and "\" ;
  escape   = "\\" | '\"' | "\x" hexdigit hexdigit ;
  plain    = ( letter | digit | "_" | "." ) { letter | digit | "_" | "." } ;
  name     = plain | string ;
  symbol   = "@" name ;
  local    = "%" name ;
  label    = "^" name ;
  dref     = "!" name ;

  letter is a-z or A-Z, digit is 0-9 and hexdigit is 0-9 or a-f. no space
  stands between a sigil and its name. spaces, tabs and carriage returns
  between tokens are skipped, and `;` starts a comment that runs to the end
  of its line. the other tokens are = , : ( ) { } [ ] < > -> + -

names

  a function or global is named `@` and its symbol name, a value `%`, a
  block `^` and a debug entry `!`. a name prints bare when it is a plain
  name and quoted otherwise, so only a name that is empty or holds a byte
  outside letters, digits, `_` and `.` is quoted. a quoted name or string
  writes `"` as `\"`, `\` as `\\` and any byte outside 0x20 to 0x7e as `\x`
  and two lowercase hex digits. a symbol name is the symbol's own, names
  it in every module and is unique within one.

  a value or block prints by the name the module gives it, unique within
  its function: values in the order they are first printed and blocks in
  body order, an erased block taking no name. one takes its own name when nothing named before it took
  that name, and otherwise its name, `.` and the least number from 1 that
  makes it unique, so a second `%x` prints `%x.1`. one with no name takes
  the least number not taken, counting on from the last number taken that
  way, so unnamed values print `%0`, `%1` ... and unnamed blocks `^0`,
  `^1` ... when nothing else is named. values and blocks are named apart.
  debug entries print by kind and position: `!f` files, `!l` locations,
  `!s` sites, `!t` debug types and `!v` variables. a name of a value, block
  or debug entry means nothing beyond the text, and a reader takes any name
  and gives it to the value or block it names.

module

  module      = version target { item } ;
  file        = target { item } ;
  items       = { item } ;
  version     = "mirl" string newline ;
  target      = "target" string newline ;
  item        = newline | debug | global | function | attribute ;

  `parse` reads a module, `parse_body` a file and `parse_into` items. the
  version line is the first line, and a reader refuses a version other than
  its own, and refuses a version line in a file. a reader takes items in any
  order. a symbol, a value or a block may be named before it is defined, and
  so may a debug entry named from a body or a debug type named from a debug
  type. any other debug entry is named after its line. a name nothing
  defines is refused, naming it, and a refusal carries the line and column
  of the token that caused it. the printer writes the debug entries first,
  the globals next and the functions last, each symbol's attributes just
  after its item and a blank line before each function.

types

  type        = integer | float | pointer | vector | array | structure
              | union | signature | handle ;
  integer     = word ;                    ; `i` and a legal width: i1 i8 ... i512
  float       = word ;                    ; a number format row's name: binary32
  pointer     = "ptr" [ "<" uint ">" ] ;  ; its address space, 0 when left out
  vector      = "vec" "<" uint "," type ">" ;            ; lanes, lane type
  array       = "array" "<" uint "," type ">" ;          ; count, element type
  structure   = "struct" ( "{" [ types ] "}" | "at" "{" [ placed { "," placed } ] "}" ) ;
  placed      = uint ":" type ;           ; a member at its stated byte offset
  union       = "union" "{" [ types ] "}" ;
  signature   = "fun" "(" [ extended ] ")" "->" "(" [ extended ] ")" ;
  extended    = type [ "sext" | "zext" ] { "," type [ "sext" | "zext" ] } ;
  handle      = "handle" "<" name ">" ;   ; the target's kind name
  types       = type { "," type } ;

  `struct at` states every member's offset, and a plain `struct` leaves
  them to the data layout. the printer spells space 0 as a bare `ptr`.

  a parameter or result of a signature may state how an integer is extended,
  `sext` or `zext`, and states none by leaving the word out. it is part of
  the type: `fun(i8 sext) -> ()` and `fun(i8) -> ()` are different types.

constants

  constant    = type literal ;
  literal     = uint | "-" uint | "zero"
              | "{" [ constant { "," constant } ] "}"
              | symbol [ ( "+" | "-" ) uint ] ;

  a number of an integer type is its bits read unsigned, and a number of a
  float type is the bits of its encoding. `-` gives the two's complement of
  those bits at the type's width. the printer writes an integer of at most
  64 bits in decimal and any other number in hex. `zero` is every bit zero.
  braces hold an aggregate's members, elements or lanes in order. a symbol
  is the address of a function or global plus a byte offset, of a pointer
  type.

globals

  global      = [ "export" ] "global" symbol ":" type linkage [ "constant" ]
                [ "align" uint ] [ "section" string name ] [ "tls" model ]
                [ "=" constant ] newline ;
  model       = "general_dynamic" | "local_dynamic" | "initial_exec" | "local_exec" ;
  linkage     = "linkage" name "visibility" name ;

  a function or global states its linkage, its binding and its visibility,
  spelled by the names of mink's symbol rows: local, global, weak, unique,
  and default, protected, hidden, internal. a global with no initial value
  is defined by another module, so its binding is one other objects may
  refer to, any but local.

  `constant` states that the program never writes the global. a section is
  its name and its kind, spelled by the name of a row of mink's section
  kinds: text, rodata, relro, data, bss, tdata, tbss and the rest.

attributes

  attribute   = "attribute" symbol name name "=" datum newline ;
  datum       = uint | "[" [ uint { "," uint } ] "]" | string ;

  the names are the attribute's family and its name within that family.

functions

  function    = [ "export" ] "function" symbol ":" type linkage [ "constant_time" ]
                [ [ "placed" places ] "{" newline { newline } { block } "}" ] newline ;
  block       = label [ "(" param { "," param } ")" ] ":" newline { line } ;
  param       = local ":" [ "secret" ] type ;
  line        = newline | binding newline | instruction newline ;
  binding     = "bind" dref ( "=" operand { "," step } | "unavailable" ) ;
  step        = word ( constant | type ) ;
  instruction = [ local { "," local } "=" ] ( operation | assembly ) ;
  operation   = word [ entry { "," entry } ] [ "loc" dref ] [ "site" dref ]
                [ "volatile" ] [ "kept" ] [ "bounded" ] [ "checked" ] [ "secret" ] [ "bind" "[" [ dref { "," dref } ] "]" ] ;
  entry       = operand | immediate | target ;
  operand     = local | constant ;
  immediate   = word ( type | uint | ordering | "[" [ uint { "," uint } ] "]"
                     | "all" | places ) ;
  places      = "[" [ place { "," place } ] "]" ;
  place       = ( "register" uint uint | "stack" uint | "operand" uint )
                ( "fixed" | "scaled" uint ) fill ;
  fill        = "exact" | "undefined" | "boxed"
              | ( "sign" | "zero" | "declared" ) uint ;
  ordering    = "relaxed" | "acquire" | "release" | "acq_rel" | "seq_cst" ;
  target      = label [ "(" [ operand { "," operand } ] ")" ] ;
  assembly    = "asm" ... ;

  `kept` marks a store or a fill whose write no pass may take away (see
  the specification's memory section). `bounded` marks a shift whose count is
  below its operand's width. `checked` marks a division whose zero divisor,
  signed overflow and quotient that does not fit are tested before it.

  `constant_time` marks a function that must run in time independent of its
  secret values.

  `placed` marks a body the abi legalisation has rewritten into pieces: its
  entry parameters are the pieces, one per place in the list, and a function
  that states it has a body. a `named` immediate is `all` or the count of
  named arguments. a place is where its piece travels, how its size scales
  and how the place is filled past the piece. a register place is masc's
  class and number, a stack place a byte offset in the argument area and an
  operand place a position in the target's own call form.

  a function without braces is declared here and defined by another module,
  so its binding is not local. its first block is its entry, whose
  parameters are its parameters. only
  the blocks of a body that are not erased print, and only the instructions
  placed in them, so a detached or erased instruction and an erased block
  do not print.

  an operation is spelled entirely from its opcode's row: the word is the
  row's name, then every operand in order, the fixed ones and then the
  tail, then one immediate per slot of the row in order, led by the slot's
  name and spelled by what it holds, then each target in order with its
  arguments. results are not typed, since the row derives their types.
  after the entries comes the metadata record: its location, its inlining
  site, its flags, its secrecy and the debug bindings whose storage its
  result addresses, each left out when empty. no slot name is a type word
  or a metadata keyword, so one token tells an operand from an immediate, a
  target or the record.

  a binding line is a value binding record: from its point on, the
  variable is the operand, read through each step in order. a step is a
  salvage step row's name, then a constant of the type it reads when the
  row takes one, or the type it gives otherwise: `add` and `sub` a
  constant, `ext.u`, `ext.s` and `trunc` a type. `unavailable` gives the
  variable no value from the point on. a record stands just before the
  instruction line after it, or at its block's end when none follows, so
  the records after a block's label stand at its entry, and records print
  in the order they stand. no opcode is named `bind`, so the first word
  tells a record from an instruction.

  `asm` is reserved for inline assembly items, whose block is spelled
  through masc's text form.

debug table

  debug       = dref "=" record newline ;
  record      = "file" string
              | "location" dref uint ":" uint
              | "site" dref string [ "parent" dref ]
              | "type" string string shape
              | "variable" string dref "declared" dref [ "parameter" uint ] ;
  shape       = "base" encoding uint
              | "structure" type members
              | "union" type members
              | "tagged" type ( "open" | "discriminant" member "payload" uint
                "{" [ case { "," case } ] "}" )
              | "enumeration" ( "open" | dref "{" [ enumerator { "," enumerator } ] "}" )
              | "array" ( "open" | dref uint )
              | "pointer" string
              | "function" ( "open" | "(" [ drefs ] ")" "->" "(" [ drefs ] ")" ) ;
  encoding    = "signed" | "unsigned" | "float" | "boolean" | "character" | "address" ;
  members     = "open" | "{" [ member { "," member } ] "}" ;
  member      = string ":" dref "field" uint ;
  case        = string uint [ "payload" member ] ;
  enumerator  = string uint ;
  drefs       = dref { "," dref } ;

  a location is a file, a line and a column. a site is the location of the
  call, the inlined function's symbol name and the site the call was itself
  inlined at. a type is its key, its source name ("" when anonymous) and its
  shape: a structure or union is its layout and its members, each a source
  name, a debug type and the field of the layout it is laid out as, a tagged
  union its layout, discriminant, payload field and cases, an enumeration
  its base type and values, an array its element and count, a pointer the
  key of its pointee and a function its parameters and results. `open` is an
  entry declared and not yet defined. a variable is its source name, debug
  type, declaring location and its position among the parameters when it
  is one. every file is printed, then every location, site, type and
  variable, each in order, so a reference names an entry printed before
  it, except a type naming a type.
```
