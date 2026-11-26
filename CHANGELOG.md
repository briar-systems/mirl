# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release groups its entries under `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed` and `Security`, and marks a breaking change inside the entry.

## [Unreleased]

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
