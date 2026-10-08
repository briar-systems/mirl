# Instruction selection

Selection turns an IR function into the machine form. A target supplies one table, `mirl.machine.select.Table`, and nothing else. The engine reads the table, the IR opcode rows and masc's rows, and names no target.

## The table

A table holds

- `rules`, the rules for IR instructions,
- `constants`, the rules that materialise a constant into a register,
- `holds`, which register class holds a value of each type,
- `jump`, an unconditional jump to edge 0's block.

`mirl.machine.select.init` checks a table once against the schema and against the target it is made ready for. A table that breaks either is refused with a typed error and nothing is built.

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
