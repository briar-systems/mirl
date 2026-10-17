# AArch64 selection rules

`mirl.target.register.aarch64.isa.TABLE` is the selection table for AArch64 under AAPCS64 and darwinpcs (see [selection](../machine/select.md)). It is static data, written out by a generator kept beside the work, and names rows of masc's AArch64 catalog by the handles masc publishes for them (`gen_row.ADD_64_ADDSUB_SHIFT`), so mirl never encodes and never invents an instruction. Its record in `mirl.target.register.isa` joins it, the frame code, the moves and the loops to masc's set.

## What it reads

- The register is 64 bits. A rule's type tests state the width against it, `register` for a doubleword and `part{2}` for a word, so a word takes the w form of a row and a doubleword the x form.
- The extensions come from the target's selection. A rule emits rows and the engine drops a rule whose row masc does not admit, so LSE's atomics, CSSC's `ctz`, `cnt` and the SVE whole register rows are each a row's requirement and never a branch in the table. FP and SIMD are the baseline both rows require.
- The object format comes from the target's record. A symbol is reached through ELF's relocation kinds or Mach-O's, each address rule's hook reading the format, so no rule names a system.
- Every register and class is a handle masc generates (`gen_register.X_CLASS`, `gen_register.XZR`), so no file here holds a position in masc's register file.

## Values

An integer or pointer lives in an x register. A word computes in its w view, which the allocator names through the view of the x virtual, and its write zeroes the upper half as masc's `overwrites` states. The bits of a narrow integer above its width are unspecified, so every reader that needs them extends: a compare of narrow values, a pointer offset of 32 bits (`add` with `sxtw`), a narrow minimum or maximum. A condition is 0 or 1.

A float of either width and a vector live in a v register. A scalar row names its s or d view of the v virtual, so every copy of a float or a vector is one exact move of a v register. Binary16 is not held. The flags are written and read inside one expansion and never hold a value.

- A comparison whose only use is a branch selects with it as `subs` and `b.cond`, and one against zero as `cbz` or `cbnz`, and a test of one bit as `tbz` or `tbnz`. A select takes the compare it reads into `csel` or `fcsel`. Any other comparison gives 0 or 1 by `cset`, which is `csinc` of the zero register.
- A float comparison is `fcmp` and one condition, with `mi`, `ls`, `lt`, `le`, `hi` and `pl` reading the ordered and unordered outcomes as the Arm ARM's table of `fcmp` flags gives them. An equal or unordered and an ordered not equal take two conditions.
- Constants: `orr` of a bitmask immediate from the zero register, `movz` or `movn` of one sixteen-bit chunk, and `movz` with up to three `movk` for any value, costing 2, 2, 2 and 8. A float constant is built in a general register and moved by `fmov`, and zero is `fmov` from the zero register.
- A float to integer conversion is `fcvtzs` or `fcvtzu`, which round toward zero, saturate at 32 and 64 bits and give 0 for a NaN, as the IR does. A narrow destination clamps the saturated word against its least and greatest values with `cmp` and `csel`, with no branch, so it keeps constant time. A conversion to a condition is true for a signed value of minus one or less and an unsigned one of one or more.
- `fminnum` and `fmaxnum` take the other operand where one is a NaN by two `fcmp` of an operand with itself and two `fcsel`, then `fmin` or `fmax`, since `fminnm` gives the default NaN for a signalling operand. `fcopysign` goes through the general registers.

## Calls, returns and addresses

- A call to a symbol is `bl` under `call26` on ELF and `branch26` on Mach-O. A call through a register is `blr`. A return is `ret` of the convention's link register, a `link` source.
- An `alloca` is the `address` pseudo of a frame slot of its type.
- The address of a symbol follows the target's relocation model. A symbol not preemptible is `adrp` and `add` (`page21`, `lo12_add`), and a preemptible one `adrp` and a load from the global offset table (`got_page21`, `got_lo12`). Mach-O's are `page21` and `pageoff12`, and `got_load_page21` and `got_load_pageoff12`. `func.addr` takes the same pairs.
- A thread-local variable follows the access the model declares. Local exec is `mrs` of `tpidr_el0` and two adds (`tlsle_add_tprel_hi12`, `tlsle_add_tprel_lo12_nc`). Initial exec loads the offset from the global offset table. A descriptor access is the TLSDESC sequence, `adrp`, `ldr` of the resolver, `add` into x0 and `blr`, a call to the descriptor (`Callee.descriptor`), which leaves only the registers the row states for it undefined, then `mrs` and `add`. Darwin's variable access loads the thunk from its descriptor and calls it with the descriptor in x0, which gives the address back in x0.

## Atomics

| ordering | load | store | read-modify-write | exclusive loop | fence |
|---|---|---|---|---|---|
| relaxed | `ldr{b,h}` | `str{b,h}` | `<op>` | `ldaxr`, `stlxr` | |
| acquire | `ldar{b,h}` | | `<op>a` | `ldaxr`, `stlxr` | `dmb ishld` |
| release | | `stlr{b,h}` | `<op>l` | `ldaxr`, `stlxr` | `dmb ish` |
| acq_rel | | | `<op>al` | `ldaxr`, `stlxr` | `dmb ish` |
| seq_cst | `ldar{b,h}` | `stlr{b,h}` | `<op>al` | `ldaxr`, `stlxr` | `dmb ish` |

The mapping is the Arm ARM's and the C++ one compilers use. A read-modify-write with LSE is `ldadd`, `ldset`, `ldeor`, `swp`, `ldsmax`, `ldsmin`, `ldumax` or `ldumin`, a subtraction `ldadd` of the negated operand and an and `ldclr` of the inverted one, at each size. A compare and exchange is `cas`, its first register tied to the value expected, and the success flag compares the value found with it in its low bits. Without LSE every operation is a loop of `mirl.target.register.aarch64.loop`: the load-acquire exclusive, the computation in base rows, the store-release exclusive, and `cbnz` back while it failed. A byte and a halfword have exclusives of their own, so no loop works on a field. A nand has no LSE row and is always a loop. The bodies keep `LLSC`, sixteen instructions at most with no memory access, fence or branch between the pair but a compare and exchange's branch out.

## Vectors

The table selects a NEON subset by lane width and by register size, a vector of at most 64 bits in a 64-bit arrangement and one of 128 in a 128-bit arrangement: integer `add`, `sub`, `mul`, `and`, `orr`, `eor`, `not` and `neg`, float `fadd`, `fsub`, `fmul`, `fdiv`, `fneg`, `fabs` and `fsqrt`, a splat by `dup`, and loads and stores of 16, 32, 64 and 128 bits. It selects these directly:

- `smull` and `umull`: the product of two extensions of 64-bit vectors to twice their width, and `smull2` and `umull2` of the high halves of 128-bit vectors taken by a shuffle.
- `smlal`, `umlal`, `smlal2` and `umlal2`: a sum of a value and such a product, the accumulator tied, where masc states the accumulator read and written (see the limits).
- `addv`: a sum across the lanes, and `addp` for two lanes, moved to a general register by `umov` or `fmov`.
- `saddlv` and `uaddlv`: a sum across the lanes of a vector extended to twice their width.

## Cost

A cost is two for each instruction an expansion emits, with a multiply counting three, a divide twelve and a loop twelve. It is one less for each instruction the pattern covers and one less when the rule takes its constant operand as an immediate.

## What the table does not select

The declared operations are in `declared.mach`, each with the job that closes it.

- Vector operations beyond the subset: `vbuild`, `vextract` and `vinsert`, whose lane is an immediate no source reads, a shuffle other than the high half a widening multiply takes, and every reduction but a sum (vectorisation, #72). A select of vectors and a vector of a lane count no arrangement holds are refused naming the instruction.
- `frem`, `mem.copy`, `mem.fill` and the wide division, which the helpers legalisation takes out on every build, since AArch64 states none natively.
- A call and a return, `ptr.member`, `ptr.index`, `switch`, `extract` and `insert`, as on RISC-V.

Some operations select only for the operands a base form covers.

- A shift by a variable count selects only when it carries the bounded mark, since `lslv`, `lsrv` and `asrv` take the count modulo the width.
- Division selects to `sdiv` and `udiv`, which give 0 for a zero divisor and the dividend for an overflowing quotient, only when it carries the `checked` flag.
- The counts, the byte swap and the overflow forms at 1, 8 and 16 bits, which the narrowing leaves, extend their operands as they read them and compute in a word.

## Limits

- A load or store takes its address in a base register alone. Its immediate and register offset forms wait on the address source the selection engine gains with x86 (#43).
- Mach-O's relocation kinds, Windows', and every ELF thread-local kind have no binding in masc yet, so a darwin address, any thread-local access and darwin's call are refused `unbound` when encoded. ELF TLS is masc#441, and the others wait on mink's neutral AArch64 relocation kinds and masc's rebinding of them.
- masc states the roles of some rows other than the instruction does: integer stores' `Rt` written, float loads' `Rt` read, `stp` and `ldp` operands read and written, float data processing destinations read and written, and the accumulator of `smlal` and `umlal` written alone. Liveness reads masc's roles, so these rows mislead it until masc corrects them. A tie needs a row that reads and writes the position, so the multiply-accumulate rules hold only where masc states every accumulator so, and until then the product and the sum select apart.
- `aapcs64win` is not carried, since mink writes no PE image yet (mink#70).
- Neither z nor p holds a value: SVE code generation is the vectorisation job's (#72). The frame code states their whole register loads and stores and their scaled steps.
