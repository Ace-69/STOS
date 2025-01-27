ORG 0x0 ; special kernel boi

bits 16 ; 16-bit real mode

%define ENDL 0x0D, 0x0A ; newline

start:
    mov si, msg_hello
    call puts




.halt:
    cli
    hlt

; print a string to the screen
puts:
    push si
    push ax
    push bx

.loop:
    lodsb           ; load the next byte from si into al
    or al, al       ; check if al is 0
    jz .done        ; if al is 0, we're done
    mov ah, 0x0E    ; teletype output
    mov bh, 0x00    ; page number = 0
    int 0x10        ; call BIOS interrupt
    jmp .loop       ; loop back
.done:
    pop bx
    pop ax
    pop si
    ret

msg_hello: db 'Welcome to STOS', ENDL ,0