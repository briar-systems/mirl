# Opcode reference

This file is generated from the rows of the opcode table and is not edited by hand. Each opcode's semantics are stated in [the specification](../ir.md).

Operand names are the names the text form gives them. A subject such as `lhs` is the type of that operand, and a subject written as the type in an immediate is the type that immediate holds. In a lanewise opcode a class applies to the lanes of a vector operand. In an across opcode the operand must be a vector and a class applies to its lanes.

| opcode | operands | immediates | vector | secrecy |
|---|---|---|---|---|
| `add` | `lhs`, `rhs` | none | lanewise | propagates |
| `sub` | `lhs`, `rhs` | none | lanewise | propagates |
| `mul` | `lhs`, `rhs` | none | lanewise | propagates |
| `div.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `div.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `rem.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `rem.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `and` | `lhs`, `rhs` | none | lanewise | propagates |
| `or` | `lhs`, `rhs` | none | lanewise | propagates |
| `xor` | `lhs`, `rhs` | none | lanewise | propagates |
| `shl` | `lhs`, `rhs` | none | lanewise | propagates |
| `shr.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `shr.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `neg` | `operand` | none | lanewise | propagates |
| `not` | `operand` | none | lanewise | propagates |
| `eq` | `lhs`, `rhs` | none | lanewise | propagates |
| `ne` | `lhs`, `rhs` | none | lanewise | propagates |
| `lt.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `le.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `gt.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `ge.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `lt.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `le.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `gt.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `ge.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `load` | `address` | `type` a type, `align` an alignment | none | declared |
| `store` | `address`, `value` | `align` an alignment | none | no results |
| `alloca` | none | `type` a type, `pointer` a type, `align` an alignment | none | propagates |
| `ptr.add` | `address`, `offset` | none | none | propagates |
| `br` | none | none | none | no results |
| `cbr` | `condition` | none | none | no results |
| `call` | `callee`, then any number of argument operands | `signature` a type, `named` a named argument count | none | declared |
| `ret` | any number of returned value operands | none | none | no results |
| `fadd` | `lhs`, `rhs` | none | lanewise | propagates |
| `flt.o` | `lhs`, `rhs` | none | lanewise | propagates |
| `ext.u` | `operand` | `to` a type | lanewise | propagates |
| `trunc` | `operand` | `to` a type | lanewise | propagates |
| `itof.s` | `operand` | `to` a type | lanewise | propagates |
| `ftoi.s` | `operand` | `to` a type | lanewise | propagates |
| `fpromote` | `operand` | `to` a type | lanewise | propagates |
| `bitcast` | `operand` | `to` a type | none | propagates |
| `ptrtoint` | `operand` | `to` a type | none | propagates |
| `vsplat` | `scalar` | `vector` a type | none | propagates |
| `vbuild` | any number of value operands | `vector` a type | none | propagates |
| `vshuffle` | `lhs`, `rhs` | `vector` a type, `lanes` a lane list | none | propagates |
| `vextract` | `vector` | `lane` a lane index | none | propagates |
| `vinsert` | `vector`, `scalar` | `lane` a lane index | none | propagates |
| `reduce.add` | `operand` | none | across | propagates |
| `reduce.fadd.seq` | `operand` | none | across | propagates |
| `atomic.load` | `address` | `type` a type, `order` a memory ordering | none | declared |
| `atomic.store` | `address`, `value` | `order` a memory ordering | none | no results |
| `atomic.add` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.cmpxchg` | `address`, `expected`, `desired` | `success` a memory ordering, `failure` a memory ordering | none | declared |
| `fence` | none | `order` a memory ordering | none | no results |
| `mem.copy` | `destination`, `source`, `length` | `align` an alignment | none | no results |
| `mem.fill` | `destination`, `byte`, `length` | `align` an alignment | none | no results |
| `select` | `condition`, `then`, `else` | none | lanewise | propagates |
| `declassify` | `operand` | none | none | declassifies |
| `add.ov.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `popcnt` | `operand` | none | lanewise | propagates |
| `bswap` | `operand` | none | lanewise | propagates |
| `unreachable` | none | none | none | no results |
| `fsub` | `lhs`, `rhs` | none | lanewise | propagates |
| `fmul` | `lhs`, `rhs` | none | lanewise | propagates |
| `fdiv` | `lhs`, `rhs` | none | lanewise | propagates |
| `frem` | `lhs`, `rhs` | none | lanewise | propagates |
| `fmin` | `lhs`, `rhs` | none | lanewise | propagates |
| `fmax` | `lhs`, `rhs` | none | lanewise | propagates |
| `fminnum` | `lhs`, `rhs` | none | lanewise | propagates |
| `fmaxnum` | `lhs`, `rhs` | none | lanewise | propagates |
| `fcopysign` | `lhs`, `rhs` | none | lanewise | propagates |
| `fneg` | `operand` | none | lanewise | propagates |
| `fabs` | `operand` | none | lanewise | propagates |
| `fsqrt` | `operand` | none | lanewise | propagates |
| `ffloor` | `operand` | none | lanewise | propagates |
| `fceil` | `operand` | none | lanewise | propagates |
| `fint` | `operand` | none | lanewise | propagates |
| `fnearest` | `operand` | none | lanewise | propagates |
| `fma` | `first`, `second`, `third` | none | lanewise | propagates |
| `feq.o` | `lhs`, `rhs` | none | lanewise | propagates |
| `fne.o` | `lhs`, `rhs` | none | lanewise | propagates |
| `fle.o` | `lhs`, `rhs` | none | lanewise | propagates |
| `fgt.o` | `lhs`, `rhs` | none | lanewise | propagates |
| `fge.o` | `lhs`, `rhs` | none | lanewise | propagates |
| `ford` | `lhs`, `rhs` | none | lanewise | propagates |
| `feq.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `fne.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `flt.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `fle.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `fgt.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `fge.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `funo` | `lhs`, `rhs` | none | lanewise | propagates |
| `ext.s` | `operand` | `to` a type | lanewise | propagates |
| `itof.u` | `operand` | `to` a type | lanewise | propagates |
| `ftoi.u` | `operand` | `to` a type | lanewise | propagates |
| `fdemote` | `operand` | `to` a type | lanewise | propagates |
| `inttoptr` | `operand` | `to` a type | none | propagates |
| `reduce.mul` | `operand` | none | across | propagates |
| `reduce.and` | `operand` | none | across | propagates |
| `reduce.or` | `operand` | none | across | propagates |
| `reduce.xor` | `operand` | none | across | propagates |
| `reduce.smin` | `operand` | none | across | propagates |
| `reduce.smax` | `operand` | none | across | propagates |
| `reduce.umin` | `operand` | none | across | propagates |
| `reduce.umax` | `operand` | none | across | propagates |
| `reduce.fadd.any` | `operand` | none | across | propagates |
| `reduce.fmul.any` | `operand` | none | across | propagates |
| `reduce.fmin` | `operand` | none | across | propagates |
| `reduce.fmax` | `operand` | none | across | propagates |
| `reduce.fminnum` | `operand` | none | across | propagates |
| `reduce.fmaxnum` | `operand` | none | across | propagates |
| `reduce.fmul.seq` | `operand` | none | across | propagates |
| `atomic.sub` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.and` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.or` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.xor` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.nand` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.xchg` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.smax` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.smin` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.umax` | `address`, `value` | `order` a memory ordering | none | declared |
| `atomic.umin` | `address`, `value` | `order` a memory ordering | none | declared |
| `add.ov.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `sub.ov.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `sub.ov.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `mul.ov.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `mul.ov.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `clz` | `operand` | none | lanewise | propagates |
| `ctz` | `operand` | none | lanewise | propagates |
| `call.placed` | `callee`, then any number of argument operands | `signature` a type, `places` a place list | none | declared |
| `ret.placed` | any number of returned value operands | `places` a place list | none | no results |
| `div.wide.u` | `high`, `low`, `divisor` | none | lanewise | propagates |
| `mul.high.u` | `lhs`, `rhs` | none | lanewise | propagates |
| `mul.high.s` | `lhs`, `rhs` | none | lanewise | propagates |
| `mul.high.su` | `lhs`, `rhs` | none | lanewise | propagates |

### `add`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `sub`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `mul`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `div.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: mergeable
  - traps when `rhs` is zero in any lane
  - traps when `lhs` is the least signed value and `rhs` is all ones in any lane
- secrecy: propagates
- vector: lanewise

### `div.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: mergeable
  - traps when `rhs` is zero in any lane
- secrecy: propagates
- vector: lanewise

### `rem.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: mergeable
  - traps when `rhs` is zero in any lane
  - traps when `lhs` is the least signed value and `rhs` is all ones in any lane
- secrecy: propagates
- vector: lanewise

### `rem.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: mergeable
  - traps when `rhs` is zero in any lane
- secrecy: propagates
- vector: lanewise

### `and`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `or`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `xor`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `shl`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- shift by the width or more: zero

### `shr.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- shift by the width or more: zero

### `shr.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- shift by the width or more: every bit is the sign bit of the shifted operand

### `neg`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `not`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `eq`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `ne`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `lt.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `le.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `gt.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `ge.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `lt.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `le.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `gt.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `ge.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `load`

- operands: `address`
- immediates: `type` a type, `align` an alignment
- targets: 0
- typing:
  - `address` is a pointer
- results:
  - one result of the type in `type`
- effects: reads memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `store`

- operands: `address`, `value`
- immediates: `align` an alignment
- targets: 0
- typing:
  - `address` is a pointer
- results: none
- effects: writes memory, may be kept
  - traps when the address in `address` cannot be accessed
- secrecy: no results
- vector: none

### `alloca`

- operands: none
- immediates: `type` a type, `pointer` a type, `align` an alignment
- targets: 0
- typing:
  - the type in `pointer` is a pointer
- results:
  - one result of the type in `pointer`
- effects: none
- secrecy: propagates
- vector: none

### `ptr.add`

- operands: `address`, `offset`
- immediates: none
- targets: 0
- typing:
  - `address` is a pointer
  - `offset` is an integer
- results:
  - one result of the type of `address`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `br`

- operands: none
- immediates: none
- targets: 1, ends its block
- typing: none
- results: none
- effects: none
- secrecy: no results
- vector: none

### `cbr`

- operands: `condition`
- immediates: none
- targets: 2, ends its block
- typing:
  - `condition` is an integer of width 1
- results: none
- effects: none
- secrecy: no results
- vector: none

### `call`

- operands: `callee`, then any number of argument operands
- immediates: `signature` a type, `named` a named argument count
- targets: 0
- typing:
  - `callee` is a pointer
  - the type in `signature` is a function type
  - the tail operands are the parameters of the type in `signature`
  - `named` is stated, naming no more arguments than the parameters of the type in `signature`
- results:
  - the results of the type in `signature`
- effects: reads memory, writes memory
  - traps when the function called traps
- secrecy: declared
- vector: none

### `ret`

- operands: any number of returned value operands
- immediates: none
- targets: 0, ends its block
- typing:
  - the tail operands are the results of the function the instruction is in
- results: none
- effects: none
- secrecy: no results
- vector: none

### `fadd`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `flt.o`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: ordered

### `ext.u`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is an integer
  - the type in `to` is an integer
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
  - the type in `to` has more bits than `operand`
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `trunc`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is an integer
  - the type in `to` is an integer
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
  - `operand` has more bits than the type in `to`
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `itof.s`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is an integer
  - the type in `to` is a float
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `ftoi.s`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is a float
  - the type in `to` is an integer
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fpromote`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is a float
  - the type in `to` is a float
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
  - the type in `to` has more bits than `operand`
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `bitcast`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` and the type in `to` have the same number of bits
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `ptrtoint`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is a pointer
  - the type in `to` is an integer
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `vsplat`

- operands: `scalar`
- immediates: `vector` a type
- targets: 0
- typing:
  - `scalar` is an integer, a float or a pointer
  - the type in `vector` is a vector
  - `scalar` and the type in `vector` have the same lane type, a scalar being its own lane
- results:
  - one result of the type in `vector`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `vbuild`

- operands: any number of value operands
- immediates: `vector` a type
- targets: 0
- typing:
  - the type in `vector` is a vector
  - the tail operands are the lanes of the type in `vector`, one per lane and of its lane type
- results:
  - one result of the type in `vector`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `vshuffle`

- operands: `lhs`, `rhs`
- immediates: `vector` a type, `lanes` a lane list
- targets: 0
- typing:
  - `lhs` is a vector
  - `lhs` and `rhs` are the same type
  - the type in `vector` is a vector
  - `lhs` and the type in `vector` have the same lane type, a scalar being its own lane
  - each lane index in `lanes` is below the lane count of `lhs` plus that of `rhs`
  - `lanes` holds one index per lane of the type in `vector`
- results:
  - one result of the type in `vector`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `vextract`

- operands: `vector`
- immediates: `lane` a lane index
- targets: 0
- typing:
  - `vector` is a vector
  - each lane index in `lane` is below the lane count of `vector`
- results:
  - one result of the lane type of `vector`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `vinsert`

- operands: `vector`, `scalar`
- immediates: `lane` a lane index
- targets: 0
- typing:
  - `vector` is a vector
  - `scalar` is an integer, a float or a pointer
  - `vector` and `scalar` have the same lane type, a scalar being its own lane
  - each lane index in `lane` is below the lane count of `vector`
- results:
  - one result of the type of `vector`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `reduce.add`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.fadd.seq`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across
- order: sequential

### `atomic.load`

- operands: `address`
- immediates: `type` a type, `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - the type in `type` is an integer
  - `order` is one of relaxed, acquire, seq_cst
- results:
  - one result of the type in `type`
- effects: reads memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.store`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, release, seq_cst
- results: none
- effects: writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: no results
- vector: none

### `atomic.add`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.cmpxchg`

- operands: `address`, `expected`, `desired`
- immediates: `success` a memory ordering, `failure` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `expected` is an integer
  - `expected` and `desired` are the same type
  - `success` is one of relaxed, acquire, release, acq_rel, seq_cst
  - `failure` is one of relaxed, acquire, seq_cst
- results:
  - one result of the type of `expected`
  - one result of i1, or of a vector of i1 with the lanes of `expected` when it is a vector
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `fence`

- operands: none
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `order` is one of acquire, release, acq_rel, seq_cst
- results: none
- effects: reads memory, writes memory
- secrecy: no results
- vector: none

### `mem.copy`

- operands: `destination`, `source`, `length`
- immediates: `align` an alignment
- targets: 0
- typing:
  - `destination` is a pointer
  - `source` is a pointer
  - `length` is an integer
- results: none
- effects: reads memory, writes memory
  - traps when the address in `destination` cannot be accessed
  - traps when the address in `source` cannot be accessed
- secrecy: no results
- vector: none

### `mem.fill`

- operands: `destination`, `byte`, `length`
- immediates: `align` an alignment
- targets: 0
- typing:
  - `destination` is a pointer
  - `byte` is an integer of width 8
  - `length` is an integer
- results: none
- effects: writes memory, may be kept
  - traps when the address in `destination` cannot be accessed
- secrecy: no results
- vector: none

### `select`

- operands: `condition`, `then`, `else`
- immediates: none
- targets: 0
- typing:
  - `condition` is an integer of width 1
  - `then` and `else` are the same type
  - `condition` and `then` are both scalars, or both vectors of the same lane count
- results:
  - one result of the type of `then`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `declassify`

- operands: `operand`
- immediates: none
- targets: 0
- typing: none
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: declassifies
- vector: none

### `add.ov.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `popcnt`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `bswap`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer of a whole number of bytes
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `unreachable`

- operands: none
- immediates: none
- targets: 0, ends its block
- typing: none
- results: none
- effects: none
  - traps on every execution
- secrecy: no results
- vector: none

### `fsub`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fmul`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fdiv`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `frem`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fmin`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fmax`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fminnum`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fmaxnum`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fcopysign`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fneg`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fabs`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fsqrt`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `ffloor`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fceil`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fint`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fnearest`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fma`

- operands: `first`, `second`, `third`
- immediates: none
- targets: 0
- typing:
  - `first` is a float
  - `first` and `second` are the same type
  - `first` and `third` are the same type
- results:
  - one result of the type of `first`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `feq.o`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: ordered

### `fne.o`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: ordered

### `fle.o`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: ordered

### `fgt.o`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: ordered

### `fge.o`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: ordered

### `ford`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: ordered

### `feq.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: unordered

### `fne.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: unordered

### `flt.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: unordered

### `fle.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: unordered

### `fgt.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: unordered

### `fge.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: unordered

### `funo`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is a float
  - `lhs` and `rhs` are the same type
- results:
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise
- order: unordered

### `ext.s`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is an integer
  - the type in `to` is an integer
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
  - the type in `to` has more bits than `operand`
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `itof.u`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is an integer
  - the type in `to` is a float
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `ftoi.u`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is a float
  - the type in `to` is an integer
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `fdemote`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is a float
  - the type in `to` is a float
  - `operand` and the type in `to` are both scalars, or both vectors of the same lane count
  - `operand` has more bits than the type in `to`
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `inttoptr`

- operands: `operand`
- immediates: `to` a type
- targets: 0
- typing:
  - `operand` is an integer
  - the type in `to` is a pointer
- results:
  - one result of the type in `to`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: none

### `reduce.mul`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.and`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.or`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.xor`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.smin`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.smax`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.umin`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.umax`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across

### `reduce.fadd.any`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across
- order: reassociable

### `reduce.fmul.any`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across
- order: reassociable

### `reduce.fmin`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across
- order: reassociable

### `reduce.fmax`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across
- order: reassociable

### `reduce.fminnum`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across
- order: reassociable

### `reduce.fmaxnum`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across
- order: reassociable

### `reduce.fmul.seq`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is a float
- results:
  - one result of the lane type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: across
- order: sequential

### `atomic.sub`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.and`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.or`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.xor`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.nand`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.xchg`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.smax`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.smin`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.umax`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `atomic.umin`

- operands: `address`, `value`
- immediates: `order` a memory ordering
- targets: 0
- typing:
  - `address` is a pointer
  - `value` is an integer
  - `order` is one of relaxed, acquire, release, acq_rel, seq_cst
- results:
  - one result of the type of `value`
- effects: reads memory, writes memory
  - traps when the address in `address` cannot be accessed
- secrecy: declared
- vector: none

### `add.ov.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `sub.ov.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `sub.ov.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `mul.ov.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `mul.ov.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
  - one result of i1, or of a vector of i1 with the lanes of `lhs` when it is a vector
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `clz`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `ctz`

- operands: `operand`
- immediates: none
- targets: 0
- typing:
  - `operand` is an integer
- results:
  - one result of the type of `operand`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `call.placed`

- operands: `callee`, then any number of argument operands
- immediates: `signature` a type, `places` a place list
- targets: 0
- typing:
  - `callee` is a pointer
  - the type in `signature` is a function type
  - the tail operands are the parameters of the type in `signature`
  - `places` holds one place per parameter and result of the type in `signature`
- results:
  - the results of the type in `signature`
- effects: reads memory, writes memory
  - traps when the function called traps
- secrecy: declared
- vector: none

### `ret.placed`

- operands: any number of returned value operands
- immediates: `places` a place list
- targets: 0, ends its block
- typing:
  - `places` holds one place per tail operand
- results: none
- effects: none
- secrecy: no results
- vector: none

### `div.wide.u`

- operands: `high`, `low`, `divisor`
- immediates: none
- targets: 0
- typing:
  - `high` is an integer
  - `high` and `low` are the same type
  - `high` and `divisor` are the same type
- results:
  - one result of the type of `divisor`
  - one result of the type of `divisor`
- effects: mergeable
  - traps when `divisor` is zero in any lane
  - traps when `high` is no less than `divisor` read as unsigned, so the quotient does not fit, in any lane
- secrecy: propagates
- vector: lanewise

### `mul.high.u`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `mul.high.s`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

### `mul.high.su`

- operands: `lhs`, `rhs`
- immediates: none
- targets: 0
- typing:
  - `lhs` is an integer
  - `lhs` and `rhs` are the same type
- results:
  - one result of the type of `lhs`
- effects: speculatable, mergeable
- secrecy: propagates
- vector: lanewise

