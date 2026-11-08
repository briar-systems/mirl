# the example lane targets, sourced by test/example.sh and test/ct/tools.sh:
# the one list of the targets every example program is emitted, listed and
# run for, see doc/machine/emit.md. covering a target is adding its line.
#
# each line is a target as -t spells it, then its architecture, system and
# environment in mink's catalog, its baseline as masc's selection, its
# convention and its object format in mink's catalog, separated by single
# spaces
lanes='linux-riscv64 riscv64 linux gnu rv64gc lp64d elf
linux-riscv32 riscv32 linux gnu rv32gc ilp32d elf
linux-x86_64 x86_64 linux gnu cmov,cx8,x87,fxsr,mmx,osfxsr,sce,sse,sse2 sysv64 elf
linux-aarch64 aarch64 linux gnu armv8-a+fp+simd aapcs64 elf'
