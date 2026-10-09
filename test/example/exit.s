# __mirl_exit(i64): exit the process with the status in a0 through the linux
# exit system call, never a C library
	.globl __mirl_exit
	.type __mirl_exit, @function
	.section .text, "ax", @progbits
__mirl_exit:
	li a7, 93
	ecall
