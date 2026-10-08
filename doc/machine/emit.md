# Block layout and emission

`mirl.machine.layout` orders the blocks of an allocated and framed function and settles its branches. `mirl.machine.emit` hands the laid out functions of a module to masc, which encodes them into mink's object. This is the last stage of a register machine. mirl never encodes a byte and never writes an object file.

```
lay(a, ?function)                                  # res[Laid, lay.Error]
emit(a, ?module, ?machine, ?target, units)         # res[object.Object, emit.Error]
```

`emit` is the one entry a consumer of the library calls, and it returns the object in memory. The machine form text is the one text hand-over: a function read from it is the same function and emits the same object. masc's listing of the result is for debugging.

## Layout

- A block that only jumps is bypassed: everything that names it names the block its chain of such jumps ends at. The entry stays, so does a jump to itself, a chain that closes on itself and a jump a partner operand labels.
- Blocks are placed in a greedy topological order over the forward edges. A block is followed by its likely successor when that one is ready, the one deepest in loops and then the last listed, and otherwise by the ready block earliest in reverse postorder. Blocks the entry does not reach follow, and blocks that end in a trap go last. A trap is a row whose control is a trap.
- A jump to the block that follows is dropped. A conditional branch whose taken arm follows is inverted, so it jumps to the other arm, and the jump after it is dropped.
- The inverse of a branch is the first step of its row's relaxation in masc: the longer form of an out of range branch is its inverse over a jump. Its operands follow from the branch's by that step's sources. A branch whose row has no such form is left as it is.
- The function keeps its instruction ids, so what names an instruction, the frame's call frame facts and the labels, still does. `Laid.order` lists the blocks that stay. The function changes only when layout succeeds.

## Emission

- One builder holds one text section. A function is a named label exposed as a global function symbol of default visibility, placed at the target's function alignment. A block is an anonymous label.
- An operand takes the masc value its row's position reads: a register, an immediate, an enumerant or a condition, or a label with a fixup. A block operand is a label of the operand's own fixup. A symbol operand names the function's label and takes the fixup kind the set binds its relocation kind to, read through an index of the set's bindings built once. Where several fixup kinds are bound to one relocation kind, the operand's own is taken, else the emission is refused.
- An instruction another names as a partner (`label n`, `partner n : kind`) is an anonymous label of its own, placed before it, so a pc-relative low part's relocation names its high part. The labels map one to one.
- A fixup whose relocation covers the instructions after it, as RISC-V's call pair, is written with them as one sequence, as the set's spans state. masc attaches the marker the span states.
- Alignment and fill come from the target's code declaration: `code.function` aligns each function, `code.text` aligns the section, and `code.fill` is the byte code is padded with. masc takes one byte, so a fill that is not one byte repeated is refused.
- The traits of the object that the convention owns come from the convention row (`Convention.traits`). lp64d states the float ABI, `riscv-float-abi` as `double`. The builder passes them to the object unchanged, and masc refuses a set whose required axis is not stated.
- `instruction.fixed` is masc's `emit.fixed`: it states the same fact, a row's fixed register for an operand, so mirl keeps no reading of the effect.

## Refusals

An instruction is refused, naming the function, the instruction and the operand, when it is a pseudo no stage expanded, still names a virtual register or a frame slot, names a location of a memory-backed class, sits at an operand position emission does not give (memory, list, id, literal), names the address of a global, names a relocation kind the set binds no fixup kind to, or has a label problem or a span the block cannot hold.

## Limits

- Call frame facts stay mirl records (`Framed.facts`) and are not handed over: masc has no call frame calls yet (masc#41).
- The object is checked in memory, structurally. Writing it as ELF and reading it back waits for mink#23.
- Function symbols are global with default visibility and carry no size, since IR functions state neither linkage nor visibility (#181) and the size is unknown until masc lays the section out.
- Debug line and location facts are not carried: masc has no line directives.
- Global data is not emitted, so the address of a global is refused.
- A `pseudo copy` between registers is refused: no stage turns it into the target's move yet.
