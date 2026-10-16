# Machine form text

`mirl.machine.text` prints machine functions as text and reads them back, the same functions. The printer writes through the IR text form's printer and the parser reads through its lexer, so quoting, names of symbols and debug entries, and the metadata record are that form's. Registers and instructions are spelled by the rows of the target's register file and catalog.

```
mirl.machine.text.print(w, m, items)        # err[Error]
mirl.machine.text.parse_body(a, m, text)    # res[Unit, Refusal]
```

## Grammar

```
text      := target-line function*
function  := "function" SYMBOL placement? "{" NEWLINE line* "}"
placement := "placed" places
line      := virtual | slot | label | instruction
virtual   := "virtual" LOCAL ":" ("class" NAME | "memory" NAME)
slot      := "slot" "[" N "]" ":" "size" N ("per" N "scale" N)? "align" N area?
area      := ("incoming" | "outgoing") N ("per" N)?
label     := LABEL ":"
instruction := opcode operands? state? reads? writes? calls? ("label" N)? metadata ("declassifies")?
calls     := "places" places
places    := "[" (place ("," place)*)? "]"
place     := where scale fill
where     := "register" REGISTER | "stack" ("scaled" N)? N | "operand" N
scale     := "fixed" | "scaled" N
fill      := "exact" | "undefined" | "sign" N | "zero" N | "boxed"
```

A slot's `per` and `scale` state bytes per unit of a scale's multiplier. A slot whose argument area offset scales states its scale too, `per 0` when its size is fixed. An area's `per` is the scaled part of its offset.

## Placement

`placed` after a function's symbol is where its parameters arrive, and `places` after an instruction is where the pieces of the call it makes travel, the arguments' and then the results'. Both are printed from what the abi legalisation stored, the entry's places and the `call.placed` instruction's, which selection carries to the machine function and every later stage keeps. The printer classifies nothing, and nothing reads the annotation to decide anything: it is for debugging and tests. A place reads as the IR text's place does, with the register spelled by the register file's name in place of its class and number.

```
function @caller placed [register x10 fixed exact, register x11 fixed exact] {
    ...
    jalr x1, x1, 0 reads [x10] writes [x10] places [register x10 fixed exact, stack 0 fixed exact, register x10 fixed exact]
```
