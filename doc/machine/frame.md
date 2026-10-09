# Frames

`mirl.machine.frame` lays out the stack frame of an allocated register machine function, saves the callee-saved registers it writes, writes its prologue and epilogues, and states its call frame information as data for masc's CFI calls. It reads every frame fact from the target's convention row and from masc's rows, and names no architecture.

```
frame(a, ?allocation, Request{convention: ?resolved, at: ?locations}, ?code)   # res[Framed, Error]
lay(a, f, used, request)                                                     # res[Plan, lay.Error]
finish(a, f, ?plan, ?code)                                                   # res[Framed, finish.Error]
keeps_pointer(a, f, request)                                                 # res[bool, lay.Error]
```

`frame` is `lay` then `finish`. `keeps_pointer` answers before allocation whether the frame will keep its frame pointer, so the allowed set leaves it out.

## What it reads

- From the convention row's `Stack.memory`: the alignment at a call, the red zone, the shadow space, where a call leaves the return address (`link`: pushed one word below the canonical frame address, in a register, or nowhere code reaches) and the frame pointer (`pointer`: its register, whether every function keeps it, and the record it heads, either linked at stated offsets from the canonical frame address or free).
- From the resolved row: the preserved registers, the link and frame pointer registers, and the registers a call clobbers, from which the prologue's and epilogues' scratch registers are those of the stack pointer's class that carry no argument, result, indirect address, count or return address, in the order the row lists its clobbers.
- From masc: the stack pointer (the register flagged `STACK` that the selection admits), each saved register's storage through the selection's view, each instruction's transfer under its row's rules, the implicit writes some operand value of its row makes (masc's `may`), and its stack effect.
- From the function: every slot with its area, size and alignment, and which slots an operand names.

## The layout

A downward stack, from the canonical frame address (the stack pointer's value at the call) down:

1. the return address, where the row says a call pushes it,
2. the saved registers: the frame record at the row's offsets when the frame keeps its pointer, then every preserved register the function writes and the link register when anything writes it,
3. the scaled area: every slot whose size is bytes per unit of a scale's multiplier, at an offset per unit, the area a multiple of the alignment per unit so every multiplier keeps it,
4. the local slots, largest alignment first,
5. the outgoing area at the stack pointer: the largest `offset + size` of the outgoing slots, and at least the shadow space when the function makes a call.

Each part is rounded so the stack pointer keeps the row's alignment at every call. A slot no operand names takes no space. Incoming slots are at the canonical frame address plus their offset.

The frame keeps its pointer when the row always keeps it, or when the function allocates dynamically, moves its stack pointer by an instruction that is not a call or return, or has a local slot aligned past the stack's alignment, which the prologue then realigns. With a frame pointer every slot but the outgoing ones is addressed from it, except the local slots of a realigned frame, which are addressed from the realigned stack pointer. A realigned frame that also allocates dynamically needs a base register no row states, and is refused.

A leaf that keeps no pointer, allocates nothing dynamically, has no scaled area and fits the red zone never moves its stack pointer, and its saves and slots are below it.

## The written function

The function is made anew through its maker. The prologue opens the entry block, and an epilogue comes before every exit, a return or a jump to a symbol. A `dynamic` pseudo becomes the size rounded up to the alignment taken off the stack pointer, with the block just above the outgoing area. An `address` pseudo becomes the slot's base plus its offset. A `spill` or `reload` becomes the target's store or load of the slot's size. The saves are the same stores and loads at slots the frame adds after the function's own.

The instructions come from the target's frame code (`Code`): `add`, `mask`, `sub`, `store` and `load`, each appending rows of masc's catalog. `mirl.target.register.riscv.isa.FRAME` is RISC-V's. Every move is made through `code.make`, which gives the code the first scratch it is offered under which every instruction of the move stands against its row's register constraints, trying each by making the move into a function of its own, and refuses with `Refusal.constrained` when none does (doc/machine/constraint.md).

The code states each width it loads and stores a class at as data (`Width`): the class by masc's handle, the bits it moves scaled as masc states widths, the load and store rows, and whether those rows take an offset beside the base register. `code.admit` binds the code to the build's selection once (`Admitted`), indexing by class the widths whose load and whose store the selection admits, each list ordered by the bits it moves through the selection, and refuses a width naming a class of no row of the file or a second width of one class and storage. A load or store of a register at a size is the width that moves exactly that many bytes, found by binary search, where the register's storage through the selection takes all of them, and is refused with `Refusal.access` when there is none, so the code never emits a row the selection lacks and never moves fewer bytes than asked. Every row the code appends goes through `code.append`, which refuses one the selection does not admit (`Refusal.unadmitted`).

- RISC-V states `lb`, `lh`, `lw` and `ld` with their stores for x, `flh`, `flw`, `fld` and `flq` with theirs for f, and `vl1re8.v` and `vs1r.v` for one v register, whose size scales with the vector length. On RV32 no `ld` or `sd` is admitted, and without Zfh no `flh`. The whole register rows take their address in a register alone, so a nonzero offset is added into the scratch first.
- A set carried later states its widths the same way: x86 `movdqu` and its VEX and EVEX forms for xmm, ymm and zmm, each admitted by the extension that has it, and AArch64 `ldr` and `str` of b, h, s, d and q registers.

## Call frame rules

`Framed.facts` lists each rule beside the instruction that makes it true, before or after it: the canonical frame address as a register plus an offset (`.cfi_def_cfa`), a register saved at an offset from it (`.cfi_offset`), a register restored (`.cfi_restore`), and the remember and restore pair around each epilogue. Registers are masc's identities, so masc numbers them from its own rows. Offsets may scale, which masc writes as an expression.

## How the other rows fit

- System V x86-64: `link` is `stack`, the red zone is 128 bytes, and the record is linked at -16 with the return address at -8, where the call pushed it.
- Windows x64: the shadow space reserves 32 bytes at every call, and the record is `free`, so the frame pointer points at the bottom of the saves. Unwind codes are written from the same rules.
- AAPCS64: `link` is x30 and the record is linked at -16 and -8, and darwin keeps the pointer always. SVE callee-saved registers and spills are slots per unit of the vector length scale, in the scaled area.
- wasm: a memory stack whose `link` is `none` and whose `pointer` is `none`, so a frame that needs a pointer is refused until its row and code state one.
- SPIR-V: `Stack.none`, so a function with a slot is refused and any other has an empty frame.

## Limits

- The RISC-V code forms no offset that scales: the vector length is read from a CSR, which the machine form names no operand for. It also refuses an out-of-reach offset where it has no scratch register, as a spill mid-function past 2 KiB from its base.
- RISC-V states no whole register load or store of a register group, since the register file names no group as one register yet.
- Slots of more than one scale in one frame are refused.
- A debug binding or an asm block cannot name a slot yet, so an unnamed slot always leaves the frame.
