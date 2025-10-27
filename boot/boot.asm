[org 0x7c00]


mov ax, 3
int 0x10

xor ax,ax
mov ds,ax
mov es,ax
mov ss,ax
mov sp, 0x7c00

mov ax, MSG_REAL_MODE
mov si,ax
call bios_print

mov edi, 0x1000
mov ecx, 1
mov bl, 4
call read_disk

cmp word [0x1000], 0x9871
jnz error

jmp 0:0x1002

jmp $

bios_print:
    .ploop:
        lodsb
        or al,al
        jz .done
        mov ah, 0x0e
        int 0x10
        jmp .ploop
    .done:
    ret



read_disk:
    mov dx, 0x1f2   ;number
    mov al, bl
    out dx, al

    inc dx          ;0x1f3 sector addr low 8b
    mov al, cl
    out dx, al

    inc dx          ;0x1f4 mid 8b
    shr ecx, 8
    mov al, cl
    out dx, al

    inc dx          ;0x1f5 high 8b
    shr ecx, 8
    mov al, cl
    out dx, al

    inc dx          ;0x1f6 0~3:sector addr 24~27
    shr ecx, 8      ;4: 0 main 1 servant
    and cl, 0b1111  ;6: 0 CHS 1 LBA

    mov al, 0b1110_0000 ;5~7: fixed 1
    or al, cl
    out dx, al

    inc dx          ;0x1f7 out
    mov al, 0x20    ;0xec indentify disk
    out dx, al      ;0x20 read
                    ;0x30 write
    xor ecx, ecx    
    mov cl, bl      

    .read:
        push cx
        call .waits
        call .reads
        pop cx
        loop .read

    ret

    .waits:
        mov dx, 0x1f7
        .check:
            in al, dx           ;in(8b)
            jmp $+2
            jmp $+2
            jmp $+2
            and al, 0b1000_1000 ;0 ERR 3 DRQ 7 BSY
            cmp al, 0b0000_1000
            jnz .check
        ret

    .reads:
        mov dx, 0x1f0   ;16b IO data
        mov cx, 256
        .readw:
            in ax, dx
            jmp $+2
            jmp $+2
            jmp $+2
            mov [edi], ax
            add edi, 2
            loop .readw
        ret

error:
    mov si, MSG_ERROR
    call bios_print
    hlt
    jmp $


MSG_REAL_MODE db "Started in 16-bit Real Mode",13, 10, 0
MSG_PROT_MODE db "Landed in 32-bit Protected Mode",13, 10, 0
MSG_READ_CHECK db "Disk read successful!",13,10,0
MSG_ERROR db "Disk reading error!",13,10,0

times 510-($-$$) db 0
dw 0xAA55
