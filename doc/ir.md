# mirl IR specification

This is the specification of mirl IR, the contract between a front end and mirl. A front end author who is not the author of mach should be able to produce valid IR from this document and the library alone. It describes the library as built. Where the library and this text disagree, one of them is wrong and gets fixed.

The specification is split by subject.

| document | subject |
|---|---|
| this file | the model, types, values, control flow, semantics, secrecy, the verifier's rules and inline assembly |
| [ir/opcodes.md](ir/opcodes.md) | the opcode reference, generated from the opcode table |
| [ir/text.md](ir/text.md) | the text form, its grammar and its version |
| [ir/fold.md](ir/fold.md) | the constant folder |
| [ir/target.md](ir/target.md) | targets, capabilities, data layout and attributes |
| [ir/debug.md](ir/debug.md) | the debug table |

Names in code style such as `mirl.verify.against` are modules and functions of the library. The library is reached through its `mirl.*` modules, and the aggregate module `mirl` re-exports all of them.


## 1. The model

A **module** is one unit of code. It names the **target** it is built for and holds a type table, functions, globals, constants, a debug table, a list of exported symbols and the attributes attached to its functions and globals. A module holds no layout of its own. Every size, alignment and member offset comes from the target's data layout (see [ir/target.md](ir/target.md)).

A **function** or **global** is a **symbol**. Its symbol name is unique within its module and names it in every module. A global has a type, an optional initial value, an optional alignment, an optional section, an optional thread-local model, a linkage and a visibility. Linkage and visibility are rows of the symbol model of mink, the linker, and are spelled in text by those rows' names (`local`, `global`, `weak`, `unique` and `default`, `protected`, `hidden`, `internal`). A global with no initial value is defined by another module.

A function has a signature, which is a function type, and a body. A function with no blocks is a declaration, defined by another module. In a body, the first block is the entry and its parameters are the function's parameters.

Everything in a module is addressed by an id. A function, global or constant id indexes its module. A block, value or instruction id indexes the body of the function that made it. Ids are plain numbers that mean nothing across modules and nothing in the text form.

A front end builds a module through `mirl.build`, the builder, or by writing the text form. The builder places each instruction at a cursor, types it by its opcode's row and keeps the first refused call, after which every call is refused and answers a stand-in. A front end reads `done` once at the end. Every other producer makes instructions through the builder, and edits them through `mirl.ir.body`.


## 2. Types

Types are interned in the module's type table. Each structurally distinct type has exactly one id, so two types are the same type exactly when their ids are equal. Interning copies the lists it is given.

### 2.1 Integers

An integer is signless. Its width is 1, 8, 16, 32, 64, 128, 256 or 512 bits, and every one of these widths is legal on every target. A target that does not hold a width natively has it expanded by legalisation, and the front end never decides this. Signedness belongs to the opcode, never the type, so there are separate signed and unsigned division, comparison, extension and conversion opcodes.

`i1` is the type of every comparison and every condition. There is no boolean kind. An `i1` held in memory takes one byte and holds 0 or 1.

### 2.2 Floats

A float names one row of the number format table and nothing else. A row states a name, a width, an encoding (sign, exponent and significand fields with a bias), a default rounding rule and a not-a-number rule. The rows are `binary16`, `binary32` and `binary64`. A later format such as `bfloat16` or `binary128` is a new row. It needs no new case in the type table or in any pass that reads it, because everything reads the row.

### 2.3 Pointers

A pointer is opaque. It names an address space by number, and space 0 is the default. A pointer has no pointee type. What is read or written through it is stated by the instruction that does so. Which spaces exist, and how a pointer into each is held, is declared by the target. A space with no row is refused, and a pointer into a logical space has no representation in memory.

### 2.4 Vectors

A vector has a lane count of at least one and a lane type. Opcodes decide which lane types they accept.

### 2.5 Arrays, structures and unions

An array has an element count and an element type.

A structure is an ordered list of member types. It has no layout of its own. The target's data layout places the members. A structure may state the byte offset of every member, all or none, and the target's layout refuses stated offsets that overlap or do not keep a member's alignment.

A union is a list of member types that overlap in storage. Every member is at offset 0.

### 2.6 Function types

A function type has a list of parameter types and a list of result types. A function may have any number of results. A pointer to a function is an ordinary pointer, and a call states the signature it calls through.

### 2.7 Target handles

A handle is an opaque value that a target declares, named by a family-qualified kind such as `spirv.image`. The kind is a non-empty name compared by its bytes.

### 2.8 Tagged unions

A tagged union is not an IR type. A front end lowers one to a structure of a discriminant integer and a union of the payloads, for example `struct{i8, union{i32, i8}}`, and branches on the discriminant itself. This keeps the IR free of any source language's rules about what a tag means, and it lets the target's data layout place the parts. The debug table can still describe the lowered structure as a tagged union with its cases, so a debugger shows the source type (see [ir/debug.md](ir/debug.md)).


## 3. Values and constants

The IR is in SSA form. A value is defined exactly once, by a block parameter, by an instruction result or by a constant, and it has one type. Every use of a value is dominated by its definition.

A value is **secret** or public. See section 7.

A **constant** is typed and owned by its module. It is one of

- an integer, given as its bits in 64-bit words, low word first, with the bits above the width zero,
- a float, given as the bits of its encoding in the same way,
- `zero`, every bit of a type zero,
- an aggregate of constants, one per member, element or lane, in order,
- an address, which is a function or global plus a signed byte offset, of a pointer type.

An aggregate holds other constants, so an initial value can hold the addresses of globals and functions at any depth. An instruction uses a constant through a value. A function has one value for each constant it uses, the same one each time. A constant is always public.

Values and blocks may carry a name for the text form. A name carries no meaning, and the printer makes names unique within a function.


## 4. Control flow

A body is a graph of **blocks**. A block declares **parameters** and holds a list of instructions that ends in exactly one **terminator**. There are no phi instructions. Every edge into a block passes one argument per parameter of the block, in order, and each argument has the type of its parameter. A terminator names its targets and their arguments. The entry block's parameters are the function's parameters, in number and type.

The terminators are `br` (one target), `cbr` (two targets, taken on a condition of 1 and 0), `ret` and `unreachable`.

Any graph shape is allowed, including loops with several entries and blocks with several exits. A target that needs structured control flow gets its structure from the structurizer, so a front end never structures its control flow. Blocks and instructions that are removed from a body keep their ids but are erased, and they take no part in the module.

Every use in a block that can be reached from the entry is dominated by its definition. A use in a block that cannot be reached is not checked.


## 5. Instructions

An instruction is an opcode applied to operands, immediates and edges, with results and a metadata record.

- **operands** are values. A row states its fixed operands and, for some, a tail of any number of further operands such as the arguments of a call.
- **immediates** are facts of the instruction that are not values, such as a type, an alignment, a memory ordering or a lane index. A row states one per slot, in order.
- **edges** pair a target block with its arguments.
- **results** are the values the instruction defines, in order. A row derives their types.
- the **metadata record** holds the source location the instruction was built for, the inlining site it was inlined through, its flags (`volatile`), its secrecy mark and its debug bindings.

An instruction's typing, effects and secrecy are its opcode's row in the opcode table. The table is data, and the verifier, the printer, the parser, the folder and every pass read the same row. The reference in [ir/opcodes.md](ir/opcodes.md) is written from the table, so it states for every opcode its operands, immediates, targets, typing rules, result types, effects, secrecy rule and vector class.

### 5.1 Typing rules

One checker, `mirl.ir.opcode.check`, types an instance of a row by interpreting its rules. A rule speaks of **subjects**, which are the type of a fixed operand or the type held by a type immediate, and of **classes**, which are sets of types. The reference writes each rule as a sentence. The vocabulary is

- a subject is in a class: any type, an integer, an integer of a given width, a float, a pointer, a function type, an integer of a whole number of bytes, a vector, or a scalar (an integer, a float or a pointer),
- two subjects are the same type,
- both subjects are scalars, or both are vectors of the same lane count,
- the lane types of two subjects are the same, a scalar being its own lane,
- one subject has more bits than another, or the same number of bits. Bits are counted from the type table and the number format table alone, never a data layout, so only integers, floats and vectors of them have a bit width,
- the tail operands are the parameters of a function type, the results of the function the instruction is in, or the lanes of a vector type,
- a lane index is below the lane count of the vectors it indexes, and a lane list has one index per lane of the result,
- a memory ordering immediate is among those allowed.

Each result is derived from a subject. It has the subject's type, or it is an `i1` (or a vector of `i1` with the subject's lanes) for a comparison or flag, or it is the lane type of a vector, or the list of results of a function type.

### 5.2 Vector classes

A row's vector class says how it applies to vectors.

- **lanewise**: it applies lane by lane, and its classes speak of the lanes. `add` over `vec<4, i32>` adds four pairs of lanes.
- **across**: it takes one vector as a whole and gives a scalar, and its classes speak of the lanes of that vector. These are the reductions.
- **none**: it takes no vector as a lane operation. Vector construction and lane access are opcodes of this class and state their types through their immediates.

### 5.3 Effects

A row states what executing an instance may do beyond giving its results.

- the **traps** it may take, each a defined trap on every target (see section 6.1),
- whether it **reads** or **writes** memory,
- whether it is **speculatable**, so that it may run where its result is not needed. A speculatable row never traps, reads or writes.
- whether it is **mergeable**, so that two instances with the same operands give the same results and one may stand for both. A mergeable row never writes. A row with a memory ordering is never speculatable or mergeable.


## 6. Semantics

This section states what every opcode does. The generated reference states how each is typed. Where this section says that something traps, it is a **defined trap** that is the same on every target. Execution stops at the instruction and no later effect happens.

### 6.1 Traps

The traps are

- integer division or remainder by zero, in any lane,
- signed division or remainder of the least value of the type by minus one (all ones), in any lane,
- a load, store, atomic access, `mem.copy` or `mem.fill` through an address that cannot be accessed,
- a call whose callee traps,
- `unreachable`, which traps every time it is executed.

Nothing else traps. In particular integer addition, subtraction, multiplication and shifts wrap or saturate as stated below, and float arithmetic never traps.

### 6.2 Integers

Integer arithmetic wraps. `add`, `sub` and `mul` give the low bits of the exact result, and `mul` gives the low half of the product. `neg` is the two's complement negation and `not` flips every bit.

`div.s` rounds toward zero and `rem.s` has the sign of the dividend. `div.u` and `rem.u` read their operands as unsigned. Division and remainder by zero trap. Signed division and remainder of the least value by minus one trap as well.

A shift takes its count as an unsigned integer of the same type as the shifted operand. A shift by the width or more gives 0 for `shl` and `shr.u`, and for `shr.s` it gives every bit equal to the sign bit of the shifted operand.

`and`, `or` and `xor` are bitwise. The comparisons `eq`, `ne` and the signed and unsigned orderings give an `i1`, or a vector of `i1` for vector operands.

`popcnt` counts one bits and `bswap` reverses the bytes of an integer whose width is a whole number of bytes. `clz` and `ctz` count leading and trailing zero bits, and both give the width of the operand when it is zero.

The overflow-checked rows (`add.ov.s`, `add.ov.u`, `sub.ov.s`, `sub.ov.u`, `mul.ov.s`, `mul.ov.u`) give two results, the wrapped value and an `i1` that is 1 when the exact result does not fit the type under the signedness the opcode states.

`select` gives its `then` operand where the condition is 1 and its `else` operand where it is 0. For vectors the condition is a vector of `i1`, chosen lane by lane.

### 6.3 Conversions

`ext.u` fills the new high bits with zeros and `ext.s` with the sign bit. `trunc` keeps the low bits. Each takes the target type as an immediate and the operand and target are both scalars or both vectors of the same lane count.

`bitcast` gives the same bits as the stated type of the same bit width. It applies to integers, floats and vectors of them, since only those have a bit width in the type table.

`ptrtoint` gives a pointer's address as an integer of the stated width, and `inttoptr` gives an integer as a pointer to that address.

`itof.s` and `itof.u` round to nearest even. `ftoi.s` and `ftoi.u` round toward zero, saturate at the range of the integer type and give 0 for a not-a-number. `fpromote` converts to a wider format exactly and `fdemote` converts to a narrower one rounding to nearest even.

### 6.4 Floats

Float arithmetic is done in the operands' number format with that format's default rounding, which is to nearest with ties to even. It never traps. An invalid operation, an overflow or a division by zero gives the result the format gives, such as a not-a-number or an infinity.

A not-a-number that float arithmetic gives has an unspecified sign and payload, and only its being a not-a-number is defined. Operations that act on bits keep every bit exactly. These are `fneg`, `fabs`, `fcopysign`, `bitcast`, and loads and stores of floats.

The ordered comparisons (`feq.o`, `fne.o`, `flt.o`, `fle.o`, `fgt.o`, `fge.o`) are false when either operand is a not-a-number, and `ford` is true when neither is. The unordered comparisons (`feq.u` and the rest of that family) are true when either operand is a not-a-number, and `funo` is true when either is.

`fmin` and `fmax` give a not-a-number when either operand is one, and order negative zero below positive zero. `fminnum` and `fmaxnum` give the other operand when exactly one operand is a not-a-number. `frem` has the sign of the dividend. `fma` computes first times second plus third with one rounding. `ffloor`, `fceil`, `fint` and `fnearest` round toward negative infinity, toward positive infinity, toward zero and to nearest with ties to even.

### 6.5 Memory

`load` reads a value of the stated type from an address, `store` writes one, and each states the alignment the access may assume as an immediate. An alignment is a power of two. `alloca` gives the address of a stack slot of the stated type and alignment. `ptr.add` adds an integer byte count to an address.

`mem.copy` copies a byte count between two addresses, and the ranges may overlap. `mem.fill` sets a byte count at an address to one byte value.

A `volatile` flag on an instruction makes its memory access observable. It is never merged, moved or removed.

An atomic access is over integers only. `atomic.load` and `atomic.store` access an integer of the stated type. The read-modify-write opcodes (`atomic.add`, `atomic.sub`, `atomic.and`, `atomic.or`, `atomic.xor`, `atomic.nand`, `atomic.xchg`, `atomic.smax`, `atomic.smin`, `atomic.umax`, `atomic.umin`) give the value held before the update. `atomic.cmpxchg` gives the value held before and an `i1` that is 1 when the exchange happened. Each states its ordering as an immediate. A load may be `relaxed`, `acquire` or `seq_cst`. A store may be `relaxed`, `release` or `seq_cst`. A read-modify-write may state any ordering, and the failure ordering of a compare and exchange is a load ordering. `fence` states `acquire`, `release`, `acq_rel` or `seq_cst`.

### 6.6 Vectors

`vsplat` repeats a scalar into every lane of the stated vector type. `vbuild` builds a vector from one scalar per lane. `vextract` reads one lane and `vinsert` replaces one, each with a constant lane index immediate. `vshuffle` picks lanes of the two operands joined, by a lane list immediate with one index per lane of the result.

The reductions take one vector and give a scalar of its lane type. The integer reductions (`reduce.add`, `reduce.mul`, `reduce.and`, `reduce.or`, `reduce.xor` and the signed and unsigned minimum and maximum) are exact. A float reduction states its order. A **sequential** reduction (`reduce.fadd.seq`, `reduce.fmul.seq`) combines the lanes one after another from the first, so the result is exactly the one that order gives. A **reassociable** reduction (`reduce.fadd.any`, `reduce.fmul.any`) combines the lanes in any order and grouping, so the result is any one such an order gives. The minimum and maximum reductions combine as `fmin`, `fmax`, `fminnum` and `fmaxnum` do.

### 6.7 Calls and returns

`call` takes the callee's address, the arguments and an immediate stating the signature called through. Its results are the signature's results. `ret` takes the results of the function it is in. How arguments and results are passed is not in the IR. It is decided from the function type and the target (see [ir/target.md](ir/target.md)).


## 7. Secrecy

A value may be marked **secret**. Secrecy is stated once for each value and only moves in one direction.

- A block parameter is secret as it is declared.
- A constant is public.
- An instruction result is secret as its row's secrecy rule gives. **Propagates** means a result is secret when any operand is. **Declared** means a result is secret when the instruction's own secrecy mark is set, which is how a front end marks a value read from secret memory, returned by a call or given by an atomic access. **Declassifies** means every result is public. **None** means the row has no results.
- `declassify` is the only operation that removes secrecy. It gives its operand's value as a public value.

The library refuses the edits that would make a secret value public by a path other than `declassify`.

- A branch argument that is secret is refused for a parameter that is public. This applies when an instruction is built, when an edge is retargeted and when a block parameter is added with its incoming arguments.
- `replace`, which moves every use of a value to another value, refuses a secret replacement for a public value.
- `supplant`, which puts one instruction in the place of another, refuses a result that is secret where the one it replaces gave a public result.

An edit that replaces an instruction's metadata record whole is not refused, and the verifier holds what the edits do not, as a rule (see section 8). It reads the secrecy mark again, so a mark that no longer matches the stored results is refused. Every result must be secret exactly as its row's secrecy rule gives, and no edge may pass a secret value to a public parameter.

### 7.1 Constant time

A function that is constant time must have no secret-dependent branch, no secret-dependent address, and no operation whose latency depends on its operands. The IR carries what that check needs, which is the secrecy of every value and the metadata of every instruction. The target states which operations are constant time through its timing declaration. A row of it names an operation (`multiply`, `multiply_high`, `divide` or `shift`), an operand width and a condition, which is either always or the presence of a named extension such as RISC-V's `zkt`. A target that states no row for an operation does not guarantee it.

The check itself belongs to `mirl.ct`. This version of the library does not implement it and does not yet give a function a constant-time marker, so the IR neither marks a function constant time nor refuses a target that cannot meet the requirement.


## 8. The verifier

The verifier checks a module against the target it names. `mirl.verify.check(m)` finds the target among the target rows by the module's target name, and `mirl.verify.against(m, t)` checks against a given target. Both give ok, or the first rule the module breaks, or the allocator's refusal, which is never an answer of valid.

A refusal is a defect in the producer that made the module and never a diagnostic about the program the module was made from. It names the rule, where the module breaks it (function, block, instruction, global, constant or type, whichever apply) and a short description of the fact that does not hold.

The rules are a table. Each is a row with an id, a short name and a check over the whole module. They run in order and a later rule reads only what the earlier ones hold. The id is the rule's position in the table. The rules are

| id | rule | what it holds |
|---|---|---|
| 0 | `target` | the module names a target among the rows of `mirl.target` that declares every fact the pipeline reads, and the target's name is the module's |
| 1 | `width` | every integer type in the type table has a legal width, which is 1 or a power of two from 8 to 512 |
| 2 | `layout` | every structure that states its offsets states ones the target's data layout keeps, none overlapping and each a multiple of its member's alignment |
| 3 | `constant` | every constant is of its type, an aggregate has one element per member and an address names a function or global of the module |
| 4 | `initial` | every global's initial value is a constant of the global's type |
| 5 | `attribute` | every attribute on a function or global is of a family the target accepts |
| 6 | `reference` | every id a block or instruction names is one its body holds and has not removed, every instruction is listed in exactly one block and placed in it, every operand and branch argument is defined, every result and parameter is defined by the instruction or block that lists it, and every opcode names a row |
| 7 | `terminator` | every block ends in exactly one terminator, with none before it |
| 8 | `edge` | every edge passes its target's parameters in count and type, and the entry block takes the signature's parameters |
| 9 | `typing` | every instruction is an instance its opcode's row types, and its results are the number and types the row derives |
| 10 | `secrecy` | every result is secret exactly as its row's secrecy rule gives, and no edge passes a secret value to a public parameter |
| 11 | `dominance` | every use in a reached block is dominated by its definition, and so is every branch argument at its edge |
| 12 | `debug` | every location, inlining site and binding that an instruction's metadata names is an entry of the debug table |

A front end that gets one of these refusals reads its id here and looks at the rule's row in the table. Rule 9 reports that the opcode's row refuses the instance but not which of its typing rules failed. The checker, `mirl.ir.opcode.check`, gives that, and a front end can call it on the same instance for the precise error.


## 9. Inline assembly items

An inline assembly item is an opaque block of target assembly. masc, the assembler, parses it. It carries operand constraints, which say which values go in and out and in what kind of register or memory, and effects, which say what it reads, writes and clobbers. mirl treats the block as opaque, keeps its operands as ordinary values and effects as ordinary effects, and masc encodes it after register allocation.

The text form reserves the word `asm` for these items, and spells their block through masc's text form. This version of the library has no inline assembly item in the module, in the verifier or in the builder. The slot is reserved, and a front end that needs one today has none to build.


## 10. Where the rest is

- the opcode reference, [ir/opcodes.md](ir/opcodes.md)
- the text form and its grammar, [ir/text.md](ir/text.md)
- the constant folder, [ir/fold.md](ir/fold.md)
- targets, data layout, argument passing and attributes, [ir/target.md](ir/target.md)
- the debug table, [ir/debug.md](ir/debug.md)
