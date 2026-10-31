# Loops

An operation no instruction does, and no straight-line expansion can do, is a loop. A read-modify-write the set has no instruction for is the case in point: a load-reserved and store-conditional pair with the update between them, run again until the store succeeds. Selection emits a loop as one instruction of the machine form with its operands and scratch registers stated, allocation places them like any others, and `mirl.machine.loop.expand` writes the loop's steps once the frame and the lowering of copies are done. Nothing between selection and that expansion can put an instruction inside a loop, so no spill or reload lands in its reserved region.

```
expand(a, ?framed)                                # err[expand.Error]
```

## A loop's row

A target states each loop as data, a `mirl.machine.loop.Loop`:

- `name`, its spelling in the text form, unique among the set's loops,
- `constraint`, the shape its body keeps, one its set states (see below),
- `roles`, one per operand position: a register the loop reads, one it writes, never both, or `NONE` for a parameter, an immediate such as the width of a field,
- `before`, the steps that end the block the loop stands in,
- `body`, the steps of a block of their own, which branch back to its start,
- `after`, the steps that open the block after the body,
- `jump`, an unconditional jump, which ends the block before the body and the body.

`before`, `body` and `after` are parts, each a list of step lists run in order, so loops share the lists they have in common as data rather than as copies. A step is a row of masc's catalog and one source per operand position: the loop's operand at a register position, a literal immediate, enumerant or condition, a formula, a fixed register of masc's file, the memory at the address a register operand of the loop holds (`address`), as x86's `lock cmpxchg` names its destination, the body (`head`), the block after it (`exit`), or, in the jump alone, the block it goes to (`target`). A formula is an immediate computed from the parameters, two scaled parameters and an offset, as the register width less the field width. `mirl.machine.loop.row.check` refuses a loop that breaks this shape, a source naming a parameter as a register or a formula naming a register position, a body with no step back to its start, or a step reading an implicit register or flag no earlier step writes for certain, implicitly or through a fixed register it names at a position it writes, as x86's loops load the accumulator `cmpxchg` reads. The check reads the target's register file, which tells a fixed register from the rows an effect names.

A loop with no body is a straight sequence: its `before` and `after` steps expand where it stands, and it names neither block. It is for an operation one instruction does once its operands are prepared by steps the loops on it share, so its preparation is the same data as theirs.

## The constraint

A body is built around one of three kinds of access, `Constraint.kind`:

- `llsc`, a load-reserved and store-conditional pair. A core guarantees that the pair eventually stores only for a body of a constrained shape, as RISC-V's constrained `lr` and `sc` loop and AArch64's exclusive pair require. Without it a loop can livelock on real cores, which no test of the expansion would show.
- `cas`, one compare and swap, a row that reads and writes memory in one access, as x86's `lock cmpxchg`, AArch64's LSE `cas` and RISC-V's Zacas `amocas`. The body runs again while the value the swap found is not the one it expected. A swap fails only when another store succeeded, so no guarantee of the core is needed, and the swap's register that gives the value found is one its row reads and writes.
- `plain`, neither: a body held to its limit alone, and every straight sequence, which has no body. `mirl.machine.loop.row.SEQUENCE` is the constraint of a straight sequence.

A set states a constraint for each kind it writes loops of, and each loop names its own, a `mirl.machine.loop.Constraint`:

- `kind`, `llsc`, `cas` or `plain`,
- `limit`, the most instructions a body holds, its jump out counted,
- `plain`, the extensions a step other than the atomic access may require,
- `atomic`, the extensions the reserved pair or the swap requires, so a plain load or store is neither.

`mirl.machine.loop.row.constrained` holds a body to its loop's constraint and refuses by a typed `Breach`: a body past the limit (`long`), under `llsc` one that does not open with the load of the pair (`opened`), a step touching memory other than as its kind's atomic access, a second store or a second swap (`access`), no store of the pair under `llsc` or no swap under `cas` (`stored`), a step needing an extension past the plain ones or serialising as a fence or a system instruction does (`row`), a step transferring control other than by a conditional branch (`branch`), and a branch back to the start before the store or the swap, or a second one (`retry`). Under `plain` only the limit is held. Rows are admitted by the extensions masc states for them and by their effects, never by a list of opcodes. A straight sequence keeps any constraint.

The selection engine refuses a table whose rule emits a loop that breaks its constraint, as `breached`, or a loop the set's loops do not hold. The text form refuses a set's loops when one breaks its constraint.

The expansion reads nothing but this row, so a target's loops are added as rows and never as code. The families the schema is written against:

- RISC-V without a single instruction: `lr` and `sc` in the body, which repeats while `sc` reports failure, and a compare and exchange leaving to `exit` as soon as the value held is not the one expected. The aq and rl bits of the pair are two parameters, which the rule maps from the ir's ordering, so one loop serves every ordering.
- RISC-V with Zacas and no Zalrsc, under `cas`: the value held loaded plainly in `before`, the body's `amocas` with the value expected in its destination, which gives the value found there, and a `bne` back while the two differ.
- RISC-V on a byte or halfword without Zabha: one field loop per operation with the field width and the register width as parameters, its `before` the shared steps that find the field in its aligned word, its `after` the shared steps that give the field back, and a body that merges the new field into the word held. And, or and exclusive or are straight sequences around one word instruction.
- AArch64 without LSE: `ldaxr` and `stlxr` in the body, `cbnz` back to it, and a compare whose flags the body writes before its `b.ne` to `exit` reads them. A compare and exchange of two words has no branch out: `ldaxp`, `csel` of the words to store and `stlxp` of them in every case, since an exclusive pair of two words is atomic only where its store succeeds.
- x86's nand, under `cas`: the first load of the value in `before`, the body's `lock cmpxchg` repeated while it fails, and the value held left in `rax`, which the steps write and so the loop clobbers. AArch64 with LSE is the same shape around `cas`.

## What allocation sees

A loop writes before it has read all it reads, since the body runs again after it writes. A straight sequence is taken the same way, which costs it nothing it needs. Liveness places every write of a loop at its use slot, so a register it writes is none of the registers it reads, and the machine form refuses a loop naming one of its written registers at another position. Each step's registers come from masc's `touched` as any row's do (doc/machine/constraint.md). A register a step reads is read by the loop only when no earlier step writes it for certain, and of the steps' flags only the writes are seen, since a step reads only flags an earlier step wrote. A register a step's row fixes an operand to is the pin of that operand, and every choice of a location for a loop's operand asks the register constraints of each step's row (doc/machine/constraint.md). The frame counts a loop's steps' implicit writes as it counts any row's.

Selection admits a rule whose expansion holds a loop only when the target's selection admits every row of the loop, and the table check refuses a loop that breaks the schema. A rule passes a parameter as any immediate source, and as `width`, the bits of a value's integer type, or `register`, the bits of the target's general register. The machine form checks each formula's immediate against its step's row when the loop is made.

## The expansion

- The block a loop stands in ends with its `before` steps and the jump to the body. The body is a new block, ending in the jump to a second new block, which opens with the `after` steps and holds every instruction that followed the loop.
- Layout keeps the body whole, since it never moves an instruction between blocks. It drops a jump to the block that follows, and threads nothing away from a body, which never only jumps.
- Every step carries the loop's metadata. The call frame facts and the origins follow the instructions as the lowering of copies has them.
- The function changes only when every loop expands. A straight sequence writes its steps in the block it stands in. A loop is refused, naming it, when it breaks the schema, an operand is no register or a parameter no immediate, a partner labels it, it states locations beyond its operands, or its jump does not leave unconditionally for its target. A refusal by the function's maker is its own case.

## The text form

A loop is spelled `loop <name>` and its operands, a parameter as its number: `loop field_add x10, x11, x12, 8, 64, 3, 1, x5, x6, x7, x28, x29`. The environment of a text holds the loops of its set's record in the registry the caller hands the text (`mirl.machine.isa`), indexed by name once. A loop no stage expanded is refused by emission as a pseudo.
