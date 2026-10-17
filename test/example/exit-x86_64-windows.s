# __mirl_exit(i64): exit the process with the status in rcx through
# kernel32's ExitProcess, which takes the low word. the call keeps the stack
# aligned and its 32 bytes of shadow space, and never returns
	.intel_syntax noprefix
	.globl __mirl_exit
	.section .text, "xr"
__mirl_exit:
	sub rsp, 40
	call ExitProcess
