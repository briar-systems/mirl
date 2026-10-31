# Machine form text

`mirl.machine.text` prints a module's machine functions as text, as selection and allocation leave them, and `emit -e machine` writes it. It is written for people reading the code generator's work and is never read back. The printer writes through the IR text form's printer, so the header, quoting, symbol names, debug entry names and an instruction's location, site and bindings are that form's. Registers, classes and instructions are spelled by the rows of the target's register file and catalog, so a row added to masc needs no change here.

```
mirl.machine.text.print(w, m, isas, items)    # err[Error]
```

What the machine form names itself takes `%`, which no row's name starts with: a virtual register is `%` and its number, a frame slot `%s` and its number and a block `%b` and its number. A tuple, one register of a pair class as RISC-V's amocas.q and rv32 Zdinx operands take, is spelled by its row's name, quoted as `"x12:x13"`, or as `"vg2.v4"` for a RISC-V vector group, since the assembly syntax spells it by its first member alone. A virtual register of a group is declared of its class, `var %0: vg2;`, and `%0[1]` names its second member, which is the high half of a RISC-V pair, so a pair is made from its words and taken apart into them.

The grammar is stated once, in `src/machine/text.mach`.

## Placement

`#[placed(...)]` before a function is where its parameters arrive, and `places` after an instruction is where the pieces of the call it makes travel, the arguments' and then the results'. Both are printed from what the abi legalisation stored, the entry's places and the `call.placed` instruction's, which selection carries to the machine function and every later stage keeps. The printer classifies nothing, and nothing reads the annotation to decide anything. A place reads as the IR text's place does, with the register spelled by the register file's name in place of its class and number.

```
#[placed([{reg(x10), fixed, exact}, {reg(x11), fixed, exact}])] fun caller {
    slot %s0: size 8, align 8;
%b0:
    ...
    jalr(x1, x1, 0) reads [x10] writes [x10] places [{reg(x10), fixed, exact}, {stack(0), fixed, exact}, {reg(x10), fixed, exact}];
}
```
