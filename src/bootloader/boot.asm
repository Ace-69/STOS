ORG 0x7C00 ; BIOS loads the boot sector to 0x7c00

bits 16 ; 16-bit real mode

%define ENDL 0x0D, 0x0A ; newline

; FAT12 header

jmp short start
nop

bdb_OEM:                        db 'MSWIN4.1'                       ;8bytes
bdb_bytesPerSector:             dw 512 
bdb_sectorsPerCluster:          db 1
bdb_reservedSectors:            dw 1
bdb_fatCount:                   db 2
bdb_dirEntryCount:              dw 0e0h
bdb_totalSectors:               dw 2880                             ; 2880 * 512 = 1.44MB
bdb_mediaDescriptorType:        db 0f0h                             ; F0 = 3.5" floppy
bdb_sectorsPerFat:              dw 9                                ; 9 sectors per FAT
bdb_sectorsPerTrack:            dw 18
bdb_headCount:                  dw 2
bdb_hiddenSectors:              dd 0
bdb_largeSector_count:          dd 0


; extended boot record
ebr_driveNumber:                db 0                                ; 0x00 = floppy,  0x80 = hard drive
                                db 0                                ; reserved
ebr_signature:                  db 29h                              ; 0x29 = extended boot record
ebr_volumeID:                   dd 12h, 24h, 48h, 96h               ; volume serial number, number doesn't matter
ebr_volumeLabel:                db 'STOS       '                    ; volume label, 11 bytes padded with spaces
ebr_systemID:                   db 'FAT12   '                       ; file system identifier, 8 bytes padded with spaces



start:
    jmp main ; jump to main


; print a string to the screen
puts:
    push si
    push ax

.loop
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

    ; Read something from disk
    ; BIOS SHOULD set dl to drive number
    mov [ebr_driveNumber], dl

    mov ax, 1                               ; LBA = 1, second sector from disk
    mov cl, 1                               ; sector 1 to read
    mov bx , 0x7E00                         ; data should be after bootloader
    call disk_read


    ; Print message

    mov si, msg_hello
    call puts

    cli                                     ; disable interrupts
    hlt                                     ; halt the CPU

floppy_error:
    mov si, floppy_error_msg
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                                 ; BIOS interrupt, wait for key press
    jmp 0FFFFh:0                            ; jump to beginning of BIOS, should reboot

.halt:
    cli                                     ; disable interrupts
    jmp .halt                               ; infinite loop


; Disk Routine

; convert logical sector number to CHS
lba_to_chs:

    push ax
    push dx

    xor dx, dx                              ; clear dx       
    div word [bdb_sectorsPerTrack]          ; divide by sectors per track
                                            ; ax = LBA / SectorPerTrack
                                            ; dx = LBA % SectorPerTrack
    
    inc dx                                  ; dx = LBA % SectorPerTrack + 1 = sector
    mov cx, dx                              ; cx = sector
    xor dx, dx                              ; clear dx
    div word [bdb_headCount]                ; divide by head count
                                            ; ax = (LBA / SectorPerTrack) / HeadCount (cylinder)
                                            ; dx = (LBA / SectorPerTrack) % HeadCount (head)
    mov dh , dl                             ; dh = head
    mov ch, al                              ; ch = cylinder low 8 bits
    shr ah, 2                               ; shift ah 2 bits to get the high 2 bits of cylinder
    or cl, ah                               ; cl = cylinder high 2 bits

    pop ax
    mov dl, al                              
    pop ax
    ret

; read a sector from disk

disk_read:

    push ax                                 ; save registers before modifying
    push bx
    push cx
    push dx
    push di

    push cx                                 ; temp save cx
    call lba_to_chs                         ; convert lba to chs
    pop ax                                  ; AL = number of sectors to read

    mov ah, 02h                             ; read sector function
    mov di 3

.retry:
    pusha                                   ; save registers, you never know
    stc                                     ; set carry flag
    int 13h                                 ; carry flag cleared = success, call BIOS interrupt
    jnc .done                               ; jump if carry not set 
    
    ; read failed, try again
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts failed
    jmp floppy_error
.done:
    popa

    pop ax                                 ; restore registers
    pop bx
    pop cx
    pop dx
    pop di
    ret


; reset Disk Controller
disk_reset:
    pusha
    mov ah, 00h                             ; reset disk function
    stc
    int 13h                                 ; call BIOS interrupt
    jc floppy_error                         ; jump if error
    popa
    ret

msg_hello:                  db 'Welcome to STOS', ENDL ,0
floppy_error_msg:           db 'Read from disk failed.', ENDL, 0

times 510-($-$$) db 0 ; fill the rest of the sector with 0s
dw 0xaa55 ; magic number (required by some BIOSes)