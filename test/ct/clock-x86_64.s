# the host's side of the dudect driver on x86-64 linux, never a C library:
# __ct_ticks() reads the time stamp counter behind a fence, so no earlier
# instruction is still running, __ct_write(ptr, i64) writes the bytes to
# standard output and __mirl_exit(i64) exits with the status
	.intel_syntax noprefix
	.section .text, "ax", @progbits
	.globl __ct_ticks
	.type __ct_ticks, @function
__ct_ticks:
	lfence
	rdtsc
	lfence
	shl rdx, 32
	or rax, rdx
	ret
	.globl __ct_write
	.type __ct_write, @function
__ct_write:
	mov rdx, rsi
	mov rsi, rdi
	mov edi, 1
.Lmore:
	test rdx, rdx
	jz .Lwritten
	mov eax, 1
	syscall
	test rax, rax
	jle .Lwritten
	add rsi, rax
	sub rdx, rax
	jmp .Lmore
.Lwritten:
	ret
	.globl __mirl_exit
	.type __mirl_exit, @function
__mirl_exit:
	mov eax, 60
	syscall
