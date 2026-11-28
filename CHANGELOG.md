# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release groups its entries under `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed` and `Security`, and marks a breaking change inside the entry.

## [Unreleased]

## [0.5.0] - 2026-11-27

### Added

- `mirl.machine.lifetime` checks a machine function's slot markers: they alternate on every path, and every instruction that names a marked slot, or reaches it through a register that surely holds its address, stands inside the slot's lifetime. `mirl.machine.verify.storage` runs it (#838).
- `mirl.ir.module.secret_in` is the one question a pass asks of a secret mark: the mark says secret and the function requires constant time (briar-systems/mach#5071).
- `mirl.legal.handover` gains `lent`, `stands_until`, `stands_across`, `own_before`, `unwritten`, `stored` and `stored_whole`, so the abi legalisation and the inliner judge a value handed over, in either direction, by one rule (#811, #829). `mirl.legal.overlap.writers` lists the writers of a contained slot (#829).
- `mirl.pass.analysis.MOVES` and `GATHERS` name the analyses an instruction move and a preheader gather keep (#822).
- `mirl.machine.pseudo.copies` says which pseudo-instructions are copies, and `mirl.base.slice.reset` sizes a vector to a length, clearing it first (#805, #838).

### Changed

#### The library contract

- Breaking: a use entry is a `mirl.ir.value.Use`, the instruction and the operand (`edge = OPERAND`) or edge argument that names the value, and a predecessor entry is a `mirl.ir.block.Predecessor`, the instruction and the edge. `BlockData.predecessors` holds `Predecessor`, `mirl.ir.body.uses` answers `Slice[Use]`, use lists live in their own pool `Body.uses`, and `mirl.ir.module.Error` gains `listed` and `preceded` (#844).
- Breaking: `mirl.ir.cfg.flow` takes each block's gen and kill as lists and answers each block's live sets as ascending lists. `Sets` is replaced by `Problem` and `Work`, and `backward` and `forward` take a work, a problem and the output lists and can fail on allocation. `mirl.pass.analysis.live.compute` no longer takes dominance (#801).
- Breaking: the facts of which slots escape, move and are touched are their own analysis, `mirl.pass.analysis.ADDRESSES` (`slots.Addresses`, `addresses_of`), and the analyses after it renumber with their `OF_` sets. `slots.compute`, `slots.of` and `memory.make` take the addresses, and `escaped`, `moved` and `touched` read them, answering yes for an instruction past what they cover. `slots.readable` and `slots.secret` are removed (#822, #826).
- Breaking: `mirl.machine.frame.share.share` takes whether the function requires constant time, and `mirl.machine.verify.function` takes whether the function's markers still state its slots' storage (#805, #838).

#### IR a front end builds, and the verifier

- Breaking: the verifier refuses a use of a marked slot's address where the slot may not be begun on some path, not yet begun or already ended. The uses checked are an operand of an instruction that reads or writes memory and a return, of the alloca or of any value derived from its address. Forming an address above the begin stays legal, and an access of no bytes counts as an access. `--verify` also checks the machine form from selection until frame sharing, and a refusal from a machine step names the step and the fact (#838).
- Use and predecessor lists are kept consistent by construction. Taking an entry out updates the one entry it moves through its own back-pointer, every build checks the entries an edit touches, and an inconsistent list refuses the compile with `listed` or `preceded` where it went on with wrong positions. The verifier checks that every entry is named back by its operand or edge and the other way round (#844).

#### What the optimizer does to code

- A `^` (secret) value is optimized as any other value outside a function that requires constant time. Marks, access statements, kept stores, `$zeroize` and the call contract are unchanged, and inside constant-time functions nothing changes. A public value that takes a secret one's place, as a fold of `xor(x, x)` does, lowers the secrecy of what it feeds, and a secret division outside constant time runs the target's divide (briar-systems/mach#5071).
- Frame slots of different sizes that are never live together share one storage outside constant-time functions. Slots are taken largest first, so a group never grows. A constant-time function keeps its rule of one size, one secrecy and the same public bytes, and its code is unchanged (#805).
- The slots the abi legalisation makes for one call are begun and ended inside the call's block, so they are live only for that call and share frame storage with other slots. A by-value stack argument is copied once, straight from the memory it was loaded from into the outgoing area, wherever that memory is proven unchanged until the call, including across blocks (#829).
- An expanded call hands its aggregate arguments and results over as the call does. An argument the callee only reads is read in place, one it may write is copied once with a `mem.copy`, and a result stored into memory the callee may name is copied out once at each return, where each crossed a block edge word by word. A release build of mach has 89% fewer word moves (#811).
- Store-to-load forwarding crosses block edges. A constant stored on every edge into a join reaches a load there, differing constants become a parameter of the join, a load leaves its bytes known like a store, a compare against a constant refines a value across that branch's edge, and a `mem.copy` between frame slots carries what its source held. Bypass and jump threading move slot markers out of the way, so the test of a case an expanded call's returns stored is threaded to the arm each return decides (#812, #823).
- On wasm the globals that name one section share one data segment, so the link keeps or drops them together as it does a section on ELF, COFF and Mach-O. A global that names no section keeps a segment of its own (#814).

#### Compile time

- The liveness the allocator, frame sharing, the slots analysis and hoisting read is solved fact by fact over lists, where every function filled tables of blocks by values. Its time follows the input and the solution, not the square of the function (#801).
- LICM keeps the ranges, the addresses and the memory analysis across the loops it edits, so a large function no longer solves the slots analysis again after every loop. A release build of mach takes about 3.5% fewer instructions (#822).

### Fixed

- Taking an instruction or an edge out that names one value in several operands or arguments, as the wide legalisation's split edges do, no longer leaves stale positions in the value's use list, which could stop a compile with an internal error under `--verify`, as in a constant-time 128-bit accumulator (#835).
- mirl builds again for a host whose `usize` is 32 bits, such as mach built for wasm32-wasi, where a wasm data segment offset was converted to `usize` before being passed as the `u64` it is (#841).
## [0.4.0] - 2026-11-27

### Added

- `mirl.ir.opcode.table.named` answers an operation's name with its opcode, read from the table's own row names, and the text parser looks an operation up through it (#788).
- `mirl.target.steps` is the one owner of the walk from an address to what it is formed from and of how far each step moves it (`past`, `from`, `former`, `root_of`, `moved_by`, `formed`, `add`, `gap`, `wrap`, `element_offset`), and `mirl.target.layout.address` answers a space's address size, none for a pointer with no representation in memory. `layout.pointer` reads it, with the same answers and errors as before (#803).
- `mirl.legal.handover` holds the rule by which a call's aggregate result is built in place, which the abi legalisation and the inliner both judge by (#794).
- `mirl.ir.cfg.rounds` visits the changed nodes of a graph in the order rounds over a block order would, and `mirl.ir.cfg.flow.forward` is the forward mirror of `flow.backward` (#793).
- `mirl.pass.analysis.memory.contained` says whether an access at a constant offset inside a global the module defines cannot fault (#784).

### Changed

#### Dependencies and the library contract

- The manifest requires mink `^0.2.0`, and mirl builds against mink 0.2.0 and masc 0.2.2.
- Breaking: `mirl.machine.alloc.remade.of` takes an allocator first, for its worklist, and replaces what `out` held in place of appending to it (#793).
- Breaking: `mirl.ct.global.secret_at` and `of_secret` are replaced by `reads_secret`, which takes the read's type and sizes the global in the space of the address that reaches it. `mirl.ct.global.size` is no longer public, and `mirl.ct.global.Reach` gains a `space` field (#803).
- Breaking: `mirl.legal.overlap.root_of` moves to `mirl.target.steps.root_of` (#803).
- Breaking: `mirl.machine.inline.Inline` has no `reads` field, since an asm block states no read beyond its operands (#782).
- Breaking: `mirl.pass.analysis.memory.Place` gains `starts`, the least and greatest offset the access may start at (#784).

#### IR a front end builds, and the verifier

- Breaking: an address's offsets are read as the machine adds them: an offset or index is signed at its own width, and an index times its stride and every sum of steps wraps at the width of the root's pointer. On a target with 32-bit pointers (riscv32, wasm32) this changes what the verifier, the constant-time walk, the slots analysis and the copy-overlap order see for a very large constant index or offset. A read that states no secrecy and reaches a global's secret bytes only once wrapped is now refused with `verify.secret` where it was accepted, and it is refused where it stands in the input, where `--verify` refused it after the address legalisation and blamed that pass. 64-bit targets are unchanged (#803).
- The verifier accepts a read the front end states `#[public]` even where its address reaches a global's secret bytes, taking the statement as the front end's word, and still refuses a read that states nothing and gives a public result. The verdict no longer depends on whether a pass such as `promote` exposed that the address came from the global, and the constant-time walk is unchanged (briar-systems/mach#5054).

#### What the optimizer does to code

- The inliner expands a callee under the small size at every call standing in a loop, where a call stands in a loop when it is inside a loop of its caller or its caller is carried into one. A function is carried when it is called from such a call and is small enough to be copied there, so a chain of small helpers a loop reaches is expanded at every level (#783).
- The inliner measures a callee by what its expansion costs: the size promotion leaves less the slot every return hands back whole and the loads of it only a return reads. The size rule, the cross-module offer and the carried-into-a-loop rule all decide on that measure (#804).
- An expanded call returning an aggregate builds its result in the destination the call's result is stored to, as the abi does for a call, where the result lived in two slots with a whole copy between them. The register and wasm families run `split` and `promote` again after the aggregates and vectors are taken apart, so a slot an aggregate went through is promoted leaf by leaf. A byte the callee never wrote now reads as the destination's old contents (#794).
- The alias analysis holds two accesses apart by the offsets the value ranges bound, and the range analysis recognises a counted loop in the shape rotation leaves. LICM moves a loop-invariant load whose place no group holds when no barrier touches it, and treats an access at a constant offset inside a defined, not replaceable, not thread-local and not placed global as one that cannot fault (#784).
- An expansion gives every copied slot whose markers it does not keep the copy's own extent, begun at the copy of the entry and ended at every return, so those slots share frame storage where they lasted the whole caller (#802).
- The back end's `alloc.remade`, `addressed`, `frame.share` and `alloc.value` passes read a function once or revisit only what changed, where they swept it until nothing changed. The code they produce is unchanged and a release build of mach takes about 10% fewer instructions (#793).

### Fixed

- An asm block is stated to read no register beyond its operands, so a data directive with a `writes` clause is no longer refused with "values no location holds and no split helps", and argument and callee-saved registers a block reads are no longer held live from the entry (#782).
- x86-64 and SPIR-V with `Int8` select a one-byte `bswap`, which x86-64 refused and SPIR-V left unselected.
- mirl builds for a host whose `usize` and pointers are 32 bits (#796).
- The alias analysis takes two accesses apart by an exact offset compare only when each ends below 2^(bits-1), since an access crossing it wraps onto the most negative offsets, and an access of no stated size is never held apart by offsets (#784).
- Frame sharing never lets a slot only markers name head a group, which dropped the storage of the group's other slots (#802).
- A check that an access lies within a slot, in selection, the bulk legalisation and the slots analysis, cannot wrap for an offset near 2^64, which took a load below a slot as an access of the slot in place.

## [0.3.4] - 2026-11-27

### Fixed

- A frame under `win64` or `aapcs64win` states its call frame rules as the unwind table of its object's format takes them. In an object whose format writes no Windows unwind codes, as a freestanding ELF image, it states every rule of its prologue and of its epilogues and marks neither a prologue's end nor an epilogue's scope, where it stated them as the codes take them whatever the format. `--emit asm` of such an object was refused as an internal error, and on x86-64 its `.eh_frame` held the body's frame address through every epilogue. The code of a function is unchanged, and so is every PE, Mach-O and other ELF object (#780).

## [0.3.3] - 2026-11-27

### Added

- `base.stats.Stats.progress` takes a `Progress` that follows a compilation as it runs: `opened` when a stage begins with how many functions it knows it will take, `grew` when it learns of more, `begun` and `finished` around each function, and `closed` when the stage is done. The neutral prefix, the register machine and the wasm and SPIR-V families call it (#768).

### Changed

- `mirl compile`, `mirl verify` and `mirl fmt` write mach 7.2.0's output language. A result on stdout says `built`, `verified`, `formatted`, `unchanged` or `failed` with its fields, and never shares stdout with output written there. `-v` logs each stage to stderr as it closes, `-vv` adds each function and the target's facts, warnings and errors are blocks with a blank line after each, and on a terminal a live line names the stage that runs (#768).

## [0.3.2] - 2026-11-26

### Changed

- The manifest requires masc `^0.2.0` (#773).

### Fixed

- The wasm back end states each imported function from names the object already holds, with masc's `import_named`, instead of passing a view of its name that interning the module `env` could move out from under it, which gave imports corrupted names (#773).

## [0.3.1] - 2026-11-26

### Fixed

- A SPIR-V build with logical addressing and no `VariablePointers` no longer refuses a pointer the optimiser merges where paths join, as cse and unroll do for a store past a loop. `legal.merges.POINTER_MERGES`, run in the spir-v family once the optimiser is done, takes out each block parameter or select of such a pointer. Where the pointers share one chain of steps from a root it carries the differing indices and rebuilds the address, a select of different bases becomes a branch, and a parameter of different bases has its block's reads copied onto each edge. One it cannot take out is refused as `pass.refusal.Error.merged`, which names why. Promotion no longer keeps a pointer slot whose stores merge, and the verifier's `merged` rule holds the legalised stages to the invariant (#769).

## [0.3.0] - 2026-11-25

### Added

- A module's debug table states the directory it was compiled in. `ir.debug.place.state_directory` records it, `ir.debug.place.directory` reads it back, and the text form writes it as `directory = "...";` at the head of the debug block. The debug records name it as the unit's directory, its `DW_AT_comp_dir`, or `.` for a module that states none. A text read into a module that already holds others (`ir.text.parse.parse_into`) keeps the module's own directory, and where the text's directory differs, its relative file paths are joined to it (#762).

## [0.2.0] - 2026-11-25

### Added

- `target.options.Options.scheduled` names a writer for the module's text once the pass schedule has run, before the constant-time gate and the back end, as `mirl compile --emit ir` prints it. `target.compile.compile` writes it there, and a text that cannot be written is refused as `family.Error.scheduled` before the back end runs (#760).

### Changed

- The manifest requires mach `^7`, and the workflows build with mach 7.0.0.

## [0.1.0] - 2026-11-23

### Added

- Initial release of `mirl`, the intermediate representation, optimizer, and code generator for Mach 7 targeting `x86_64`, `x86`, `aarch64`, `riscv64`, `riscv32`, WebAssembly, and SPIR-V, with SSA verification, optimization passes, instruction selection, register allocation, calling convention legalization, debug info generation, and constant-time lowering checks.
