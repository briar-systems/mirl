# The storage model

masc states every register's storage as pieces of a bank: the bank it is in, the bit range its pieces take at each multiplier of its scale, and what a write through it leaves in the rest of the bank. `footprint.of` answers what an instruction reads, writes and kills over those facts, and `register.within` answers where one register lies in another. `mirl.machine.storage` is the one place the machine form asks them.

```
of_register(regs, row)              # opt[Storage]
of_class(regs, class)               # opt[Storage]
of_group(regs, class, span)         # opt[Storage]
shares(file, a, b)                  # bool
kills(footprint, other)             # bool
view(file, part, whole)             # opt[View]
viewed(file, whole_id, part, view)  # opt[rf.Id]
view_kills(file, view, extend)      # bool
```

A `Storage` is bits fixed plus bits per unit of one scale's multiplier, the shape of masc's scaled widths, folded through the selection so a scale the selection fixes is a fixed size. The locations' sharing, liveness and its kills, the allocation checker, copy lowering, the spiller and the frame read a location's storage, its views and its groups here, and no other module restates one.

- Liveness ends a value where a write kills it: an instruction writing a location also writes every location sharing its storage that masc's footprint says it leaves no bit of (`kills`). A write that keeps some bits, as an undisturbed tail, is a read as well.
- A memory-backed class states only the bits of each cell, which share storage with nothing but themselves.

## Views

A view is a class every register of which lies in exactly one register of another class at one placement, at every legal multiplier, with every register of that class holding exactly one of it, as x86's `eax` in the low 32 bits of `rax` or AArch64's `d0` in the low 64 of `v0`. `storage.view(file, part, whole)` finds it from masc's `within`, and is none where any register lies within none or two, or the placements differ.

- An operand at a register position whose classes admit a view of a virtual register's class may name that virtual register (`instruction.viewing`). No move is made between the views: the rewrite names the register of the view within the virtual register's location (`storage.viewed`), and the checker holds the rewritten operand to it. A view at a position a row fixes is refused, since the fixed register is the view's and not the location.
- A write through a view that keeps bits of the whole, as `al`, is also a read of the value. One whose stated extension overwrites the whole, as `eax`'s zeroing write, ends it (`view_kills`, masc's `overwrites`).

## Groups

A group of registers, as a RISC-V vector group under LMUL 2, takes its class's storage once per register, scaled where the class scales (`of_group`). That is the size of the slot it spills to, `spill.group_slot`. A list's members and their wrap, as AArch64's `{v31, v0}`, are masc's (`operand.step`, `operand.span`), which the operand shape below reads.

## Allocation policy

A hold states what the allocator may do with a value of its class (`class.Policy`): whether it may live in a frame slot (`spill: allowed | never`) and how one is had again where its location was taken (`remat: none | producer`). The zero value spills and remakes nothing. An `i1` held in a flags class, as EFLAGS or NZCV, is `never` and `producer`. The table check refuses a class whose holds state two policies (`POLICY`), and the allocator refuses a round that would carry a value of a never-spilled class in pieces (`allocate.Error.unspillable`).

## Operand shapes

Beside a register, a constant, a slot, a symbol, a block, a tie and a partner, an operand may be one of masc's memory, list and literal shapes. Each stands at a position of masc's shape as far as the position admits it, checked when the instruction is made.

- `address`: a base, an index and a segment, each a register or none, a scale, a displacement or a symbol, masc's mode, an extend and a broadcast, as x86's `[b + i*s + d]` or AArch64's pre-indexed `[x0, #16]!`. Each register stands at its part of the position. The text spells it by field between brackets, `[base: %0, index: %1, scale: 2, disp: -8]`.
- `list`: a first member and a count, as `(v8, 3)`. A virtual register as the first names a value covering the whole list, which allocation holds as one group. The members follow the first by masc's step and wrap within masc's span. The lists of one instruction hold at most `instruction.MOST_MEMBERS` members.
- `literal`: bytes the instruction holds whole, borrowed from storage that outlives the function, as a wasm `v128`. The text prints them as `<1, 2, 255>`.

Liveness, the spiller, the rewrite, the checker and the scan read the registers an operand names through one listing of them (`operand.named`, `operand.renamed`): an address's registers are read, and its base written as well where its mode writes it back. The handover gives masc the address, the list's members and the literal. An `id` is refused, as no register family keeps one.

## Vector state

A rule's instruction states the configuration state its register groups run under (`Emit.state`), a `vstate.State` over masc's `config.State`, as a RISC-V vector add's vtype. The table check refuses an instruction stating one where its rows' groups turn on none, or none where they turn on one (`STATELESS`).

The `configure` step of `STAGES`, after the lowering of copies, inserts the set's establishing instruction before each instruction whose state differs from the one in force (`mirl.machine.configure`). The state in force is unknown at a block's start and after a call. An instruction masc's hooks say sets a state leaves that one in force, and one whose state its operands decide leaves it unknown. The set states how it establishes a state as data, `StateRules{row, parts}`, each part a scratch register, a fixed register or the state as an immediate. A scratch is an allowed register the convention clobbers or the frame saves that holds no value into or across the instruction, and an instruction before which none is free is refused (`Reason.scratch`). RISC-V states `vsetvli <scratch>, x0, <vtype>`.

## Limits

- A view is total or none: a class some registers of which lie in another and some do not is no view.
- A value of a never-spilled class is refused where it would spill, and is never remade by its producer. Remaking needs the allocator to re-emit an instruction of the input at a later position.
- The configure step reads the state in force within a block only. A block always starts with the state unknown, so a loop of vector instructions establishes its state again in every iteration.
- The vector length a RISC-V `vsetvli` sets is VLMAX for the vtype, as the IR states no vector length yet (#72).
- A literal is printed but not read back from the machine text.
- No rule source makes an address, a list or a literal yet. A member whose selection emits one builds that source.
