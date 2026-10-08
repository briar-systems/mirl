# mirl

mirl is the intermediate representation and code generator of the mach toolchain. It is a library and a program written in mach. A front end builds mirl IR through the builder API, or writes it as text, and mirl optimises it, legalises it for a target, selects instructions, allocates registers, lays out frames, applies calling conventions and produces debug information.

## Place in the toolchain

```
mach -> mirl -> masc -> mink
```

- **mach** is the language front end. It hands mirl the IR.
- **mirl** is the IR and code generation. It hands masc assembly in masc's model.
- **masc** is the assembler. It owns instruction sets, registers and encodings, and hands mink objects.
- **mink** is the linker. It owns object formats, architecture identity and relocations.

mirl never reaches past masc. A front end asks mirl for data layout and calling conventions and never computes either itself.

## Parts

- `mirl.ir` holds the types, values, instructions and modules, and `mirl.ir.text` the text form. The IR is in SSA form with block parameters, and every opcode's typing rule and effects live in one table.
- `mirl.build` is the builder and `mirl.verify` the verifier.
- `mirl.target` is the target record. A target declares its capabilities, data layout and calling conventions as data, and the pipeline is chosen from those declarations.
- `mirl.pass` holds the pass contract and schedule, `mirl.opt` the optimisation passes and `mirl.legal` legalisation.
- `mirl.machine` is the machine form below the IR, with selection, register allocation, frames, block layout and emission as its children.
- `mirl.debug` produces debug information from the IR's debug tables, and `mirl.ct` preserves and validates secrecy and constant time.
- `mirl.structure` turns any control flow graph into structured regions for the SPIR-V (`mirl.spirv`) and WebAssembly (`mirl.wasm`) families.

The IR is specified in [doc/ir.md](doc/ir.md).

## Building

mirl builds with mach 6.10.1 or later.

```
mach dep pull .
mach build .
mach test .
```
