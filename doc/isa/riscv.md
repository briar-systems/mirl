# RISC-V selection rules

`mirl.isa.riscv.TABLE` is the selection table for RV32 and RV64, the first table the selection engine reads (see [selection](../machine/select.md)). It is static data. It names rows of masc's RISC-V catalog and nothing else, so mirl never encodes and never invents an instruction.

## What it reads

- The register width comes from the target's `widths.register` declaration. A rule that differs by width carries a hook that reads it. No rule reads an architecture's name.
- The extensions come from the target's selection, which masc closes over implied extensions once. A rule emits rows, and the engine drops a rule whose row masc does not admit. So M, A (Zaamo, with Zabha for bytes and halves), F and D, Zfh, Zfa, Zicond and the Zba, Zbb and Zbs bit manipulation extensions are each a row's requirement and never a branch in the table.
- A catalog row that exists once per width (`slli`, `rori`, `ld`) is two named rows, and the one the selection admits is the one the rule takes.
- A rule names each row and each scratch or holding class by the handle masc generates for it (`gen_row.ADD`, `register.X`), so no file here holds a position in masc's catalog or register file. A regenerated catalog that renames a row is a compile error here and never a different instruction.

## Values

An integer narrower than the register is held sign extended to the register, as the psABI holds it, and a condition (`i1`) is held as 0 or 1. Integers and pointers live in the general registers and floats in the float registers.

- A 32 bit operation on RV64 takes the word forms (`addw`, `slliw`, `divw`), which keep the result sign extended. On RV32 the same operation takes the plain forms.
- A comparison whose only use is a conditional branch selects with it as one `beq`, `bne`, `blt`, `bge`, `bltu` or `bgeu` and a jump, and no register holds the condition. Any other comparison gives 0 or 1 with `slt`, `sltu`, `xori` or `sltiu`.
- Constants: `addi` from x0 builds 12 signed bits, `lui` alone builds a value whose low 12 bits are zero, `lui` and `addiw` (`addi` on RV32) build 32 bits, and six instructions build any 64 bit value. Their costs are 2, 2, 4 and 12, which constant hoisting reads. A float constant is built in an integer register and moved.
- A kept store selects to a store row that carries the mark. The instructions around it, such as a constant's materialisation, do not.

## Calls, returns and addresses

The abi legalisation puts every call, entry and return in piece form before selection, and the engine places the pieces (see [selection](../machine/select.md)). The table supplies the forms.

- A call to a symbol is `auipc x1` and `jalr x1, x1, 0` under `call_plt_pair`, which the linker may relax. A call through a register is `jalr x1`. A return is `jalr x0, x1, 0`.
- An `alloca` is the `address` pseudo of a frame slot of its type.
- The address of a symbol follows the target's relocation model. Under `static` it is `lui` and `addi` (`hi20`, `lo12_i`). Under `pie` and `pic` a symbol that is not preemptible is `auipc` and `addi` (`pcrel_hi20`, `pcrel_lo12_i`), and a preemptible one is `auipc` and a load from the global offset table (`got_pcrel_hi20`) (see [ir/target.md](../ir/target.md)).
- A thread-local variable follows the access the target declares for its model. Local exec is `lui`, `add` of `tp` and `addi` (`tprel_hi20`, `tprel_lo12_i`). Initial exec is `auipc`, a load (`tls_got_pcrel_hi20`) and `add` of `tp`. General dynamic is `auipc` and `addi` into `a0` (`tls_gd_pcrel_hi20`), a call to the target's lookup function, which reads and writes `a0`, and a copy out of `a0`.
- Every pc-relative low part names its high part's instruction as its partner (`pcrel_lo12_i`), the label the relocation is applied at.

## Cost

A cost is two for each instruction an expansion emits, with a multiply counting three and a divide twelve. It is one less for each instruction the pattern covers and one less when the rule takes its constant operand as an immediate. So a rule that covers more costs less than the rules for its pieces, and no choice rests on the order of rows.

## Without an extension

Where an extension is absent the rule for its row is dropped and a base form stands in.

- Count leading zeros, count trailing zeros, population count and byte swap expand to loop free sequences of base instructions.
- A rotate by a constant is its two shifts and an `or`. A multiply by a constant of the form 2^k, 2^k+1 or 2^k-1 is a shift and an add.
- `andn`, `orn`, `xnor`, `sext.b`, `sext.h`, `zext.h` and `add.uw` fall to the instruction pairs they abbreviate, and a select without Zicond is four instructions.

## What the table does not select

The declared operations are in `declared.mach`, each with the job that closes it. The walk in the table's test checks that every opcode of the ir has a rule or is declared, and not both.

- Vector operations, because the target holds vectors in no register (scalarisation, #52).
- `frem`, which no instruction does (#225).
- `mem.copy` and `mem.fill`, which no instruction does. The helpers legalisation turns each into a call of a helper, or a kept fill into a loop of kept stores, before selection (see [target](../ir/target.md)).
- A call and a return, which the abi legalisation puts in piece form, so only `call.placed` and `ret.placed` reach the table.
- `atomic.nand` and `atomic.cmpxchg`, a loop of load reserved and store conditional that an expansion cannot hold.

Some operations select only for the operands a base form covers.

- A shift by a variable count selects only when it carries the bounded mark. RISC-V takes the count modulo the width and the ir gives 0 or the sign fill, so the shift bounding legalisation bounds the count and marks the shift, and the rule then emits `sll`, `srl` or `sra`, with the `w` forms for 32 bits on RV64.
- Division and remainder select to the instruction, which does not trap. The helpers legalisation tests the zero divisor and the signed overflow before it and marks it `checked`.
- A multiply of two registers needs M, and without it names `mul`. The high half of a product, which M gives as `mulh`, `mulhu` and `mulhsu`, is selected whole: the truncation of the product of two extensions shifted down by the register width is one `mulh`, `mulhu` or `mulhsu` (M), for operands as signed, unsigned, and one of each in either order. The 32 bit form on RV64 is left to the rules for its pieces.
- Arithmetic on conditions other than `and`, `or`, `xor` and the unsigned comparisons, which the target declares it selects on single bits, has no rule, and neither has arithmetic at 8 and 16 bits. Both are widened to the target's ALU widths before selection (see [target](../ir/target.md)), except the counts, the byte swap and the overflow forms, which `mirl.legal.LEFT` lists.
- `fmin`, `fmax`, `ffloor`, `fceil`, `fint` and `fnearest` select to Zfa rows. Without Zfa the float legalisation stands in for them with F and D instructions, which the target's rows state (see [target](../ir/target.md)). A select of floats has no rule and is a select of the bits. A 64 bit float constant is built in a register on RV64, and on RV32 the float constant legalisation loads it from read-only data.
- Half precision selects with Zfh and is otherwise legalised away (#53). Integers wider than the register are split into words before selection (see [target](../ir/target.md)), and the carry between words is `sltu`.
