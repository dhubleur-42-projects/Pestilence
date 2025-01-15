global _start

section .text

_start:
;	mov rax, 101
;	mov rdi, 0
;	xor rsi, rsi
;	xor rdx, rdx
;	syscall

	mov rax, 56
	mov rdi, 0x2000 | 0x8000
	xor rdi, rdi
	mov rsi, rsp
	sub rsi, 1000
	xor rdx, rdx
	xor r10, r10
	xor r9, r9
	syscall

	cmp rax, 0
	je .child
	jmp .parent
.child:
	call print
	jmp _pouet
.parent:
	call print2
	jmp _pouet

_pouet:
	mov rax, 101
	mov rdi, 0
	xor rsi, rsi
	xor rdx, rdx
;	syscall
	cmp rax, 0
	jl .debugged
	jmp .not_debugged
.debugged:
	call print3
	jmp .end
.not_debugged:
	call print4
	jmp .end

.end:
	mov rax, 60
	jmp .end
	mov rdi, 0
	syscall

print:
	mov rax, 1
	mov rdi, 1
	lea rsi, [rel txt]
	mov rdx, txt_len
	syscall
	ret

print2:
	mov rax, 1
	mov rdi, 1
	lea rsi, [rel txt2]
	mov rdx, txt2_len
	syscall
	ret

print3:
	mov rax, 1
	mov rdi, 1
	lea rsi, [rel txt3]
	mov rdx, txt3_len
	syscall
	ret

print4:
	mov rax, 1
	mov rdi, 1
	lea rsi, [rel txt4]
	mov rdx, txt4_len
	syscall
	ret

section .data
txt: db "Hello World!", 0x0A
txt_len: equ $ - txt
txt2: db "Salut!", 0x0A
txt2_len: equ $ - txt2
txt3: db "Txt3", 0x0A
txt3_len: equ $ - txt3
txt4: db "Txt4", 0x0A
txt4_len: equ $ - txt4
