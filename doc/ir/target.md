# Targets, data layout and attributes

A **target** is data. It is assembled from the five parts of its tuple and is never a row of its own: its architecture, system and environment, rows of mink's catalogs, its calling convention, a member of the architecture's convention axis, and its baseline, a selection over masc's catalog of the architecture's instruction set. Every part is stated and mirl supplies a default for none of them. A default, such as a system's usual baseline, belongs to whoever builds the tuple. A target declares what code generation needs to know about its parts and states the facts that data layout reads. A target has no name of its own: `mirl.target.spell` spells its tuple as text, each row by its own name and the baseline through masc's spelling of its selection, and `mirl.target.name` derives a name from that for diagnostics. Every decision reads a declaration. mirl holds no list of targets, and a new architecture, convention or system is one row on its own axis, never a row per combination and never a new case in a pass.

A module names its target by its text tuple, each part as its owner spells it and none empty (`mirl.ir.module.Tuple`). The environment of a system whose hosts run under no environment, as freestanding and, at mink's pin, vulkan, is spelled `none`, which is a stated part and is valid for no other system. `mirl.target.assemble(a, tuple)` builds the target from the parts in one place (`mirl.target.assemble`), and refuses a combination by the rule it breaks (`mirl.target.Refusal`, spelled by `mirl.target.rule`):

- every part is stated (`empty`, naming the part),
- the architecture and system are rows of mink's catalogs (`arch`, `system`),
- the environment is one of the system's, or `none` for a system with a host under none (`env`, `none`),
- the system runs the architecture under the environment, as mink states (`runs`),
- a family states the architecture's capabilities (`machine`),
- the convention is a member of the architecture's convention axis (`convention`), by mink's psABI name,
- masc reads the baseline's spelling in the catalog of the architecture's set (`baseline`),
- the requirements of the convention's row hold over the baseline (`requires`): lp64d needs D, lp64f F, and lp64e the E base, each stated as a requirement over masc's atoms (`Convention.requires`) and never by name.

Every fact is then read from the axis that owns it (`mirl.target.axis`), each family stating its rows on every axis (`Axes`): the capabilities from the architecture's row (`Machine`), whose conditions the build reads under the baseline, the data layout from the convention member, which is of one architecture (`Member.data`), and the address model from the row of the architecture and system (`Model`), a pair with no row carrying none. A member mirl carries no row for yet, as aarch64's `aapcs64`, `darwinpcs` and `aapcs64win`, the e base's `lp64e` and `ilp32e` and spir-v's `shader`, assembles to `Declared.uncarried`, whose calls are refused, and its requirements are not read. An architecture masc serves with no set has its baseline's spelling kept unread (`Baseline.uncarried`). masc serves a set for every architecture mirl carries, so an aarch64 baseline such as `armv8-a` is a selection of its catalog. The assembled target holds the storage its baseline and its rows took, which `mirl.target.release` gives back. `mirl.target.names(a, tuple, t)` says whether a tuple assembles to a target: the same rows of mink's catalogs, the same convention by name and the same baseline selection, so `rv64gc` and the spelling masc gives back are one baseline. `mirl.target.same(a, b)` says whether two targets are one tuple. The verifier's first rule requires the module's tuple to be its target's, whose declarations are all stated (see rule 0 in [the specification](../ir.md)).

## The record

A target holds

- `arch`, `system` and `env`, its rows of mink's architecture and system catalogs and the system's environment it runs under, none for a system run with none, where the system must run the architecture under that environment,
- `caps`, its capability declarations,
- `data`, the facts data layout reads,
- `convention`, the calling convention its calls are made under (see [Argument passing](#argument-passing)),
- `baseline`, the extensions and state code for it may assume, a requirement of one alternative over masc's atoms, stated through the set's extension handles, from which a family's `open` makes masc's selection (`mirl.target.basis.choose`) and the convention resolved through it. The context the selection opens must admit the baseline (`masc.core.state.admits`). A build adds extensions on top of it through the extension names `open` is given, as masc's catalog names them, and one it does not know is refused by name. The build holds the one resolved selection that the passes, the convention and the back end read,
- `addresses`, how code reaches an address (see [Addresses](#addresses)).

A target is served by the one family of `mirl.target.families` that admits its capabilities, and none or several is refused as unserved (`mirl.target.family`). A family is one record: its `name`, `admits` over the capabilities, `legal`, the rows the target runs after the neutral prefix, `open`, which makes the target's `Build` in place, `back`, its back end, `close`, which gives back what `open` made, and `opcodes`, the opcode rows it owns. A `Build` (`mirl.target.build`) exists only once `open` succeeds and holds the `basis` (the selection), every convention row of the target resolved through it, the default first (`conventions`), and the family's own `state`. An opcode row a family lists is that family's own, told by the row's identity in the opcode table (`mirl.ir.opcode.at`), and only a target the family serves admits it. A row no family lists is a core row every target admits, and a row two listings name has no one owner, which `mirl.target.families.owners` refuses. A row carries no family of its own, so the ir has no family concept. Admission is a fact of the family layer, so `mirl.target.compile` and `mirl.target.families.optimise` check it: a module holding a row its target does not admit is refused before the schedule (`foreign`), and one the schedule left holding such a row is refused after it, before any back end runs (`introduced`), naming the row, the function and the instruction. The register family (`mirl.target.register.family`) admits allocated registers, free control, physical addressing and register evaluation, opens the register machine of `mirl.target.register.machine` and refuses a target that states no convention row (`uncarried`) or a row with no register file, and compiles a function and the calls it makes under the default row alone, refusing one under another row (`convention`), and its back end is `mirl.machine.compile`.

The webassembly family (`mirl.target.wasm.family`) admits values in locals, structured control, physical addressing and stack evaluation, the capabilities wasm32 and wasm64 state. Its build is masc's wasm set and the basic C ABI resolved with no register file, its rows are the register family's after the threadless legalisation, and its back end (`mirl.target.wasm.module`) writes one final module of mink's wasm container: the functions another module defines imported from the module the environment names (`wasi_snapshot_preview1` under WASI preview1, `env` with none), every defined function of the type its placement gives, a table slot from 1 for each function whose address is taken, the globals in linear memory from the host's image base as one data segment, and the stack pointer a mutable global growing down from that base. A value the next instruction reads as its one use stays on the operand stack, and every other is held in a local assigned by live range over the IR's liveness. Control is emitted from the region tree: a two-way branch is an `if`, a switch a block per target about a `br_table` or a chain of tests, and a merge's parameters are the results of its construct. A constant-time function compiles with masc's warning that wasm cannot guarantee any instruction's timing, written to `Options.warnings`.

The pass schedule is split by what it reads. A neutral row (`mirl.pass.Row`) runs a `Pass`, which reads the target and the selection, if a family opened one, through its context. A family's row (`mirl.pass.Step`) may run a `Lowering` as well, which is given the build, so a pass that needs the convention reads it from the build and is never run where none was opened. A served target runs the neutral prefix (`mirl.pass.rows.prefix`: promotion, the typed address folding and the compare chain, the two applying by addressing and control alone) and then its family's rows over its build, and a target no family serves runs the neutral rows alone (`mirl.pass.rows.neutral`) with no selection. Every condition is read against the selection, so an extension the build adds reaches every consumer and nothing falls back to the baseline. Which rows run is chosen the same way: a pass's `applies` is given the `Ground` of the build (`mirl.pass.record.Ground`), its target and its selection, so a legalisation applies where the build lacks what it rewrites. The float stand ins, the constant pool and the helpers read the formats the build holds and the conditions it meets, and the other passes read the target's declarations alone.

`mirl.target.declared(t)` says whether a target is complete. Every declaration has an unstated zero case, so a row left zeroed reads as incomplete and never as an answer. A list that may rightly be empty sits under a case of its own, so an empty list is a stated answer.

## Capabilities

The capability declarations are

| declaration | what it states |
|---|---|
| `registers` | values live in registers the pipeline allocates, in locals it assigns by live range, or nowhere it assigns |
| `control` | control flow is free, or must be structured |
| `addressing` | memory is addressed physically, or only by access chains (logical) |
| `functions` | a function's address, the value `func.addr` gives, is a location as a data address is (`addresses`), or a slot of an indirect call table (`slots`), or code has none (`none`), as SPIR-V's logical addressing has no function pointers, so no `func.addr` stands and a call names its callee directly |
| `values` | values are untyped, or carry their type into the output |
| `evaluation` | operations take operands from named values, or from an operand stack |
| `widths` | the address spaces, how a pointer into each is held and the rules the types in each are laid out by (`c`, `std140`, `std430` or `scalar`), the register width, the widths integer arithmetic runs natively at, and the integer widths a value holds natively |
| `vectors` | none, or the vector units, each under the condition the build must meet to hold vectors in it, with its register width (`fixed`, `scaled` with a quantity of masc's register file, or `none` where vectors are values with no register width), the lane counts allowed and the lane types with how each is carried out (packed or by scalar expansion) |
| `formats` | the number formats computed natively, each under the condition the build must meet to compute in it, with the not-a-number it returns (`canonical`, `propagate` or `unspecified`), the operations of `OPTIONAL` it computes natively and under which condition, and whether a constant of it is `made` in registers or `loaded` from read-only data, or none |
| `arithmetic` | the widths with a native multiply of the low half and the condition it holds under, the multiply forms beyond it (one row per width and sign: the high half or the whole product, as signed, unsigned or mixed operands, or none), how a shift treats a count at or past the width (`wraps`, `undefined` or `saturates`), the operations on single bits it selects as they stand (`both`, `either`, `differ`, `compare`, or none), the widths of its native division, the condition they hold under and what it does with a zero divisor and with a signed overflow (`traps` or `quiet`), and its division of a two-word dividend by a word divisor: none, or the word widths it runs at and what it does with a zero divisor and with a quotient that does not fit the word |
| `bulk` | whether one instruction copies a run of bytes, and whether one fills it (`native` or `none`) |
| `code` | the alignment of a function entry, a code section and a data section, and the bytes that pad code |
| `attributes` | the schema of the target's family, whose attributes it accepts, or none |

These describe what the target does. They do not change what an operation means. A shift by the width or more gives 0 or the sign fill on every target whatever `arithmetic.shifts` says, and legalisation bounds the count where the target would not: the shift bounding applies where shifts `wrap` or are `undefined`, and not where they `saturate`.

The high half of a product is its own operation, `mul.high.u`, `mul.high.s` and `mul.high.su`, and a target computes it at a width and sign where it states a `high` or `full` row for them (`mirl.target.computes_high`). The ir has no widening multiply, which is written as a multiply of two extensions, and a front end may write the high half as that product shifted down by the width and truncated. A target selects that pattern as it stands where it has a form for it: a `high` or `full` row at the width and sign, or a native multiply at twice the width. Where it has neither, and multiplies natively at the width, the multiply forms legalisation builds the high half, of the operation or the pattern, from multiplies at the width. A width the target does not multiply natively is left to the wide integer splitting and the narrow integer widening, which multiplies the extended operands at the wider width and shifts the product down, and one it has no multiply for to the helpers legalisation, which calls the helper of the product at twice the width. A target is a row of each form it has: x86 states `full` rows (a register pair), AArch64 `high` rows at 64 bits and `full` rows at 32, RISC-V `high` rows of all three signs, and a target with none, such as WebAssembly, states none.

### Vector units

A vector splits to the widest unit the build meets that packs its lane type (`mirl.target.vector.split`): the unit whose least width under the build has room for the most of its lanes in one piece, of a count the unit admits, the first stated on a tie. Lane order is kept, and the last piece holds what is left, which splits again by its own count. A vector no unit the build meets packs is scalarised. A `fixed` width is its bits, a `none` width bounds no count, and a `scaled` width is masc's amount over the quantity of its slot, read at the least multiplier the build's selection leaves it where fixed-length vectors split to the unit (`least`), as RVV's vlen, which `v` bounds at 128 bits and the `zvl` extensions raise. A unit read only by a length-agnostic vectoriser (`agnostic`), as SVE's, takes no fixed-length vector. RISC-V states one unit, scaled under `v` and packing integers of 8 to 64 bits, binary32 and binary64, so a build that adds `v` or a `zvl` extension changes the pieces. x86-64 states SSE2's 128 bits, AArch64 NEON's 128 bits, both always, and SPIR-V a unit of no width with counts 2, 3 and 4. Selection gathers the vector types of the units the build meets alone, so a build that meets none reaches no vector type.

### Typed addresses

`ptr.member` and `ptr.index` form an address from the type they walk, the structure and member, or the array and an element index. The `address` legalisation (`mirl.legal.ADDRESS`) applies where `addressing` is `physical` and folds each to a `ptr.add` of the address it takes and a byte offset as wide as that address's pointer: a member's offset as the data layout places it, and an element's index read as signed, extended or truncated to the pointer's width, times the array's stride, each laid out by the rules of the address's space. A target whose addressing is `logical` keeps them, since it reaches memory through access chains, as SPIR-V's `OpAccessChain`, and the verifier refuses there, past legalisation, every row that forms or reads an address as a number. The pass runs right after promotion, so the integer legalisations legalise the offsets it makes as any other arithmetic.

### Multi-way branches

The `compare chain` legalisation (`mirl.legal.CHAIN`) applies where `control` is `free` and lowers a `switch` to a test of each case in its order, an `eq` of the selector and the case and a `cbr` to the case's target or on to the next test, a block of its own, with the last test going on to the first target. A `switch` with no case is a `br`. A structured target keeps the branch whole for its own multi-way form, SPIR-V's `OpSwitch` and WebAssembly's `br_table`. The chain branches only on the selector the branch already branched on, so it keeps constant time. A jump table for a dense case list is not built yet.

### Float operations a format lacks

A condition (`mirl.target.Condition`) is `always`, or `requires` a requirement over masc's atoms (`masc.core.requirement`): the extensions of the catalog of the target's instruction set and the values of its state axes, as alternatives, each a set of atoms held and a set none of which is held. A build meets it where the context its basis opened admits the requirement (`masc.core.state.admits`, through `mirl.target.basis.meets`), so an extension is told by its atom and never by its name. x86-64's v3 is one alternative of avx2, fma, bmi1, bmi2 and the rest of its atoms, and SPIR-V's capabilities and environment are atoms of its catalog once masc serves one. A build with no basis has no context, so only `always` holds there. `mirl.target.declared` refuses a condition that names an atom past the catalog and its state values (`conditions`). An architecture masc serves with no instruction set yet opens no basis, so its conditions are stated over its catalog's atoms and none is met. x86-64 opens one from masc's x86 set, as RISC-V does from its own.

A held format's `condition` says when the target computes in it at all, read through `mirl.target.basis.held`, which gives the row whose condition the build meets. A format may have several rows, each under its own condition, and `mirl.target.declared` holds the conditions of the rows of one format disjoint (`formats`): every alternative of one is apart from every alternative of the other, because one holds an atom the other rules out, the two hold two values of one state axis, or the extensions they hold imply one the other rules out or a pair the catalog states conflict. The implications are read without the catalog's combinations, so a pair only a combination parts is refused, never admitted. RISC-V holds binary32 under `f` and under `zfinx`, two rows the catalog's conflict of the two parts, and binary64 under `d` on every row, so its soft float rows differ from the others only in their baseline and convention, and a build that selects neither `f` nor `zfinx` holds no binary32. Every other target holds its formats always. A held format computes every float operation natively except those of `mirl.target.OPTIONAL`: `fmin`, `fmax`, `fminnum`, `fmaxnum`, `ffloor`, `fceil`, `fint`, `fnearest`, `select` and `frem`. Its `natives` list the ones it has, each under a condition, such as RISC-V's `zfa`, that holds where the build meets it (`mirl.target.basis.meets`). RISC-V states `fminnum` and `fmaxnum` always, the other minimums and the roundings under `zfa` and no select, AArch64 everything but `fminnum`, `fmaxnum` and `frem`, the first two of whose instructions give a nan for a signalling nan, and x86-64 the roundings under `sse4.1`. No target states `frem`: SPIR-V's `OpFRem` is held under Vulkan only to the precision of x - y * trunc(x/y), and the others have no remainder instruction.

The `floats` legalisation stands in for an operation a format lacks, where the operations its stand in is made of are native, and leaves any other for selection to refuse by name. `frem` is the helpers legalisation's instead, which calls a helper for it. Every stand in is exact under IEEE 754-2019 for every operand, nans and signed zeros included, under the rounding to nearest even the ir's float arithmetic has, and has no branch, so the pass keeps constant time.

- `fmin` and `fmax` are `fminnum` and `fmaxnum` less the square root of 0 or -1: positive zero where both operands are numbers, which leaves the result as it is, and a nan where either is one.
- The roundings add and take away T, the power of two from which every number of the format is an integer, with the sign of the operand, where the operand is below T in magnitude. That rounds it to the nearest integer, ties to even, and a step of 1 toward the operand makes `ffloor` and `fceil`. `fint` is `ffloor` of the magnitude. Each result takes the operand's sign, as a zero result of an integral rounding does.
- A `select` of floats is the select of their bits as integers of the format's width, whatever its condition, so it keeps every bit and adds no branch.

A held format whose `constants` are `loaded`, binary64 on a 32 bit RISC-V, has no rule that builds a constant in registers. The `pool` legalisation (`mirl.legal.POOL`) reads every use of such a constant, as an operand or an edge's argument, from a global of the module: local, `constant` and initialised with it, one per format and bit pattern, named `__mirl_` with the format and the bits (`__mirl_binary64_400921fb54442d18`). The load stands just ahead of the instruction that uses it and reaches the global through its address constant, so the target's addressing selects it and its placement puts the global in read-only data. It runs after the optimisations, which make and fold constants, and before the multiply forms.

### Half precision

The `half precision` legalisation (`mirl.legal.HALF`) runs first in a register family's schedule, before the helpers, and computes a format the build holds no unit for in a wider one it holds: binary16 on RISC-V without Zfh, and on every target with no half precision unit. A value of the format is held as the integer that is its encoding, and each operation widens its operands exactly, computes once in the wide format and narrows its result once, rounding to nearest with ties to even. The wide format is read from the number format table and the target's held rows, never a format's name. For an operation that rounds it is the narrowest held format whose precision is at least twice the narrow one's plus two and whose exponent range holds every narrow value as a normal number, so the two roundings give the correctly rounded result: binary32 for binary16. A fused multiply-add takes one whose precision is at least four times the narrow one's plus two and whose range holds the exact product, binary64 for binary16. Comparisons, sign operations and conversions to integers read the widened value exactly, and a conversion from an integer or another format rounds once into the narrow encoding. Widening and narrowing are integer code on the encodings, so the pass needs no conversion instruction, adds no branch and keeps constant time. A nan widens keeping its payload and narrows keeping its sign and the top of its payload, quieted, and a conversion's nan follows the other format's held nan rule. A value at the function's entry, a call's arguments and results and a return stays the format, as the convention places it, through a reinterpretation of its encoding. A vector of the format is left.

### Narrow arithmetic

`widths.alu` lists the integer widths the target's arithmetic runs at, and a row states exactly those: x86-64 at 8, 16, 32 and 64, AArch64 and RISC-V at 32 and 64 (RV32 at 32), and a target such as WebAssembly at 32 and 64. An integer operation at any other width, a condition (`i1`) included, is widened by the `narrow` legalisation to the narrowest listed width above it: the operands are extended, the same opcode runs at the wide width and the result is truncated. The pass applies to a target that lists a width above some legal width it does not list.

A condition stays `i1` where it is read as one, by a branch or a `select`, and the pass leaves that use as it is. Where the same value is also an operand of arithmetic, the operation reads an extended copy and its result is truncated back to `i1` for its readers, so a `shr.s` of one bit fills from bit 0 and an `add` of two carries out of bit 0 and drops the carry. The one exception is an operation the algebra table states is exact on single bits held as 0 or 1, the bitwise `and`, `or` and `xor` and the comparisons that read their operands as unsigned (`mirl.fold.single_bit`), which a target declares it selects on them as they stand in `arithmetic.single`. The pass leaves such an operation, and widens it on a target that declares none. RISC-V declares all four, and the other targets declare none.

- A sum, difference, product, `and`, `or`, `xor`, `neg`, `not` and `shl` take either extension, since the bits above the narrow width do not reach the bits below it. Division, remainder and comparisons extend with the sign or with zeros as their opcode reads its operands, and `shr.u` and `shr.s` extend the shifted operand to match. A shift count is always extended with zeros.
- The shift rule holds at the narrow width: a count of the narrow width or more shifts every bit out at the wide width too.
- A division by zero traps at the wide width exactly when the narrow one does. A signed division or remainder of the least narrow value by minus one does not trap at the wide width, so the dividend is replaced by the least wide value in that case, which traps there. The opcode row states which operands the trap reads, and the replacement is a select, so the pass adds no branch. A `checked` division has its traps tested before it, so it takes no replacement and the wide division keeps the flag.
- The counts, the byte swap and the overflow forms take the narrow value extended with zeros, or with the sign for a signed overflow form, and correct for the bits the extension adds. `popcnt` counts no added bit. `clz` takes the added width away from the wide count, and `ctz` counts with every added bit set, so a zero operand gives the narrow width. `bswap` swaps at the wide width and shifts the swapped bytes down by the added width. An overflow form computes the exact sum, difference or product at a width that holds it, the wide width or one twice the narrow width when a product needs it, and its flag is whether the truncated result extended back differs from the exact one.
- A vector of narrow integers and a width above the widest listed are not its job. Every integer row is widened at 8 and 16 bits, so no integer opcode reaches selection at a width the target does not compute at.

### Wide arithmetic

An integer wider than the widest width in `widths.alu` (`mirl.target.widest`) is split by the `wide` legalisation into words of that width, low word first, and every operation on it is rewritten over the words by one algorithm for every width and every word: a 512 bit integer over 32 bit words takes the path a 128 bit integer over 64 bit words takes. Every width in `widths.integers` is held within the widest alu width, so a target never declares an integer register it cannot compute at.

- A sum carries and a difference borrows from word to word through `add.ov.u` and `sub.ov.u`, the ir's carry and borrow, which a target selects as its carry forms where it has them and as a comparison where it has none (`sltu` on RISC-V).
- A product sums the low and high words of the product of every pair of words. The high word is `mul.high.u` of the two words, which a target's `high` or `full` rows select (`mulhu` on RISC-V) and the multiply forms legalisation builds where there are none. Being one operation, it stays whole through every pass after the split, folding included. A high multiply of wide operands is the upper words of the whole product, less each operand read as signed where the other is negative.
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

- A division or remainder the target runs, on a target whose division is `quiet` for a zero divisor or a signed overflow, is given the test of each trap its opcode row states and the target does not take: the block is split before it and branches to a block of one `unreachable` where it would trap. The test is made public with `declassify`, since the trap shows it, and the division carries the `checked` flag, so it is never tested twice. One whose every such trap a constant operand rules out, a divisor of 3 for instance, carries the flag with no test. x86 traps on both, and AArch64, RISC-V and SPIR-V on neither.
- A division at a width the target has no division for is given the tests of every trap its row states, since a helper takes none, and calls the helper of its width and operation. Where the divisor's magnitude fits half the word, a chain of the target's divisions at the word runs instead, two to a word of the dividend from the top, each dividing the remainder so far joined with the next half word. Where the target divides a two-word dividend by a word divisor at the word, as x86-64 does, the chain runs one such division a word instead, each of the remainder so far and the next word, for any divisor whose magnitude fits a word. A signed division divides the magnitudes and puts the sign back.
- A `div.wide.u` at a width the target declares no division of a two-word dividend for is given the tests of both traps its row states and runs as the division of the dividend joined at twice the width: the target's division where it divides at that width, and otherwise the chain or the helper of that width as above. The quotient is the low word of that quotient, which fits once the traps are tested, and the remainder is the low word of the dividend less the quotient times the divisor. Where the target declares one at the width, its traps are tested as a division's are, by what the target's instruction does with each.
- The multiply and the division hold under the condition the target row states for each, read on the build's basis as a float operation's is: RISC-V multiplies under `zmmul`, which `m` implies, and divides under `m`, and every other target always. Where the condition is not met no width has the instruction.
- A multiply at a width the target has no multiply for calls the helper of its width, a multiply by a constant and the double width product of a high half included, so no product reaches the integer legalisations there. A high multiply there extends its operands as it reads them to twice its width and takes the high half of what the helper of that width gives. Where the target multiplies at the word, a wider integer is left to the wide legalisation, which splits it into products of words.
- A conversion between a float and an integer wider than the target's arithmetic calls the helper of its width and format. Where the integer's value fits a word, or the float is no nan and lies within the word's range, the target's conversion at the word runs instead. A target's own conversion that gives something else for a nan or a value out of range is corrected by its selection rules, and the helpers' conversions at the word are always in range.
- A float operation a helper row stands in for (`stands`), `frem`, calls the helper of its format where the format is held and has no native form of it under the build's basis. A vector of floats is refused, since it is scalarised first.
- A float, or a vector of floats, of a format the build holds no unit for is refused by its type (`Why.unheld`), unless it is a value the half precision legalisation leaves as the format at a boundary, read and made only by calls, returns and reinterpretations. A soft float target whose build adds no float extension holds no format, so its float code stops here and never reaches selection.
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
val l: Layout = mirl.target.of(target, ?module.types, mirl.target.context_of(basis));
mirl.target.size(?l, ty, space)          # res[u64, Error], bytes
mirl.target.align(?l, ty, space)         # res[u64, Error], a power of two
mirl.target.extent(?l, ty, space)        # res[Extent, Error], size and alignment together
mirl.target.offset(?l, ty, space, i)     # res[u64, Error], member i of a structure or union
mirl.target.offsets(?l, ty, space, out)  # err[Error], every member of a structure in one walk
mirl.target.stride(?l, ty, space)        # res[u64, Error], the bytes from one element of an array to the next
```

`of` takes the target a module names (found by `mirl.target.row_of(a, module.target)`), the module's type table and the context the build's selection opened, `mirl.target.NO_BUILD` where no family opened a build. The query is for any IR type, laid out in an address space: the one a pointer to it points into, and the default space 0 for a call's values, a frame slot of the convention and a global. Each space's row states the rules its memory is laid out by, and a type is laid out by those rules throughout, members included. Every C target states `c` for each of its spaces. SPIR-V states `std140` for a Uniform block, `std430` for PushConstant, StorageBuffer and PhysicalStorageBuffer, and `c` for the storage classes whose layout Vulkan does not fix.

- An integer or float is a row of the target's data layout, one for each legal width and each number format. Under `c` it has the row's alignment, and under `std140`, `std430` and `scalar` its size, which is refused as `ruled` when it is not a power of two.
- A pointer is the size of the pointer row for its address space, aligned as a scalar of that row. A pointer into a logical space has none and is refused as `unsized`.
- A vector is its element's size times its lane count. Under `c` it is rounded up to its alignment, which follows the vector rule of the target: either the element's alignment or, for a vector at least as wide as the narrowest vector register, the widest register size that the vector fills of the registers the build meets. The rule states each vector register under a condition over the baseline, so x86-64 widens from SSE2's 128 bits to 256 under `avx` and 512 under `avx512f`, and AArch64 states NEON's 128 bits and SVE's scaled width, which fixed-length vectors never split to and which so widens none. A scaled register fixed-length vectors split to is read at the least width the build's selection leaves it. Under `scalar` it has its element's alignment. Under `std140` and `std430` a vector of two lanes has twice its element's alignment and one of three or four lanes four times, so a vector of three lanes is not a multiple of its alignment, and any other lane count is refused as `ruled`.
- An array has its element's alignment, rounded up to 16 under `std140`. Its stride is the one it states, or its element's size rounded up to the array's alignment, and its size is the stride times its count. A stated stride shorter than the element or not a multiple of the alignment is refused as `stride`.
- A structure places each member at the next multiple of the member's alignment, or at the offset it states. It has the largest member alignment, rounded up to 16 under `std140`, and its size is rounded up to it.
- A function type or a target handle has no size and is refused as `unsized`.
- A union is as large as its largest member rounded up to the largest member alignment, with every member at offset 0. Only `c` lays one out, and the other rules refuse it as `ruled`.

A front end lowers a tag to `struct{disc, union{...}}` and reads its layout through the same queries: `offset(l, tag, 0, 0)` is the discriminant's offset and `offset(l, tag, 0, 1)` the payload's, the union placed at the next multiple of its strictest member's alignment. On `riscv64-linux`, `struct{i32, union{i64, i8}}` has its payload at 8 and is 16 bytes at 8, and a vector of four `binary32` is 16 bytes at 16, as wide as the narrowest vector register the row's vector rule states. No second table of sizes exists: mach, mach-std and every pass ask this one.

These are Vulkan's extended alignment (`std140`), base alignment (`std430`) and scalar alignment (`scalar`), with the stride an array leaves unstated placed as tightly as they allow. Under `c` an array's stride is its element's size and every type's size is a multiple of its alignment, so the rules are those of the target's C compiler.

A request that cannot be answered is refused with a reason. The reasons are an unstated fact (the target leaves it out), an address space the target has no row for, an unsized type, a stated offset that is misaligned or overlaps the member before it, a stated stride the rules refuse, a type the space's rules do not lay out, a member index past the type's members, an offset asked of a type that is not a structure or union or a stride of one that is not an array, and a size that does not fit in 64 bits.

## Argument passing

How a function's arguments and results are passed is not in the IR. A `call` states only the signature, and a function states only its function type. A front end never computes it. It asks `mirl.target.abi`, and the backend asks the same routine once per call site.

A target declares the conventions its calls are made under in `convention`: its `Conventions`, a `default` row and the other `rows` a function type may name, or `uncarried` for a convention mirl has no row for yet, whose calls are refused. A function type names the row it is under by its name (`fun(i64) -> () convention sve`), and one that names none is under the default, so a call and a function each pick their row through their signature. The verifier refuses a name the target states no row of (rule 21), and a target whose rows share a name, or leave a field unstated, is refused as unstated. A **convention** is a row for one architecture, system and ABI, as data:

| field | what it states |
|---|---|
| `name` | its spelling, which a function type names it by |
| `abi` | the psABI row of mink's catalog it is, mink's own row (`mink.catalog.arch.riscv.RISCV_LP64D`), which must be one mink states for the target's architecture, so `RISCV_LP64E` is admitted on `riscv64e` alone and refused elsewhere naming `riscv64e`, or none for a family that names no psABI rows |
| `file` | the masc register file its registers are named in, none where there is none, as on wasm and SPIR-V |
| `classifiers` | the result classifier and the argument classifier |
| `word` | the bits of one argument word |
| `floats` | the widest float passed in float registers, or none |
| `passing`, `returning` | the argument and result registers by masc's register handles, each class in the order taken |
| `preserved` | the registers a callee preserves, each `Kept{register, bits}` with `bits` whole or its low part, as RISC-V keeps FLEN bits of `fs0` to `fs11` |
| `reserved` | the registers no call clobbers and nothing allocates |
| `stack` | none, or a stack in memory with its alignment at a call, its red zone, its shadow space, where a call leaves the return address (`link`), its frame pointer with the frame record it heads (`pointer`) and where the stack pointer lives (`pointer_home`: a register, or a global symbol as wasm's `__stack_pointer`) |
| `indirect` | what carries the address of a result passed by reference, and where a callee hands it back |
| `variadic` | where unnamed arguments travel, the count a caller sets, and how a callee reaches them |
| `half` | whether a 16-bit float travels as a float or as an integer |
| `pairs` | whether a two-word value the classifier pairs starts at an even register or at any |
| `packing` | whether stack arguments take word slots or pack at their own size and alignment |
| `tail` | the rule that says whether a call of an assignment may be a tail call |

A row is resolved once per build (`mirl.target.abi.resolve`). A row with a register file is resolved against a masc selection of it, which looks its names up, groups the argument and result registers by class and computes the registers a call clobbers, and its `Resolved` holds those `registers`. A preserved register the row keeps only in part where the selection's register is wider is preserved for a callee, which saves it whole, and clobbered for a caller, and a row that keeps more bits than the register has is refused. A row with no register file resolves with no selection and holds no registers. A build resolves every row of its target, the default first.

```
val c: *Convention = mirl.target.abi.of(target);                                  # res[*Convention, Error], the default
val r: Resolved    = mirl.target.abi.resolve(a, c, opt[*Context].some{?ctx});     # res[Resolved, Unresolved]
mirl.target.abi.classify(a, ?layout, ?r, signature, statement)                    # res[Assignment, Error]
mirl.target.abi.tail(?r, ?assignment)                                             # bool
```

`classify` describes each argument and result type through the **type view**, a tree of nodes whose every size, alignment and offset was asked of the data layout, and runs the row's result classifier and then its argument classifier over it. It is the only caller of a row's classifiers, as `tail` is of its tail rule. The **assignment** it returns states, for each argument and result, whether it travels by value or by reference to a copy the caller makes and owns, and its **pieces**: for each piece a place (a register by masc's identity, a stack offset that is fixed or scales, or an operand of the target's own call form), the offset and size of the bytes it carries, how the offset and size scale, and how the rest of its place is filled. A narrow integer piece in an operand place is extended to the row's word, as wasm's basic C ABI passes an `i8` as an `i32`.

### The placement query

A front end, or a checker such as mach-std's assembly wipe check, reads where a signature's values travel through `mirl.legal.abi.placement`, the one classification the abi legalisation lowers every call, entry and return through. It is never restated elsewhere, so what the query states is what the pass places.

```
val p: Passage = mirl.legal.abi.placement(a, ?build, ?layout, signature, named)   # res[Passage, Unplaced]
mirl.legal.abi.release(?p)                                                         # err[allocator.Error]
```

It takes the build a family opened for the target, whose resolved rows classify, the layout of the module the signature is in, the function type and how many of its arguments a call names (`all` for an entry). The **passage** holds

- `row`, the resolved row the signature names,
- `assignment`, for each argument and result in order its passing (by value, or by reference to a copy of a stated size and alignment) and its pieces, each a place (a register by masc's identity, a stack offset that is fixed or scales, or an operand of the target's call form), the bytes it carries, how they scale and how its place is filled; the piece the address of a result by reference travels in (`address`, the first argument's place where the row's `indirect` carrier is `first`, or a register of its own such as aapcs64's x8); and `stack`, the bytes of the outgoing argument area the arguments take, packed as the row's `packing` says,
- `named`, the named count, the unnamed arguments placed as the row's `variadic` places them,
- `align`, the stack's alignment at a call, 0 for a row with no stack in memory.

Hidden references (win64 passes an aggregate wider than 8 bytes, or of an odd size, by reference), homogeneous float and vector aggregates in their lane registers, split pairs (an aggregate across an integer and a float register, a two-word scalar across a register pair, a value split between the last register and the stack) and darwin arm64's packed stack are each pieces of the one assignment as their rows state them, so a row added later fills the contract and never reshapes it. A placement the row cannot state is refused with a typed reason (`Unplaced`): `signature` for a type that is no function type, `row` naming a convention row the target does not state, and `classify` for the row's own refusal or a target whose convention is uncarried.

On `riscv64-linux` under lp64d, `fun(struct{i64, binary64}) -> (struct{i64, i64, i64})` passes its result by reference to a 24 byte copy at 8 whose address travels in a0, its argument in a1 (the integer, bytes 0 to 8) and fa0 (the double, bytes 8 to 16), and nothing on the stack.

The abi legalisation builds a result returned by reference in place wherever nothing can tell. In the callee, a stack slot every return hands back whole, read just before the return with nothing touching memory in between, and whose address is only ever a load's or a store's, is the memory the carrier addresses, so no return copies into it, and a variable bound to it is bound to that memory. In the caller, a result whose one use stores it whole, right after the call, to memory aligned as the copy is, is passed that destination as its address when the destination is in a stack slot of the function's whose address goes nowhere but its own loads and stores, so the callee cannot reach it through an argument, a global or a pointer it holds. Otherwise the call keeps its own slot and the copy, since the callee may read the destination while it writes the result. A large `err[Fail]` a sink call returns is built straight into the variable it is stored to.

The integers are signless, so a convention that extends a narrow integer by the source type's signedness leaves the piece **declared**, and `classify` fills it from the extension the signature states for that parameter or result: sign or zero extended. A declared piece whose parameter or result states none is refused, naming it, and is never guessed.

The call's **statement** says how its language passes aggregates (by the platform's C rules, or each by reference to a copy the caller makes) and how many of its arguments are named. Both have an unstated zero case, which is refused.

The rows are the six RISC-V conventions of the RISC-V ELF psABI 1.0, rows of one classifier that reads XLEN, the row's `word`, and FLEN, its `floats`, and has no code for any one variant:

| row | word | floats | float ABI |
|---|---|---|---|
| `lp64` | 64 | none | soft |
| `lp64f` | 64 | 32 | single |
| `lp64d` | 64 | 64 | double |
| `ilp32` | 32 | none | soft |
| `ilp32f` | 32 | 32 | single |
| `ilp32d` | 32 | 64 | double |

A named float no wider than FLEN takes a float register, and a wider one passes as an integer of its width. A named structure or array that flattens to one or two floats, or to one float and one integer no wider than a word, each float no wider than FLEN, takes float and integer registers when enough are free, whatever its size. Anything else wider than two words passes by reference, and the rest takes one or two integer registers, an unnamed value of two-word alignment starting at an even one, as every row's `pairs` says, and the e rows' do not. Stack arguments take word slots, as every row's `packing` says. A call may be a tail call when it passes nothing on the stack and no result by reference. A soft float row passes and keeps no float register and reads the integer rule alone.

Every row reserves the global and thread pointers. The rows that pass floats in float registers also reserve the float control and status register, `fcsr` and its `frm` and `fflags` fields. The psABI gives `fcsr` thread storage duration, so a call neither saves nor clobbers the rounding mode that a dynamic rounding reads or the flags that every float operation accrues. A soft float row names no float register, so it resolves on a selection that has none.

The RISC-V targets and the floor each states:

| target | baseline | convention | floats |
|---|---|---|---|
| `riscv64-linux` | `rv64gc` | `lp64d` | F and D |
| `riscv64-freestanding` | `rv64ifd` | `lp64d` | F and D |
| `riscv64imac-freestanding` | `rv64imac` | `lp64` | software |
| `riscv32-linux` | `rv32gc` | `ilp32d` | F and D |
| `riscv32-freestanding` | `rv32i` | `ilp32` | software |
| `riscv32imac-freestanding` | `rv32imac` | `ilp32` | software |

A freestanding target's baseline is the least its convention needs, so a build assumes no extension a chip of that target may lack and adds the rest through `open_with`. A chip below a target's floor is a target of its own. A soft float target holds no float format under its baseline, so every float operation is a helper call. A build that adds `f` or `d` to it computes in binary32 or binary64 natively, under the same soft float convention.

## Addresses

A target states its address model, or `uncarried` when it has none yet and no address is selected. The model is the relocation model, `static`, `pie` or `pic`, and the access each thread-local model of the ir is reached by: local exec, initial exec, general dynamic through the runtime function `lookup` names, a descriptor, a per variable thunk or an index into the thread's module table. `mirl.target.address.reach(model, defined, linkage, tls)` says how one symbol is reached: absolutely, by its distance from the code, through the global offset table, or by its thread-local access. Under `static` every symbol is reached absolutely. Under `pie` and `pic` reach reads one fact, `mirl.target.address.preemptible(relocation, linkage, defined)`, which holds the whole rule of the specification for what the model builds: `static` and `pie` build an executable and `pic` a shared object. A preemptible symbol goes through the table, and any other is reached by its distance from the code, defined or not, so the linker refuses a hidden or internal reference that ends up undefined. Selection reads this and never a target's name, and names relocations by mink's kinds.

RISC-V Linux, RV64 and RV32 alike, is `pie` and reaches local dynamic as general dynamic through `__tls_get_addr`.

An access may be `single` under a condition: where the build does not meet it, one thread runs and a thread-local variable is an ordinary one, and where it does, threads run that reach no thread-local variable yet. WASI states `single` under the atomics extension for every model, so on a threadless build the threadless legalisation (`mirl.legal.threadless`) makes every thread-local global an ordinary one, read from the target's statement and never its name, and on a build with threads refuses each, naming it.

## Attributes

An attribute is a fact one target family needs about a function or global and that no other family reads. A fact such as a SPIR-V entry point's stage or a shader variable's binding is an attribute the family defines. It is never a field of a core record.

An attribute holds

- `family`, the target family that defines it, such as `spirv`,
- `name`, its name within that family, such as `stage`,
- a datum, which is one number, an ordered list of numbers such as a workgroup size, or a name.

`mirl.ir.module.attach(m, symbol, attribute)` attaches an attribute to a function or global. The names and lists are copied. The text form spells an attribute as `attribute @symbol family name = datum`.

A family defines its attributes in a **schema** (`mirl.target.Schema`): the family's name and its entries, sorted by name with no name twice. An entry states

- `name`, the attribute's name,
- `datum`, the kind of datum it states (`mirl.ir.attribute.Kind`: an integer, integers or text),
- `attaches`, whether it attaches to a function or to a global,
- `check`, the rule its datum keeps. The rule reads the datum, every attribute on the same symbol and the target's declarations, so a rule across attributes, such as a workgroup size stated only on a compute entry point, is the entry's own. A broken rule answers a `mirl.target.Violation`, a static row of the family's naming the violation and its wording, so a refusal is told by its row and never by its text.

A target's `attributes` declaration is the schema of its family, or none when it accepts no attribute. Verifier rule 5 refuses an attribute whose family word is not the schema's, whose name the schema has no entry for, attached to the other kind of symbol, with a datum of another kind, or that breaks its entry's rule, and `mirl.verify.module.unfit` gives which, a broken rule carrying its violation's row. The family word is the text spelling only: it is matched against the schema the target names and never looked up.

The register family (`mirl.target.register.schema`) defines no attribute, since no register stage reads a fact only that family needs, so every register target refuses every attribute by name. The SPIR-V target accepts none until its family's schema is written.
