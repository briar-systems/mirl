# Copies

`mirl.machine.copy` turns every `pseudo copy` and `parallel_copy` of a framed register machine function into the target's moves. It runs after the frame, where every operand is a location or a placed slot, and before block layout. It names no instruction: the set states its moves as data.

```
index(a, ?table, ?locations, ?registers)          # res[Index, move.Error]
lower(a, ?framed, ?request)                       # err[lower.Error]
```

`index` is built once per target from the set's `Table`, the locations and the registers the selection gives. `lower` replaces the framed function with its copies lowered, or leaves it as it was when refused. `compile` calls it between the frame and the expansion of loops (see [loops](loop.md)), which comes before layout, and the machine corpus walk checks clobbers and entry pieces after it.

## The set's moves

A set's `Table` lists its moves and its swaps. A `Move` names the class it writes and the class it reads (`Holder`, a class row of masc's file or a memory class), the bits it moves (scaled as masc states widths), the row of masc's catalog, and what each operand position takes: the location written, the location read, or a fixed immediate. A swap is a move between two locations of one class that exchanges them.

- A move is admitted when the selection admits its row's requirements. It moves a pair only where both locations' storage through the selection is exactly its bits, so a class whose width follows an extension states one move per width and exactly one fits. RISC-V's float registers state `fsgnj.s`, `fsgnj.d` and `fsgnj.q`, and f, d or q picks one.
- The index groups the admitted moves by the pair of class keys and the swaps by class key, each list ordered by storage, so a pair's move is a binary search. A second admitted move of one pair and one storage is refused, and so is a move naming a class of no register file of the locations.
- `mirl.isa.riscv.MOVES` is RISC-V's: `addi` by zero for a general register, the sign injection of a float register at its width, and `vmv1r.v` for a vector register. RISC-V has no exchange of two registers and no copy between classes, so it states neither.

## The lowering

- A copy whose destination is the location it reads disappears, and so does that pair of a parallel copy.
- A move between two registers or cells is the set's move for their classes. Between a register and a slot it is the frame code's load or store at the slot's place and size, as the frame expands a spill or reload. Between two memory locations, slots or cells, it is two moves through a free register of the stack pointer's class.
- The pairs of a parallel copy are ordered by the storage each one touches, as masc states which registers share storage: a pair is written once no other pending pair reads a location that shares storage with its destination. A pair whose source and destination share part of their storage is its single move, which reads before it writes. Two pairs whose destinations share storage are refused, since no order writes both.
- When every pending pair is in a cycle, the first pending pair's destination is cleared of readers: each pending pair reading storage it shares has the value it reads saved in a free location that holds all of it, and reads it from there. A register's value is saved in its own class and a value in memory in the stack pointer's class, both through one choice the lowering makes in one place. Where one of them finds no free location and the set states a swap for the pair's two locations, the swap breaks the cycle instead, when it moves only values pending pairs read whole: a pending pair writes the pair's source exactly, and every other pending pair reading storage either location shares reads that location exactly.
- A free location is one the allocator was allowed to assign that a call clobbers or the frame saves, so writing it never reaches a caller, and that holds no value across the copy, read from liveness of the framed function: no hold of it or of any location sharing its storage meets the copy's use or def slot. The liveness states no call clobbers, which only makes a location busy longer.
- The free location taken is the first under which every instruction of the moves through it stands against its row's register constraints, each tried by making those moves into a function of their own. The frame code's load or store is offered every free register of the stack pointer's class as its scratch the same way (doc/machine/constraint.md).
- The call frame facts and the origins follow the instructions: a fact before an instruction stands before the first one it became, one after it after the last, and one after a copy that disappeared before the instruction that follows.

## Refusals

A copy is refused, naming it and the operand where there is one, when an operand is no register, cell or slot, a partner labels it, it states implicit locations, two pairs write storage one location shares, the set states no move for a pair directly or through a register, two memory locations have no free register to go through, a cycle has no free location and no swap, every free location breaks a register constraint of the moves through it, or it names a slot the frame dropped. A refusal by the frame code or the function's maker is its own case. A pair is never spilled to break a cycle.

## Limits

- A cycle through locations that share part of their storage, with no free location for a value one of its readers needs, is refused as a cycle: the swap moves whole locations only, and the lowering knows which locations overlap but not which part of one another is, so it cannot follow a part of a swapped value.
- A cell is never a free location, since a convention states no cell a call clobbers, so a cycle of cells is broken only by a swap.
- RISC-V states no move between classes, since selection places no copy between them.
