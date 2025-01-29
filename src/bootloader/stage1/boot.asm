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
ebr_volumeID:                   dd 12h, 34h, 56h, 78h               ; volume serial number, number doesn't matter
ebr_volumeLabel:                db 'STOS       '                    ; volume label, 11 bytes padded with spaces
ebr_systemID:                   db 'FAT12   '                       ; file system identifier, 8 bytes padded with spaces



start:
    ; Setup data segment
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; Setup stack segment
    mov ss, ax
    mov sp, 0x7C00 ; Stack grows downwards

    ; Some BIOSes might start us at 07c0:0000, so we need to make sure we are in 0000:7c00
    push es
    push word .after
    retf
.after:

    ; Read something from disk
    ; BIOS SHOULD set dl to drive number
    mov [ebr_driveNumber], dl
    ; Print message
    mov si, msg_hello
    call puts
    ; Read drive parameters (SPT and HC we don't rely on data on formatted disk)
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es
    and cl, 0x3f                            ; clear the high 2 bits of cl   
    xor ch, ch
    mov [bdb_sectorsPerTrack], cx           ; sector count
    inc dh
    mov [bdb_headCount], dh                 ; head count
    ; Read FAT root directory
    mov ax, [bdb_sectorsPerFat]             ; LBA of root directory = reserved sectors + sectors per FAT
    mov bl, [bdb_fatCount]
    xor bh, bh
    mul bx                                  ; ax = fats * sectors per fat
    add ax, [bdb_reservedSectors]           ; ax = LBA of root directory
    push ax
    ; size of root dir = (32 * number of entries) / bytes per sector
    mov ax, [bdb_sectorsPerFat]            
    shl ax, 5                               ; ax *= 32
    xor dx, dx
    div word [bdb_bytesPerSector]           ; bytes per sector to read
    test dx, dx                             ; if dx != 0 add 1
    jz .root_dir_after
    inc ax                                  ; division remainder not 0, add 1
                                            ; sector only partially filled
.root_dir_after:
    ; read root directory
    mov cl, al                              ; number of sectors to read = size of root dir
    pop ax                                  ; LBA of root directory
    mov dl, [ebr_driveNumber]               ; drive number
    mov bx, buffer                          ; es:bx = buffer
    call disk_read
    ; Search for kernel binary file
    xor bx, bx
    mov di, buffer                          ; es:di = buffer
.search_kernel:
    mov si, file_kernel_bin                 ; si = kernel file name
    mov cx, 11                              ; cx = kernel file name length
    push di
    repe cmpsb                              ; cmpsb = compare string bytes in ds:si and es:di si and di are incremented or decremented based on direction flag
    pop di
    je .kernel_found                        ; if equal, jump to kernel found
    add di, 32                              ; move to next entry
    inc bx                                  ; increment entry count
    cmp bx, [bdb_dirEntryCount]             ; compare entry count with total entries
    jl .search_kernel
    ; kernel not found
    jmp Kernel_not_found
.kernel_found:
    mov ax, [di+26]                         ; fisrst logical cluster of field (offset 26)
    mov [kernel_cluster], ax                ; save cluster number
    ; load FAT from disk into memoryà
    mov ax, [bdb_reservedSectors]           ; LBA of FAT = reserved sectors
    mov bx, buffer                          ; es:bx = buffer
    mov cl, [bdb_sectorsPerFat]             ; number of fats
    mov dl, [ebr_driveNumber]               ; drive number
    call disk_read
    ; read kernel, process FAT chain
    ; we still are in 16bit real mode, cannot access memory above 1MB  
    mov bx, KERNEL_LOAD_SEGMENT             ; segment to load kernel
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET              ; offset to load kernel
.load_kernel_loop:
    ; Read Next Cluster
    mov ax, [kernel_cluster]                ; current cluster
    ; lazy, hardcoded value, fix later.
    add ax, 31                              ; first cluster = (kernel cluster - 2) * sectors per cluster + start sector
                                            ; start sector = reserved + fats + root dir size = 1 + 18 + 134 = 33
    mov cl, 1                               
    mov dl, [ebr_driveNumber]               
    call disk_read
    add bx, [bdb_bytesPerSector]            ; increment offset, will oveflow if kernel larger than 64kb
    ; compute location of next cluster
    mov ax, [kernel_cluster]                
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                                  ; ax = index of FAT entry, dx = cluster mod 2 
    mov si, buffer                       
    add si, ax
    mov ax, [ds:si]                         ; read FAT entry
    or dx, dx
    jz .even
.odd:
    shr ax, 4
    jmp .next_cluster_after
.even:
    and ax, 0x0FFF
.next_cluster_after:
    cmp ax, 0x0FF8                          ; end of chain
    jae .read_finish
    mov [kernel_cluster], ax                
    jmp .load_kernel_loop
.read_finish:
    ; jump to kernel
    mov dl, [ebr_driveNumber]               ; boot device in dl
    mov ax, KERNEL_LOAD_SEGMENT             ; set segment registers
    mov ds, ax
    mov es, ax
    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET
    ; should never reach here
    jmp wait_key_and_reboot

    cli                                     ; disable interrupts
    hlt                                     ; halt the CPU
Kernel_not_found:
    mov si, kernel_not_found_msg
    call puts
    jmp wait_key_and_reboot
floppy_error:
    mov si, floppy_error_msg
    call puts
    jmp wait_key_and_reboot
wait_key_and_reboot:
    mov ah, 0
    int 16h                                 ; BIOS interrupt, wait for key press
    jmp 0FFFFh:0                            ; jump to beginning of BIOS, should reboot
;.halt:
;    cli                                     ; disable interrupts
;    hlt                                     ; halt system
; print a string to the screen
puts:
    push si
    push ax
    ;push bx
.loop:
    lodsb           ; load the next byte from si into al
    or al, al       ; check if al is 0
    jz .done        ; if al is 0, we're done
    mov ah, 0x0E    ; teletype output
    ;mov bh, 0       ; page number to 0
    int 0x10        ; call BIOS interrupt
    jmp .loop       ; loop back
.done:
    ;pop bx
    pop ax
    pop si
    ret
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
    shr ah, 6                               ; shift ah 2 bits to get the high 2 bits of cylinder
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
    mov di, 3
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
    pop di
    pop dx
    pop cx
    pop bx
    pop ax                                 ; restore registers
    ret
; reset Disk Controller
disk_reset:
    pusha
    mov ah, 0                             ; reset disk function
    stc
    int 13h                                 ; call BIOS interrupt
    jc floppy_error                         ; jump if error
    popa
    ret
msg_hello:                  db 'Loading....', ENDL ,0
floppy_error_msg:           db 'Read from disk failed.', ENDL, 0
kernel_not_found_msg:       db 'Stage 2 not found.', ENDL, 0
file_kernel_bin:            db 'STAGE2  BIN', 0
kernel_cluster:             dw 0
KERNEL_LOAD_SEGMENT         equ 0x2000
KERNEL_LOAD_OFFSET          equ 0
times 510-($-$$) db 0 ; fill the rest of the sector with 0s
dw 0aa55h ; magic number (required by some BIOSes)
buffer: 