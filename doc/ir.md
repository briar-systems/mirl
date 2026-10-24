# mirl IR specification

This is the specification of mirl IR, the contract between a front end and mirl. A front end author who is not the author of mach should be able to produce valid IR from this document and the library alone. It describes the library as built. Where the library and this text disagree, one of them is wrong and gets fixed.

The specification is split by subject.

| document | subject |
|---|---|
| this file | the model, types, values, control flow, semantics, secrecy, the verifier's rules, inline assembly and target ops |
| [ir/opcodes.md](ir/opcodes.md) | the opcode reference, generated from the opcode table |
| [ir/text.md](ir/text.md) | the text form, its grammar and its version |
| [ir/fold.md](ir/fold.md) | the constant folder |
| [ir/target.md](ir/target.md) | targets, capabilities, data layout and attributes |
| [ir/debug.md](ir/debug.md) | the debug table |
| [machine/select.md](machine/select.md) | instruction selection into the machine form: the table, the rule tie-break and the class of a type |

Names in code style such as `mirl.verify.against` are modules and functions of the library. The library is reached through its `mirl.*` modules, and the aggregate module `mirl` re-exports all of them.


## 1. The model

A **module** is one unit of code. It names the **target** it is built for and holds a type table, functions, globals, constants, a debug table, a list of exported symbols and the attributes attached to its functions and globals. A module holds no layout of its own. Every size, alignment and member offset comes from the target's data layout (see [ir/target.md](ir/target.md)).

A module may state the **source language** its code was written in, a name and the code a debug producer writes for it (`mirl.ir.language.Language`), which its front end gives with `mirl.ir.module.state_language` after making it. mirl states rows for the languages it knows (`mach` and `c`), and a front end may state one of its own. The language changes nothing the IR means. A debug producer reads it to tell a debugger whose rules to read the source by (see [ir/debug.md](ir/debug.md)), and a module that states none is described as of no stated language.

A **function** or **global** is a **symbol**. Its symbol name is unique within its module and names it in every module. Every symbol has a **linkage** (`mirl.ir.linkage.Linkage`): a binding, which says how far other objects see it, and a visibility, which says how far other images see it. Both are rows of the symbol model of mink, the linker, which owns them, and are spelled in text by those rows' names (`local`, `global`, `weak`, `unique` and `default`, `protected`, `hidden`, `internal`). A symbol another module defines has a binding other objects may refer to, so never `local`. Whether a symbol is **preemptible**, so that it may resolve to a definition in another image at load, follows from its linkage and from what the code is built as. A `local` symbol resolves in its object and a `hidden` or `internal` one in its image. An executable keeps every symbol it defines, and a shared object may have one of `default` visibility preempted. A symbol another module defines may be in another image unless it is `hidden` or `internal`. Code reaches a preemptible symbol through the global offset table (see [ir/target.md](ir/target.md)). Emission gives each symbol of the object the binding and visibility its linkage states. A global has a type, an optional initial value, an optional alignment, an optional section and an optional thread-local model, and may be `constant`, which states that the program never writes it. A global with no initial value is defined by another module. A section a global states is a name and a kind, a row of mink's section kinds (`text`, `rodata`, `relro`, `data`, `bss`, `tdata`, `tbss` and the rest). A global that states none is placed by its facts (`mirl.target.address.placement`): a thread-local one in thread-local data, zero filled when its initial value is every bit zero and it is not constant, a constant one in read-only data, or in data read-only once relocated when the loader relocates its initial value, and any other in data, zero filled when its initial value is every bit zero. The loader relocates an initial value that holds an address under `pie` and `pic`, whether the symbol is preemptible or not, and never under `static`.

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

A pointer is opaque. It names an address space by number, and space 0 is the default. A pointer has no pointee type. What is read or written through it is stated by the instruction that does so. Which spaces exist, how a pointer into each is held and the rules the types in each are laid out by are declared by the target. A space with no row is refused, and a pointer into a logical space has no representation in memory.

### 2.4 Vectors

A vector has a lane count of at least one and a lane type. Opcodes decide which lane types they accept.

### 2.5 Arrays, structures and unions

An array has an element count and an element type, and may state its **stride**, the bytes from one element to the next. An array that states none has its elements placed by the rules of the address space it is laid out in, and the target's layout refuses a stated stride that is shorter than the element or that the array's alignment does not divide.

A structure is an ordered list of member types. It has no layout of its own. The target's data layout places the members. A structure may state the byte offset of every member, all or none, and the target's layout refuses stated offsets that overlap or do not keep a member's alignment.

A union is a list of member types that overlap in storage. Every member is at offset 0.

### 2.6 Function types

A function type has a list of parameter types and a list of result types. A function may have any number of results. A pointer to a function is an ordinary pointer, and a call states the signature it calls through.

The integers are signless, but a convention extends a narrow integer by the signedness of the source type. Each parameter and each result of a function type may therefore state an **extension**: `sext` for sign extended, `zext` for zero extended, or none. Only an integer may state one. The extensions are part of the type, so `fun(i8 sext) -> ()` and `fun(i8 zext) -> ()` are different types, and a function and the call that states a signature carry them as data of that one type. The debug information keeps the signedness of its own types and is not derived from the extension.

A function type may also name the **convention** row it is called under, after its results: `fun(i64) -> () convention sve`. A function of that type is entered and returned from under the row, and a call that states the type is made under it. The name is part of the type, so `fun() -> ()` and `fun() -> () convention sve` are different types. A type that names none is under the row of the convention its target's tuple names, which is the target's own and not a default of mirl's. A type may name any other convention of the architecture whose row's requirements hold over the baseline, and the verifier refuses a name the target states no row of.

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

An aggregate holds other constants, so an initial value can hold the addresses of globals and functions at any depth. An instruction uses a constant through a value. In code, an address constant names a global, or names a function only as a call's callee, which is the function the call calls rather than an address value. Code takes a function's address only with `func.addr`, so a target whose function addresses are not data addresses selects them apart. A function has one value for each constant it uses, the same one each time. A constant is always public.

Values and blocks may carry a name for the text form. A name carries no meaning, and the printer makes names unique within a function.


## 4. Control flow

A body is a graph of **blocks**. A block declares **parameters** and holds a list of instructions that ends in exactly one **terminator**. There are no phi instructions. Every edge into a block passes one argument per parameter of the block, in order, and each argument has the type of its parameter. A terminator names its targets and their arguments. The entry block's parameters are the function's parameters, in number and type.

The terminators are `br` (one target), `cbr` (two targets, taken on a condition of 1 and 0), `switch`, `ret` and `unreachable`.

`switch` branches on an integer selector of at most 64 bits. Its case list holds one value per target after the first, in strictly increasing order, each the selector's bits read unsigned, and it goes to the target after the first whose case is the selector's value, or to the first target when no case is. A target may be named by more than one edge. A target whose control is free has it lowered to a compare chain by legalisation, or, where the target's table density admits its case list, to an indexed `switch` its selection branches through a jump table for, and a structured target keeps it whole for its own multi-way branch, SPIR-V's `OpSwitch` and WebAssembly's `br_table` (see [ir/target.md](ir/target.md)).

Any graph shape is allowed, including loops with several entries and blocks with several exits. A target that needs structured control flow gets its structure from the structurizer, so a front end never structures its control flow. Blocks and instructions that are removed from a body keep their ids but are erased, and they take no part in the module.

Every use in a block that can be reached from the entry is dominated by its definition. A use in a block that cannot be reached is not checked.


## 5. Instructions

An instruction is an opcode applied to operands, immediates and edges, with results and a metadata record.

- **operands** are values. A row states its fixed operands and, for some, a tail of any number of further operands such as the arguments of a call.
- **immediates** are facts of the instruction that are not values, such as a type, an alignment, a memory ordering or a lane index. A row states one per slot, in order.
- **edges** pair a target block with its arguments.
- **results** are the values the instruction defines, in order. A row derives their types.
- the **metadata record** holds the source location the instruction was built for, the inlining site it was inlined through, its flags (`volatile`, `kept`, `bounded` and `checked`), its secrecy mark and the debug bindings of the variables whose storage its result addresses.

A variable's value is bound by a **value binding record** at a program point of a block, before an instruction or at the block's entry. A record is not an instruction and no instruction walk sees it. It reads a value and a salvage expression over it, or nothing when what it read is gone, and reading a value is never a use of it (see [ir/debug.md](ir/debug.md)).

An instruction's typing, effects and secrecy are its opcode's row in the opcode table. The table is data, and the verifier, the printer, the parser, the folder and every pass read the same row. A target family may own rows of the table, which only a target that family serves admits (see [ir/target.md](ir/target.md)). The reference in [ir/opcodes.md](ir/opcodes.md) is written from the table, so it states for every opcode its operands, immediates, targets, typing rules, result types, effects, secrecy rule and vector class.

### 5.1 Typing rules

One checker, `mirl.ir.opcode.check`, types an instance of a row by interpreting its rules. A rule speaks of **subjects**, which are the type of a fixed operand or the type held by a type immediate, and of **classes**, which are sets of types. The reference writes each rule as a sentence. The vocabulary is

- a subject is in a class: any type, an integer, an integer of a given width, a float, a pointer, a function type, an integer of a whole number of bytes, a vector, a scalar (an integer, a float or a pointer), a structure, an array, or an aggregate (a structure or an array),
- two subjects are the same type,
- both subjects are scalars, or both are vectors of the same lane count,
- the lane types of two subjects are the same, a scalar being its own lane,
- one subject has more bits than another, or the same number of bits. Bits are counted from the type table and the number format table alone, never a data layout, so only integers, floats and vectors of them have a bit width,
- the tail operands are the parameters of a function type, the results of the function the instruction is in, or the lanes of a vector type,
- a lane index is below the lane count of the vectors it indexes, and a lane list has one index per lane of the result,
- a memory ordering immediate is among those allowed,
- a member index names a member of an aggregate, below a structure's member count or an array's element count, and a subject is the type of that member,
- a case list holds one value per target after the first, in strictly increasing order, each within the width of a selector of at most 64 bits.

Each result is derived from a subject. It has the subject's type, or it is an `i1` (or a vector of `i1` with the subject's lanes) for a comparison or flag, or it is the lane type of a vector, or the list of results of a function type, or the type of a member of an aggregate.

### 5.2 Vector classes

A row's vector class says how it applies to vectors.

- **lanewise**: it applies lane by lane, and its classes speak of the lanes. `add` over `vec<4, i32>` adds four pairs of lanes.
- **across**: it takes one vector as a whole and gives a scalar, and its classes speak of the lanes of that vector. These are the reductions.
- **none**: it takes no vector as a lane operation. Vector construction and lane access are opcodes of this class and state their types through their immediates.

### 5.3 Address formation

A row states how it forms an address. Most form none. `ptr.add`, `ptrtoint` and `inttoptr` form or read one as a number, which only physical addressing gives meaning, so the verifier refuses them past legalisation on a target whose addressing is logical. `ptr.member` and `ptr.index` form one from the type they walk: the address of a member of a structure or of an element of an array, at the address they take. A target whose addressing is physical folds them to a `ptr.add` of the byte offset its data layout gives, and one whose addressing is logical keeps them, as SPIR-V's access chains reach memory. `func.addr` forms the address of the function its immediate names, and is the only way code names one.

### 5.4 Effects

A row states what executing an instance may do beyond giving its results.

- the **traps** it may take, each a defined trap on every target (see section 6.1),
- whether it **reads** or **writes** memory,
- whether it is **speculatable**, so that it may run where its result is not needed. A speculatable row never traps, reads or writes.
- whether it is **mergeable**, so that two instances with the same operands give the same results and one may stand for both. A mergeable row never writes. A row with a memory ordering is never speculatable or mergeable.
- whether it is **keepable**, so that an instance may carry the `kept` flag (see section 6.5). A keepable row writes memory, never reads it, is not mergeable and has no memory ordering. The keepable rows are `store` and `mem.fill`.


## 6. Semantics

This section states what every opcode does. The generated reference states how each is typed. Where this section says that something traps, it is a **defined trap** that is the same on every target. Execution stops at the instruction and no later effect happens.

### 6.1 Traps

The traps are

- integer division or remainder by zero, in any lane,
- signed division or remainder of the least value of the type by minus one (all ones), in any lane,
- a division of a two-word dividend by a word divisor whose quotient does not fit the word, in any lane,
- a load, store, atomic access, `mem.copy` or `mem.fill` through an address that cannot be accessed,
- a call whose callee traps,
- `unreachable`, which traps every time it is executed.

Nothing else traps. In particular integer addition, subtraction, multiplication and shifts wrap or saturate as stated below, and float arithmetic never traps.

### 6.2 Integers

Integer arithmetic wraps. `add`, `sub` and `mul` give the low bits of the exact result, and `mul` gives the low half of the product. `neg` is the two's complement negation and `not` flips every bit.

`mul.high.u`, `mul.high.s` and `mul.high.su` give the high half of the exact product of their two operands, the bits from the width up, which `mul` leaves out. `mul.high.u` reads both operands as unsigned, `mul.high.s` both as signed, and `mul.high.su` its first as signed and its second as unsigned. None traps. A target computes one in one instruction at the widths whose multiply forms it states, `mulhu`, `mulh` and `mulhsu` on RISC-V, and the multiply forms legalisation builds it from the multiplies a target has at the others.

`div.s` rounds toward zero and `rem.s` has the sign of the dividend. `div.u` and `rem.u` read their operands as unsigned. Division and remainder by zero trap. Signed division and remainder of the least value by minus one trap as well.

`div.wide.u` divides a dividend of two words, its `high` and `low` operands, by a `divisor` of the same type, all read as unsigned, and gives two results of that type, the quotient and the remainder. It traps for a zero divisor, and for a high word no less than the divisor, which is exactly when the quotient does not fit the word. It is the division a machine such as x86-64 runs on `rdx:rax`, and a target that has no such instruction at a width has it lowered by the helpers legalisation.

A `checked` flag on a division or remainder says its zero divisor and, for a signed one, its least value over minus one, or for `div.wide.u` its quotient that does not fit, are tested before it and trap there, so it never meets them and a machine division that gives a result for them runs it as it stands. Only a row with a zero, overflow or quotient trap takes it. The helpers legalisation sets it where it puts the tests, and where a constant operand rules out every trap the target's division does not take, and reads it so it never tests a division twice. Selection takes a division without it only on a target whose division traps for every trap its row states, so every pass after the helpers legalisation that makes or rewrites a division keeps the flag of the one it replaces or tests it again.

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

`load` reads a value of the stated type from an address, `store` writes one, and each states the alignment the access may assume as an immediate. An alignment is a power of two. `alloca` gives the address of a stack slot of the stated type and alignment. The pointer type it states is into the target's slot space (`mirl.target.record.slot_space`), which the target declares and is not always the default space: SPIR-V's is the Function storage class, and the verifier refuses an `alloca` whose pointer is into another. `ptr.add` adds an integer byte count to an address.

`ptr.member` gives the address of a member of the structure at an address, the structure's type and the member's index stated as immediates. `ptr.index` gives the address of an element of the array at an address, the array's type stated and the element's index an integer operand read as signed. Neither reads memory, and neither checks the index against the array's count, so an index past it gives an address past the array as `ptr.add` would. The address is in the space of the one each takes.

The memory of a stack slot holds no defined value until it is stored to, and it is not zero. A `load` that no store reaches gives an unspecified value of the stated type: any bit pattern, the same one on every read until the next store, and never poison, so nothing after it is undefined. The verifier does not refuse it, since whether a store reaches it depends on the path taken. A front end that wants a zero stores one. A pass may choose any value for it, and the promotion of stack slots chooses a zero of the type.

`mem.copy` copies a byte count between two addresses, and the ranges may overlap. `mem.fill` sets a byte count at an address to one byte value.

A `volatile` flag on an instruction makes its memory access observable. It is never merged, moved or removed.

A `bounded` flag on a shift says its count is below its operand's width, so a machine shift that takes the count modulo the width gives the result the shift states. Only a row with a shift by the width or more rule takes it. The shift bounding legalisation sets it and recomputes it from scratch on every run, and selection reads it to emit the plain instruction.

A `kept` flag on a store or a fill makes its write a fixed fact. It is how a front end wipes memory that held a secret. The mark is a fact of the instruction, stated once in its metadata record, and every pass reads it from there. The one checker refuses it on an instance of a row that is not keepable, so the builder never makes such an instruction and the verifier's typing rule refuses one.

- No pass removes a kept write, narrows it, merges it with another write or forwards its value away, even when the memory is dead afterwards, as on a slot about to leave scope or a buffer about to be freed. Dead store removal, stack promotion, scalar replacement, load forwarding and store merging all hold it fixed. Stack promotion refuses a slot that a kept write stores into, so the write stays.
- Kept writes keep their order relative to each other.
- A kept write's length and timing depend on its size alone, never on the bytes it writes, so the bytes may be secret and the write is compatible with constant time.
- Kept is not volatile. It does not stop unrelated memory operations from moving around it, and it never makes the access observable to anything other than memory.
- `set_metadata` may set the mark and refuses to take it off, and `supplant` refuses to put an instruction without the mark in the place of one with it. `erase` and `remove_dead` refuse a placed kept instruction, so no pass can take one away alone. Every edit and copy that moves or copies an instruction carries its metadata record whole, so the mark goes with it. A kept write goes only with a set of blocks no edge from outside enters and that does not hold the entry, through `erase_unreached`, since it can never run there. The undo of an edit (`rewind`, `restore`) puts back what was, and is no removal.

Legalisation and emission inherit an obligation for a kept fill. It is never lowered to a call of an external or preemptible symbol, such as a library `memset` that the linker may resolve to anything, including a routine an optimiser later folds away. A kept fill is either expanded inline into kept stores, or it calls a helper that mirl emits itself, local to the module, whose own stores are kept. This holds for a fill whose length is known only at run time as much as for a constant one. Any rewrite of a kept store into other stores, such as a split of a wide store, marks every store it makes kept.

An atomic access is over integers only. `atomic.load` and `atomic.store` access an integer of the stated type. The read-modify-write opcodes (`atomic.add`, `atomic.sub`, `atomic.and`, `atomic.or`, `atomic.xor`, `atomic.nand`, `atomic.xchg`, `atomic.smax`, `atomic.smin`, `atomic.umax`, `atomic.umin`) give the value held before the update. `atomic.cmpxchg` gives the value held before and an `i1` that is 1 when the exchange happened. Each states its ordering as an immediate. A load may be `relaxed`, `acquire` or `seq_cst`. A store may be `relaxed`, `release` or `seq_cst`. A read-modify-write may state any ordering, and the failure ordering of a compare and exchange is a load ordering. `fence` states `acquire`, `release`, `acq_rel` or `seq_cst`.

### 6.6 Vectors

`vsplat` repeats a scalar into every lane of the stated vector type. `vbuild` builds a vector from one scalar per lane. `vextract` reads one lane and `vinsert` replaces one, each with a constant lane index immediate. `vshuffle` picks lanes of the two operands joined, by a lane list immediate with one index per lane of the result.

The reductions take one vector and give a scalar of its lane type. The integer reductions (`reduce.add`, `reduce.mul`, `reduce.and`, `reduce.or`, `reduce.xor` and the signed and unsigned minimum and maximum) are exact. A float reduction states its order. A **sequential** reduction (`reduce.fadd.seq`, `reduce.fmul.seq`) combines the lanes one after another from the first, so the result is exactly the one that order gives. A **reassociable** reduction (`reduce.fadd.any`, `reduce.fmul.any`) combines the lanes in any order and grouping, so the result is any one such an order gives. A sequential reduction becomes the reassociable one only where the build permits float reassociation ([target.md](ir/target.md), Float relaxations). The minimum and maximum reductions combine as `fmin`, `fmax`, `fminnum` and `fmaxnum` do.

### 6.7 Aggregates

`extract` gives one member of a structure value or one element of an array value, by a constant index immediate, and `insert` gives the aggregate with that member replaced by a value of the member's type. They take an aggregate whole, so a target that holds aggregate values in no register has them taken apart before selection.

### 6.8 Calls and returns

`func.addr` gives the address of a function of the module, at the pointer type it states. What that address is comes from the target's `functions` declaration: a location as a data address is, or a slot of an indirect call table that only equality and an indirect call read. A target whose code has no function addresses, as logical SPIR-V has none, declares `none`, and the verifier refuses `func.addr` there. A direct call is unaffected, since its callee names the function it calls rather than an address value (see [ir/target.md](ir/target.md)).

`call` takes the callee, the arguments and an immediate stating the signature called through. A direct call names the function it calls as its callee, by the address constant of that function, and an indirect call takes a value, such as one `func.addr` gave. Its results are the signature's results. `ret` takes the results of the function it is in. How arguments and results are passed is not in the IR. It is decided from the function type and the target (see [ir/target.md](ir/target.md)).


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
- `set_metadata`, which replaces an instruction's metadata record whole, may raise the secrecy mark and refuses to lower it on any instruction, with or without results, so a mark never drifts from what was declared through this edit.

Folding never produces a public value from a secret computation. An instruction that is secret by declaration or by its operands, or whose fold the folder marks secret, stays in place, since a constant of a module is public.

The verifier states the same facts as a rule (see section 8). Every result must be secret exactly as its row's secrecy rule gives, and no edge may pass a secret value to a public parameter.

### 7.1 Constant time

A function that is constant time must have no secret-dependent branch, no secret-dependent address, and no operation whose latency depends on its operands. The IR carries what that check needs, which is the secrecy of every value and the metadata of every instruction. Which instructions run in constant time is masc's to state, and mirl states none of it. Each row of masc's instruction set has a constant-time class, which says the inputs its timing depends on, under a condition over the selection and the state axes such as RISC-V's `zkt`, and each set states whether it classifies its rows' timing at all.

A function requires constant time when its declaration says so. `FunctionData` has a `constant_time` flag, set when the function is declared and read by every pass. The text form writes it as `constant_time` after the function's type (see [ir/text.md](ir/text.md)).

Every pass declares whether it keeps the requirement. A pass that may branch on a value or otherwise change how long the code takes declares that it breaks it, and that is the default. The pass driver in `mirl.pass` never gives such a pass a function that requires constant time, so the pass needs no check of its own. A module pass asks the driver's `touches` before it rewrites a function.

The check asks masc through `mirl.ct`. The machine form's question of an instruction is `latency`, the refusal of a secret in one of its inputs, read from its row's class under the context the function runs under. `check` walks a function's encoded bytes with masc's walk (`masc.walk.walk.check`) under that context, from the secrets the caller seeds it with, and answers by the set's timing through `masc.core.ct.required`:

- A set that classifies its rows, as RISC-V, holds the requirement for code its walk clears, and refuses a secret the walk finds where the code may hold none.
- A set whose timing is not guaranteed, as wasm, compiles the code with masc's one warning (`masc.core.ct.UNGUARANTEED`), which states no guarantee. Its walk still refuses a secret that decides a branch or forms an address. The walk reads wasm code under a context whose stream is entered into the function the code is the body of, and code it cannot follow compiles with the warning as not verified, its discipline kept by mirl's own passes.
- A set that classifies no timing, as SPIR-V, refuses the requirement with masc's one refusal record and wording.

Both of masc's questions are asked under the build's context with the timing modes the guarantee assumes set, in one place, `mirl.ct.assumed` (mach#3872, "The guarantee"): `dit=on` on AArch64, where std sets PSTATE.DIT wherever the CPU has it, and `doitm=on` on x86-64, the data operand independent timing mode. On x86-64 only the operating system sets DOITM, and an AArch64 CPU without FEAT_DIT has no DIT, so on a system that does not set the mode the code still runs, without the guarantee the mode gives.

masc classes each x86-64 row on Intel's list of data operand independent timing instructions as independent of its inputs under `doitm=on`, but for any input its class still names, so a secret may reach those inputs, and every other x86-64 row depends on all of its inputs. The walk carries secrecy across every register that overlaps another, so a secret seeded or written under one view is secret where any overlapping view reads it, as x86-64's `rdi` and `edi` or AArch64's `x` and `w` and `v`, `q`, `d` and `s`. `check` passes the walk the declassify points its caller states, which are the guards of a division's traps (see below), and no other value is made public there.

Every function that requires constant time is checked at four sites, and every site reports the one record `mirl.ct.Refused`: masc's refusal (`masc.core.ct.Refusal`, worded once by masc), the function, and where in its code it stands.

- A pass that cannot keep the requirement refuses with `Why.timing`, which carries masc's record, as the helpers legalisation refuses a copy or fill whose length is secret.
- Before any back end, `mirl.target.compile` refuses the module when the target's set classifies no timing, as SPIR-V's, and runs the oblivious check of `mirl.ct.oblivious` over every such function. The check refuses a secret that decides a branch or a switch, names the function a call calls, or forms the address, offset, index or length of a memory access. It reads the secrecy every value is marked with, with one change: a `declassify` makes its result public only in the exact shape the helpers legalisation makes it, a `declassify` whose only use is the condition of a `cbr` whose taken target is a block of one `unreachable`, whose edges pass nothing, and whose operand is the trap condition of the division the other target reaches, as the division's row states its traps (the test of a zero divisor, of a signed overflow or of a quotient that does not fit, each under the `reduce.or` of a vector's lanes, joined by `or` in the row's order). The division reached is an instance of a dividing row in that block whose traps they are, or a call of a dividing helper of whose arguments they are the traps of a dividing row, or, for a division of a two-word dividend, any of those in a block that reads every value the condition tests. Any other `declassify` passes its operand's secrecy on. These are the secrecy facts, which `facts` gives of any function and `public` answers of one value, so a pass that may choose a faster form when every operand is public asks there.
- After selection, the machine form's `timing` step asks of every instruction of a row a secret reaches the latency refusal `mirl.ct.latency` reads from the row's class under the build's context, and refuses an address formed from a secret register. A virtual register is secret when any instruction writing it is.
- Emission marks each such function's code as a constant-time range of masc's builder, which mink keeps in its object and lowers into the note the linker reads. Once the object is made, `mirl.machine.emit.timed` walks each range's bytes with `check`, seeded with the register each secret parameter's piece arrives in or the bytes of the incoming argument slot it arrives at, with every register allocation gave a secret value but those parameters arrive in, and with every frame slot marked secret (a secret value's spill slot, or a frame local a secret is stored into, which allocation marks) at the place framing put it. Every memory seed is an extent from the stack pointer at entry, the only base masc's `Seed.memory` takes. The walk takes one declassify point (`masc.walk.walk.Declassify`) for each guard of a division's traps, the `cbr` the oblivious check accepts. Selection emits that guard as a test and a separate branch on what the test leaves, never a fused compare and branch on the divisor, and marks the branch as declassifying: `seqz` then `bnez` on RISC-V, `test` then `je` on x86-64 and `cmp` then `b.eq` on AArch64 for a zero divisor, and a test of the joined condition then a branch on it for a signed overflow. Emission places a label before each such branch and makes a point before it on every register it reads and every flag its row reads, as RISC-V's condition register, x86-64's `zf` (`RFLAGS_ZF`) and AArch64's NZCV. The point lifts that one read and leaves the divisor and every other value as secret as it was. The machine form's `timing` step reads the same branch's operands as public. Code the walk cannot follow on a set that classifies its rows is refused as `Unfollowed`, since nothing is decided, and so is a point outside its function's range. Wasm walks its own code the same way, with no declassify points, and compiles code the walk cannot follow with the warning.

No native division of a set that classifies its rows is data independent, so a secret division would be refused `LATENCY` at the divide even once its guard passes. The helpers legalisation therefore lowers a division or remainder with an operand the secrecy facts do not prove public, on such a set and at any width including the register's, to a call of its constant-time helper (`mirl.legal.helper.table`), with the test of every trap its row states, and never to the target's division or the chain of word divisions. A division whose operands are all public keeps the target's instruction. A variable-time helper (#256) may apply only where the secrecy facts prove every operand public.


## 8. The verifier

The verifier checks a module against the target it names. `mirl.verify.check(m)` assembles the target from the module's tuple, refused by the rule of assembly it breaks, and checks the module as it stands before legalisation, and `mirl.verify.against(m, t, ctx, stage)` checks against a given target at a given stage, laying types out under the context the build's selection opened, or `mirl.target.NO_BUILD` where no family opened one, so a stated offset is held to the alignment its member has under the vector registers the build meets. Both give ok, or the first rule the module breaks, or the allocator's refusal, which is never an answer of valid.

The stage says how far the module has come through its schedule. `open` is any module before legalisation, so no rule that holds only of legal code applies to it. `legal` is a module past every legalisation, and carries a lookup of the region tree each function's structure analysis holds. The pass driver verifies a run as `open` until it reaches the last legalisation of its plan, and as `legal` from that pass's own verification on.

A refusal is a defect in the producer that made the module and never a diagnostic about the program the module was made from. It names the rule, where the module breaks it (function, block, instruction, global, constant or type, whichever apply) and a short description of the fact that does not hold.

The rules are a table. Each is a row with an id, a short name and a check over the whole module. They run in order and a later rule reads only what the earlier ones hold. The id is the rule's position in the table. The rules are

| id | rule | what it holds |
|---|---|---|
| 0 | `target` | the module's tuple is its target's, and the target declares every fact the pipeline reads |
| 1 | `width` | every integer type in the type table has a legal width, which is 1 or a power of two from 8 to 512 |
| 2 | `layout` | every structure that states its offsets and every array that states its stride states ones the rules of some address space of the target keep: offsets none overlapping and each a multiple of its member's alignment, and a stride no shorter than the element and a multiple of the array's alignment. A type names no space, so it is not held to the space of each use |
| 3 | `constant` | every constant is of its type, an aggregate has one element per member and an address names a function or global of the module |
| 4 | `initial` | every global's initial value is a constant of the global's type |
| 5 | `attribute` | every attribute on a function or global is one the schema of the target's family defines: of that family, of a name the schema has an entry for, attached to the kind of symbol the entry attaches to, with a datum of the entry's kind, and keeping the entry's rule, which reads the datum beside the symbol's other attributes and the target's declarations. A target that accepts no attribute refuses every one |
| 6 | `reference` | every id a block or instruction names is one its body holds and has not removed, every instruction is listed in exactly one block and placed in it, every operand and branch argument is defined, every result and parameter is defined by the instruction or block that lists it, and every opcode names a row |
| 7 | `terminator` | every block ends in exactly one terminator, with none before it |
| 8 | `edge` | every edge passes its target's parameters in count and type, and the entry block takes the signature's parameters, or one parameter per place once the abi legalisation has placed them |
| 9 | `typing` | every instruction is an instance its opcode's row types, and its results are the number and types the row derives, and an `alloca`'s pointer is into the target's slot space |
| 10 | `secrecy` | every result is secret exactly as its row's secrecy rule gives, and no edge passes a secret value to a public parameter |
| 11 | `dominance` | every use in a reached block is dominated by its definition, and so is every branch argument at its edge |
| 12 | `debug` | every location, inlining site and binding that an instruction's metadata names is an entry of the debug table |
| 13 | `binding` | every value binding record stands before an instruction of its block, in the order of their points, names a variable of the debug table and reads a defined value through an expression that applies to its type, and in a reached block the value dominates the record's point |
| 14 | `structured` | past legalisation on a target that declares structured control, every function with a body is the tree of regions its structure analysis holds, and the tree keeps the rules of structured control: every selection and loop header strictly dominates its merge, no block is the merge or the continue target of two constructs, every block the entry reaches is in exactly one region, a selection's arms start at its header's edges in order, a loop's body starts at its header and its continue sequence at its continue target, a loop is entered back by exactly one edge from that target, and every edge goes on to the next region of its sequence, to the merge of the construct around it, to the innermost loop's merge or to its continue target, so a construct is entered only at its header. A refusal names the construct's header and the rule broken |
| 15 | `call` | every call through the address of a function of the module states the extension of each parameter and result that the function's signature states |
| 16 | `linkage` | every function with no body and every global with no initial value, which another module defines, has a binding other objects may refer to |
| 17 | `placement` | every section a global states is thread-local exactly when the global is, writable unless the global is constant, and zero filled only for a global that is not constant and whose initial value is every bit zero |
| 18 | `thread` | no global's initial value holds the address of a thread-local global, stated in the module or declared, since it has no one static address and is reached only through code by its model |
| 19 | `addressing` | past legalisation on a target that declares logical addressing, no instruction forms or reads an address as a number: no row whose address formation is arithmetic, which `ptr.add`, `ptrtoint` and `inttoptr` are |
| 20 | `functions` | code names a function's address only through `func.addr`, and only on a target whose `functions` declaration is not `none`, whose function immediate names a function of the module, and an address constant naming a function stands only as a call's callee, the function it calls with no offset |
| 21 | `convention` | every function type names no convention row, for the one its target's tuple names, or one of the convention rows its target states: its own and every other of its architecture whose requirements hold over its baseline |
| 22 | `assembly` | every immediate an inline assembly block binds is a constant: an integer, or an address where the operand's constraint lets a symbol stand for it |
| 23 | `op` | every target op names an instruction set its target's `ops` catalog holds and an op that set holds, refusing it by declaration on a target whose catalog holds no such set or op, and the refusal names both. An op the catalog refuses because the ir has a form of it is refused naming that form, and an own op whose row transfers control is refused. It passes the operands and states the results the op's row binds: each of the row's own operands after the ones the target supplies takes the next operand where it reads and gives the next result where it writes, an optional one may be left out at the end and a variadic one takes the rest, an immediate, an enumerant and a number written inline take an integer constant, an enumerant naming only members its row's enumeration has and taking the params of those members after it, an operand or result the catalog names a handle kind for is a handle of that kind, and a value the row defines is the op's first result or, where the op states none, a result the target gives no type. It declares that it reads and writes memory exactly as the row's accesses state, and where a build is open its selection admits the row's requirement |

A front end that gets one of these refusals reads its id here and looks at the rule's row in the table. Rule 9 reports that the opcode's row refuses the instance but not which of its typing rules failed. The checker, `mirl.ir.opcode.check`, gives that, and a front end can call it on the same instance for the precise error.


## 9. Inline assembly items

An inline assembly item is an `asm` instruction whose `block` immediate (`mirl.ir.assembly.Assembly`) holds a block of target assembly. masc, the assembler, reads the block. mirl never reads its instructions, and every pass sees the item only through what the block declares.

A block is its text in the source dialect of the target's instruction set, its operands and what it declares it reads and writes of memory beyond its memory operands. The text names each operand as `{name}`. Each operand states its name, its role (`read`, `write` or `read_write`, masc's operand roles), its constraint (masc's `inline.Constraint`: a register class of the set's register file by its handle, `memory`, or an immediate of a number of bits, signed or unsigned, which a symbol may stand for) and the type of the value it binds.

- An operand the block reads, and every memory and immediate operand, binds an operand of the instruction, in the order the block states them. A memory operand binds the address the block reaches memory through, and its role says whether the block reads or writes that memory. An immediate binds a constant (verifier rule 22).
- An operand of a register class the block writes binds a result, in the order the block states them. A `read_write` operand binds one operand and one result of one type.
- A block binds at most `mirl.ir.assembly.MOST_OPERANDS` (30) operands.

The row reads and writes memory and is neither speculatable nor mergeable, so no pass removes, merges or moves an item by its row. The memory analysis gives an item one place for each memory operand, of no size it states, read or written as the operand's role says, and `anywhere` when the block declares `reads` or `writes`. `conflicts` compares every pair of places of two instructions, so two items compare at most 30 by 30 places, and an item against an opcode row at most 30 by 2.

The register family owns the `asm` row, so a target of any other family, whose set masc reads no inline block in, refuses an item by declaration. Selection hands masc the block under the build's context: masc parses it, refusing it with its first diagnostic's wording, and answers its footprint. Each operand becomes a virtual register of its constraint's class (tied for `read_write`), an address based in the register its pointer is in, or the constant. The registers the block itself reads and writes are the instruction's implicit locations, so no value is live across a register the block writes, and the frame saves a preserved register the block writes. A block that changes the stack pointer makes the frame keep its frame pointer, and a frame whose convention row has none is refused (`lay.Error.pointer`). A block leaves the frame pointer as it found it: a frame that keeps its pointer refuses a block whose footprint writes it (`lay.Error.taken`). After allocation the handover gives masc each operand's location, and masc encodes the block at the builder's cursor. A constant-time function's code, an inline block's bytes among it, is walked by masc's walk after encoding.

Limits:

- A block whose control leaves it other than by a call is refused at selection. A block that calls leaves undefined what the default convention row's callee does.
- A footprint masc leaves undecided, as a data directive with no `writes` clause, is taken as writing every register the view admits but the stack pointer, the convention's frame pointer and a zero register, as front ends assume a block leaves both pointers intact, and the memory analysis takes the block as declared. Its stack effect is taken as none.
- An operand whose value selection holds in another class than its constraint's is refused (`Refusal.class`), and so is a symbolic immediate bound to an address, which the machine form carries no relocation kind for yet (`Refusal.symbolic`).
- The machine form text prints an inline block as `asm` and its text, and its reader does not read one.
- Legalisation does not rewrite an item's operands, so an operand of a type the target holds in no register, as a narrow or a wide integer, is refused at selection.


## 10. Target ops

A target op is one instruction of an instruction set its target's catalog names: a `target.op` instruction, or `target.op.memory` where it touches memory, whose `op` immediate (`mirl.ir.native.Op`) names the set as the catalog names it, the op as the set names it, the types of its results and whether it reads and writes memory. It is how a front end reaches a target's own instruction, as GLSL.std.450's `Sqrt` or OpenCL.std's `fma`, and one form serves every family: the catalog is the target's `ops` declaration over masc's rows of the target's set, never a case of the ir.

The op's row of masc's set states everything the verifier holds the item to (rule 23). The row's operands after the ones the target supplies itself are the op's own: each takes the next operand of the instruction where it reads and gives the next result where it writes, an optional one may be left out at the end, a variadic one takes the rest, and an immediate, an enumerant or a number written inline takes an integer constant. A value the row defines is the op's first result, or none, which the target gives no type. The item declares that it reads and writes memory exactly as the row's accesses state, and where a build is open its selection admits the row's requirement. masc states no type of an extended instruction's ids, so the types of the operands and results are the front end's, and the module the target writes is checked against them by the target's own validator.

A target op of no memory is a function of its operands: its row is speculatable and mergeable, so it is merged, hoisted and removed as any pure operation is, and two are the same computation when they name one set and one op. A target op that touches memory is neither, and the memory analysis takes it as reading and writing anywhere as it declares, since which of its operands address memory is the catalog's to say and no pass reads the catalog. No fold evaluates either.

A target whose catalog holds no instruction set, every register and webassembly target, refuses every target op by declaration, and one whose catalog holds no such set or op refuses it naming both. SPIR-V holds GLSL.std.450, NonSemantic.Shader.DebugInfo.100 and OpenCL.std, each an `OpExtInst` of the set's import whose result type, result and import come before the op's own operands, so the set imports once and the module declares what the op's row requires (see [ir/target.md](ir/target.md)).

SPIR-V also holds `core`, its core instructions, each the instruction its row of masc's set is, named by its opcode as `OpImageSampleImplicitLod`. The target supplies the result type and the result where the row gives one, and the rest are the op's own, an image op's trailing `Image Operands` mask among them with the params of its set bits after it. The catalog refuses an opcode the ir has a form of, naming the form to write in its place, as `add` for `OpIAdd`, `load` for `OpLoad` and `a type` for `OpTypeInt`, so each operation has one spelling, and it refuses an opcode that transfers control, which the ir's control flow states. An image, sampler or sampled image operand or result is a target handle (2.7) of the kind `spirv.image`, `spirv.sampler` or `spirv.sampled_image`, which the catalog names for each image op, since masc's rows state those operands as bare ids. An atomic, a barrier and a group operation have no ir form that states their scope, so they are core ops.

Limits:

- masc does not state the memory of SPIR-V's core rows yet (masc#539), so the `core` set refuses every op whose row states no memory access, naming it, rather than taking an image write as touching nothing. Until masc states it every core op is refused.
- Legalisation does not rewrite a target op's operands or results, so one of a format or width the target computes through lowering, as a binary16 value without `Float16`, is refused after it.


## 11. Where the rest is

- the opcode reference, [ir/opcodes.md](ir/opcodes.md)
- the text form and its grammar, [ir/text.md](ir/text.md)
- the constant folder, [ir/fold.md](ir/fold.md)
- targets, data layout, argument passing and attributes, [ir/target.md](ir/target.md)
- the debug table, [ir/debug.md](ir/debug.md)
- instruction selection into the machine form, [machine/select.md](machine/select.md)
