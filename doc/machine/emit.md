# Block layout and emission

`mirl.machine.layout` orders the blocks of an allocated and framed function and settles its branches. `mirl.machine.emit` hands the laid out functions of a module to masc, which encodes them into mink's object. This is the last stage of a register machine. mirl never encodes a byte and never writes an object file.

```
compile(a, ?module, ?machine, ?target)             # res[object.Object, compile.Error]
lay(a, ?function)                                  # res[Laid, lay.Error]
emit(a, ?module, ?machine, ?target, units)         # res[object.Object, emit.Error]
```

`mirl.machine.compile.compile` is the one entry a consumer of the library calls, and it returns the object in memory. `emit` is the hand-over it ends in. The machine form text is the one text hand-over: a function read from it is the same function and emits the same object. masc's listing of the result is for debugging.

## Compilation

- `compile` takes a module the pass schedule has run on, the target's machine opened, the target and the allocator. A machine opened for another target than the one given is refused at entry (`Error.foreign`), before anything is compiled. The target reaches its selection table, frame code and moves through its row of `mirl.isa.rows`, so compilation names no set.
- Every function with a body is selected with the convention's clobbers, allocated over the locations `allowed.of_machine` lists, framed, its copies lowered to the set's moves (doc/machine/copy.md) and laid out. The functions are then emitted into one object.
- A function refused at a stage is `Error.function`, naming the function and the stage with that stage's own error. A refusal before any function, or by emission, is its own case.

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

- Call frame facts stay mirl records (`Framed.facts`) and are not handed over: masc has no call frame calls yet (#197, masc#41).
- The object is checked in memory, structurally. Writing it as ELF and reading it back is #198, which waits for mink#23.
- Function symbols are global with default visibility and carry no size, since IR functions state neither linkage nor visibility (#181) and the size is unknown until masc lays the section out.
- Debug line and location facts are not carried until masc states its location API (#200, masc#42).
- Global data is not emitted, so the address of a global is refused (#196, #181).
- Memory-shaped operand positions are refused (#43).
- mirl computes a row's position among the catalog's for `relax.find` until masc keys relaxation by row (#199, masc#139).
