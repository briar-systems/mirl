# Block layout and emission

`mirl.machine.layout` orders the blocks of an allocated and framed function and settles its branches. `mirl.machine.emit` hands the laid out functions of a module to masc, which encodes them into mink's object. This is the last stage of a register machine. mirl never encodes a byte and never writes an object file.

```
compile(a, ?module, ?machine, ?target)             # res[object.Object, compile.Error]
lay(a, ?function)                                  # res[Laid, lay.Error]
emit(a, ?module, ?machine, ?target, units)         # res[object.Object, emit.Error]
```

`mirl.machine.compile.compile` is the one entry a consumer of the library calls, and it returns the object in memory. `emit` is the hand-over it ends in. The machine form text is the one text hand-over: a function read from it is the same function and emits the same object. masc's listing of the result is for debugging.

## Compilation

- `compile` takes a module the pass schedule has run on, the target's machine opened, the target and the allocator. A machine opened for another target than the one given is refused at entry (`Error.foreign`), before anything is compiled. The machine reaches its selection table, frame code and moves through the row of `mirl.target.register.isa` carrying the instruction set its basis holds (`isa.of`), which masc found once when the machine was opened, so compilation names no set and looks nothing up by architecture again.
- Every function with a body is selected with the convention's clobbers, allocated over the locations `allowed.of_machine` lists, framed, its copies lowered to the set's moves (doc/machine/copy.md), its loops expanded (doc/machine/loop.md) and laid out. The functions are then emitted into one object.
- The steps are stated once, as the rows of `STAGES`, each a name and a run that reads the form the steps before it left (selected, allocated, framed, laid out) and gives the next. `through` runs one function through a sequence of steps, verifies it after each when the compilation is checked and hands it to a `Watch` when one is given. `compile` runs `STAGES` with no watch. The machine corpus walk (`src/machine/corpus.mach`) runs the same `STAGES` through `through`, its clobber and piece checks attached to the steps they name, so a step added to `STAGES` runs there with no edit to the walk.
- A function refused at a step is `Error.function`, naming the function, the step and what refused it with its own error. A step given a form the steps before it did not leave is `Stage.misplaced`, and a sequence that ends before layout is `Stage.unfinished`. A refusal before any function, or by emission, is its own case.

## The entry and `mirl emit`

- `mirl.compile.compile(a, ?module, ?target, options)` is the entry mach calls. It opens the build's machine with the extensions `options.added` names, runs the pass schedule at `options.level` and hands the module to the back end the target's declarations choose. A register machine (allocated registers, free control, physical addressing, register evaluation) is compiled by `mirl.machine.compile.compile`. A target no back end serves is refused before anything runs (`Error.unserved`).
- `options.checked` verifies the module after every pass and every function of the machine form after every stage: selection, allocation, the frame, the lowering of copies, the expansion of loops and layout. The machine form verifier (`mirl.machine.verify`) holds that every instruction a block places is one of the function's own, placed once, and stands against its opcode's row.
- `options.machine` and `options.listing` name writers for the machine form text of the laid out functions and masc's listing of the object, in the set's default syntax. Both are written only once the object is made, so a refused compilation writes nothing.
- `mirl.compile.write(a, ?object, ?target, w)` lays the object out in the one object format the target's system states, through mink, and refuses a system that states none or several.
- `mirl emit <file> --kind machine|listing|object` is a thin wrapper over the two. A kind is a row of the command's own table. `--target`, `--level`, `--extension`, `--checked` and `--body` are read as `mirl opt` reads them, and each `--extension` names one extension the build adds to the target's baseline through `mirl.target.machine.build`.
- The example programs in `test/example/` (arithmetic, a loop, a call, a global and a recursive function) each carry a start stub that calls `main` and hands its result to `__mirl_exit`. One test walks every example through every kind, checked.

## The example lane

`test/example.sh <run>` runs the example programs. It runs locally and is never part of CI, which builds mirl and runs `mach test` only. It writes into a fresh `out/example/<run>` and exits with the number of checks that failed.

- It needs mirl built (`mach build . -a cli`), the qemu user emulator of every lane target (`qemu-riscv64`, `qemu-riscv32`) and `git`. The masc program and mink's `exec` driver are built from the pinned `dep/masc` and `dep/mink`, each as a shadow project whose dependencies are mirl's own pins, once per set of pins into `out/example/tools/`, with the compiler `$MACH` (`mach` by default). `$MASC` and `$EXEC` name built ones instead.
- The input set is every `test/example/*.mirl`. Each names the target `riscv64-linux` and states the status its program exits with in a line `; exits <n>: ...`. `test/example/exit.s` is `__mirl_exit`, which makes the Linux exit system call with no C library, and masc assembles it for each lane target.
- The lane targets are the rows of the script's `LANES`, `riscv64-linux` and `riscv32-linux`, each with masc's reading of it, mink's architecture and the qemu that runs it. An example is built for each from a copy whose target line names that target and is its only change, so an example states nothing a lane target lays out otherwise. The start stub and `exit.s` are the same at either XLEN, since Linux sets the stack pointer before `_start` and under ILP32 `a0` holds the low word of the `i64` status, which is all the kernel reads.
- Round trip: `mirl emit --kind listing` writes the builder's listing, which masc assembles under the target's selection and traits. The listing is printed from what mirl asked the builder for, so reassembling it checks the builder's encoding independently. The lane shows `masc disassemble` of both objects, diffed, when their bytes differ, and that is only for reading: an object keeps an anonymous label as a nameless symbol, which reassembly names `.LtmpN`, so the bytes of the files can differ in that name alone. What passes or fails is the `mach test` unit `roundtrip__every_example_listing_assembles_to_its_own_object`, which the lane runs once, over the examples as written, so at `riscv64-linux` only. It compares the two objects as data: every section's contents, every relocation's kind, offset and addend, and every symbol by name, that one nameless symbol by its place.
- Run: `mirl emit --kind object` writes each example's object, mink's `exec` driver links it with the exit object into a static executable, and the executable exits with the stated status under the lane target's qemu.

## Layout

- A block that only jumps is bypassed: everything that names it names the block its chain of such jumps ends at. The entry stays, so does a jump to itself, a chain that closes on itself and a jump a partner operand labels.
- Blocks are placed in a greedy topological order over the forward edges. A block is followed by its likely successor when that one is ready, the one deepest in loops and then the last listed, and otherwise by the ready block earliest in reverse postorder. Blocks the entry does not reach follow, and blocks that end in a trap go last. A trap is a row whose control is a trap.
- A jump to the block that follows is dropped. A conditional branch whose taken arm follows is inverted, so it jumps to the other arm, and the jump after it is dropped.
- The inverse of a branch is the first step of its row's relaxation in masc: the longer form of an out of range branch is its inverse over a jump. Its operands follow from the branch's by that step's sources. A branch whose row has no such form is left as it is.
- The function keeps its instruction ids, so what names an instruction, the frame's call frame facts and the labels, still does. `Laid.order` lists the blocks that stay. The function changes only when layout succeeds.

## Emission

- One builder holds the object's sections. A function is a named label exposed as a function symbol of the binding and visibility its linkage states, placed at the target's function alignment in the text section. A block is an anonymous label.
- A function symbol's size is its range: its own label and an anonymous label placed after its last instruction, before the alignment padding of whatever follows. masc measures the distance between them once it has laid the section out, so relaxation is counted and padding is not, and mirl never counts a byte. Each unit's end label is made before any function is named, so a symbol is exposed once with its range whether a call or its unit names it first. A function no unit emits states no size. A part of a function placed apart, as a cold part, would be a unit of its own symbol and range. The size is a fact of mink's neutral symbol, and how a container carries it is mink's: ELF states it as `st_size`, COFF in its function table, and Mach-O by the next symbol.
- Every global the module defines is a named label exposed as a data symbol, or a thread-local one, of its linkage and its type's size, after the functions. It is placed in the section it states, or the one its facts pick (doc/ir.md), at its alignment or its type's. A section is opened once per name, and a global naming a section the code or another global names with another kind is refused. The globals that state no section share one section of each kind. A section is aligned to `code.text` when its kind executes and to `code.data` otherwise.
- An initial value is its bytes, laid out by the data layout in the architecture's byte order, and a datum for each address in it, an absolute reference of the pointer's width to the symbol plus its offset, which masc relocates as a fixup. One every bit zero is zero fill, which holds no bytes in a zero filled section. A global the module does not define is an undefined symbol, named when an operand or a datum first names it.
- An operand takes the masc value its row's position reads: a register, an immediate, an enumerant or a condition, or a label with a fixup. A block operand is a label of the operand's own fixup. A symbol operand names the function's or global's label and takes the fixup kind the set binds its relocation kind to, read through an index of the set's bindings built once. Where several fixup kinds are bound to one relocation kind, the operand's own is taken, else the emission is refused.
- An instruction another names as a partner (`label n`, `partner n : kind`) is an anonymous label of its own, placed before it, so a pc-relative low part's relocation names its high part. The labels map one to one.
- A fixup whose relocation covers the instructions after it, as RISC-V's call pair, is written with them as one sequence, as the set's spans state. masc attaches the marker the span states.
- Alignment and fill come from the target's code declaration: `code.function` aligns each function, `code.text` aligns the section, and `code.fill` is the byte code is padded with. masc takes one byte, so a fill that is not one byte repeated is refused.
- The traits of the object that the convention owns come from the convention row (`Convention.traits`). Each RISC-V row states the float ABI, `riscv-float-abi` as `soft`, `single` or `double`. The builder passes them to the object unchanged, and masc refuses a set whose required axis is not stated.
- `instruction.fixed` is masc's `emit.fixed`: it states the same fact, a row's fixed register for an operand, so mirl keeps no reading of the effect.

## Refusals

An instruction is refused, naming the function, the instruction and the operand, when it is a pseudo no stage expanded, still names a virtual register or a frame slot, names a location of a memory-backed class, sits at an operand position emission does not give (memory, list, id, literal), names a relocation kind the set binds no fixup kind to, or has a label problem or a span the block cannot hold.

A global is refused, naming it, when its initial value holds an address and the target states no address model, it names a section another names with another kind, the data layout gives its type no extent, or an address in its initial value is wider than a datum masc relocates.

## Limits

- Call frame facts stay mirl records (`Framed.facts`) and are not handed over: masc has no call frame calls yet (#197, masc#41).
- Debug line and location facts are not carried until masc states its location API (#200, masc#42).
- Default section names mirror a mink fact, deleted by #222 (blocked by mink#214).
- Memory-shaped operand positions are refused (#43).
- The listing is refused, as `Error.listing`, for an object masc cannot state as source: one with line facts, a first section that is not `.text`, or a format with no assembly dialect (COFF, Mach-O). The round trip therefore covers the ELF targets only.
- The start stubs cannot make the exit syscall, since the IR has no inline assembly (#44). They call `__mirl_exit`, which the example lane links from `test/example/exit.s`, assembled by masc.
- `mirl emit` writes to standard output only, the object's bytes included.
