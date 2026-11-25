# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release groups its entries under `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed` and `Security`, and marks a breaking change inside the entry.

## [Unreleased]

## [0.2.0] - 2026-11-25

### Added

- `target.options.Options.scheduled` names a writer for the module's text once the pass schedule has run, before the constant-time gate and the back end, as `mirl compile --emit ir` prints it. `target.compile.compile` writes it there, and a text that cannot be written is refused as `family.Error.scheduled` before the back end runs (#760).

### Changed

- The manifest requires mach `^7`, and the workflows build with mach 7.0.0.

## [0.1.0] - 2026-11-23

### Added

- Initial release of `mirl`, the intermediate representation, optimizer, and code generator for Mach 7 targeting `x86_64`, `x86`, `aarch64`, `riscv64`, `riscv32`, WebAssembly, and SPIR-V, with SSA verification, optimization passes, instruction selection, register allocation, calling convention legalization, debug info generation, and constant-time lowering checks.
