# Targets, data layout and attributes

A **target** is data. It names an architecture and a system, declares what code generation needs to know about them and states the facts that data layout reads. Nothing in the pipeline reads a target's name to decide what to do. Every decision reads a declaration. A new target is a new row in `mirl.target`'s table and never a new case in a pass.

A module names its target by the target's name. The verifier's first rule requires the name to be a row of the table whose declarations are all stated (see rule 0 in [the specification](../ir.md)). The table has one row at this version, `riscv64-linux`.

## The record

A target holds

- `name`, its spelling, used for diagnostics and lookup only,
- `arch` and `system`, the names of its rows in mink's architecture and system catalogs, where the system must run the architecture,
- `caps`, its capability declarations,
- `data`, the facts data layout reads,
- `convention`, the calling convention its calls are made under (see [Argument passing](#argument-passing)),
- `baseline`, the extensions code for it may assume, in masc's spelling, from which `mirl.target.machine.open` makes masc's selection, the registers it gives and the convention resolved through them. A build adds extensions on top of it through `mirl.target.machine.open_with`, which takes extension names as masc's catalog names them and refuses one it does not know by name, `choose` makes the selection alone for a target with no convention yet, and the machine holds the one resolved selection that selection, the convention and the allocator's allowed set read,
- `addresses`, how code reaches an address (see [Addresses](#addresses)).

A target states a machine when it has both a baseline and a convention row (`mirl.target.machine.stated`). The selection is a fact of its own: a build opens what it holds of its target through `mirl.target.machine.build`, a `Build` of the basis (the selection, for every target with a baseline) and the machine (for a target that states a convention too, its basis the same one), and hands it to the pass driver. The driver's context carries both to every pass, no pass opens either of its own, every extension condition is read against the basis, and a pass that needs the convention refuses a run that holds no machine (`Why.unmachined`), so an extension the build adds reaches every consumer, with or without a convention, and nothing falls back to the baseline.

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
| `formats` | the number formats computed natively, each with the not-a-number it returns (`canonical`, `propagate` or `unspecified`), the operations of `OPTIONAL` it computes natively and under which condition, and whether a constant of it is `made` in registers or `loaded` from read-only data, or none |
| `arithmetic` | the widths with a native multiply of the low half and the condition it holds under, the multiply forms beyond it (one row per width and sign: the high half or the whole product, as signed, unsigned or mixed operands, or none), how a shift treats a count at or past the width (`wraps`, `undefined` or `saturates`), the operations on single bits it selects as they stand (`both`, `either`, `differ`, `compare`, or none), the widths of its native division, the condition they hold under and what it does with a zero divisor and with a signed overflow (`traps` or `quiet`), and its division of a two-word dividend by a word divisor: none, or the word widths it runs at and what it does with a zero divisor and with a quotient that does not fit the word |
| `bulk` | whether one instruction copies a run of bytes, and whether one fills it (`native` or `none`) |
| `timing` | the operations that run in constant time, by operation, width and condition, or none |
| `code` | the alignment of a function entry, a code section and a data section, and the bytes that pad code |
| `attributes` | the attribute families the target accepts |

These describe what the target does. They do not change what an operation means. A shift by the width or more gives 0 or the sign fill on every target whatever `arithmetic.shifts` says, and legalisation bounds the count where the target would not: the shift bounding applies where shifts `wrap` or are `undefined`, and not where they `saturate`.

The ir has no high multiply and no widening multiply. Both are written as a multiply of two extensions, and the high half as that product shifted down by the width and truncated. A target selects the pattern as it stands where it has a form for it: a `high` or `full` row at the width and sign, or a native multiply at twice the width. Where it has none, and multiplies natively at the width, the multiply forms legalisation builds the high half from multiplies at the width. A width the target does not multiply natively is left to the wide integer splitting and the narrow integer widening. A target is a row of each form it has: x86 states `full` rows (a register pair), AArch64 `high` rows at 64 bits and `full` rows at 32, RISC-V `high` rows of all three signs, and a target with none, such as WebAssembly, states none.

### Float operations a format lacks

A held format computes every float operation natively except those of `mirl.target.OPTIONAL`: `fmin`, `fmax`, `fminnum`, `fmaxnum`, `ffloor`, `fceil`, `fint`, `fnearest`, `select` and `frem`. Its `natives` list the ones it has, each under a condition: `always`, or an extension, such as RISC-V's `zfa`, that holds when the build's basis selects it (`mirl.target.machine.meets`). A build with no basis selects no extension, so only an unconditional row holds there. RISC-V states `fminnum` and `fmaxnum` always, the other minimums and the roundings under `zfa` and no select, AArch64 everything but `fminnum`, `fmaxnum` and `frem`, the first two of whose instructions give a nan for a signalling nan, and x86-64 the roundings under `sse4.1`. No target states `frem`: SPIR-V's `OpFRem` is held under Vulkan only to the precision of x - y * trunc(x/y), and the others have no remainder instruction.

The `floats` legalisation stands in for an operation a format lacks, where the operations its stand in is made of are native, and leaves any other for selection to refuse by name. `frem` is the helpers legalisation's instead, which calls a helper for it. Every stand in is exact under IEEE 754-2019 for every operand, nans and signed zeros included, under the rounding to nearest even the ir's float arithmetic has, and has no branch, so the pass keeps constant time.

- `fmin` and `fmax` are `fminnum` and `fmaxnum` less the square root of 0 or -1: positive zero where both operands are numbers, which leaves the result as it is, and a nan where either is one.
- The roundings add and take away T, the power of two from which every number of the format is an integer, with the sign of the operand, where the operand is below T in magnitude. That rounds it to the nearest integer, ties to even, and a step of 1 toward the operand makes `ffloor` and `fceil`. `fint` is `ffloor` of the magnitude. Each result takes the operand's sign, as a zero result of an integral rounding does.
- A `select` of floats is the select of their bits as integers of the format's width, whatever its condition, so it keeps every bit and adds no branch.

A held format whose `constants` are `loaded`, binary64 on a 32 bit RISC-V, has no rule that builds a constant in registers. The `pool` legalisation (`mirl.legal.POOL`) reads every use of such a constant, as an operand or an edge's argument, from a global of the module: local, `constant` and initialised with it, one per format and bit pattern, named `__mirl_` with the format and the bits (`__mirl_binary64_400921fb54442d18`). The load stands just ahead of the instruction that uses it and reaches the global through its address constant, so the target's addressing selects it and its placement puts the global in read-only data. It runs after the optimisations, which make and fold constants, and before the multiply forms.

### Narrow arithmetic

`widths.alu` lists the integer widths the target's arithmetic runs at, and a row states exactly those: x86-64 at 8, 16, 32 and 64, AArch64 and RISC-V at 32 and 64 (RV32 at 32), and a target such as WebAssembly at 32 and 64. An integer operation at any other width, a condition (`i1`) included, is widened by the `narrow` legalisation to the narrowest listed width above it: the operands are extended, the same opcode runs at the wide width and the result is truncated. The pass applies to a target that lists a width above some legal width it does not list.

A condition stays `i1` where it is read as one, by a branch or a `select`, and the pass leaves that use as it is. Where the same value is also an operand of arithmetic, the operation reads an extended copy and its result is truncated back to `i1` for its readers, so a `shr.s` of one bit fills from bit 0 and an `add` of two carries out of bit 0 and drops the carry. The one exception is an operation the algebra table states is exact on single bits held as 0 or 1, the bitwise `and`, `or` and `xor` and the comparisons that read their operands as unsigned (`mirl.fold.single_bit`), which a target declares it selects on them as they stand in `arithmetic.single`. The pass leaves such an operation, and widens it on a target that declares none. RISC-V declares all four, and the other targets declare none.

- A sum, difference, product, `and`, `or`, `xor`, `neg`, `not` and `shl` take either extension, since the bits above the narrow width do not reach the bits below it. Division, remainder and comparisons extend with the sign or with zeros as their opcode reads its operands, and `shr.u` and `shr.s` extend the shifted operand to match. A shift count is always extended with zeros.
- The shift rule holds at the narrow width: a count of the narrow width or more shifts every bit out at the wide width too.
- A division by zero traps at the wide width exactly when the narrow one does. A signed division or remainder of the least narrow value by minus one does not trap at the wide width, so the dividend is replaced by the least wide value in that case, which traps there. The opcode row states which operands the trap reads, and the replacement is a select, so the pass adds no branch.
- A vector of narrow integers and a width above the widest listed are not its job. The counts (`clz`, `ctz`, `popcnt`), `bswap` and the overflow forms are left, since a count reads the bits an extension adds, a swap moves them and an overflow at the wide width is not the overflow at the narrow one (`mirl.legal.LEFT`).

### Wide arithmetic

An integer wider than the widest width in `widths.alu` (`mirl.target.widest`) is split by the `wide` legalisation into words of that width, low word first, and every operation on it is rewritten over the words by one algorithm for every width and every word: a 512 bit integer over 32 bit words takes the path a 128 bit integer over 64 bit words takes. Every width in `widths.integers` is held within the widest alu width, so a target never declares an integer register it cannot compute at.

- A sum carries and a difference borrows from word to word through `add.ov.u` and `sub.ov.u`, the ir's carry and borrow, which a target selects as its carry forms where it has them and as a comparison where it has none (`sltu` on RISC-V).
- A product sums the low and high words of the product of every pair of words. The high word is written as the ir's high multiply at twice the word, so a target's `high` or `full` rows select it (`mulhu` on RISC-V) and the multiply forms legalisation builds it where there are none.
- A shift by a constant moves whole words and then bits across them. A shift by a value does the same through selects on the bits of its count, and a count of the width or more gives 0 or the sign fill.
- A comparison decides on the top word, read as its opcode reads it, and falls to the words below, read as unsigned, only where those are equal.
- A `bitcast` between a wide integer and a float, a binary64 on a 32 bit target, goes through a stack slot of the float: the float is stored and its words loaded, or the words stored and the float loaded, each word at its offset in the target's byte order.
- The counts, the byte swap and the overflow forms are computed over the words. An extension, a truncation, a select, a load, a store and a block parameter are one per word, and an access carries its flags to every word at the word's offset in the target's byte order. A `bitcast` to or from a vector whose lanes fill words whole takes or places each lane at its bits, lane 0 at the low bits, which is how the abi legalisation's rebuilt vectors reach selection.
- Nothing it builds branches, so the pass keeps constant time, and every word of a secret value is secret.
- An `i1` a store writes or a load reads is held in memory as the integer of its layout size, 0 or 1.
- A variable bound to no more than the low word reads it from the low word. One bound to more than a word, which no one record can read from two words, is unavailable.

A wide value at a function's entry, a call or a return is the abi legalisation's, which runs before it. A wide division, remainder or conversion to or from a float is the helpers legalisation's, which runs before it too and leaves a call of a helper (`mirl.legal.helper.takes`). A vector of wide lanes and a wide access through a logical address are refused.

### Division, multiplication, float remainders, conversion and bulk memory

The `helpers` legalisation (`mirl.legal.HELPERS`) runs after promotion and before the abi legalisation, at the widths the source states, so the calls it makes and the helpers it delivers are lowered and legalised as any other function.

- A division or remainder the target runs, on a target whose division is `quiet` for a zero divisor or a signed overflow, is given the test of each trap its opcode row states and the target does not take: the block is split before it and branches to a block of one `unreachable` where it would trap. The test is made public with `declassify`, since the trap shows it, and the division carries the `checked` flag, so it is never tested twice. x86 traps on both, and AArch64, RISC-V and SPIR-V on neither.
- A division at a width the target has no division for is given the tests of every trap its row states, since a helper takes none, and calls the helper of its width and operation. Where the divisor's magnitude fits half the word, a chain of the target's divisions at the word runs instead, two to a word of the dividend from the top, each dividing the remainder so far joined with the next half word. Where the target divides a two-word dividend by a word divisor at the word, as x86-64 does, the chain runs one such division a word instead, each of the remainder so far and the next word, for any divisor whose magnitude fits a word. A signed division divides the magnitudes and puts the sign back.
- A `div.wide.u` at a width the target declares no division of a two-word dividend for is given the tests of both traps its row states and runs as the division of the dividend joined at twice the width: the target's division where it divides at that width, and otherwise the chain or the helper of that width as above. The quotient is the low word of that quotient, which fits once the traps are tested, and the remainder is the low word of the dividend less the quotient times the divisor. Where the target declares one at the width, its traps are tested as a division's are, by what the target's instruction does with each.
- The multiply and the division hold under the condition the target row states for each, read on the build's basis as a float operation's is: RISC-V multiplies under `zmmul`, which `m` implies, and divides under `m`, and every other target always. Where the condition is not met no width has the instruction.
- A multiply at a width the target has no multiply for calls the helper of its width, a multiply by a constant and the double width product of a high half included, so no product reaches the integer legalisations there. Where the target multiplies at the word, a wider integer is left to the wide legalisation, which splits it into products of words.
- A conversion between a float and an integer wider than the target's arithmetic calls the helper of its width and format. Where the integer's value fits a word, or the float is no nan and lies within the word's range, the target's conversion at the word runs instead. A target's own conversion that gives something else for a nan or a value out of range is corrected by its selection rules, and the helpers' conversions at the word are always in range.
- A float operation a helper row stands in for (`stands`), `frem`, calls the helper of its format where the format is held and has no native form of it under the build's basis. A vector of floats is refused, since it is scalarised first, and a format the target does not hold is left to the legalisation that expands it.
- A copy or fill on a target whose `bulk` is `none` calls the helper of the length's width and the address space. A kept fill calls nothing another module could define: it is a loop of kept stores of its byte, one address a step, in its place.
- The native paths branch on a value, so a function that requires constant time calls the helper whatever the value. Every helper runs in a time that depends on nothing but a length, and a copy or fill whose length is secret in such a function is refused with the one constant time refusal (`Why.timing`).

Each helper is stated once, as ir text in the table of `mirl.legal.helper.table`, with its name built from mirl's own prefix (`__mirl_`), the operation's stem, the width, and the format for a conversion or the address space for a copy or fill, or the format alone for a float remainder: `__mirl_udiv128`, `__mirl_mul64`, `__mirl_stof256_binary64`, `__mirl_fill64`, `__mirl_frem_binary64`. The text is filled in from the target's declarations and the format's row and read into the module the first time a function there needs it, weak, hidden and constant time, and never twice. A symbol of the module that has a helper's name and is not that helper is refused.

- Unsigned division is restoring shift and subtract over the wide integer, which the wide legalisation splits. Signed division and remainder take the magnitudes, call the unsigned helper and fix the sign.
- A product is shift and add, one bit of the second operand a step from the bottom, the first operand shifted up and added through a mask of that bit, so no step depends on a value.
- An integer converts to a float by a binary search over its leading zeros, a sticky bit for every bit below the float's precision, the native conversion of the top word and a scale by an exact power of two. Where the precision and its round and sticky bits do not fit a word, two words convert exactly and are summed.
- A float converts to an integer word by word from the top, each word taken by exact float arithmetic. A value out of range saturates and a nan gives 0.
- A float remainder is the dividend's magnitude less the divisor's magnitude scaled by each power of two from the largest exponent down, wherever it is no greater, one step for every exponent of the format down to the least subnormal's. Each difference is exact, since the scaled divisor is at least half of what is left, so the remainder never rounds. A subnormal divisor is scaled into the normal range first, the dividend's sign goes back on, and a nan, an infinite dividend or a zero divisor gives a nan, as the folder does. A format with no implicit leading bit is refused.
- A format the target computes in none of, or whose exponent range a word or two cannot reach, is refused.

The texts are filled in by substitution, so a test walks every row of the table at every width, format and address space a target row declares, delivers each helper and verifies the module (`mirl.legal.helper.deliver_test`). The float remainder is also run there instruction by instruction through the folder, at remainders worked out by hand. A text that a fill breaks fails mirl's own tests, never a user's build.

## Asking for layout

A front end never computes a size, an alignment or an offset. It asks mirl, and so does the backend and every debug producer, through the same routine.

```
val l: Layout = mirl.target.of(target, ?module.types);
mirl.target.size(?l, ty)          # res[u64, Error], bytes
mirl.target.align(?l, ty)         # res[u64, Error], a power of two
mirl.target.extent(?l, ty)        # res[Extent, Error], size and alignment together
mirl.target.offset(?l, ty, i)     # res[u64, Error], member i of a structure or union
mirl.target.offsets(?l, ty, out)  # err[Error], every member of a structure in one walk
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

How a function's arguments and results are passed is not in the IR. A `call` states only the signature, and a function states only its function type. A front end never computes it. It asks `mirl.target.abi`, and the backend asks the same routine once per call site.

A target declares the convention its calls are made under in `convention`: the row of the convention, or `uncarried` for a convention mirl has no row for yet, whose calls are refused. A **convention** is a row for one architecture, system and ABI, as data:

| field | what it states |
|---|---|
| `results`, `arguments` | the result classifier and the argument classifier |
| `file` | the masc register file its registers are named in, none where there is none |
| `word` | the bits of one argument word |
| `floats` | the widest float passed in float registers, or none |
| `passing`, `returning` | the argument and result registers by masc's register handles, each class in the order taken |
| `preserved`, `reserved` | the registers a callee preserves whole, and those no call clobbers and nothing allocates |
| `stack` | none, or a stack in memory with its alignment at a call, its red zone, its shadow space, where a call leaves the return address (`link`) and its frame pointer with the frame record it heads (`pointer`) |
| `indirect` | what carries the address of a result passed by reference, and where a callee hands it back |
| `variadic` | where unnamed arguments travel, the count a caller sets, and how a callee reaches them |
| `half` | whether a 16-bit float travels as a float or as an integer |

A row is resolved once against a masc selection of its register file (`mirl.target.abi.resolve`), which looks its names up, groups the argument and result registers by class and computes the registers a call clobbers.

```
val c: *Convention = mirl.target.abi.of(target);                    # res[*Convention, Error]
val r: Resolved    = mirl.target.abi.resolve(a, c, ?registers);     # res[Resolved, Unresolved]
mirl.target.abi.classify(a, ?layout, ?r, signature, statement)      # res[Assignment, Error]
```

`classify` describes each argument and result type through the **type view**, a tree of nodes whose every size, alignment and offset was asked of the data layout, and runs the row's result classifier and then its argument classifier over it. It is the only caller of a row's classifiers. The **assignment** it returns states, for each argument and result, whether it travels by value or by reference to a copy the caller makes and owns, and its **pieces**: for each piece a place (a register by masc's identity, a stack offset, or an operand of the target's own call form), the offset and size of the bytes it carries, how the offset and size scale, and how the rest of its place is filled.

The integers are signless, so a convention that extends a narrow integer by the source type's signedness leaves the piece **declared**, and `classify` fills it from the extension the signature states for that parameter or result: sign or zero extended. A declared piece whose parameter or result states none is refused, naming it, and is never guessed.

The call's **statement** says how its language passes aggregates (by the platform's C rules, or each by reference to a copy the caller makes) and how many of its arguments are named. Both have an unstated zero case, which is refused.

The one row is `lp64d`, the RISC-V convention of RV64 with hardware double precision, to the RISC-V ELF psABI 1.0.

lp64d reserves the global and thread pointers and the float control and status register, `fcsr` and its `frm` and `fflags` fields. The psABI gives `fcsr` thread storage duration, so a call neither saves nor clobbers the rounding mode that a dynamic rounding reads or the flags that every float operation accrues.

## Addresses

A target states its address model, or `uncarried` when it has none yet and no address is selected. The model is the relocation model, `static`, `pie` or `pic`, and the access each thread-local model of the ir is reached by: local exec, initial exec, general dynamic through the runtime function `lookup` names, a descriptor, a per variable thunk or an index into the thread's module table. `mirl.target.address.reach(model, defined, linkage, tls)` says how one symbol is reached: absolutely, by its distance from the code, through the global offset table, or by its thread-local access. Under `static` every symbol is reached absolutely. Under `pie` and `pic` reach reads one fact, `mirl.target.address.preemptible(relocation, linkage, defined)`, which holds the whole rule of the specification for what the model builds: `static` and `pie` build an executable and `pic` a shared object. A preemptible symbol goes through the table, and any other is reached by its distance from the code, defined or not, so the linker refuses a hidden or internal reference that ends up undefined. Selection reads this and never a target's name, and names relocations by mink's kinds.

RV64 Linux is `pie` and reaches local dynamic as general dynamic through `__tls_get_addr`.

## Attributes

An attribute is a fact one target family needs about a function or global and that no other family reads. A fact such as a SPIR-V entry point's stage or a shader variable's binding is an attribute the family defines. It is never a field of a core record.

An attribute holds

- `family`, the target family that defines it, such as `spirv`,
- `name`, its name within that family, such as `stage`,
- a datum, which is one number, an ordered list of numbers such as a workgroup size, or a name.

`mirl.ir.module.attach(m, symbol, attribute)` attaches an attribute to a function or global. The names and lists are copied. A target states the families it accepts in its `attributes` declaration, either none or a list of family names, and verifier rule 5 refuses an attribute of any other family. The text form spells an attribute as `attribute @symbol "family" "name" = datum`.
