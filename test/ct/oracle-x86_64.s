# the start of an oracle program on x86-64 linux, never a C library. the
# secret is the eight bytes at `secret`. under valgrind the client request
# VALGRIND_MAKE_MEM_UNDEFINED marks them undefined, so memcheck reports any
# branch or address they decide (ctgrind), and natively the request is a
# sequence of rotates that leaves every register as it was. BINSEC's checkct
# reads `secret` as the secret global. @probe is called once with the secret
# and its result is dropped, so the exit status depends on nothing secret
	.intel_syntax noprefix
	.section .data, "aw", @progbits
	.p2align 3
	.globl secret
	.type secret, @object
	.size secret, 8
secret:
	.quad 0x5a5a5a5a5a5a5a5a
	.p2align 3
request:
	.quad 0x4d430001
	.quad secret
	.quad 8
	.quad 0
	.quad 0
	.quad 0
	.section .text, "ax", @progbits
	.globl _start
	.type _start, @function
_start:
	lea rax, [rip + request]
	xor edx, edx
	rol rdi, 3
	rol rdi, 13
	rol rdi, 61
	rol rdi, 51
	xchg rbx, rbx
	mov rdi, qword ptr [rip + secret]
	call probe
	xor edi, edi
	call __mirl_exit
	.globl __mirl_exit
	.type __mirl_exit, @function
__mirl_exit:
	mov eax, 60
	syscall
