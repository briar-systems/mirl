# Targets, data layout and attributes

A **target** is data. It names an architecture and a system, declares what code generation needs to know about them and states the facts that data layout reads. Nothing in the pipeline reads a target's name to decide what to do. Every decision reads a declaration. A new target is a new row in `mirl.target`'s table and never a new case in a pass.

A module names its target by the target's name. The verifier's first rule requires the name to be a row of the table whose declarations are all stated (see rule 0 in [the specification](../ir.md)). The table has one row at this version, `riscv64-linux`.

## The record

A target holds

- `name`, its spelling, used for diagnostics and lookup only,
- `arch` and `system`, the names of its rows in mink's architecture and system catalogs, where the system must run the architecture,
- `caps`, its capability declarations,
- `data`, the facts data layout reads.

`mirl.target.declared(t)` says whether a target is complete. Every declaration has an unstated zero case, so a row left zeroed reads as incomplete and never as an answer. A list that may rightly be empty sits under a case of its own, so an empty list is a stated answer.

## Capabilities

The capability declarations are

| declaration | what it states |
|---|---|
| `registers` | values live in registers the pipeline allocates, or not |
| `control` | control flow is free, or must be structured |
| `addressing` | memory is addressed physically, or only by access chains (logical) |
| `values` | values are untyped, or carry their type into the output |
| `evaluation` | operations take operands from named values, or from an operand stack |
| `widths` | the address spaces and how a pointer into each is held, the register width, the widths integer arithmetic runs natively at, and the integer widths a value holds natively |
| `vectors` | none, or a vector unit with a register width, the lane counts allowed and the lane types with how each is carried out (packed or by scalar expansion) |
| `formats` | the number formats computed natively, each with the not-a-number it returns (`canonical`, `propagate` or `unspecified`), or none |
| `arithmetic` | the widths with a native multiply of the low half, the multiply forms beyond it (one row per width and sign: the high half or the whole product, as signed, unsigned or mixed operands, or none) and how a shift treats a count at or past the width (`wraps`, `undefined` or `saturates`) |
| `timing` | the operations that run in constant time, by operation, width and condition, or none |
| `code` | the alignment of a function entry, a code section and a data section, and the bytes that pad code |
| `attributes` | the attribute families the target accepts |

These describe what the target does. They do not change what an operation means. A shift by the width or more gives 0 or the sign fill on every target whatever `arithmetic.shifts` says, and legalisation bounds the count where the target would not: the shift bounding applies where shifts `wrap` or are `undefined`, and not where they `saturate`.

The ir has no high multiply and no widening multiply. Both are written as a multiply of two extensions, and the high half as that product shifted down by the width and truncated. A target selects the pattern as it stands where it has a form for it: a `high` or `full` row at the width and sign, or a native multiply at twice the width. Where it has none, and multiplies natively at the width, the multiply forms legalisation builds the high half from multiplies at the width. A width the target does not multiply natively is left to the wide integer splitting and the narrow integer widening. A target is a row of each form it has: x86 states `full` rows (a register pair), AArch64 `high` rows at 64 bits and `full` rows at 32, RISC-V `high` rows of all three signs, and a target with none, such as WebAssembly, states none.

## Asking for layout

A front end never computes a size, an alignment or an offset. It asks mirl, and so does the backend and every debug producer, through the same routine.

```
val l: Layout = mirl.target.of(target, ?module.types);
mirl.target.size(?l, ty)          # res[u64, Error], bytes
mirl.target.align(?l, ty)         # res[u64, Error], a power of two
mirl.target.extent(?l, ty)        # res[Extent, Error], size and alignment together
mirl.target.offset(?l, ty, i)     # res[u64, Error], member i of a structure or union
```

`of` takes the target a module names (found by `mirl.target.by_name(module.target)`) and the module's type table. The query is for any IR type.

- An integer or float is a row of the target's data layout, one for each legal width and each number format.
- A pointer is the size and alignment of the pointer row for its address space. A pointer into a logical space has none and is refused as `unsized`.
- A vector is its element's size times its lane count, rounded up to its alignment. Its alignment follows the vector rule of the target, which is either the element's alignment or, for a vector at least as wide as the narrowest vector register, the widest register size that the vector fills.
- An array is its element's size times its count and has its element's alignment.
- A structure places each member at the next multiple of the member's alignment, or at the offset it states, and rounds its size up to the largest member alignment.
- A function type or a target handle has no size and is refused as `unsized`.
- A union is as large as its largest member rounded up to the largest member alignment, with every member at offset 0.

A request that cannot be answered is refused with a reason. The reasons are an unstated fact (the target leaves it out), a pointer into an unknown address space, an unsized type, a stated offset that is misaligned or overlaps the member before it, a member index past the type's members, an offset asked of a type that is not a structure or union, and a size that does not fit in 64 bits.

## Argument passing

How a function's arguments and results are passed is not in the IR. A `call` states only the signature, and a function states only its function type. The calling convention is chosen below the IR from the function type and the system and architecture the target names, and a front end does not compute it. This version of the library does not yet expose a query for it, because the machine layer that applies calling conventions is not built.

## Attributes

An attribute is a fact one target family needs about a function or global and that no other family reads. A fact such as a SPIR-V entry point's stage or a shader variable's binding is an attribute the family defines. It is never a field of a core record.

An attribute holds

- `family`, the target family that defines it, such as `spirv`,
- `name`, its name within that family, such as `stage`,
- a datum, which is one number, an ordered list of numbers such as a workgroup size, or a name.

`mirl.ir.module.attach(m, symbol, attribute)` attaches an attribute to a function or global. The names and lists are copied. A target states the families it accepts in its `attributes` declaration, either none or a list of family names, and verifier rule 5 refuses an attribute of any other family. The text form spells an attribute as `attribute @symbol "family" "name" = datum`.
