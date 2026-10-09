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
- A move between two registers or cells is the set's move for their classes. Between a register and a slot it is the frame code's load or store at the slot's place and size, as the frame expands a spill or reload (doc/machine/frame.md).
- Between two memory locations, slots or cells, of one storage through the selection, it is two moves through a free location that holds the whole value, chosen by the value's storage and never from a fixed class: a register the frame code both loads and stores at a slot's size, or a location the set moves a cell into and back out of exactly. One function, `holds`, makes that choice for every free location the lowering takes, so a value saved to break a cycle goes where it fits the same way. Two memory locations of different storage are refused, since no move between them states how the value changes size.
- Where no free location holds the value, a copy between two slots of a fixed size is split into exact parts through one free register, at offsets into both slots. Each part is the widest the frame code both loads and stores that register at, no more than the bytes left and no wider than the alignment both slots keep at its offset, so an RV64 copy of 16 bytes is two `ld` and `sd` pairs and an RV32 copy of 8 bytes two `lw` and `sw` pairs. No move takes fewer bytes than the slots hold. A value no location holds and no split moves is refused.
- The pairs of a parallel copy are ordered by the storage each one touches, as masc states which registers share storage: a pair is written once no other pending pair reads a location that shares storage with its destination. A pair whose source and destination share part of their storage is its single move, which reads before it writes. Two pairs whose destinations share storage are refused, since no order writes both.
- When every pending pair is in a cycle, the first pending pair's destination is cleared of readers: each pending pair reading storage it shares has the value it reads saved in a free location that holds all of it, and reads it from there. Where one of them finds no free location and the set states a swap for the pair's two locations, the swap breaks the cycle instead, when it moves only values pending pairs read whole: a pending pair writes the pair's source exactly, and every other pending pair reading storage either location shares reads that location exactly.
- A free location is one the allocator was allowed to assign that a call clobbers or the frame saves, so writing it never reaches a caller, and that holds no value across the copy, read from liveness of the framed function: no hold of it or of any location sharing its storage meets the copy's use or def slot. The liveness states no call clobbers, which only makes a location busy longer.
- The free location taken is the first, by class key and then by location, that holds what it is taken for and under which every instruction of the moves through it stands against its row's register constraints, each tried by making those moves into a function of their own. On RISC-V a general register comes before a float one, so an 8 byte slot copy goes through f only when no x register is free. The frame code's load or store is offered every free register of the stack pointer's class as its scratch for an address the same way (doc/machine/constraint.md).
- The call frame facts and the origins follow the instructions: a fact before an instruction stands before the first one it became, one after it after the last, and one after a copy that disappeared before the instruction that follows.

## Refusals

A copy is refused, naming it and the operand where there is one, when an operand is no register, cell or slot, a partner labels it, it states implicit locations, two pairs write storage one location shares, the set states no move for a pair directly or through a register, two memory locations differ in storage or have no free location holding their value and no split into parts, a cycle has no free location and no swap, every free location breaks a register constraint of the moves through it, or it names a slot the frame dropped. A refusal by the frame code or the function's maker is its own case. A pair is never spilled to break a cycle.

## Limits

- A cycle through locations that share part of their storage, with no free location for a value one of its readers needs, is refused as a cycle: the swap moves whole locations only, and the lowering knows which locations overlap but not which part of one another is, so it cannot follow a part of a swapped value.
- A cell is never a free location, since a convention states no cell a call clobbers, so a cycle of cells is broken only by a swap.
- RISC-V states no move between classes, since selection places no copy between them.
- A cell is moved whole by the set's moves, so a copy of cells no free location holds is refused rather than split, and so is a split of a slot whose size scales.
- A split takes its parts greedily, the widest first, which covers every size where the widths are the powers of two up to a byte, as on every set carried now. A set whose widths are not would need a search over the sums of its widths.
