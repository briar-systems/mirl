# The debug table

Each module has a debug table that describes the source behind its IR. It holds source files, locations, inlining sites, debug types and variable bindings. A producer of debug information such as `mirl.debug` reads this table and the IR together and nothing else, so a front end that wants a debugger to see its source types, lines and variables fills the table and attaches entries to instructions.

No record in the table holds a size or an offset. A producer asks the target's data layout for those, through the IR type an aggregate is laid out as (see [target.md](target.md)).

Every id into the table is a plain index and means something only in its module. The text form prints them by kind and position (see [text.md](text.md)).

## Files and locations

`file(table, path)` adds a source file and gives its id. The same path gives the same id. `location(table, position)` adds a location, which is a file, a line from one and a column from one. A location is always in a file the table gave out.

## Inlining sites

A site records code inlined at a call. It holds the location of the call, the symbol name of the inlined function, which names the function in every module, and the site the call was itself inlined at, or none. A chain of sites reaches from the innermost inlined code out to the function that was compiled.

## Debug types

A debug type describes a source type. Its **key** is its identity across modules. The front end supplies it and the table never derives it, so two modules that describe the same source type under the same key describe one type. An entry also has a source name, empty when the type is anonymous.

The kinds are

| kind | what it describes |
|---|---|
| base | a scalar, with an encoding (signed, unsigned, float, boolean, character or address) and a width in bits of at least one |
| structure | members, each a source name, a debug type and the **field** of the IR structure it is laid out as |
| union | members laid out as fields of an IR union |
| tagged | a tagged union, laid out as an IR structure of a discriminant and a union of the cases. It holds the discriminant member, the field that is the union of the cases and the cases in source order, each with the discriminant value that selects it and an optional payload member |
| enumeration | a base debug type and named values in source order |
| array | an element debug type and a count |
| pointer | the key of its pointee, which is linked to the one entry described under that key |
| function | parameter and result debug types |

This is how a front end gives a debugger the source type of a lowered tagged union (see section 2.8 of [the specification](../ir.md)). The IR carries the structure of the discriminant and the union, and the debug type says which field is which and what each case means.

### Declaring and defining

An aggregate refers to itself and to others, so an entry is declared under its key before its members are walked. `declare(table, types, entry)` gives either a **fresh** open entry, whose members the caller walks and then gives with `define`, or the **known** entry already described under that key. A base or pointer entry is complete once declared. An entry declared a second time under its key must say the same thing, or the table refuses it as a conflict.

`define(table, types, entry, shape)` gives an open entry its members. A member that is laid out as a field of the owner's IR type must name a field that exists and agree with it, and a table refuses a member that does not.

A pointer names its pointee by key. `pending(table)` gives the key of the first pointee that no entry is described under yet, and the caller describes it and asks again until none is left. `finish(table)` links every pointee and confirms that every entry is defined. A producer reads the table only after `finish` succeeds.

## Variable bindings

A binding ties a source variable to an instruction. It holds the variable's source name, its debug type, the location where it is declared, its position among the function's parameters when it is one, and what the instruction gives it, which is either **value** (the instruction's result is the variable's value) or **storage** (the result addresses the variable's storage).

Bindings are attached through the instruction's metadata as a list. `bindings(m, list)` makes a list of bindings that instructions can share, and a list never changes once made. The empty list is always the first.

## On an instruction

An instruction's metadata record names the location it was built for, the site it was inlined through and its list of bindings. All three are optional. A copy of an instruction copies the record whole.

## What the verifier holds

Verifier rule 12, `debug`, requires that every location, site and binding list named by an instruction's metadata is an entry of the module's debug table.
