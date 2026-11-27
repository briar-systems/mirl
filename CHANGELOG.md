# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release groups its entries under `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed` and `Security`, and marks a breaking change inside the entry.

## [Unreleased]

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
