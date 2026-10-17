# __mirl_exit(i64): exit the process with the status in x0 through the linux
# exit system call, never a C library
	.globl __mirl_exit
	.type __mirl_exit, @function
	.section .text, "ax", @progbits
	.p2align 2
__mirl_exit:
	mov x8, #93
	svc #0
