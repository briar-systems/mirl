# __mirl_exit(i64): exit the process with the status in x0 through darwin's
# exit system call, never a C library. the call number is in x16 and the trap
# is svc 0x80. the symbol is spelled as the ir names it
	.globl __mirl_exit
	.section __TEXT,__text,regular,pure_instructions
	.p2align 2
__mirl_exit:
	mov x16, #1
	svc #0x80
