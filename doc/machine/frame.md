# Frames

`mirl.machine.frame` lays out the stack frame of an allocated register machine function, saves the callee-saved registers it writes, writes its prologue and epilogues in the shape the convention row states, and states its call frame information as mink's frame records, the rules masc's CFI calls take. It reads every frame fact from the target's convention row and from masc's rows, and names no architecture.

```
frame(a, ?allocation, Request{convention: ?resolved, at: ?locations}, ?code, Need{allowed, configured})   # res[Framed, Error]
lay(a, f, used, request, reserve)                                            # res[Plan, lay.Error]
needed(a, f, ?plan, ?code, request, need)                                    # res[u32, scavenge.Error]
finish(a, f, ?plan, ?code)                                                   # res[Framed, finish.Error]
keeps_pointer(a, f, request)                                                 # res[bool, lay.Error]
```

`frame` is `lay` then `finish`, laid out again with the emergency slots `scavenge.needed` counts until it holds as many as it needs (below). `keeps_pointer` answers before allocation whether the frame will keep its frame pointer, so the allowed set leaves it out.

## What it reads

- From the convention row's `Stack.memory`: the alignment at a call, the red zone, the shadow space, where a call leaves the return address (`link`: pushed one word below the canonical frame address, in a register, or nowhere code reaches), the frame pointer (`pointer`: its register, whether every function keeps it, and the record it heads, either linked at stated offsets from the canonical frame address or free), where the stack pointer lives (`pointer_home`), and the prologue's shape (`prologue`, below).
- From the resolved row: the preserved registers, each saved whole when the function writes it even where the row keeps only its low part, the link and frame pointer registers, and the registers a call clobbers, from which the prologue's and epilogues' scratch registers are those of the stack pointer's class that carry no argument, result, indirect address, count or return address, in the order the row lists its clobbers.
- From the resolved row: the stack pointer, the register its `pointer_home` names, which masc must flag `STACK`.
- From masc: each saved register's storage through the selection's view, each instruction's transfer under its row's rules, the implicit writes some operand value of its row makes (masc's `may`), and its stack effect.
- From the function: every slot with its area, size and alignment, and which slots an operand names.

## The layout

A downward stack, from the canonical frame address (the stack pointer's value at the call) down:

1. the return address, where the row says a call pushes it,
2. the saved registers: the frame record at the row's offsets when the frame keeps its pointer, then every preserved register the function writes and the link register when anything writes it, then the emergency slots of a frame that keeps its pointer,
3. the scaled area: every slot whose size is bytes per unit of a scale's multiplier, at an offset per unit, the area a multiple of the alignment per unit so every multiplier keeps it,
4. the local slots, largest alignment first, and below them the emergency slots of a frame that keeps no pointer,
5. the outgoing area at the stack pointer: the largest `offset + size` of the outgoing slots, and at least the shadow space when the function makes a call. Where a call passes a stack piece of scaled size or at an offset that scales, the area also has bytes per unit: the most any outgoing slot's offset and size per unit reach, rounded to the alignment. The stack pointer moves by that scaled part on its own, after the fixed parts in the prologue and before them in each epilogue.

A call's stack pieces are addressed from the stack pointer at the call, each at its offset's fixed bytes plus its bytes per unit, as the convention placed it. Every slot above the outgoing area sits its scaled bytes per unit further from the stack pointer, so a fixed local is at its fixed depth plus the outgoing per-unit bytes, and the scaled area and the saves are past both.

Each part is rounded so the stack pointer keeps the row's alignment at every call. A slot no operand names takes no space. Incoming slots are at the canonical frame address plus their offset.

The frame keeps its pointer when the row always keeps it, or when the function allocates dynamically, moves its stack pointer by an instruction that is not a call or return, has a local slot aligned past the stack's alignment, which the prologue then realigns, or is unwound and may have a slot that scales. With a frame pointer every slot but the outgoing ones is addressed from it, except the local slots of a realigned frame, which are addressed from the realigned stack pointer. A realigned frame that also allocates dynamically needs a base register no row states, and is refused.

A leaf that keeps no pointer, allocates nothing dynamically, has no scaled area and fits the red zone never moves its stack pointer, and its saves and slots are below it.

## Emergency slots

A move of the frame code that needs a scratch is offered the registers liveness shows free there. Where too few are free, `scavenge.make` saves the fewest allowed registers of the stack pointer's class the move names none of to the frame's emergency slots, offers them beside the free ones, and restores them after the move, as LLVM's register scavenger does. The configuration step's establishing instruction scavenges its scratch the same way (doc/machine/storage.md). Each emergency slot holds one register of the stack pointer's class at a fixed offset the frame code reaches with no scratch: below the saves off the frame pointer, or at the bottom of the locals off the stack pointer when the frame keeps no pointer, so their own saves and restores take none.

A frame reserves them only where it could need them. `scavenge.needed` takes, at each instruction, the fewest scratches the frame code takes for its slot accesses and addresses, up to `Code.most`, and for an instruction stating a configuration state the scratches its establishing instruction takes, less the allowed registers of the stack pointer's class a call clobbers or the frame saves that liveness of the allocated function shows free there, and counts the most at any. A parallel copy counts none free, since its own values may take them. A frame whose moves all stand under the registers free reserves none and pays nothing.

## The prologue's shape

```
Prologue { probe: none | page{bytes, helper}, pair_saves: bool, apart: bool, unwind: none | dwarf | seh | compact | seh_arm64 }
```

The shape lives on the convention row beside the red zone and the shadow space, since it differs between rows of one instruction set, as Windows x64 and System V x86-64 do.

- `probe`: `none` moves the stack pointer by the whole frame at once. `page` touches each page of a frame that moves the stack pointer more than `bytes`, through `helper` (Windows' `__chkstk`) or inline where there is none (Linux's stack clash probes).
- `pair_saves`: registers are saved and restored in pairs, as AArch64's `stp` and `ldp`.
- `apart`: the saves take a move of the stack pointer of their own and the locals a second after them, as Windows arm64's prologue, so the frame pointer set at the saves stays near the stack pointer and a probe routine called for the locals' move finds the link register saved. A row whose calls write a link register and whose prologue calls a probe routine must move apart, and a frame that calls the routine and did not save the link register is laid out again saving it.
- `unwind`: the encoding the shape must suit. `dwarf` states any shape. `seh` states only saves and one stack and frame pointer move in a fixed order before the body. `compact` states a frame whose record is the first pair saved, as darwin's arm64 `stp fp, lr`. `seh_arm64` states Windows' arm64 codes, one per prologue instruction, with the frame pointer set at most 2040 bytes above the stack pointer, a multiple of 8. `none` is a row whose call stack no unwinder walks, as wasm's, and its frames state no call frame rule.

The frame writes `probe: none`, `page` through a helper, `pair_saves` and `apart` either way, and every `unwind`. Under `pair_saves` the prologue and epilogues move two adjacent fixed saves of one size in one instruction where the frame code states a pair (`Code.pairs`), and one at a time where it states none or the pair is out of its reach (`Refusal.unpaired`), so a row asking for pairs frames on any set. Under `compact` a non-empty frame must keep its pointer with the frame pointer and the link saved first, adjacent and above every other save, the record darwin's arm64 encoding reads; the object format describes what its encoding holds compactly and the rest by call frame information. `lay` refuses a frame whose row asks for more: `probe` for a frame that moves its stack pointer past a page with no helper the module declares, by a scaled or a dynamic amount, or whose saves alone move past a page where it moves apart, and `unwind` for a frame `seh` or `seh_arm64` cannot state, a scaled one or one whose frame pointer is set out of the codes' reach, or under `compact` without that record. A frame the shape asks nothing of is laid out as it would be unprobed.

## The written function

The function is made anew through its maker. The prologue opens the entry block, and an epilogue comes before every exit, a return or a jump to a symbol. A `dynamic` pseudo becomes the size rounded up to the alignment taken off the stack pointer, with the block just above the outgoing area. A `spill`, `reload` or `address` pseudo is copied through, for the lowering of copies to make the target's store or load of the slot's size, or the add of the slot's offset to its base, under a scratch that liveness shows free there (doc/machine/copy.md). The saves are the same stores and loads at slots the frame adds after the function's own.

The instructions come from the target's frame code (`Code`): `add`, `mask`, `sub`, `store` and `load`, each appending rows of masc's catalog. `mirl.target.register.riscv.isa.FRAME` is RISC-V's. Every move is made through `code.make`, which gives the code the first scratch it is offered under which every instruction of the move stands against its row's register constraints, trying each by making the move into a function of its own, and refuses with `Refusal.constrained` when none does (doc/machine/constraint.md).

The code states each width it loads and stores a class at as data (`Width`): the class by masc's handle, the bits it moves scaled as masc states widths, the load and store rows, and whether those rows take an offset beside the base register. `code.admit` binds the code to the build's selection once (`Admitted`), indexing by class the widths whose load and whose store the selection admits, each list ordered by the bits it moves through the selection, and refuses a width naming a class of no row of the file or a second width of one class and storage. A load or store of a register at a size is the width that moves exactly that many bytes, found by binary search, where the register's storage through the selection takes all of them, and is refused with `Refusal.access` when there is none, so the code never emits a row the selection lacks and never moves fewer bytes than asked. Every row the code appends goes through `code.append`, which refuses one the selection does not admit (`Refusal.unadmitted`).

- RISC-V states `lb`, `lh`, `lw` and `ld` with their stores for x, `flh`, `flw`, `fld` and `flq` with theirs for f, and `vl1re8.v` and `vs1r.v` for one v register, whose size scales with the vector length, with `vl2re8.v` and `vs2r.v`, `vl4re8.v` and `vs4r.v`, and `vl8re8.v` and `vs8r.v` for a group of `vg2`, `vg4` and `vg8`, whose slot is the group's registers together. On RV32 no `ld` or `sd` is admitted, and without Zfh no `flh`. The whole register rows take their address in a register alone, so a nonzero offset is added into the scratch first.
- AArch64 states `ldrb`, `ldrh` and `ldr` of w and x with their stores for x, `ldr` and `str` of b, h, s, d and q for v, and under SVE `ldr` and `str` of a whole z or p register, whose offset counts registers of the vector length. A register is named through the view of its class the row takes. Its pairs are `stp` and `ldp` of x, d and q, and an offset of the vector length's scale is stepped by `addvl` or `addpl` (`Steps.native`).
- A set carried later states its widths the same way: x86 `movdqu` and its VEX and EVEX forms for xmm, ymm and zmm, each admitted by the extension that has it.

### Scaled steps

An offset that scales is bytes fixed plus bytes per unit of one scale's multiplier. `Code.scaled` states, for such an offset, how the code forms it (`Steps`):

- `native`: instructions that add or address a multiple of the scale's unit themselves, as SVE's `addvl`, `addpl` and `mul vl` addressing, and SME's `addsvl` under the streaming scale. The offset's scale picks between the two.
- `measured`: the register that measures the scale's quantity is read into a register, multiplied by the bytes per unit and added to the fixed part, as RVV's `vlenb`. The measuring register is masc's to name, as the scale's quantity's `register`.
- `none`: the code forms none. `make` refuses a move at such an offset with `Refusal.scaled` before the code is asked.

RISC-V states `measured` for the v registers' scale and `none` for the others, which a selection fixes. It forms such an offset in a temporary: `csrrs` reads `vlenb`, the register masc's `vlen` quantity names as measuring it, its CSR at the row's id position (a system register at a masc `id` operand stands as its number in its class), it is scaled by the offset's share of each byte read, negated below the base, and the fixed part is added after. A share that is a power of two is one `slli` of the temporary. Any other is a sum of powers of two: a second register of the scratches reads `vlenb` and is shifted up to each set bit in turn by `slli`, each added into the temporary, so no multiply is needed. A fixed part past 12 bits is built in that second register and added. An offset that needs the second register where the scratches hold none is refused `reach`.

A frame whose call stack is unwound and that may have a slot that scales (one of its own, or a virtual register of a class whose spill slot scales) keeps its frame pointer, so its canonical frame address is the frame pointer plus fixed bytes and no rule states a scaled offset. `keeps_pointer` answers the same before allocation, so the allocator leaves the pointer out.

## Call frame rules

`Framed.facts` lists each rule beside the instruction that makes it true, before or after it, as mink's frame record (`mink.model.frame.Rule`), the value masc's builder takes through `cfi`: the canonical frame address as a register plus an offset (`def_cfa`, `.cfi_def_cfa`), a register saved at an offset from it (`offset`, `.cfi_offset`), a register restored (`restore`, `.cfi_restore`), and the `remember` and `restore_state` pair around each epilogue. Each register is numbered by masc's DWARF column under the build's context, and a register the column does not number is refused (`unnumbered`). mirl spells no CFI byte: mink owns the bytes of every encoding.

## How the other rows fit

- System V x86-64: `link` is `stack`, the red zone is 128 bytes, and the record is linked at -16 with the return address at -8, where the call pushed it. Under Linux's stack clash protection the prologue probes every 4096 bytes inline, `page{4096, none}`.
- Windows x64: the shadow space reserves 32 bytes at every call, and the record is `free`, so the frame pointer points at the bottom of the saves. The prologue probes through `__chkstk`, `page{4096, "__chkstk"}`, and its shape is `seh`, whose unwind codes mink writes from the same rules.
- AAPCS64: `link` is x30 and the record is linked at -16 and -8, and darwin keeps the pointer always. Saves are paired, and darwin's shape is `compact`, its record the `stp fp, lr` saved first. aapcs64win keeps the pointer always, moves `apart` and probes the locals' move through `__chkstk`, `page{4096, "__chkstk"}`, as `mov x15, #n/16; bl __chkstk; sub sp, sp, x15, uxtx #4`, and its shape is `seh_arm64`, whose unwind codes mink writes from the same rules. SVE callee-saved registers and spills are slots per unit of the vector length scale, in the scaled area, formed `native` by `addvl` and `addpl`.
- wasm: a memory stack in linear memory, its stack pointer homed in the `__stack_pointer` global, whose `link` is `none`, whose `pointer` is `none` and whose `unwind` is `none`, so a frame that needs a pointer is refused until its row and code state one, and no frame states a call frame rule.
- SPIR-V: `Stack.none`, so a function with a slot is refused and any other has an empty frame.

## Limits

- The RISC-V code refuses an out-of-reach offset where it has no scratch register and none can be scavenged, as when the emergency slot itself lies past 2 KiB from its base, or above a scaled outgoing area in a frame that keeps no pointer.
- A copy between two slots goes through a free location (doc/machine/copy.md) and never scavenges one, so where none is free it is refused `Reason.scratch`.
- A call frame rule at an offset that scales is refused (`finish.Error.scaled`): mink's frame records state a scaled save only as one offset times a measuring register's value, and a scaled canonical frame address only as expression bytes, which mirl does not spell.
- An offset scales by one scale, so a frame with slots of two scales, as SME's vector length and streaming vector length, is refused (`scales`).
- A probe of a dynamic allocation is not written, so `lay` refuses a dynamic allocation under a row that probes.
- A pair is two saves the layout already put side by side. The layout does not reorder or widen saves into pairs, so darwin's x19 to x28 and d8 to d15 are described compactly only where they land at the encoding's places, and by call frame information otherwise.
- A debug binding or an asm block cannot name a slot yet, so an unnamed slot always leaves the frame.
