# Register constraints

masc states each row's operand register constraints on `row.Row.constraints`: an output written before every input is read, two operands that must differ, a register group kept apart from another or from a mask register. `mirl.machine.constraint` is the one place mirl asks them, through masc's `constraint.violated`. mirl states no constraint of its own and keeps no list of constrained rows.

```
grouping_of(f, op)            # res[Grouping, u32]
ask(f, op, values)            # opt[Breach]
stands(f, op, operands)       # opt[Breach]
```

`ask` hands masc the instruction's operand values under its grouping and answers the breach, or none when every constraint stands. A virtual register is a value not chosen yet, which masc reads as one that may take any register. A constant goes to masc as its position's kind: an immediate, an enumerant or a condition.

## Breaches

- `broken`: a constraint the values break.
- `outside`: an operand whose group runs past the last register of its class, answered only where the grouping states its length.
- `inexact`: a constraint with a gap (`SEW_INDEX`, `INDEX_OVERLAP`) whose registers the values share. The state no operand holds decides whether the form is reserved, so it is never read as clear. The constraint names its gap and its sides.
- `unknown`: an operand of a vector class, whose groups depend on vector state the machine form does not carry.

Each one is a conflict for the choice that met it, never a refusal by itself.

## Where it is asked

- The allocator's scan, at every location it considers for a bundle: the copy hint, each free candidate, and each candidate whose bundles it would evict. The bundle is at the candidate, every other operand at its bundle's location, at its pin while it has none, or not chosen yet. A bundle no location of its class stands at is refused with `scan.Error.constrained`, naming the instruction and the breach at the first location tried.
- The allocation checker, which asks again of every rewritten instruction (`check.Failure.breach`).
- Copy lowering's free locations: a register a move between two memory locations goes through, and a location a cycle's value is saved into. Each free one is tried by making the moves through it into a function of their own, and the first under which every instruction stands is taken. When every free one breaches, the copy is refused with `Reason.constrained`.
- The frame code's scratch: `code.make` makes a move under each scratch it is offered in turn, the frame's being every register calls clobber of the stack pointer's class that carries nothing, and copy lowering's every free register of that class. When none stands, the code refuses with `Refusal.constrained`.

## Grouping

How many registers an operand's group covers can depend on state no operand holds, as RISC-V's vtype sets SEW and LMUL. The machine form carries no vector state, and selection produces no operand of a vector class, since every target scalarises its vector operations (`declared.VECTOR` on RISC-V). So `grouping_of` answers masc's `UNIT` for an instruction whose row has no operand of a vector class, where every operand is one register a group and `UNIT` is exact. For any other it answers the first operand of a vector class, which `ask` reports as `unknown`: machine text that names a vector row is refused when allocated rather than allocated as one register a group.

## Limits

- An instruction with an operand of a vector class is refused in allocation, and copy lowering cannot save a vector register's value through a free one. The machine form carries no vtype yet, and masc states no operand's element width against SEW and LMUL (#232, blocked by briar-systems/masc#164).
- A row whose vector operand is always one register, as a whole-register move or an x86 or AArch64 vector register, is refused the same way, since masc states no fact that sets it apart from a grouped one.
