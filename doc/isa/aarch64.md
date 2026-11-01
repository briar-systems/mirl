# AArch64 selection rules

`mirl.target.register.aarch64.isa.TABLE` is the selection table for AArch64 under AAPCS64, darwinpcs, aapcs64win and arm64ec (see [selection](../machine/select.md)). It is static data, and names rows of masc's AArch64 catalog by the handles masc publishes for them (`gen_row.ADD_64_ADDSUB_SHIFT`), so mirl never encodes and never invents an instruction. Its record in `mirl.target.register.isa` joins it, the frame code, the moves and the loops to masc's set.

## What it reads

- The register is 64 bits. A rule's type tests state the width against it, `register` for a doubleword and `part{2}` for a word, so a word takes the w form of a row and a doubleword the x form.
- The extensions come from the target's selection. A rule emits rows and the engine drops a rule whose row masc does not admit, so LSE's atomics, CSSC's `ctz`, `cnt` and the SVE whole register rows are each a row's requirement and never a branch in the table. FP and SIMD are the baseline both rows require.
- The object format comes from the target's record. A symbol is reached through ELF's relocation kinds, Mach-O's or COFF's, each address rule's hook reading the format, so no rule names a system.
- Every register and class is a handle masc generates (`gen_register.X_CLASS`, `gen_register.XZR`), so no file here holds a position in masc's register file.

## Values

An integer or pointer lives in an x register. A word computes in its w view, which the allocator names through the view of the x virtual, and its write zeroes the upper half as masc's `overwrites` states. The bits of a narrow integer above its width are unspecified, so every reader that needs them extends: a compare of narrow values, a pointer offset of 32 bits (`add` with `sxtw`), a narrow minimum or maximum. A condition is 0 or 1.

A float of either width and a vector live in a v register. With FPCR.DN clear, as Linux and darwin run, an operation gives its first signalling NaN operand quieted, else its first quiet one, and an invalid operation the positive default NaN, which the target states as `Nans.propagate` with the `signalling` priority. An `fma` takes its addend first, as FPMulAdd calls FPProcessNaNs3. A scalar row names its s or d view of the v virtual, so every copy of a float or a vector is one exact move of a v register. Binary16 is not held. The flags are written and read inside one expansion and never hold a value.

- A comparison whose only use is a branch selects with it as `subs` and `b.cond`, and one against zero as `cbz` or `cbnz`, and a test of one bit as `tbz` or `tbnz`. A select takes the compare it reads into `csel` or `fcsel`. Any other comparison gives 0 or 1 by `cset`, which is `csinc` of the zero register.
- A float comparison is `fcmp` and one condition, with `mi`, `ls`, `lt`, `le`, `hi` and `pl` reading the ordered and unordered outcomes as the Arm ARM's table of `fcmp` flags gives them. An equal or unordered and an ordered not equal take two conditions.
- Constants: `orr` of a bitmask immediate from the zero register, `movz` or `movn` of one sixteen-bit chunk, and `movz` with up to three `movk` for any value, costing 2, 2, 2 and 8. A float constant is built in a general register and moved by `fmov`, and zero is `fmov` from the zero register.
- A float to integer conversion is `fcvtzs` or `fcvtzu`, which round toward zero, saturate at 32 and 64 bits and give 0 for a NaN, as the IR does. A narrow destination clamps the saturated word against its least and greatest values with `cmp` and `csel`, with no branch, so it keeps constant time. A conversion to a condition is true for a signed value of minus one or less and an unsigned one of one or more.
- `fminnum` and `fmaxnum` take the other operand where one is a NaN by two `fcmp` of an operand with itself and two `fcsel`, then `fmin` or `fmax`, since `fminnm` gives the default NaN for a signalling operand. `fcopysign` goes through the general registers.

## Calls, returns and addresses

- A call to a symbol is `bl` under `call26` on ELF and COFF and `branch26` on Mach-O. A call through a register is `blr`. A return is `ret` of the convention's link register, a `link` source.
- An `alloca` is the `address` pseudo of a frame slot of its type.
- The address of a symbol follows the target's relocation model. A symbol not preemptible is `adrp` and `add` (`page21`, `lo12_add`), and a preemptible one `adrp` and a load from the global offset table (`got_page21`, `got_lo12`). Mach-O's are `page21` and `pageoff12`, and `got_load_page21` and `got_load_pageoff12`. A PE image resolves every symbol at link time, so COFF's is always `page21` and `lo12_add`. `func.addr` takes the same pairs.
- A thread-local variable follows the access the model declares. Local exec is `mrs` of `tpidr_el0` and two adds (`tlsle_add_tprel_hi12`, `tlsle_add_tprel_lo12_nc`). Initial exec loads the offset from the global offset table. A descriptor access is the TLSDESC sequence, `adrp`, `ldr` of the resolver, `add` into x0 and `blr`, a call to the descriptor (`Callee.descriptor`), which leaves only the registers the row states for it undefined, then `mrs` and `add`. Darwin's variable access loads the thunk from its descriptor and calls it with the descriptor in x0, which gives the address back in x0. Windows' indexed access is `adrp` and `ldr` of the index from `_tls_index`, `ldr` of the TEB's ThreadLocalStoragePointer at `[x18, #0x58]`, `ldr` of the module's block at the index with the register offset form, and two adds of the variable's offset in its section (`secrel_hi12`, `secrel_lo12_add`). Local exec keeps an address's offset past its variable in its relocations. A global offset table load and every other access take the symbol at its start and add the offset after, an `add` or `sub` of twelve bits or an `add` of a register `movz` and `movk` fill ([select.md](../machine/select.md)).

## Atomics

| ordering | load | store | read-modify-write | exclusive loop | fence |
|---|---|---|---|---|---|
| relaxed | `ldr{b,h}` | `str{b,h}` | `<op>` | `ldaxr`, `stlxr` | |
| acquire | `ldar{b,h}` | | `<op>a` | `ldaxr`, `stlxr` | `dmb ishld` |
| release | | `stlr{b,h}` | `<op>l` | `ldaxr`, `stlxr` | `dmb ish` |
| acq_rel | | | `<op>al` | `ldaxr`, `stlxr` | `dmb ish` |
| seq_cst | `ldar{b,h}` | `stlr{b,h}` | `<op>al` | `ldaxr`, `stlxr` | `dmb ish` |

The mapping is the Arm ARM's and the one Arm's C/C++ atomics ABI for the 64-bit architecture states (abi-aa, atomicsabi64). A read-modify-write with LSE is `ldadd`, `ldset`, `ldeor`, `swp`, `ldsmax`, `ldsmin`, `ldumax` or `ldumin`, a subtraction `ldadd` of the negated operand and an and `ldclr` of the inverted one, at each size. A compare and exchange is `cas`, its first register tied to the value expected, and the success flag compares the value found with it in its low bits. Without LSE every operation is a loop of `mirl.target.register.aarch64.loop`: the load-acquire exclusive, the computation in base rows, the store-release exclusive, and `cbnz` back while it failed. A byte and a halfword have exclusives of their own, so no loop works on a field. A nand has no LSE row and is always a loop. The bodies keep `LLSC`, sixteen instructions at most with no memory access, fence or branch between the pair but a compare and exchange's branch out.

A compare and exchange of two words, which the wide legalisation makes of a 128-bit one, is LSE's `casp`, `caspa`, `caspl` or `caspal` on two virtual registers of the `xp` pair class, each an even `x` register and the next. One parallel copy writes the expected words into the members of the first, one the desired words into the second, and one takes the words found out of the first, member 0 the low word since masc states `xp` in order of address and every aarch64 target is little-endian. Without LSE it is the loop `cmpxchg_xp`: `ldaxp`, a compare of the low words and a `ccmp` of the high ones, a `csel` of each word to store, the desired word where both matched and the word held otherwise, `stlxp` and `cbnz` back. It stores in every case and has no branch out, since an exclusive pair of two words is single-copy atomic only where its store succeeds. The success flag compares the words found with the expected ones by `cmp`, `ccmp` and `cset`.

## Vectors

The table selects NEON by lane width and by register size, a vector of at most 64 bits in a 64-bit arrangement and one of 128 in a 128-bit arrangement: integer `add`, `sub`, `mul`, `and`, `orr`, `eor`, `not` and `neg`, float `fadd`, `fsub`, `fmul`, `fdiv`, `fneg`, `fabs` and `fsqrt`, a splat by `dup`, and loads and stores of 16, 32, 64 and 128 bits. A vector narrower than its register leaves the bytes above it undefined, so no rule reads a lane past the vector's. It selects these directly:

- `smull` and `umull`: the product of two extensions of 64-bit vectors to twice their width, and `smull2` and `umull2` of the high halves of 128-bit vectors taken by a shuffle.
- `smlal`, `umlal`, `smlal2` and `umlal2`: a sum of a value and such a product, the accumulator tied.
- `addv`: a sum across the lanes, and `addp` for two lanes, moved to a general register by `umov` or `fmov`.
- `saddlv` and `uaddlv`: a sum across the lanes of a vector extended to twice their width.
- `sxtl` and `uxtl` (`sshll` and `ushll` by zero): an extension of each lane to twice its width, and `sxtl2` and `uxtl2` of the high half of a 128-bit vector a shuffle takes.

The lane rules are in `mirl.target.register.aarch64.lanes`. A lane's index and a shuffle's lanes are the root's immediates, which computed sources turn into the immediates of the instructions.

- `vextract` is `umov` to a general register, or the scalar `dup` of a float lane. `vinsert` is `ins`, the vector tied. `vbuild` is `dup` of the first lane and `ins` of each other.
- `vshuffle` is `dup` by lane for a broadcast, `ext` for consecutive lanes of one operand or of the two joined, `zip1`, `zip2`, `uzp1`, `uzp2`, `trn1` and `trn2` for those permutations of two whole vectors, and `rev16`, `rev32` and `rev64` for a reversal within groups. Any other is `tbl` on one operand and `tbx` on the other, by selectors built in a general register by `movz` and `movk` and moved across.
- An integer reduction is `addv`, `smaxv`, `sminv`, `umaxv` or `uminv` where NEON has one, the pairwise form for two 32-bit lanes, and otherwise a tree that folds the upper half of what is left onto the lower by `ext`. A reduction of two doublewords NEON has no form for is taken in the general registers, a minimum or maximum by `cmp` and `csel`.
- A reassociable float sum is `faddp`. A sequential one adds the lanes in order, `faddp` giving the first lane plus the second as `fadd` does. A float product of either order is `fmul` by element, lane after lane. A float minimum or maximum is `fminp`, `fmaxp`, `fminv` or `fmaxv`, which combine as `fmin` and `fmax` do.

The NEON unit's operation rows (`AARCH64_OPERATIONS`) state what the table selects on its own, so the vector legalisation leaves those packed and takes every other lane by lane.

## Cost

A cost is two for each instruction an expansion emits, with a multiply counting three, a divide twelve and a loop twelve. It is one less for each instruction the pattern covers and one less when the rule takes its constant operand as an immediate.

## What the table does not select

The declared operations are in `declared.mach`, each with the job that closes it.

- `reduce.fminnum` and `reduce.fmaxnum`: `fminnmv` and `fmaxnmv` give a NaN for a signalling NaN lane where the IR's opcodes give the other operand, so no row of the NEON unit states them and the vector legalisation takes them lane by lane. A vector of a lane count no arrangement holds is refused naming the instruction.
- `frem`, `mem.copy`, `mem.fill` and the wide division, which the helpers legalisation takes out on every build, since AArch64 states none natively.
- A call and a return, `ptr.member`, `ptr.index`, a sparse `switch`, `extract` and `insert`, as on RISC-V. A dense `switch` reaches selection indexed, with its cases 0 to its count less one over an x register, and branches through a jump table. `subs` and `b.hs` to the first target test the index against the count, or `movz`, `movk` and the register `subs` do when the count doesn't fit the immediate. `adrp` and `add` form the table's address, which reaches the function's own table under static, pie and pic alike. `add` scales the index to the pointer, then `ldr` loads the entry and `br` jumps through it. Every target begins with the table's landing, `bti j`, where the build holds BTI. A switch on a system with no address model stays a chain.

Some operations select only for the operands a base form covers.

- A shift by a variable count selects only when it carries the bounded mark, since `lslv`, `lsrv` and `asrv` take the count modulo the width.
- Division selects to `sdiv` and `udiv`, which give 0 for a zero divisor and the dividend for an overflowing quotient, only when it carries the `checked` flag.
- The counts, the byte swap and the overflow forms at 1, 8 and 16 bits, which the narrowing leaves, extend their operands as they read them and compute in a word.

## Limits

- A load or store takes a base register and a constant offset: `ldr` and `str` with the scaled unsigned immediate, and `ldur` and `stur` with nine signed bits where that does not reach. The register offset form, `[base, index, lsl #n]`, is selected only in windows' thread-local sequence, spelling masc's enumerant values: elsewhere an index is added into the base first.
- masc states the destination of `scvtf` and `ucvtf` read and written, since FPCR.NEP set would merge the upper lanes, and masc's state takes no caller-fixed value for it. mach never sets NEP, but liveness keeps the old value of each such destination live until masc can be told so.
- Under `aapcs64win` a function that allocates dynamically is refused, as on windows x64, since its probe of each page is not written. Every frame keeps the frame pointer, and a frame whose saves would set it more than 2040 bytes above the stack pointer, past what the arm64 unwind codes state, is refused.
- `arm64ec` is mink's architecture row of its own, with aarch64's capabilities and windows arm64's address model. Its row reserves x13, x14, x23, x24 and x28 and v16 to v31 with every view of each, which map to no x64 register, keeps the rest of aapcs64win's, probes through `__chkstk_arm64ec` and places a variadic call's arguments as x64 does, one word each in x0 to x3 and 8 byte stack slots. A variadic call is refused, since the callee is handed the stack words' address in x4 and their size in x5 and the address of the outgoing area is no value of the IR yet. masc serves no set for `arm64ec` and mink's windows hosts run no `arm64ec`, so the target does not assemble yet, and the entry and exit thunks, the `#name` decoration and the calls through `__os_arm64x_check_icall` are not written.
- Neither z nor p holds a value: SVE code generation is the vectorisation job's (#72). The frame code states their whole register loads and stores and their scaled steps.
