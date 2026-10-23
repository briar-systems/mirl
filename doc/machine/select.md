# Instruction selection

Selection turns an IR function into the machine form. A target supplies one table, `mirl.machine.select.Table`, and nothing else. The engine reads the table, the IR opcode rows and masc's rows, and names no target.

## The table

A table holds

- `rules`, the rules for IR instructions,
- `constants`, the rules that materialise a constant into a register,
- `holds`, which register class holds a value of each type,
- `jump`, an unconditional jump to edge 0's block.

`mirl.machine.select.init` takes the record of the target's instruction set, a `mirl.machine.isa.Isa` the caller hands in with its table, masc's set and its loops, and the registers of the target's default convention row. It checks the table once against the schema and against the target it is made ready for. A table that breaks either is refused with a typed error and nothing is built.

## Sources

An emitted operand comes from the pattern (a register an operand is in, a constant as an immediate or a symbol), from the expansion (a temporary) or from the table. A symbol is the link-time address a value is: an address constant, or the result of a row whose address formation is a function, which is `func.addr` (`match.address`). A hook reads the address a rule builds, the constant of a materialisation or the first result of the root, through `match.built`, so one hook serves both.

- `fixed` is a register of masc's file for the target, such as a hardwired zero or the thread pointer. The row it stands in must admit it, and an instruction that does not is refused as the machine form's error. A register the calling convention names is never `fixed`.
- `link` is the register a call leaves its return address in, and `argument` and `returned` an argument or result register by its bank's kind and its place there, each read from the convention row the call runs under: the row a placed call's signature names, and the target's default row the selector is made ready with for any other. So a call, a return and the runtime call of a general dynamic thread-local access hold under any row the target states. The table check refuses a rule naming one the row does not as a defect of the table, and a selection made ready with no row refuses such a rule when it emits. An implied register, which an instruction reads or writes beyond its operands, is named the same way, by a `fixed`, `link`, `argument` or `returned` source.
- `scratch` is a temporary of a class of the register file. `fresh` takes its class from a value's type, which a temporary inside a float constant's expansion cannot, since only an integer register can hold the bits.

- `width` is the bits of a value's integer type and `register` the bits of the target's general register, each as an immediate. A rule passes them to a loop's parameters, so one loop serves every width the rule's guard admits.
- `ordered` is the immediate a target's `Forms` give the ordering a node states, one immediate per ir ordering, as RISC-V's aq and rl bits. The ordering is the join of every ordering immediate the node's ir row holds, so a compare and exchange's success and failure are read as one, the weakest ordering at least as strong as both (`mirl.ir.opcode.joined`). A node whose row holds no ordering immediate is refused by the table check as `unordered`.
- `tied` is one register an instruction both reads and writes, the value of an operand in and a result of the root out, at a row position masc states read and written, as `amocas` reads the value expected and gives the value held. The allocator gives both halves one location and copies the value in first when it is read again later.

An emitted instruction is a row, a pseudo or a target's loop (see [loops](loop.md)). A rule whose expansion holds a loop is admitted only when the selection admits every row of the loop's steps, and the table check refuses a loop that breaks the loop schema, one the set's loops do not hold, and, as `breached`, one whose body breaks its constraint.

A guard's hook reads the matched instructions through `mirl.machine.select.match`, the one reader the engine also uses, so a hook never repeats how the engine finds an operand or a constant.

`address` builds a memory operand from the pattern, as x86's `[b + i*s + d]`: a base and an index, each the register of a value the pattern reads or a fixed register of masc's file for the base, as the string moves' `rdi`, a scale that is a literal or derived from a constant, as the shift or the power of two of a multiplier the pattern covers, a displacement that is a constant's bits or a symbol's address, a segment register, and whether it is formed from the instruction's own address, as x86-64's rip-relative reach of a symbol. The engine admits it where the row's memory position takes that address (`mirl.machine.instruction.fits_address`), so the scales, the displacement's reach and the forms a row takes are masc's.

Three sources name what only the engine knows. `slot` is the frame slot an `alloca` root asks for, of its type's size at its alignment. `partner` is the address of an earlier instruction of the same expansion under a relocation kind, which labels that instruction, as a pc-relative low part names its high part. `lookup` is the runtime function the target's general dynamic thread-local access calls, which the module declares. An emitted instruction may also state the registers it reads and writes beyond its operands and row, as the call to the lookup reads and writes its argument register.

## Shared nodes

A pattern's node is consumed, and emits nothing, when its parent is consumed and the parent is the only use of its results. A node several patterns read is shared. The engine counts the node slots of chosen patterns that read each instruction, and when that count equals the uses of the instruction's results, every use is a pattern and the instruction is consumed, each pattern repeating its computation. Only an instruction whose opcode row neither reads, writes nor traps is repeated. Any other is selected once, on its own, and the patterns that would read it do not match. This concerns selection of shared nodes and no particular opcode.

## Calls, entries and returns

The abi legalisation leaves every call, entry and return in piece form, each piece a scalar at the place the convention gave it (see [the ir](../ir.md)). Selection never classifies. It reads the places.

- An entry copies each parameter out of its register, or reloads it from an incoming slot at its offset. An entry's parameter at an operand place is refused as `placed`, since no call form gives it.
- An entry with parameters that nothing placed is refused as `unplaced`, naming its function, since nothing says where they arrive.
- A call or a return materialises its constant pieces first, then copies each piece into its register or spills it to its stack slot: a call's to the caller's outgoing area and a return's to the incoming area its caller passed. The rule for `call.placed` or `ret.placed` supplies the call or return form. The instruction of that form that calls or returns reads the pieces' registers and writes the results' registers, and the results are copied out of theirs, or reloaded from the outgoing area where the convention returns one on the stack.
- A piece at an operand place is never moved. The rule's call or return form reads it as its operand, by its position among the root's operands, and defines a result at an operand place itself, as wasm's `call` takes its arguments and SPIR-V's `OpFunctionCall` its operands.
- A stack piece whose size scales takes a slot of its type's bytes per unit of the scale's multiplier, and one whose offset scales a slot at that many bytes per unit into its area (`Argued`), the slot's scale the piece's. A piece whose size and offset scale by two scales is refused as `placed`.
- The instruction that makes the call states its pieces' places, the arguments' and then the results', as the legalisation stored them, and the machine function states where its parameters arrive (`Function.entry`). Every stage that rebuilds the function keeps both, so the machine text prints them from that stored result and never classifies.

Selection is the one place the convention's clobbers reach the register allocator. `select(s, m, f, ?calls)` takes the registers a call leaves undefined (`Resolved.clobbered`) and the allocator's locations, and gives the machine function with one `live.Clobber` per clobbered register at every instruction it emits that calls, the table's call forms and the lookup alike.

The other half of the allocator's request is the allowed set. `allowed.of_machine(a, ?machine, ?locations, keeps)` lists it from the opened machine: every register the selection admits that masc gives no fixed role and the convention does not reserve, the frame pointer left out when `keeps_pointer` says the frame keeps it, every tuple of a class no instruction fixes whose members all are, as RISC-V's pair x12:x13 and never x4:x5 while tp is reserved, and every memory cell. `Request{at, registers, allowed, clobbers}` is that list beside selection's clobbers.

A value of an aggregate type has no register and is refused as `aggregate`. The abi legalisation leaves one only where a value is loaded whole from memory, which a later legalisation has to split.

## Divisions that do not trap

A division whose opcode row states a trap (a zero divisor, a signed overflow, a quotient that does not fit) is selected without the `checked` flag only where the target's division traps for each of them as the ir does. Where `arithmetic.division` declares the division, or the division of a two-word dividend, `quiet` for a trap the row states, a chosen rule that covers a division without the flag is refused as `unchecked`, naming the instruction, since no test of the trap stands before it. The engine reads the opcode row's traps and the target's declared faults, and names no target.

## Choosing among rules

A rule's guard is its type tests, its `orderings` and its hook. A type test names a class and, for an integer or a pointer, a width against the target's general register (`Test.width`): `any`, `register` for as wide as the register, `part` for a part of it scaled down, as a 32-bit word of a 64-bit register, and `whole` for a value this many registers wide. A pointer's width is its address space's pointer width. So one rule serves every register width, as RISC-V's `add` serves rv32 and rv64, and no hook reads the width. `orderings` is the set of orderings of its root the rule is chosen for, read as an `ordered` source reads them, or nil for a rule that takes any. So a target whose forms differ in their instructions and not only in an immediate, as a RISC-V load is plain when relaxed and fenced when acquire, states one rule per form, and the selection never branches on an ordering. A rule naming orderings of a root whose row holds none is refused as `unordered`.

Of the rules for an instruction whose guard holds, the least cost wins. Of equal cost the earlier row in the target's table wins. This is the whole tie-break. A target that cares about a choice gives its rules different costs, and never relies on a row's place to express a preference it has not costed.

## One class per type

Every type the target reaches has exactly one class, its default, and exactly one row of `holds` admits it. A `Hold` row admits a class of the IR typing vocabulary (`ir.within` is the one whole-type test), so two rows overlap when some type is in both classes. Order is never identity: no code in selection or in a register class picks a class by the position of a `holds` row.

A row holds under a condition over the build's extensions (`Hold.requires`), so a type held in one class on one build and in another on another, as a RISC-V float in the float registers under F and in the general registers under Zfinx, is two rows of which a build meets one. The count reads only the rows whose condition the build's context meets, and a float format is reached only where a row for it holds. A row also states its class's allocation policy (doc/machine/storage.md), and two rows of one class stating different ones are refused as a defect of the table.

Any choice of class beyond the default belongs to the rules or to the register allocator. An integer moved into a float register, or a vector held in a narrower vector class, is a rule that emits the move or an allocator decision. It is never a second `holds` row that happens to come later.

### The types a target reaches

The check counts, for each type the target reaches, the rows that admit it. It is linear in the types and the rows and never compares rows with each other. A table is refused when a reached type is admitted by

- more than one row, naming the type and the first two rows (`overlap`),
- no row, naming the type (`uncovered`).

The types reached are the target's declared native types and the types its own rules name:

- `i1`, the type of every condition,
- an integer of each width in `widths.integers`,
- a pointer into each address space in `widths.pointers`,
- a float in each format in `formats`,
- a vector of each packed lane type in `vectors`, of each lane count listed or, where any count is allowed, of two lanes,
- an integer of each width and a float of each format that a rule's type test names.

A class such as `integer` therefore covers every width it admits, and the check still counts each declared width once. A type outside this set that the engine meets while selecting is checked the same way at that point, and is refused as `unheld` when no row admits it and `ambiguous` when more than one does.
