# Register constraints

masc states each row's operand register constraints on `row.Row.constraints`: an output written before every input is read, two operands that must differ, a register group kept apart from another or from a mask register. `mirl.machine.constraint` is the one place mirl asks them, through masc's `constraint.violated`. mirl states no constraint of its own and keeps no list of constrained rows.

```
grouping_of(f, d)             # res[Grouping, Breach]
covers(op, g, at)             # u32
asks(f, d)                    # bool
ask(f, d, values)             # opt[Breach]
stands(f, d)                  # opt[Breach]
```

`ask` hands masc the instruction's operand values under its grouping and answers the breach, or none when every constraint stands and the grouping admits every group. The values come from `instruction.values_of`, the one place an operand becomes masc's value, which the instruction's transfer and emission read as well. A virtual register is a value not chosen yet, which masc reads as one that may take any register. A constant goes to masc as the kind its row position states: an immediate, an enumerant or a condition.

## Breaches

- `broken`: a constraint the values break.
- `outside`: an operand whose group runs past the last register of its class, or whose first register is off the group's alignment, answered only where the grouping states its length.
- `inexact`: a constraint whose answer turns on an element width the grouping does not state. The state no operand holds decides whether the form is reserved, so it is never read as clear. The constraint names its sides. A grouping masc forms under a vtype states every width, so only a grouping with no element width meets it.
- `needs`: an operand whose groups turn on a vector state the instruction does not state. The checker refuses such an instruction when it is made.
- `reserved`: an operand whose groups the instruction's vtype cannot form, as a widening destination under LMUL 8.
- `unencodable`: the instruction's vtype has no encoding.

`broken`, `outside` and `inexact` are a conflict for the choice that met them, never a refusal by themselves. The other three do not depend on a location: they refuse the instruction wherever it is asked, and liveness refuses it as `live.Error.ungrouped`.

## Where it is asked

- The allocator's scan, at every location it considers for a bundle: the copy hint, each free candidate, and each candidate whose bundles it would evict. The bundle is at the candidate, every other operand at its bundle's location, at its pin while it has none, or not chosen yet. A bundle no location of its class stands at is refused with `scan.Error.constrained`, naming the instruction and the breach at the first location tried.
- The allocation checker, which asks again of every rewritten instruction (`check.Failure.breach`).
- Copy lowering's free locations: a register a move between two memory locations goes through, and a location a cycle's value is saved into. Each free one is tried by making the moves through it into a function of their own, and the first under which every instruction stands is taken. When every free one breaches, the copy is refused with `Reason.constrained`.
- The frame code's scratch: `code.make` makes a move under each scratch it is offered in turn, the frame's being every register calls clobber of the stack pointer's class that carries nothing, and copy lowering's every free register of that class. When none stands, the code refuses with `Refusal.constrained`.

## Grouping

How many registers an operand's group covers can depend on state no operand holds, as RISC-V's vtype sets SEW and LMUL. A machine instruction states the vector state it runs under, `mirl.machine.vstate.State`, which holds masc's public record (`masc.riscv_vtype.Vtype`: SEW, LMUL, tail and mask policy). It is spelled `vtype e32, m2, ta, ma` in the text form and read by masc's vtype reader. `vstate` is the one module of the machine form that names a set's record.

- An instruction whose row has no operand of a vector class answers masc's `UNIT`, where every operand is one register a group and `UNIT` is exact.
- Any other answers masc's grouping of its row (`vstate.grouping`): `riscv_vtype.grouping(row, vtype)` under the state it states, or `constraint.grouping(operands, count, none)` when it states none. The second forms the groups of a row no state decides, as a whole register load (`vl2re8.v`) or an x86 or AArch64 vector register, and answers `needs` for a row whose spans or element widths turn on a state. masc owns every operand's element width against SEW and LMUL for widened, narrowed, extension, segment and mask operands, and mirl restates none.
- The instruction checker refuses a state on an instruction whose row needs none, as a scalar row or a whole register load, and an instruction whose row needs a state it does not state. So an instruction states one exactly when masc says its row turns on one.

`covers` is how many registers of its class one value of an operand covers under a grouping: its fields back to back, each a group of the length the grouping states, one for a group within one register.

## Groups in allocation

A value whose group covers several registers holds all of them. Liveness gives each virtual register a span, the most registers any operand naming it covers, and a physical operand's group reads or writes every register of it. The scan holds a bundle at every register its span covers from its location: each is busy, free and held as the location itself is, so interference and eviction see the whole group, and a location fits only when every register of its group exists, is allowed and is of the bundle's classes. The allocation checker places each value at every register of its group before it sweeps for two values that meet.

## Limits

- A value of a span past one is never carried in pieces, untied or given a value of its own, since no copy, spill or reload moves a group, so a round that would do so is refused with `scan.Error.grouped`, and such a bundle is never evicted. A pseudo copy of a vector class moves one register.
- Copy lowering states no move of a vector class, so it cannot save a vector register's value through a free one.
- A destination masc reads as well as writes, as a vector destination under an undisturbed tail, is live before its instruction, so liveness keeps it apart from the sources even where the overlap rules would permit sharing.
