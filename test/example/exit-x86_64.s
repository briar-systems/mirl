# __mirl_exit(i64): exit the process with the status in rdi through the
# linux exit system call, never a C library. the kernel reads the low byte
	.intel_syntax noprefix
	.globl __mirl_exit
	.type __mirl_exit, @function
	.section .text, "ax", @progbits
__mirl_exit:
	mov eax, 60
	syscall
