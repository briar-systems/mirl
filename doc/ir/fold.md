# The constant folder

`mirl.fold` is the one place an operation of the opcode table is evaluated on constants. There is exactly one definition of each operation, and it is here. A front end that needs the value of an operation at compile time, such as a constant expression or a `comptime` block, calls the folder. It never evaluates the operation itself, so the compile-time value and the run-time value cannot differ. There is no IR interpreter.

## The operation

```
fold(a: *Allocator, t: *types.Table, req: Request) Outcome
```

`fold` evaluates one operation and gives a result or a refusal.

- `a` is the allocator the results are taken from.
- `t` is the type table the request's types are in. The folder may intern a mask type in it.
- `req` is the operation, a `Request`.

A **request** holds the opcode, its operands in order (the fixed ones and then the tail) and one immediate per slot of the row. Lists are borrowed for the call. An **operand** is a constant `Value` and a flag saying whether it is secret. A **value** is a type, which is an integer, a float or a vector of either, and one `Bits` per lane of the lane type, a scalar being one lane. Each `Bits` holds the type and the bits in 64-bit words, low word first.

The **outcome** is one of two cases.

- `folded` holds the results, one value per result of the row in order, and a flag saying whether they are secret by the row's secrecy rule. The caller owns them until `release(a, folded)`.
- `refused` holds why there is no constant.

## Refusals

| refusal | meaning |
|---|---|
| `unfoldable` | the row is not evaluated on constants |
| `trap` | the operation would trap, by this trap of its row |
| `check` | the request breaks a typing rule of its row, with the checker's error |
| `operand` | the operand at this position does not hold one lane of bits per lane of its type |
| `types` | the type table refused a read |
| `alloc` | the allocator refused storage for a result |

An operation that would trap is refused by the trap and never answered. A fold gives exactly what the operation gives when it runs, or it refuses.

The folder decides nothing by opcode name. The row decides everything but the arithmetic. Its rules type the request through the one checker, its traps refuse what would trap, its overshift rule settles shifts past the width, its order settles comparisons of a not-a-number, and its secrecy rule marks the results. The arithmetic itself is the row's entry in the evaluation table, one entry for each row of the opcode table. A row added to the opcode table without an entry fails a test.

## What folds

Every row that reads or writes memory, transfers control, computes an address from a pointer or has declared secrecy is unfoldable. These are `load`, `store`, `alloca`, `ptr.add`, `br`, `cbr`, `call`, `ret`, `ptrtoint`, `inttoptr`, `unreachable`, `fence`, `mem.copy`, `mem.fill` and every atomic opcode. Every other row folds, including the vector opcodes, the reductions and `declassify`.

## Secrecy

An operand carries a flag saying whether it is secret, and `folded` says whether the results are secret by the row's secrecy rule. A caller that places the results as constants never places a public constant over a secret result: folding never produces a public value from a secret computation, so the constant folding pass leaves such an instruction in place.

## Not-a-number results

A float operation that gives a not-a-number gives one with a sign and payload that the IR leaves unspecified. The folder gives one valid choice. A not-a-number operand gives itself quieted, the first such operand when there are several, and an invalid operation gives the format's canonical quiet not-a-number. A caller compares the folder's result as a not-a-number and never by its bits.

## Floats

The folder computes every float format from its row of the number format table with exact multiword arithmetic and one rounding. It names no format, so a new row of the table folds as it stands.
