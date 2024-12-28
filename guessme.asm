; GuessME
;
;
; This file is a part of the GuessME 1.0 source code and is published under BSD 3-Clause License.
; Visit https://github.com/FarzanHajian/GuessME/blob/main/LICENSE for details.



; Stack alignment is crucial when calling external (Windows API) functions.
; If a pure Assembly function calls only other pure Assembly functions, ignoring stack
; alignments doesn't bother anyone. But when there is a call to a Windows API function,
; or any external C or C++ function built for Windows x64, the stack pointer register,
; rsp, must be 16-byte aligned - devisible by 16 - when calling the external function,
; otherwise, the program is susceptible to crash due to the access violation exception.
; Bear in mind that every invocation of the "call" instruction implicitly pushes the
; return address onto the stack and you need to consider it when try aligning rsp.
;
; Function prologue on Windows x64 consists of a precise calculation of the stack frame
; size based on the function needs (local variables, stack parameters, shadow area, etc.)
; and to make it 16-byte aligned the following rule can be used:
;        Required stack space + 8 bytes (return address) + padding must be divisible by 16
; Using the rule above, you can calculate how much the padding should be. You need to
; make sure that rsp is divisible by 16 after the function prologue.
; 
; It is still possible to save the base pointer register, rbp, by pushing it onto the
; stack in the function prologue but it is mainly used for debugging purposes to ease
; stack frame navigaions. In this case, you also have to take pushed rbp into consideration
; while aligning the stack pointer.
;
; In addition to 16-byte alignment, be careful to build the correct stack layout (shadow
; space, room for stack allocated parameters,...) when calling an external function. 
;
; THE STACK POINTER DECREASES WHEN PUSHING A VALUE ONTO THE STACK


bits 64
default rel
global main

extern ExitProcess
extern GetStdHandle
extern ReadFile
extern WriteFile


section .data
    upper_bound         equ 100_000     ; remember that you might also need to change max_tries and buffer_len if you change this
    max_tries           equ 20

    ; The logo ASCII art can be found at https://patorjk.com/software/taag/#p=display&h=3&v=2&f=Isometric1&t=GUESS%0A%20%20ME
    ; A larger version is also avaialbe at https://patorjk.com/software/taag/#p=display&h=2&v=3&f=Alpha&t=GUESS%0A%20%20%20%20%20ME
    ; but it's useful for width (full-screen) terminal windows.
    logo                db 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5f, 0x5f, 0x5f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5f, 0x5f, 0x5f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5f, 0x5f, 0x5f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5f, 0x5f, 0x5f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5f, 0x5f, 0x5f, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x5c, 0x20, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x5c, 0x20, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x5f, 0x5f, 0x5f, 0x20, 0x2f, 0x3a, 0x3a, 0x5c, 0x7e, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x5f, 0x5c, 0x3a, 0x5c, 0x7e, 0x5c, 0x20, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x5f, 0x5c, 0x3a, 0x5c, 0x7e, 0x5c, 0x20, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0xd, 0xa, 
                        db 0x20, 0x2f, 0x3a, 0x2f, 0x5f, 0x5f, 0x2f, 0x5f, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x2f, 0x3a, 0x2f, 0x5f, 0x5f, 0x2f, 0x20, 0x20, 0x2f, 0x5c, 0x5f, 0x5f, 0x2f, 0x3a, 0x2f, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x2f, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x20, 0x5c, 0x5f, 0x5f, 0x2f, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x20, 0x5c, 0x5f, 0x5f, 0x5c, 0xd, 0xa, 
                        db 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x2f, 0x5c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x7e, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0xd, 0xa, 
                        db 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x5f, 0x5f, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x5f, 0x5f, 0x20, 0x5c, 0x3a, 0x5c, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x5c, 0x3a, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x3a, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x5c, 0x2f, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x5c, 0x3a, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x3a, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x3a, 0x3a, 0x7c, 0x20, 0x20, 0x7c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x3a, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x7c, 0x3a, 0x7c, 0x20, 0x20, 0x7c, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x7c, 0x3a, 0x7c, 0x5f, 0x5f, 0x7c, 0x5f, 0x5f, 0x20, 0x2f, 0x3a, 0x3a, 0x5c, 0x7e, 0x5c, 0x3a, 0x5c, 0x20, 0x20, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x7c, 0x3a, 0x3a, 0x3a, 0x3a, 0x5c, 0x5f, 0x5f, 0x2f, 0x3a, 0x2f, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x7e, 0x7e, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x7e, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2f, 0x3a, 0x2f, 0x20, 0x20, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x3a, 0x5c, 0x5f, 0x5f, 0x5c, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa, 
                        db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x5c, 0x2f, 0x5f, 0x5f, 0x2f, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xd, 0xa
    logo_len            equ $-logo

    newline             db 0xd, 0xa
    
    welcome_msg1        db 'Hello and welcome to "Guess Me". I have picked a number for you to guess between 1 and '
    welcome_msg1_len    equ $-welcome_msg1

    welcome_msg2        db '.', 0xd, 0xa, 'You have '
    welcome_msg2_len    equ $-welcome_msg2

    welcome_msg3        db ' guesses. Good luck :)'
    welcome_msg3_len    equ $-welcome_msg3

    ask_guess_msg1      db 'Enter your guess (#'
    ask_guess_msg1_len  equ $-ask_guess_msg1

    ask_guess_msg2      db '): '
    ask_guess_msg2_len  equ $-ask_guess_msg2

    too_low_msg         db '  too LOW.'
    too_low_msg_len     equ $-too_low_msg

    too_high_msg        db '  too HIGH.'
    too_high_msg_len    equ $-too_high_msg

    nan_guess_msg       db 'Enter a number please :('
    nan_guess_msg_len   equ $-nan_guess_msg

    winner_msg          db 'Congratulations! You made it :) :) :)'
    winner_msg_len      equ $-winner_msg

    loser_msg           db 'Ooooh Nooo it was not your day :( My number was '
    loser_msg_len       equ $-loser_msg

    play_again_msg      db 'Do you want to play again (Y)?'
    play_again_msg_len  equ $-play_again_msg

    goodbye_msg         db 'Goodby :)'
    goodbye_msg_len     equ $-goodbye_msg

    no_rdrand_msg       db 'Sorry but your CPU does not support the RDRAND instruction :('
    no_rdrand_msg_len   equ $-no_rdrand_msg

    buffer_len          equ 6
    error_code          equ 4_000_000


section .bss
    buffer              resb buffer_len
    picked_number       resq 1
    current_try         resw 1


section .text
main:
    sub     rsp, 40                     ; stack alignment (8) + shadow space (32)

    main_start:
    call    print_intro

    call    rand
    cmp     rax, error_code
    je      main_norand
    mov     [picked_number], rax

    mov     qword[current_try], 1
    main_loop:
        call    ask_for_guess
        cmp     rax, [picked_number]
        ja      main_high_guess
        je      main_win

        lea     rcx, [too_low_msg]
        mov     rdx, too_low_msg_len
        mov     r8, 1
        call    print
        call    print_empty_line
        jmp     main_next_try

        main_high_guess:
        lea     rcx, [too_high_msg]
        mov     rdx, too_high_msg_len
        mov     r8, 1
        call    print
        call    print_empty_line

        main_next_try:
        mov     rax, [current_try]
        cmp     rax, max_tries
        je      main_lose
        inc     rax
        mov     [current_try], rax
        jmp     main_loop
    
    main_win:
    lea     rcx, [winner_msg]
    mov     rdx, winner_msg_len
    mov     r8, 1
    call    print        
    xor     rcx, rcx
    jmp     main_exit

    main_lose:
    lea     rcx, [loser_msg]
    mov     rdx, loser_msg_len
    mov     r8, 0
    call    print
    mov     rcx, [picked_number]        
    mov     rdx, 1
    call    print_int
    xor     rcx, rcx
    jmp     main_exit

    main_norand:
    lea     rcx, [no_rdrand_msg]
    mov     rdx, no_rdrand_msg_len
    mov     r8, 1
    call    print
    mov     rcx, 1

    main_exit:
    call    ask_for_play_again
    cmp     rax, 1
    je      main_start

    lea     rcx, [goodbye_msg]
    mov     rdx, goodbye_msg_len
    mov     r8, 1
    call    print
    call    print_empty_line
    call    ExitProcess


print_intro:
    sub     rsp, 8      ; stack alignment

    lea     rcx, [logo]
    mov     rdx, logo_len
    mov     r8, 0
    call    print

    lea     rcx, [welcome_msg1]
    mov     rdx, welcome_msg1_len
    mov     r8, 0
    call    print
    
    mov     rcx, upper_bound
    mov     rdx, 0
    call    print_int

    lea     rcx, [welcome_msg2]
    mov     rdx, welcome_msg2_len
    mov     r8, 0
    call    print

    mov     rcx, max_tries
    mov     rdx, 0
    call    print_int

    lea     rcx, [welcome_msg3]
    mov     rdx, welcome_msg3_len
    mov     r8, 1
    call    print

    add     rsp, 8
    ret 


ask_for_guess:
    ; Returns an integer.

    sub     rsp, 8      ; stack alignment

    ask_for_guess_loop:
        ; Printing the prompt
        lea     rcx, [ask_guess_msg1]
        mov     rdx, ask_guess_msg1_len
        mov     r8, 0
        call    print
        mov     rcx, [current_try]
        mov     rdx, 0
        call    print_int
        lea     rcx, [ask_guess_msg2]
        mov     rdx, ask_guess_msg2_len
        mov     r8, 0
        call    print

        ; Waiting for the user input
        call    read_int
        cmp     rax, error_code
        jne     ask_for_guess_exit      ; everything is fine

        ; Invalid (Not A Number) input
        lea     rcx, [nan_guess_msg]
        mov     rdx, nan_guess_msg_len
        mov     r8, 1
        call    print
        call    print_empty_line
        jmp     ask_for_guess_loop
    
    ask_for_guess_exit:
    add     rsp, 8
    ret


ask_for_play_again:
    ; Asks the user if they want to play again and returns 1 if yes otherwise returns 0.

    sub     rsp, 40             ; one qword local variable (8) +  shadow space (32)
    mov     qword[rsp+32], 0    ; local variable (byte count actually read)
    
    lea     rcx, [play_again_msg]
    mov     rdx, play_again_msg_len
    mov     r8, 0
    call    print

    mov     rcx, -10            ; STD_INPUT_HANDLE
    call    GetStdHandle

    mov     rcx, rax
    lea     rdx, [buffer]
    mov     r8, 1                   ; number of bytes to read
    lea     r9, [rsp+32]            ; number of bytes actually read
    call    ReadFile

    cmp     byte[buffer], 0x59      ; 'Y'
    je      ask_for_play_again_yes
    cmp     byte[buffer], 0x79      ; 'y'
    je      ask_for_play_again_yes
    mov     rax, 0                  ; it's a no anwser
    jmp     ask_for_play_again_exit

    ask_for_play_again_yes:
    mov     rax, 1
    
    ask_for_play_again_exit:
    add     rsp, 40
    ret    


print:
    ; rcx: points to the string
    ; rdx: the length of the string
    ; r8 : 1=> add a newline
    
    sub     rsp, 72             ; 4 qword local variables (32) + 1 qword stack parameter (the last parameter of WriteFile) (8) + shadow space (32)
    mov     [rsp+64], r8        ; has newline?
    mov     [rsp+56], rdx       ; string length 
    mov     [rsp+48], rcx       ; string
    mov     qword[rsp+40], 0    ; STD OUT handle
    mov     qword[rsp+32], 0    ; Stack parameter

    mov     rcx, -11            ; STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     [rsp+40], rax
    
    mov     rcx, rax            ; file handle
    mov     rdx, [rsp+48]       ; string
    mov     r8, [rsp+56]        ; length
    mov     r9, 0               ; we don't need to know how many bytes are written
    call    WriteFile

    cmp     qword[rsp+64], 1    ; is newline needed?
    jne     print_exit

    mov     rcx, [rsp+40]       ; file handle
    lea     rdx, [newline]      ; string
    mov     r8, 2               ; length
    mov     r9, 0               ; we don't need to know how many bytes are written
    call    WriteFile

    print_exit:
    add     rsp, 72
    ret


print_empty_line:
    sub     rsp, 8              ; stack alignment

    lea     rcx, [newline]
    mov     rdx, 2
    mov     r8, 0
    call    print

    add     rsp, 8
    ret


read_int:
    ; Tries to read an integer from the standard input and returns the integer value.
    ; error_code is returned if no integer convertible value is read.
    ; NOTE: The user input always ends with "\r\n" and it might contain more characters than buffer_len.
    ;       As a result, we either need to remove the "\r\n" if it occurs inside "buffer", or flush the
    ;       excess characters that did not fit in "buffer" but still reside in the standard input buffer as
    ;       they will be read automatically by the next ReadFile invocation. ReadFile reads maximum of 
    ;       buffer_len bytes each time so the number of actual bytes read that gets reported by ReadFile,
    ;       never surpasses buffer_len. The following pseudocode shows the whole logic where #OfBytesRead
    ;       is the actual bytes read reported by ReadFile:
    ;
    ;       if #OfBytesRead < buffer_len
    ;           find the \r starting from the end
    ;           clear_buffer from \r to the end
    ;           call str_to_int
    ;       else
    ;           if buffer ends with \r\n
    ;               clear_buffer from the second to the end byte
    ;               call str_to_int
    ;           else
    ;               if the last byte == \r
    ;                   clear_buffer from the last byte
    ;               call str_to_int
    ;               flush stdin
    ;
    ;       And it can be summarized to:
    ;
    ;       flushStdin=false
    ;       if #OfBytesRead == buffer_len       // user has inputted either exactly buffer_len bytes or more
    ;           if buffer last byte != \n       // input length is greater than buffer_len, so StdIn buffer must be flushed
    ;               flushStdin = true
    ;       find the \r starting from the end
    ;       clear_buffer from \r to the end
    ;       if flushStdin == true
    ;           flush stdin

    sub     rsp, 56             ; 2 qword local variables (16) + 1 qword stack parameter (the last parameter of ReadFile) (8) + shadow space (32)
    mov     qword[rsp+48], 0    ; local variable (StdIn handle)
    mov     qword[rsp+40], 0    ; local variable (byte count actually read)
    mov     qword[rsp+32], 0    ; Stack parameter

    mov     rcx, -10            ; STD_INPUT_HANDLE
    call    GetStdHandle
    mov     qword[rsp+48], rax

    ; r15b keeps track of two flags in its two least significant bits:
    ;   7         ...            1                           0
    ;  ---------------------------------------------------------------------------
    ; |                         | flush stdin buffer during | current iteration   |
    ; |           ...           | the next iteration?       | mode?               |
    ; |                         | 0: no                     | 0: read-data mode   |
    ; |                         | 1: yes                    | 1: flush-stdin mode |
    ;  ---------------------------------------------------------------------------
    mov     r15b, 0

    read_int_loop:
        mov     rcx, qword[rsp+48]
        lea     rdx, [buffer]
        mov     r8, buffer_len      ; number of bytes to read
        lea     r9, [rsp+40]        ; number of bytes actually read
        call    ReadFile

        and     r15b, 1111_1101b                    ; resetting the flush flag
        cmp     qword[rsp+40], buffer_len
        jne     read_int_process_input              ; the input length is less than buffer_len
        cmp     byte[buffer+buffer_len-1], 0xa      ; the input length might be equal to or more than buffer_len
        je      read_int_process_input              ; the last byte is \n so, the input length is excatly buffer_len
        or      r15b, 10b                           ; setting the flush flag as the input legnth is greater than buffer_len

        read_int_process_input:
        test    r15b, 01b                   ; are we in flush-stdin mode?
        jz      read_int_process_buffer     ; ...no, processing user's guess
        jmp     read_int_loop_epilog

        read_int_process_buffer:
        ; Searching for the first "\r" starting from the end to then Remove the possible trailing "\r\n" from the input.
        mov     rcx, buffer_len
        read_int_check_cr_loop:
            lea     rax, [buffer]
            lea     rax, [rax+rcx-1]
            cmp     byte[rax], 0xd
            je      read_int_clear
            loop    read_int_check_cr_loop

        jmp     read_int_convert    ; no remove is needed as we have at least buffer_len charaters

        read_int_clear:
        dec     rcx
        call    clear_buffer

        read_int_convert:
        call    str_to_int
        mov     r14, rax        ; the final result
        
        read_int_loop_epilog:
        test    r15b, 10b       ; does stdin need to be flushed? ...
        jz      read_int_exit   ; ... no
        or      r15b, 01b       ; entering flush-stdin mode
        jmp read_int_loop

    read_int_exit:
    add     rsp, 56
    mov     rax, r14
    ret


print_int:
    ; rcx: holds the integer
    ; rdx: 1=> add a newline

    sub     rsp, 8          ; 1 qword local variable (newline)(8)
    mov     [rsp], rdx

    call    int_to_str      ; loads the integer into buffer
    lea     rcx, [buffer]   ; the string
    mov     rdx, rax        ; the string length
    mov     r8, [rsp]       ; add newline?
    call    print
    
    add     rsp, 8
    ret


clear_buffer:
    ; Clears the string buffer (https://stackoverflow.com/questions/39154103/how-to-clear-a-buffer-in-assembly/39231516#39231516)
    ; rcx: the start index (must be between 0 and buffer_len, invalid values lead to undefined behavior)

    push    rdi                 ; rdi is non-volatile (callee-save)

    ; Calculating the destination (rdi)
    lea     rdi, [buffer]
    add     rdi, rcx

    ; Calculating the repetition count (rcx)
    mov     rax, buffer_len
    sub     rax, rcx
    mov     rcx, rax

    xor     rax, rax            ; filling the buffer with zeros (rax)
    rep     stosb               ; storing buffer_len 0s into the buffer
    
    pop     rdi                 ; restoring rdi
    ret       


align_buffer:
    ; Shifts the buffer content to the begining of buffer
    ; rcx: number of characters

    sub     rsp, 8          ; stack alignment (8)
    push    rsi             ; rsi is non-volatile (callee-save)
    push    rdi             ; rdi is non-volatile (callee-save)

    ; Moving the content
    lea     rsi, [buffer]   ; source = buffer start + (buffer len - string len)
    add     rsi, buffer_len
    sub     rsi, rcx
    lea     rdi, [buffer]   ; destination = buffer start
    rep     movsb

    ; Filling the end portion with zeros
    mov     rsi, buffer_len ; repetition count (rsi is used as a temporary variable)
    sub     rsi, rcx
    mov     rcx, rsi
    call    clear_buffer

    pop     rdi             ; restoring rdi
    pop     rsi             ; restoring rsi
    add     rsp, 8
    ret       


int_to_str:
    ; rcx: holds the integer
    ; Returns number of digits
    
    sub     rsp, 8              ; 1 qword local variable (8)
    mov     [rsp], rcx          ; clear_buffer manipulates rcx and we need it after it

    mov     rcx, 0
    call    clear_buffer
    
    mov     rax, [rsp]
    mov     rcx, 10             ; we'll keep dividing by 10 to extract all digits
    xor     rbx, rbx            ; stores the number of digits temporarily
    int_to_str_loop:
        xor     rdx, rdx        ; rdx is not needed for this division operation
        div     rcx             ; eax = Quotient, edx = Remainder
        inc     rbx             ; one more digit was extracted

        ; filling the buffer
        add     rdx, 030h       ; finding the ascii character
        lea     r8, [buffer]
        add     r8, buffer_len
        sub     r8, rbx
        mov     [r8], dl
        
        cmp     rax, 0
        je      int_to_str_exit
        jmp     int_to_str_loop

    int_to_str_exit:
    mov     rcx, rbx
    call    align_buffer    ; we've built the string from end to start so we need to shift it to the begining of the buffer
    mov     rax, rbx
    add     rsp, 8
    ret


str_to_int:
    ; Converts the string inside the buffer to an integer
    ; Returns the integer or error_code if the string is not convertible

    cmp     byte[buffer], 0     ; do we have anything in buffer?
    je      str_to_int_error

    lea     rcx, [buffer]
    xor     rax, rax            ; the result
    mov     r9, 10              ; we'll keep mutiplying by 10 to aggregate all digits
    xor     r8, r8              ; will hold each step character temporarily
    mov     rbx, 1              ; loop counter
    str_to_int_loop:
        mov     r8b, [rcx+rbx-1]    ; current digit
        
        cmp     r8b, 0              ; is the character string terminator?
        je      str_to_int_exit
        
        cmp     r8b, 030h           ; character '0'
        jb      str_to_int_error
        cmp     r8b, 039h           ; character '9'
        ja      str_to_int_error
        sub     r8b, 030h           ; char to int conversion
        mul     r9
        add     rax, r8
        inc     rbx
        
        cmp     rbx, buffer_len     ; have we reached the end of the buffer?
        ja      str_to_int_exit
        
        jmp     str_to_int_loop
    
    str_to_int_error:
    mov     rax, error_code
    
    str_to_int_exit:
    ret
    
    
rand:
    ; Using RDRAND to return a random number. error_code is returned in the case of errors.

    ; Checking whether RDRAND is supported (https://wiki.osdev.org/Random_Number_Generator)
    mov     eax, 1
    mov     ecx, 0
    cpuid
    shr     ecx, 30
    and     ecx, 1
    jz      rand_no_rdrand

    retry_rand:
    xor     rax, rax
    rdrand  eax
    cmp     eax, upper_bound
    ja      retry_rand
    ret

    rand_no_rdrand:
    mov     rax, error_code
    ret