# Loops

An operation no instruction does, and no straight-line expansion can do, is a loop. A read-modify-write the set has no instruction for is the case in point: a load-reserved and store-conditional pair with the update between them, run again until the store succeeds. Selection emits a loop as one instruction of the machine form with its operands and scratch registers stated, allocation places them like any others, and `mirl.machine.loop.expand` writes the loop's steps once the frame and the lowering of copies are done. Nothing between selection and that expansion can put an instruction inside a loop, so no spill or reload lands in its reserved region.

```
expand(a, ?framed)                                # err[expand.Error]
```

## A loop's row

A target states each loop as data, a `mirl.machine.loop.Loop`:

- `name`, its spelling in the text form, unique among the set's loops,
- `roles`, one per operand position: a register the loop reads, one it writes, never both, or `NONE` for a parameter, an immediate such as the width of a field,
- `before`, the steps that end the block the loop stands in,
- `body`, the steps of a block of their own, which branch back to its start,
- `after`, the steps that open the block after the body,
- `jump`, an unconditional jump, which ends the block before the body and the body.

`before`, `body` and `after` are parts, each a list of step lists run in order, so loops share the lists they have in common as data rather than as copies. A step is a row of masc's catalog and one source per operand position: the loop's operand at a register position, a literal immediate, enumerant or condition, a formula, a fixed register of masc's file, the body (`head`), the block after it (`exit`), or, in the jump alone, the block it goes to (`target`). A formula is an immediate computed from the parameters, two scaled parameters and an offset, as the register width less the field width. `mirl.machine.loop.row.check` refuses a loop that breaks this shape, a source naming a parameter as a register or a formula naming a register position, a body with no step back to its start, or a step reading an implicit register or flag no earlier step writes for certain.

A loop with no body is a straight sequence: its `before` and `after` steps expand where it stands, and it names neither block. It is for an operation one instruction does once its operands are prepared by steps the loops on it share, so its preparation is the same data as theirs.

The expansion reads nothing but this row, so a target's loops are added as rows and never as code. The families the schema is written against:

- RISC-V without a single instruction: `lr` and `sc` in the body, which repeats while `sc` reports failure, and a compare and exchange leaving to `exit` as soon as the value held is not the one expected.
- RISC-V on a byte or halfword without Zabha: one field loop per operation with the field width and the register width as parameters, its `before` the shared steps that find the field in its aligned word, its `after` the shared steps that give the field back, and a body that merges the new field into the word held. And, or and exclusive or are straight sequences around one word instruction.
- AArch64 without LSE: `ldaxr` and `stlxr` in the body, `cbnz` back to it, and a compare whose flags the body writes before its `b.ne` to `exit` reads them.
- x86's nand: the first load of the value in `before`, the body's `lock cmpxchg` repeated while it fails, and the value held left in `rax`, which the steps write and so the loop clobbers.

## What allocation sees

A loop writes before it has read all it reads, since the body runs again after it writes. A straight sequence is taken the same way, which costs it nothing it needs. Liveness places every write of a loop at its use slot, so a register it writes is none of the registers it reads, and the machine form refuses a loop naming one of its written registers at another position. Of its steps' implicit registers and flags, only the writes are seen: a read is of something an earlier step wrote. A register a step's row fixes an operand to is the pin of that operand. The frame counts a loop's steps' implicit writes as it counts any row's.

Selection admits a rule whose expansion holds a loop only when the target's selection admits every row of the loop, and the table check refuses a loop that breaks the schema. A rule passes a parameter as any immediate source, and as `width`, the bits of a value's integer type, or `register`, the bits of the target's general register. The machine form checks each formula's immediate against its step's row when the loop is made.

## The expansion

- The block a loop stands in ends with its `before` steps and the jump to the body. The body is a new block, ending in the jump to a second new block, which opens with the `after` steps and holds every instruction that followed the loop.
- Layout keeps the body whole, since it never moves an instruction between blocks. It drops a jump to the block that follows, and threads nothing away from a body, which never only jumps.
- Every step carries the loop's metadata. The call frame facts and the origins follow the instructions as the lowering of copies has them.
- The function changes only when every loop expands. A straight sequence writes its steps in the block it stands in. A loop is refused, naming it, when it breaks the schema, an operand is no register or a parameter no immediate, a partner labels it, it states locations beyond its operands, or its jump does not leave unconditionally for its target. A refusal by the function's maker is its own case.

## The text form

A loop is spelled `loop <name>` and its operands, a parameter as its number: `loop field_add x10, x11, x12, 8, 64, x5, x6, x7, x28, x29`. The environment of a text holds the loops mirl carries for its set, from `mirl.isa.loops`, indexed by name once. A loop no stage expanded is refused by emission as a pseudo.
