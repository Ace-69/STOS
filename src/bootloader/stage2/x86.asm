bits 16

section _TEXT class=CODE

; void _cdecl x86_div64_32(uint64_t dividend, uint32_t divisor, uint64_t* quotient, uint32_t* remainder);

global _x86_div64_32
_x86_div64_32:
    push bp                     ; save old call frame
    mov bp, sp                  ; init new call frame

    push bx                     ; save bx

    ; divide upper 32bits
    mov eax, [bp+8]             ; load upper 32 bits of dividend
    mov ecx, [bp+12]            ; load divisor

    xor edx, edx                ; clear edx
    div ecx                     ; eax = quotient, edx = remainder

    ; store upper 32 bits of result
    mov ebx, [bp+16]            ; load quotient pointer
    mov [ebx], eax              ; store quotient

    ; divide lower 32bits

    mov eax, [bp+4]             ; load lower 32 bits of dividend
    div ecx                     ; eax = quotient, edx = remainder

    ; store result
    mov [bx], eax               ; store quotient
    mov bx, [bp+18]
    mov [bx], edx               ; store remainder

    pop bx                      ; restore bx

    mov sp, bp                  ; restore old call frame
    pop bp
    ret


; void _x86_Video_WriteCharTeletype(char c, char page)

global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:
    
    push bp                     ; save old call frame
    mov bp, sp                  ; init new call frame
    
    push bx                     ; save bx

    mov ah, 0x0e
    mov al, [bp+4]              ; fist argument (charachter)
    mov bh, [bp+6]              ; second argument (page)
    int 0x10
    
    pop bx                      ; restore bx

    mov sp, bp                  ; restore old call frame
    pop bp
    ret