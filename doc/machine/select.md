# Instruction selection

Selection turns an IR function into the machine form. A target supplies one table, `mirl.machine.select.Table`, and nothing else. The engine reads the table, the IR opcode rows and masc's rows, and names no target.

## The table

A table holds

- `rules`, the rules for IR instructions,
- `constants`, the rules that materialise a constant into a register,
- `holds`, which register class holds a value of each type,
- `jump`, an unconditional jump to edge 0's block.

`mirl.machine.select.init` checks a table once against the schema and against the target it is made ready for. A table that breaks either is refused with a typed error and nothing is built.

## Sources

An emitted operand comes from the pattern (a register an operand is in, a constant as an immediate or a symbol), from the expansion (a temporary) or from the table.

- `fixed` is a register of masc's file for the target, such as a hardwired zero. The row it stands in must admit it, and an instruction that does not is refused as the machine form's error.
- `scratch` is a temporary of a class of the register file. `fresh` takes its class from a value's type, which a temporary inside a float constant's expansion cannot, since only an integer register can hold the bits.

- `width` is the bits of a value's integer type and `register` the bits of the target's general register, each as an immediate. A rule passes them to a loop's parameters, so one loop serves every width the rule's guard admits.

An emitted instruction is a row, a pseudo or a target's loop (see [loops](loop.md)). A rule whose expansion holds a loop is admitted only when the selection admits every row of the loop's steps, and the table check refuses a loop that breaks the loop schema.

A guard's hook reads the matched instructions through `mirl.machine.select.match`, the one reader the engine also uses, so a hook never repeats how the engine finds an operand or a constant.

Three sources name what only the engine knows. `slot` is the frame slot an `alloca` root asks for, of its type's size at its alignment. `partner` is the address of an earlier instruction of the same expansion under a relocation kind, which labels that instruction, as a pc-relative low part names its high part. `lookup` is the runtime function the target's general dynamic thread-local access calls, which the module declares. An emitted instruction may also state the registers it reads and writes beyond its operands and row, as the call to the lookup reads and writes its argument register.

## Shared nodes

A pattern's node is consumed, and emits nothing, when its parent is consumed and the parent is the only use of its results. A node several patterns read is shared. The engine counts the node slots of chosen patterns that read each instruction, and when that count equals the uses of the instruction's results, every use is a pattern and the instruction is consumed, each pattern repeating its computation. Only an instruction whose opcode row neither reads, writes nor traps is repeated. Any other is selected once, on its own, and the patterns that would read it do not match. This concerns selection of shared nodes and no particular opcode.

## Calls, entries and returns

The abi legalisation leaves every call, entry and return in piece form, each piece a scalar at the place the convention gave it (see [the ir](../ir.md)). Selection never classifies. It reads the places.

- An entry copies each parameter out of its register, or reloads it from an incoming slot at its offset.
- An entry with parameters that nothing placed is refused as `unplaced`, naming its function, since nothing says where they arrive.
- A call or a return materialises its constant pieces first, then copies each piece into its register or spills it to an outgoing slot at its offset. The rule for `call.placed` or `ret.placed` supplies the call or return form. The instruction of that form that calls or returns reads the pieces' registers and writes the results' registers, and the results are copied out of theirs.
- A piece at an operand place, a stack piece whose size scales, and a result on the stack are refused as `placed`.

Selection is the one place the convention's clobbers reach the register allocator. `select(s, m, f, ?calls)` takes the registers a call leaves undefined (`Resolved.clobbered`) and the allocator's locations, and gives the machine function with one `live.Clobber` per clobbered register at every instruction it emits that calls, the table's call forms and the lookup alike.

The other half of the allocator's request is the allowed set. `allowed.of_machine(a, ?machine, ?locations, keeps)` lists it from the opened machine: every register the selection admits that masc gives no fixed role and the convention does not reserve, the frame pointer left out when `keeps_pointer` says the frame keeps it, and every memory cell. `Request{at, registers, allowed, clobbers}` is that list beside selection's clobbers.

A value of an aggregate type has no register and is refused as `aggregate`. The abi legalisation leaves one only where a value is loaded whole from memory, which a later legalisation has to split.

## Choosing among rules

Of the rules for an instruction whose guard holds, the least cost wins. Of equal cost the earlier row in the target's table wins. This is the whole tie-break. A target that cares about a choice gives its rules different costs, and never relies on a row's place to express a preference it has not costed.

## One class per type

Every type the target reaches has exactly one class, its default, and exactly one row of `holds` admits it. A `Hold` row admits a class of the IR typing vocabulary (`ir.within` is the one whole-type test), so two rows overlap when some type is in both classes. Order is never identity: no code in selection or in a register class picks a class by the position of a `holds` row.

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
