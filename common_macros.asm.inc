%ifndef COMMON_MACROS_
%define COMMON_MACROS_

%if __?NASM_VERSION_ID?__ < 0x0020F0500
  %fatal Insufficient Version of NASM found! Please use version __?NASM_VER?__ or later.
%endif
%pragma preproc sane_empty_expansion
BITS 64

; 1st arg: The delimiter as a string
; 2nd arg: Either of "a,1,2" to select all, first or second 
; 3rd arg: The token to be split
%macro _splitvarparam 3+.nolist
  %push
  %defstr %$string %3
  %strlen %$length %$string
  %assign %$ii 0
  %assign %$exit 0
  %rep %$length
    %substr %$point %$string %$ii + 1, 1
    %ifidn %$point, %1
      %assign %$exit 1
      %exitrep
    %endif
    %ifn %$exit
      %assign %$ii %$ii + 1
    %endif
  %endrep
  %ifn %$exit
    %fatal Expected %1 in variable declaration
  %endif
  %substr %$first %$string 1, %$ii
  %substr %$second %$string %$ii + 2, -1 
  
  %ifidn %2, a
    %strcat %$result %$first, ',', %$second
    %deftok __split_result %$result
  %elifidn %2, 1
    %deftok __split_result %$first
  %elifidn %2, 2
    %deftok __split_result %$second
  %else 
    %fatal invalid selector
  %endif
  %pop
%endmacro

; Unfolds a list of variable parameters such as "foo:4, bar:4" into a token list "foo,4,bar,4"
%macro unfoldvarparam 0-*.nolist
  %push
  _splitvarparam ':', a, %1
  %xdefine %$ret __split_result
  %rotate 1
  %rep %0 - 1
    _splitvarparam ':', a, %1
    %xdefine %$ret %[%$ret %, __split_result]
    %rotate 1
  %endrep
  %xdefine __split_result %$ret
  %pop
%endmacro

; Generate local variables and calculate used space
%macro _genlocals 2-*.nolist
  %if %0 % 2 == 1
    %error Uneven amount of local args passed
  %endif
  %push
  %assign %$offset 8
  %rep %0 / 2
    %xdefine %$$%1 (rbp-%$offset)
    %assign %$offset %$offset + %2
    %rotate 2
  %endrep
  %assign %$$localsize %$offset - 8
  %pop
%endmacro

; Generate stack arguments
%macro _genparams 2-*.nolist
  %if %0 % 2 == 1
    %error Uneven amount of param args passed
  %endif
  %push
  %assign %$offset 16
  %rep %0 / 2
    %xdefine %$$%1 (rbp+%$offset)
    %assign %$offset %$offset + %2
    %rotate 2
  %endrep
  %pop
%endmacro

%macro _proc 3.nolist
  %1:
    %push %1
    %define %$procname %1
    %ifnempty %2
      %undef %$argtok
      unfoldvarparam %2
      _genparams __split_result
    %endif
    %ifnempty %3
      %undef %$argtok
      unfoldvarparam %3
      _genlocals __split_result
    %else
      %assign %$localsize 0
    %endif
    enter %$localsize, 0
%endmacro


; Two macros for the user to set their custom align (when they pushed to the stack or made space some other way)
%macro proc_align 1.nolist
  %assign %$localsize %$localsize - %1
%endmacro
%macro proc_restore 1.nolist
  %assign %$localsize %$localsize + %1
%endmacro

; This macro must be used to properly exit a proc function
%macro proc_return 0.nolist
  leave
  ret
%endmacro

; Syntax for defining a function:
; proc <name>: {<stack argument name>:<size in bytes>}, {<local variable name>:<size in bytes>}
; <code>
; endp
; Do note that if you push manually, you must also manually align that stack space
; NEVER USE RET, ALWAYS USE PROC_RETURN INSTEAD
%macro proc 1+.nolist
  _splitvarparam ':', a, %1
  _proc __split_result
%endmacro

%macro endp 0.nolist
  leave
  ret
  %pop 
%endmacro


%define ABIREG1 rdi
%define ABIREG2 rsi
%define ABIREG3 rdx
%define ABIREG4 rcx
%define ABIREG5 r8
%define ABIREG6 r9

%macro ccall 1-*
  %push ccallctx
  %xdefine %$TARGET %1


  %rotate 1
  %assign %$i 1
  %rep %0-1
    %ifnidn ABIREG%[%$i], %1
      mov ABIREG%[%$i], %1
    %endif
    %if %$i == 6
      %exitrep
    %endif
    %rotate 1
    %assign %$i %$i+1
  %endrep

  ; push remainder onto stack
  %if %0-1-%$i > 0
    %rotate -i-1
    %rep %0-1-%$i
      push %1
      %rotate -1
    %endrep
  %endif

  ; Stack Alignment values
  ; + 8 at the end for the return address on stack
  %assign %$STACK_SHIFT ((%0-1-%$i) * 8) + 8 
  %ifdef %$$localsize
    %assign %$STACK_SHIFT %$STACK_SHIFT + %$$localsize
  %endif
  %assign %$STACK_SHIFT (16-(%$STACK_SHIFT % 16))% 16

  %if %$STACK_SHIFT != 0
    sub rsp, %$STACK_SHIFT
  %endif
  call %$TARGET
  %if %$STACK_SHIFT != 0
    add rsp, %$STACK_SHIFT
  %endif
  %pop
%endmacro


%endif