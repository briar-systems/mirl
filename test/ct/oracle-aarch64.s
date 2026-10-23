# the start of an oracle program on aarch64 linux, never a C library. the
# secret is the eight bytes at `secret`. under valgrind the client request
# VALGRIND_MAKE_MEM_UNDEFINED marks them undefined, so memcheck reports any
# branch or address they decide (ctgrind), and natively the request is a
# sequence of rotates that leaves every register as it was. BINSEC's checkct
# reads `secret` as the secret global. @probe is called once with the secret
# and its result is dropped, so the exit status depends on nothing secret
	.section .data, "aw", @progbits
	.p2align 3
	.globl secret
	.type secret, @object
	.size secret, 8
secret:
	.quad 0x5a5a5a5a5a5a5a5a
request:
	.quad 0x4d430001
	.quad secret
	.quad 8
	.quad 0
	.quad 0
	.quad 0
	.section .text, "ax", @progbits
	.p2align 2
	.globl _start
	.type _start, @function
_start:
	adrp x4, request
	add x4, x4, :lo12:request
	mov x3, #0
	ror x12, x12, #3
	ror x12, x12, #13
	ror x12, x12, #51
	ror x12, x12, #61
	orr x10, x10, x10
	adrp x0, secret
	ldr x0, [x0, :lo12:secret]
	bl probe
	mov x0, #0
	bl __mirl_exit
	.globl __mirl_exit
	.type __mirl_exit, @function
__mirl_exit:
	mov x8, #93
	svc #0
