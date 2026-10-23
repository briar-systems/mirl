# the host's side of the dudect driver on aarch64 linux, never a C library:
# __ct_ticks() reads the virtual counter behind a barrier, so no earlier
# instruction is still running, __ct_write(ptr, i64) writes the bytes to
# standard output and __mirl_exit(i64) exits with the status
	.section .text, "ax", @progbits
	.p2align 2
	.globl __ct_ticks
	.type __ct_ticks, @function
__ct_ticks:
	isb
	mrs x0, cntvct_el0
	isb
	ret
	.globl __ct_write
	.type __ct_write, @function
__ct_write:
	mov x2, x1
	mov x1, x0
.Lmore:
	cbz x2, .Lwritten
	mov x0, #1
	mov x8, #64
	svc #0
	cmp x0, #0
	b.le .Lwritten
	add x1, x1, x0
	sub x2, x2, x0
	b .Lmore
.Lwritten:
	ret
	.globl __mirl_exit
	.type __mirl_exit, @function
__mirl_exit:
	mov x8, #93
	svc #0
