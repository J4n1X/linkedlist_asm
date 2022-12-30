BITS 64
%include "common_macros.asm.inc"

; The only registers that the called function is required to preserve (the calle-save registers) are: 
; rbp, rbx, r12, r13, r14, r15. All others are free to be changed by the called function.

extern printf
extern malloc
extern free
global main
global main.manipulation

section .text

struc listitem
  .prev:  resq 1,
  .next:  resq 1,
  .value: resq 0
endstruc

; (prev, next, val, valsize)
proc listitem_create: {}, {}
  push rcx
  push rdx
  push rsi
  push rdi

  add rcx, listitem_size ; get effective size(do note that the value is stored in the same struct)
  ccall malloc, rcx

  cmp rax, 0
  jne .assign
  ccall printf, mallocfail
  mov rax, 1
  proc_return
  .assign:
    .prev:
      pop rdx
      mov [rax + listitem.prev], rdx
      cmp rdx, 0
      je .next
      lea rcx, [rdx + listitem.next]
      mov rdi, [rcx]
      cmp rdi, 0
      jne .next
      mov [rcx], rax ; only move the pointer of the current in if the previous doesn't have next set
    .next:
      pop rdx
      mov [rax + listitem.next], rdx
      cmp rdx, 0
      je .value
      lea rcx, [rdx + listitem.prev]
      mov rdi, [rcx]
      cmp rdi, 0
      jne .value
      mov [rcx], rax ; only move the pointer of the current in if the next doesn't have previous set
    .value:
    cld ; direction: forward(increment rsi)
    lea rdi, [rax + listitem.value]
    pop rsi
    pop rcx
    rep movsb
    .exit:
endp

; Should work from any item in the list
; (item)
proc listitem_free_all: {}, {}
  push r12
  ccall list_traverse, rdi, listitem.prev
  cmp rax, 0
  je .exit
  .loop:
    mov r12, [rax+listitem.next]
    proc_align 8
    ccall free, rax
    proc_restore 8
    mov rax, r12
    cmp rax, 0 
    jne .loop
  .exit:
    pop r12
endp

; (dest_list, field_offset)
; if NULL is returned, the operation failed
; otherwise returns a pointer to the last item with a valid pointer in the selected field
proc list_traverse: {}, {}
  cmp rdi, 0
  mov rax, 0
  je .exit
  mov rax, rdi
  .loop:
    mov rax, [rax+rsi]
    cmp rax, 0 
    cmovne rdi, rax
    jne .loop
  mov rax, rdi
  .exit:
endp

; (dest_list, item)
; if NULL is returned, the operation failed
; otherwise returns a pointer to the newly added item
proc list_append: {}, {}
  push rsi
  mov rsi, listitem.next
  call list_traverse
  cmp rax, 0
  je .exit
  mov rdi, rax
  pop rax
  mov [rdi+listitem.next], rax
  mov [rax+listitem.prev], rdi
  .exit: 
endp

; (dest_list, item)
; if NULL is returned, the operation failed
; otherwise returns a pointer to the newly added item
proc list_prepend: {}, {}
  push rsi
  mov rsi, listitem.prev
  call list_traverse
  cmp rax, 0
  je .exit
  mov rdi, rax
  pop rax
  mov [rdi+listitem.prev], rax
  mov [rax+listitem.next], rdi
  .exit:
endp

; (dest_list, item, index from start)
; if NULL is returned, the operation failed
; If successful, the added item is returned
proc list_insert: {}, {}
  push rsi
  push rdx
  ccall list_traverse, rdi, listitem.prev
  pop rdx
  pop rsi
  cmp rax, 0
  je .exit
  mov rdi, rax
  xor rcx, rcx
  .loop:
    mov rdi, [rdi+listitem.next]
    cmp rdi, 0
    je .exit
    inc rcx
    cmp rcx, rdx
    jne .loop
  ; grab the prev from the current index and bind against the new one
  mov rcx, [rdi+listitem.prev]
  mov [rsi+listitem.prev], rcx
  mov [rcx+listitem.next], rsi
  ; bind the current index to the new one
  mov [rdi+listitem.prev], rsi
  mov [rsi+listitem.next], rdi
  mov rax, rsi
  .exit:
endp

proc print_listitem: {}, {}
  [section .rdata]
    print_listitem_msg: db "Self: %p; Previous: %p; Next: %p; Value: %lu", 10, 0
  __SECT__
  mov rax, rdi
  ccall printf, print_listitem_msg, rax, [rax + listitem.prev], [rax + listitem.next], [rax + listitem.value]
  xor rax, rax
endp

proc main: {}, {argc:8, argv:8, item1:8, item2:8, item3:8}
  [section .rdata]
    main_testtext: db "This is some test text", 10, 0
    main_testlen: equ $-main_testtext
    main_listitem_failed: db "Failed to create a new list item", 10, 0
    v1: dq 123
    v2: dq 456
    v3: dq 789
  __SECT__

  mov [%$argc], rdi
  mov [%$argv], rsi

  
  ccall listitem_create, 0, 0, v1, 8
  mov [%$item1], rax
  cmp rax, 0 
  je .listitem_error

  ccall listitem_create, 0, 0, v2, 8
  mov [%$item2], rax
  cmp rax, 0 
  je .listitem_error

  ccall listitem_create, 0, 0, v3, 8
  mov [%$item3], rax
  cmp rax, 0 
  je .listitem_error

  ccall list_append, [%$item1], [%$item3]
  cmp rax, 0 
  je .listitem_error

  ; oops, we forgot about item2!
  ccall list_insert, [%$item1], [%$item2], 1
  cmp rax, 0 
  je .listitem_error

  push r12
  mov r12, [%$item1]
  .loop:
    proc_align 8
    ccall print_listitem, r12
    proc_restore 8
    mov r12, [r12+listitem.next]
    cmp r12, 0
    jne .loop
  
  pop r12
  ccall listitem_free_all, [%$item1]
  

  xor rax, rax
  .exit:
    mov rdi, rax
    mov rax, 60
    syscall
    proc_return
  .listitem_error:

  .error:
    ccall printf, rcx
    mov rax, 1
    jmp .exit
endp

section .rdata
  mallocfail: db "Failed to allocate memory with malloc", 10, 0