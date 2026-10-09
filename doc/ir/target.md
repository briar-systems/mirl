# Targets, data layout and attributes

A **target** is data. It names an architecture and a system, declares what code generation needs to know about them and states the facts that data layout reads. Nothing in the pipeline reads a target's name to decide what to do. Every decision reads a declaration. A new target is a new row in `mirl.target`'s table and never a new case in a pass.

A module names its target by the target's name. The verifier's first rule requires the name to be a row of the table whose declarations are all stated (see rule 0 in [the specification](../ir.md)). The table has one row at this version, `riscv64-linux`.

## The record

A target holds

- `name`, its spelling, used for diagnostics and lookup only,
- `arch` and `system`, the names of its rows in mink's architecture and system catalogs, where the system must run the architecture,
- `caps`, its capability declarations,
- `data`, the facts data layout reads,
- `convention`, the calling convention its calls are made under (see [Argument passing](#argument-passing)),
- `baseline`, the extensions code for it may assume, in masc's spelling, from which `mirl.target.machine.open` makes masc's selection, the registers it gives and the convention resolved through them. A build adds extensions on top of it through `mirl.target.machine.open_with`, which takes extension names as masc's catalog names them and refuses one it does not know by name, `choose` makes the selection alone for a target with no convention yet, and the machine holds the one resolved selection that selection, the convention and the allocator's allowed set read,
- `addresses`, how code reaches an address (see [Addresses](#addresses)).

`mirl.target.declared(t)` says whether a target is complete. Every declaration has an unstated zero case, so a row left zeroed reads as incomplete and never as an answer. A list that may rightly be empty sits under a case of its own, so an empty list is a stated answer.

## Capabilities

The capability declarations are

| declaration | what it states |
|---|---|
| `registers` | values live in registers the pipeline allocates, or not |
| `control` | control flow is free, or must be structured |
| `addressing` | memory is addressed physically, or only by access chains (logical) |
| `values` | values are untyped, or carry their type into the output |
| `evaluation` | operations take operands from named values, or from an operand stack |
| `widths` | the address spaces and how a pointer into each is held, the register width, the widths integer arithmetic runs natively at, and the integer widths a value holds natively |
| `vectors` | none, or a vector unit with a register width, the lane counts allowed and the lane types with how each is carried out (packed or by scalar expansion) |
| `formats` | the number formats computed natively, each with the not-a-number it returns (`canonical`, `propagate` or `unspecified`), or none |
| `arithmetic` | the widths with a native multiply of the low half, the multiply forms beyond it (one row per width and sign: the high half or the whole product, as signed, unsigned or mixed operands, or none), how a shift treats a count at or past the width (`wraps`, `undefined` or `saturates`), and the operations on single bits it selects as they stand (`both`, `either`, `differ`, `compare`, or none) |
| `timing` | the operations that run in constant time, by operation, width and condition, or none |
| `code` | the alignment of a function entry, a code section and a data section, and the bytes that pad code |
| `attributes` | the attribute families the target accepts |

These describe what the target does. They do not change what an operation means. A shift by the width or more gives 0 or the sign fill on every target whatever `arithmetic.shifts` says, and legalisation bounds the count where the target would not: the shift bounding applies where shifts `wrap` or are `undefined`, and not where they `saturate`.

The ir has no high multiply and no widening multiply. Both are written as a multiply of two extensions, and the high half as that product shifted down by the width and truncated. A target selects the pattern as it stands where it has a form for it: a `high` or `full` row at the width and sign, or a native multiply at twice the width. Where it has none, and multiplies natively at the width, the multiply forms legalisation builds the high half from multiplies at the width. A width the target does not multiply natively is left to the wide integer splitting and the narrow integer widening. A target is a row of each form it has: x86 states `full` rows (a register pair), AArch64 `high` rows at 64 bits and `full` rows at 32, RISC-V `high` rows of all three signs, and a target with none, such as WebAssembly, states none.

### Narrow arithmetic

`widths.alu` lists the integer widths the target's arithmetic runs at, and a row states exactly those: x86-64 at 8, 16, 32 and 64, AArch64 and RISC-V at 32 and 64 (RV32 at 32), and a target such as WebAssembly at 32 and 64. An integer operation at any other width, a condition (`i1`) included, is widened by the `narrow` legalisation to the narrowest listed width above it: the operands are extended, the same opcode runs at the wide width and the result is truncated. The pass applies to a target that lists a width above some legal width it does not list.

A condition stays `i1` where it is read as one, by a branch or a `select`, and the pass leaves that use as it is. Where the same value is also an operand of arithmetic, the operation reads an extended copy and its result is truncated back to `i1` for its readers, so a `shr.s` of one bit fills from bit 0 and an `add` of two carries out of bit 0 and drops the carry. The one exception is an operation the algebra table states is exact on single bits held as 0 or 1, the bitwise `and`, `or` and `xor` and the comparisons that read their operands as unsigned (`mirl.fold.single_bit`), which a target declares it selects on them as they stand in `arithmetic.single`. The pass leaves such an operation, and widens it on a target that declares none. RISC-V declares all four, and the other targets declare none.

- A sum, difference, product, `and`, `or`, `xor`, `neg`, `not` and `shl` take either extension, since the bits above the narrow width do not reach the bits below it. Division, remainder and comparisons extend with the sign or with zeros as their opcode reads its operands, and `shr.u` and `shr.s` extend the shifted operand to match. A shift count is always extended with zeros.
- The shift rule holds at the narrow width: a count of the narrow width or more shifts every bit out at the wide width too.
- A division by zero traps at the wide width exactly when the narrow one does. A signed division or remainder of the least narrow value by minus one does not trap at the wide width, so the dividend is replaced by the least wide value in that case, which traps there. The opcode row states which operands the trap reads, and the replacement is a select, so the pass adds no branch.
- A vector of narrow integers and a width above the widest listed are not its job. The counts (`clz`, `ctz`, `popcnt`), `bswap` and the overflow forms are left until the algebra table states them (`mirl.legal.LEFT`).

## Asking for layout

A front end never computes a size, an alignment or an offset. It asks mirl, and so does the backend and every debug producer, through the same routine.

```
val l: Layout = mirl.target.of(target, ?module.types);
mirl.target.size(?l, ty)          # res[u64, Error], bytes
mirl.target.align(?l, ty)         # res[u64, Error], a power of two
mirl.target.extent(?l, ty)        # res[Extent, Error], size and alignment together
mirl.target.offset(?l, ty, i)     # res[u64, Error], member i of a structure or union
mirl.target.offsets(?l, ty, out)  # err[Error], every member of a structure in one walk
```

`of` takes the target a module names (found by `mirl.target.by_name(module.target)`) and the module's type table. The query is for any IR type.

- An integer or float is a row of the target's data layout, one for each legal width and each number format.
- A pointer is the size and alignment of the pointer row for its address space. A pointer into a logical space has none and is refused as `unsized`.
- A vector is its element's size times its lane count, rounded up to its alignment. Its alignment follows the vector rule of the target, which is either the element's alignment or, for a vector at least as wide as the narrowest vector register, the widest register size that the vector fills.
- An array is its element's size times its count and has its element's alignment.
- A structure places each member at the next multiple of the member's alignment, or at the offset it states, and rounds its size up to the largest member alignment.
- A function type or a target handle has no size and is refused as `unsized`.
- A union is as large as its largest member rounded up to the largest member alignment, with every member at offset 0.

A request that cannot be answered is refused with a reason. The reasons are an unstated fact (the target leaves it out), a pointer into an unknown address space, an unsized type, a stated offset that is misaligned or overlaps the member before it, a member index past the type's members, an offset asked of a type that is not a structure or union, and a size that does not fit in 64 bits.

## Argument passing

How a function's arguments and results are passed is not in the IR. A `call` states only the signature, and a function states only its function type. A front end never computes it. It asks `mirl.target.abi`, and the backend asks the same routine once per call site.

A target declares the convention its calls are made under in `convention`: the row of the convention, or `uncarried` for a convention mirl has no row for yet, whose calls are refused. A **convention** is a row for one architecture, system and ABI, as data:

| field | what it states |
|---|---|
| `results`, `arguments` | the result classifier and the argument classifier |
| `file` | the masc register file its registers are named in, none where there is none |
| `word` | the bits of one argument word |
| `floats` | the widest float passed in float registers, or none |
| `passing`, `returning` | the argument and result registers by masc's register handles, each class in the order taken |
| `preserved`, `reserved` | the registers a callee preserves whole, and those no call clobbers and nothing allocates |
| `stack` | none, or a stack in memory with its alignment at a call, its red zone, its shadow space, where a call leaves the return address (`link`) and its frame pointer with the frame record it heads (`pointer`) |
| `indirect` | what carries the address of a result passed by reference, and where a callee hands it back |
| `variadic` | where unnamed arguments travel, the count a caller sets, and how a callee reaches them |
| `half` | whether a 16-bit float travels as a float or as an integer |

A row is resolved once against a masc selection of its register file (`mirl.target.abi.resolve`), which looks its names up, groups the argument and result registers by class and computes the registers a call clobbers.

```
val c: *Convention = mirl.target.abi.of(target);                    # res[*Convention, Error]
val r: Resolved    = mirl.target.abi.resolve(a, c, ?registers);     # res[Resolved, Unresolved]
mirl.target.abi.classify(a, ?layout, ?r, signature, statement)      # res[Assignment, Error]
```

`classify` describes each argument and result type through the **type view**, a tree of nodes whose every size, alignment and offset was asked of the data layout, and runs the row's result classifier and then its argument classifier over it. It is the only caller of a row's classifiers. The **assignment** it returns states, for each argument and result, whether it travels by value or by reference to a copy the caller makes and owns, and its **pieces**: for each piece a place (a register by masc's identity, a stack offset, or an operand of the target's own call form), the offset and size of the bytes it carries, how the offset and size scale, and how the rest of its place is filled.

The integers are signless, so a convention that extends a narrow integer by the source type's signedness leaves the piece **declared**, and `classify` fills it from the extension the signature states for that parameter or result: sign or zero extended. A declared piece whose parameter or result states none is refused, naming it, and is never guessed.

The call's **statement** says how its language passes aggregates (by the platform's C rules, or each by reference to a copy the caller makes) and how many of its arguments are named. Both have an unstated zero case, which is refused.

The one row is `lp64d`, the RISC-V convention of RV64 with hardware double precision, to the RISC-V ELF psABI 1.0.

## Addresses

A target states its address model, or `uncarried` when it has none yet and no address is selected. The model is the relocation model, `static`, `pie` or `pic`, and the access each thread-local model of the ir is reached by: local exec, initial exec, general dynamic through the runtime function `lookup` names, a descriptor, a per variable thunk or an index into the thread's module table. `mirl.target.address.reach(model, defined, linkage, tls)` says how one symbol is reached: absolutely, by its distance from the code, through the global offset table, or by its thread-local access. Under `static` every symbol is reached absolutely. Under `pie` and `pic` reach reads one fact, `mirl.target.address.preemptible(relocation, linkage, defined)`, which holds the whole rule of the specification for what the model builds: `static` and `pie` build an executable and `pic` a shared object. A preemptible symbol goes through the table, and any other is reached by its distance from the code, defined or not, so the linker refuses a hidden or internal reference that ends up undefined. Selection reads this and never a target's name, and names relocations by mink's kinds.

RV64 Linux is `pie` and reaches local dynamic as general dynamic through `__tls_get_addr`.

## Attributes

An attribute is a fact one target family needs about a function or global and that no other family reads. A fact such as a SPIR-V entry point's stage or a shader variable's binding is an attribute the family defines. It is never a field of a core record.

An attribute holds

- `family`, the target family that defines it, such as `spirv`,
- `name`, its name within that family, such as `stage`,
- a datum, which is one number, an ordered list of numbers such as a workgroup size, or a name.

`mirl.ir.module.attach(m, symbol, attribute)` attaches an attribute to a function or global. The names and lists are copied. A target states the families it accepts in its `attributes` declaration, either none or a list of family names, and verifier rule 5 refuses an attribute of any other family. The text form spells an attribute as `attribute @symbol "family" "name" = datum`.
