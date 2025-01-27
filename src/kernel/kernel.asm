ORG 0x7C00 ; BIOS loads the boot sector to 0x7c00

bits 16 ; 16-bit real mode

%define ENDL 0x0D, 0x0A ; newline

start:
    jmp main ; jump to main


; print a string to the screen
puts:
    push si
    push ax

.loop:
    lodsb           ; load the next byte from si into al
    or al, al       ; check if al is 0
    jz .done        ; if al is 0, we're done
    mov ah, 0x0E    ; teletype output
    int 0x10        ; call BIOS interrupt
    jmp .loop       ; loop back
.done:
    pop ax
    pop si
    ret

main:
    ; Setup data segment
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; Setup stack segment
    mov ss, ax
    mov sp, 0x7C00 ; Stack grows downwards

    ; Print message

    mov si, msg_hello
    call puts

    hlt ; halt the CPU

.halt:
    jmp .halt ; infinite loop

msg_hello: db 'Welcome to STOS', ENDL ,0

times 510-($-$$) db 0 ; fill the rest of the sector with 0s
dw 0xaa55 ; magic number
