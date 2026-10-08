# RISC-V selection rules

`mirl.isa.riscv.TABLE` is the selection table for RV32 and RV64, the first table the selection engine reads (see [selection](../machine/select.md)). It is static data. It names rows of masc's RISC-V catalog and nothing else, so mirl never encodes and never invents an instruction.

## What it reads

- The register width comes from the target's `widths.register` declaration. A rule that differs by width carries a hook that reads it. No rule reads an architecture's name.
- The extensions come from the target's selection, which masc closes over implied extensions once. A rule emits rows, and the engine drops a rule whose row masc does not admit. So M, A (Zaamo, with Zabha for bytes and halves), F and D, Zfh, Zfa, Zicond and the Zba, Zbb and Zbs bit manipulation extensions are each a row's requirement and never a branch in the table.
- A catalog row that exists once per width (`slli`, `rori`, `ld`) is two named rows, and the one the selection admits is the one the rule takes.
- `rows.mach` names every row once, by its position in the generated catalog. The table's test checks each name against the mnemonic and width it stands for, so a regenerated catalog that moves a row is a failing test.

## Values

An integer narrower than the register is held sign extended to the register, as the psABI holds it, and a condition (`i1`) is held as 0 or 1. Integers and pointers live in the general registers and floats in the float registers.

- A 32 bit operation on RV64 takes the word forms (`addw`, `slliw`, `divw`), which keep the result sign extended. On RV32 the same operation takes the plain forms.
- A comparison whose only use is a conditional branch selects with it as one `beq`, `bne`, `blt`, `bge`, `bltu` or `bgeu` and a jump, and no register holds the condition. Any other comparison gives 0 or 1 with `slt`, `sltu`, `xori` or `sltiu`.
- Constants: `addi` from x0 builds 12 signed bits, `lui` alone builds a value whose low 12 bits are zero, `lui` and `addiw` (`addi` on RV32) build 32 bits, and six instructions build any 64 bit value. Their costs are 2, 2, 4 and 12, which constant hoisting reads. A float constant is built in an integer register and moved.
- A kept store selects to a store row that carries the mark. The instructions around it, such as a constant's materialisation, do not.

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
- `frem`, `mem.copy` and `mem.fill`, which no instruction does (helpers, #54).
- A call, whose operands and results the calling convention places (#28), and a return with operands. A return with none selects to `jalr`.
- `alloca`, the address of a frame slot (#29), and the address of a global or function as a constant.
- `atomic.nand` and `atomic.cmpxchg`, a loop of load reserved and store conditional that an expansion cannot hold.

Some operations select only for the operands a base form covers.

- A shift selects for a constant count. RISC-V takes a variable count modulo the width and the ir gives 0 or the sign fill, so a variable shift waits for the shift bounding that marks a count it has bounded (#55).
- Division and remainder select to the instruction, which does not trap. The zero and overflow checks are inserted before selection (#54).
- A multiply of two registers needs M, and without it names `mul`. A narrower multiply form waits for #55.
- Arithmetic at 8 and 16 bits, and a signed comparison of conditions, has no rule. The target's ALU widths are 32 and 64, so narrower arithmetic is promoted before selection.
- `fmin`, `fmax`, `ffloor`, `fceil`, `fint` and `fnearest` select to Zfa rows and have no base form. A select of floats has no rule. A 64 bit float constant needs RV64.
- Half precision selects with Zfh and is otherwise legalised away (#53), and so are integers wider than the register (#51).
