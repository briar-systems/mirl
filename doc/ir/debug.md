# The debug table

Each module has a debug table that describes the source behind its IR. It holds source files, locations, inlining sites, debug types and variable bindings. A producer of debug information such as `mirl.debug` reads this table and the IR together and nothing else, so a front end that wants a debugger to see its source types, lines and variables fills the table, attaches entries to instructions and binds variables at program points.

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

A binding ties a source variable to the code. It holds the variable's source name, its debug type, the location where it is declared and its position among the function's parameters when it is one. A variable is bound in two ways, by where the binding is attached.

- **Storage.** An instruction whose result addresses the variable's storage, such as the `alloca` of a stack slot, names the binding in its metadata. Bindings are attached there as a list. `bindings(m, list)` makes a list of bindings that instructions can share, and a list never changes once made. The empty list is always the first.
- **Value.** A value binding record at a program point gives the variable a value from that point on.

## Value binding records

A record stands at a point of a block: just before one of its instructions, or at the block's entry, which is the point before its first instruction and how a block parameter gets one. It names a binding and what it reads, which is an operand and a salvage expression over it, or `unavailable`. The operand is any value of the function: an instruction result, a block parameter or a constant. A binding has to be at a point rather than on a value, since a value has no "from here on". After `x = y`, with `y` defined earlier, a binding on `y` would make `x` read as `y` before the assignment, and a constant has no point of definition at all.

A record is not an instruction. No instruction walk sees it, and it carries no scheduling, cost or ordering constraint. Reading a value is never a use of it, so a record holds nothing alive for liveness, dead code removal or any pass. Records live in a pool of the body and stand in runs. Each instruction holds the run of records just before it and each block the run at its end, linked through the pool, and each value lists the pool positions of the records that read it. Every body edit keeps each record at its point by moving whole runs, so it costs nothing per record it does not touch.

- An instruction placed before another lands after the records standing before that one, and an instruction appended to a block lands after the records at its end.
- An erased instruction leaves its records to the instruction after it.
- A block split moves the records standing before the moved instructions with them, and a merge puts the merged block's records after those of the branch it replaces.
- A replacement of a value moves every record that reads it to the value that replaces it when that value is a constant or the caller states that it stands at every point of the old one (`Records.follow`). Otherwise those records become `unavailable`. A record never refuses a replacement. A merge moves the records of the parameters it removes to the arguments of the branch it replaces, and putting one instruction in the place of another moves the records of each result to the result that takes its place.
- A copy of a region of blocks, in the same function or another, gives each copy its source's records at the same positions, reading through the map as an operand does.
- A snapshot copies them and a restore puts them back.

When what a record reads goes, through an erased instruction, a removed parameter or an erased block, the record becomes `unavailable` at its point. It is never deleted, since that would leave the variable's earlier value standing as a stale answer. A pass that removes a value it can still describe salvages the record first with `mirl.ir.body.rebind`, giving it another operand and an expression that recovers the variable from it. `mirl.ir.body.salvage` finds that expression from the step table: when an operand is the result of an instruction a step row names, with a constant operand where the row takes one, it reads the instruction's other operand through that step, and otherwise it answers `unavailable`. Dead code removal salvages every record that reads a value it removes this way, through as many removed instructions as the chain holds.

Records are made through the builder, by `mirl.build.bind_at`, at the builder's cursor and with no sticky attribute. `copy_binding` copies one through a map.

### Salvage expressions

A salvage expression is a list of steps applied in order to the operand, made by `mirl.ir.module.expression` and shared by id like a binding list. The empty expression is the operand as it is. Each kind of step is a row of the step table in `mirl.ir.point`, which states its name, what argument it takes and how its result type follows from what it reads.

| step | argument | result |
|---|---|---|
| `add` | an integer constant of the type it reads | that type, the wrapping sum |
| `sub` | an integer constant of the type it reads | that type, the wrapping difference |
| `ext.u` | a wider integer type | that type, zero extended |
| `ext.s` | a wider integer type | that type, sign extended |
| `trunc` | a narrower integer type | that type, keeping the low bits |

Every step is one a DWARF location expression can state, so a producer encodes each kind as a column of its row.

## On an instruction

An instruction's metadata record names the location it was built for, the site it was inlined through and its list of storage bindings. All three are optional. A copy of an instruction copies the record whole.

## What the verifier holds

Verifier rule 12, `debug`, requires that every location, site and binding list named by an instruction's metadata is an entry of the module's debug table. Rule 13, `binding`, requires that every value binding record stands before an instruction of its block, in the order of their points, names a variable of the debug table, and reads a value the body defines through an expression that applies to its type, and that the value dominates the record's point when the entry reaches its block.
