# Frames

`mirl.machine.frame` lays out the stack frame of an allocated register machine function, saves the callee-saved registers it writes, writes its prologue and epilogues in the shape the convention row states, and states its call frame information as mink's frame records, the rules masc's CFI calls take. It reads every frame fact from the target's convention row and from masc's rows, and names no architecture.

```
frame(a, ?allocation, Request{convention: ?resolved, at: ?locations}, ?code)   # res[Framed, Error]
lay(a, f, used, request)                                                     # res[Plan, lay.Error]
finish(a, f, ?plan, ?code)                                                   # res[Framed, finish.Error]
keeps_pointer(a, f, request)                                                 # res[bool, lay.Error]
```

`frame` is `lay` then `finish`. `keeps_pointer` answers before allocation whether the frame will keep its frame pointer, so the allowed set leaves it out.

## What it reads

- From the convention row's `Stack.memory`: the alignment at a call, the red zone, the shadow space, where a call leaves the return address (`link`: pushed one word below the canonical frame address, in a register, or nowhere code reaches), the frame pointer (`pointer`: its register, whether every function keeps it, and the record it heads, either linked at stated offsets from the canonical frame address or free), where the stack pointer lives (`pointer_home`), and the prologue's shape (`prologue`, below).
- From the resolved row: the preserved registers, each saved whole when the function writes it even where the row keeps only its low part, the link and frame pointer registers, and the registers a call clobbers, from which the prologue's and epilogues' scratch registers are those of the stack pointer's class that carry no argument, result, indirect address, count or return address, in the order the row lists its clobbers.
- From the resolved row: the stack pointer, the register its `pointer_home` names, which masc must flag `STACK`.
- From masc: each saved register's storage through the selection's view, each instruction's transfer under its row's rules, the implicit writes some operand value of its row makes (masc's `may`), and its stack effect.
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

## The prologue's shape

```
Prologue { probe: none | page{bytes, helper}, pair_saves: bool, unwind: none | dwarf | seh | compact }
```

The shape lives on the convention row beside the red zone and the shadow space, since it differs between rows of one instruction set, as Windows x64 and System V x86-64 do.

- `probe`: `none` moves the stack pointer by the whole frame at once. `page` touches each page of a frame that moves the stack pointer more than `bytes`, through `helper` (Windows' `__chkstk`) or inline where there is none (Linux's stack clash probes).
- `pair_saves`: registers are saved and restored in pairs, as AArch64's `stp` and `ldp`.
- `unwind`: the encoding the shape must suit. `dwarf` states any shape. `seh` states only saves and one stack and frame pointer move in a fixed order before the body. `compact` states a frame whose record is the first pair saved, as darwin's arm64 `stp fp, lr`. `none` is a row whose call stack no unwinder walks, as wasm's, and its frames state no call frame rule.

The frame writes `probe: none`, `pair_saves` either way, `unwind: dwarf`, `compact` and `none`. Under `pair_saves` the prologue and epilogues move two adjacent fixed saves of one size in one instruction where the frame code states a pair (`Code.pairs`), and one at a time where it states none or the pair is out of its reach (`Refusal.unpaired`), so a row asking for pairs frames on any set. Under `compact` a non-empty frame must keep its pointer with the frame pointer and the link saved first, adjacent and above every other save, the record darwin's arm64 encoding reads; the object format describes what its encoding holds compactly and the rest by call frame information. `lay` refuses a frame whose row asks for more: `probe` for a frame that moves its stack pointer past a page, by a scaled or a dynamic amount, and `unwind` for a frame that moves or saves under `seh`, or under `compact` without that record. A frame the shape asks nothing of is laid out as it would be unprobed.

## The written function

The function is made anew through its maker. The prologue opens the entry block, and an epilogue comes before every exit, a return or a jump to a symbol. A `dynamic` pseudo becomes the size rounded up to the alignment taken off the stack pointer, with the block just above the outgoing area. An `address` pseudo becomes the slot's base plus its offset. A `spill` or `reload` becomes the target's store or load of the slot's size. The saves are the same stores and loads at slots the frame adds after the function's own.

The instructions come from the target's frame code (`Code`): `add`, `mask`, `sub`, `store` and `load`, each appending rows of masc's catalog. `mirl.target.register.riscv.isa.FRAME` is RISC-V's. Every move is made through `code.make`, which gives the code the first scratch it is offered under which every instruction of the move stands against its row's register constraints, trying each by making the move into a function of its own, and refuses with `Refusal.constrained` when none does (doc/machine/constraint.md).

The code states each width it loads and stores a class at as data (`Width`): the class by masc's handle, the bits it moves scaled as masc states widths, the load and store rows, and whether those rows take an offset beside the base register. `code.admit` binds the code to the build's selection once (`Admitted`), indexing by class the widths whose load and whose store the selection admits, each list ordered by the bits it moves through the selection, and refuses a width naming a class of no row of the file or a second width of one class and storage. A load or store of a register at a size is the width that moves exactly that many bytes, found by binary search, where the register's storage through the selection takes all of them, and is refused with `Refusal.access` when there is none, so the code never emits a row the selection lacks and never moves fewer bytes than asked. Every row the code appends goes through `code.append`, which refuses one the selection does not admit (`Refusal.unadmitted`).

- RISC-V states `lb`, `lh`, `lw` and `ld` with their stores for x, `flh`, `flw`, `fld` and `flq` with theirs for f, and `vl1re8.v` and `vs1r.v` for one v register, whose size scales with the vector length. On RV32 no `ld` or `sd` is admitted, and without Zfh no `flh`. The whole register rows take their address in a register alone, so a nonzero offset is added into the scratch first.
- AArch64 states `ldrb`, `ldrh` and `ldr` of w and x with their stores for x, `ldr` and `str` of b, h, s, d and q for v, and under SVE `ldr` and `str` of a whole z or p register, whose offset counts registers of the vector length. A register is named through the view of its class the row takes. Its pairs are `stp` and `ldp` of x, d and q, and an offset of the vector length's scale is stepped by `addvl` or `addpl` (`Steps.native`).
- A set carried later states its widths the same way: x86 `movdqu` and its VEX and EVEX forms for xmm, ymm and zmm, each admitted by the extension that has it.

### Scaled steps

An offset that scales is bytes fixed plus bytes per unit of one scale's multiplier. `Code.scaled` states, for such an offset, how the code forms it (`Steps`):

- `native`: instructions that add or address a multiple of the scale's unit themselves, as SVE's `addvl`, `addpl` and `mul vl` addressing, and SME's `addsvl` under the streaming scale. The offset's scale picks between the two.
- `measured`: the register that measures the scale's quantity is read into a register, multiplied by the bytes per unit and added to the fixed part, as RVV's `vlenb`. The measuring register is masc's to name, as the scale's quantity's `register`.
- `none`: the code forms none. `make` refuses a move at such an offset with `Refusal.scaled` before the code is asked.

RISC-V states `measured` for the v registers' scale and `none` for the others, which a selection fixes.

## Call frame rules

`Framed.facts` lists each rule beside the instruction that makes it true, before or after it, as mink's frame record (`mink.model.frame.Rule`), the value masc's builder takes through `cfi`: the canonical frame address as a register plus an offset (`def_cfa`, `.cfi_def_cfa`), a register saved at an offset from it (`offset`, `.cfi_offset`), a register restored (`restore`, `.cfi_restore`), and the `remember` and `restore_state` pair around each epilogue. Each register is numbered by masc's DWARF column under the build's context, and a register the column does not number is refused (`unnumbered`). mirl spells no CFI byte: mink owns the bytes of every encoding.

## How the other rows fit

- System V x86-64: `link` is `stack`, the red zone is 128 bytes, and the record is linked at -16 with the return address at -8, where the call pushed it. Under Linux's stack clash protection the prologue probes every 4096 bytes inline, `page{4096, none}`.
- Windows x64: the shadow space reserves 32 bytes at every call, and the record is `free`, so the frame pointer points at the bottom of the saves. The prologue probes through `__chkstk`, `page{4096, "__chkstk"}`, and its shape is `seh`, whose unwind codes mink writes from the same rules.
- AAPCS64: `link` is x30 and the record is linked at -16 and -8, and darwin keeps the pointer always. Saves are paired, and darwin's shape is `compact`, its record the `stp fp, lr` saved first. SVE callee-saved registers and spills are slots per unit of the vector length scale, in the scaled area, formed `native` by `addvl` and `addpl`.
- wasm: a memory stack in linear memory, its stack pointer homed in the `__stack_pointer` global, whose `link` is `none`, whose `pointer` is `none` and whose `unwind` is `none`, so a frame that needs a pointer is refused until its row and code state one, and no frame states a call frame rule.
- SPIR-V: `Stack.none`, so a function with a slot is refused and any other has an empty frame.

## Limits

- The RISC-V code forms no offset that scales: it states `measured` through `vlenb`, but masc's `vlen` quantity names no register that measures it and the machine form names no operand for a CSR. It also refuses an out-of-reach offset where it has no scratch register, as a spill mid-function past 2 KiB from its base.
- A call frame rule at an offset that scales is refused (`finish.Error.scaled`): mink's frame records state a scaled save only as one offset times a measuring register's value, and a scaled canonical frame address only as expression bytes, which mirl does not spell.
- An offset scales by one scale, so a frame with slots of two scales, as SME's vector length and streaming vector length, is refused (`scales`).
- The frame writes no probe and no `seh` shape. `lay` refuses each where the frame would need it.
- A pair is two saves the layout already put side by side. The layout does not reorder or widen saves into pairs, so darwin's x19 to x28 and d8 to d15 are described compactly only where they land at the encoding's places, and by call frame information otherwise.
- An incoming argument slot at an offset that scales is placed at the canonical frame address plus that offset. An outgoing one, or an outgoing slot whose size scales, is refused (`argument`): the frame lays its scaled area above the fixed locals and the outgoing area, and has no scaled area below them for a call's scaled stack arguments yet.
- RISC-V states no whole register load or store of a register group, since the register file names no group as one register yet.
- A debug binding or an asm block cannot name a slot yet, so an unnamed slot always leaves the frame.
