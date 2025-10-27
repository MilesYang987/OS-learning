[org 0x1000]
    dw 0x9871
    mov si, loading
    call bios_print

    call detect_memory
    ; mov ax, [ADRS_count]
    ; mov [print_data], ax
    ; call bios_print_hex

    call prepare_PE

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

loading:
    db "Loading OS...",10,13,0


bios_print_hex:
    mov di, outstr+2
    mov ax, [print_data]
    mov si, hexstr
    mov cx, 4
.hex_loop:
    rol ax, 4
    mov bx, ax
    and bx, 0x0f
    mov bl, [si+bx]
    mov [di], bl
    inc di
    loop .hex_loop

    mov si, outstr
    call bios_print
    
    ret
outstr: db "0x0000", 0
hexstr: db "0123456789ABCDEF"
print_data: dw 0


detect_memory:
    xor ebx, ebx

    mov ax, 0
    mov es, ax
    mov di, ADRS_buffer

    mov edx, 0x534d4150

.next:
    mov eax, 0xe820
    mov ecx, 20

    int 0x15

    jc error

    add di, cx
    inc word [ADRS_count]
    cmp ebx, 0
    jnz .next

    mov si, detecting
    call bios_print

    ret

detecting:
    db "Detect memory successful!",10,13,0
error:
    db "Error in detecting memory!",10,13,0



prepare_PE:
    cli
    ;open A20
    in al, 0x92
    or al, 0b10
    out 0x92, al

    lgdt [GDT_ptr]
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp dword code_selector: protected


[bits 32]
protected:
    mov ax, data_selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x10000

    mov byte [0xb8000], 'P'
    
    mov edi, 0x10000
    mov ecx, 10
    mov bl, 200
    call read_disk

    jmp dword code_selector:0x10000

    ud2


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



;selector RPL(2) TI(1) index(13)
code_selector equ (1 << 3)
data_selector equ (2 << 3)

memory_base equ 0
memory_limit equ ((4*1024*1024*1024)/(4*1024))-1


GDT_ptr:
    dw (GDT_end-GDT_base) - 1
    dd GDT_base
GDT_base:
    dd 0,0
GDT_code:
    dw memory_limit & 0xffff        ;memory_limit low 15b
    dw memory_base & 0xffff         ;memory base 0~15b
    db (memory_base >> 16) & 0xff   ;memory base 16~23b
    db 0b_1_00_1_1010               ;type(4) segment(1) DPL(2) present(1) type: x|c/e|r/w|a (x:1 data x:0 code a:accessed)
    db 0b1_1_0_0_0000 | (memory_limit >> 16) & 0xf  ;memory limit 16~19b available(1) long mode(1) big(1) granularity(1)
    db (memory_base >> 24) & 0xff   ;memory base 24~31b
GDT_data:
    dw memory_limit & 0xffff        ;memory_limit low 15b
    dw memory_base & 0xffff         ;memory base 0~15b
    db (memory_base >> 16) & 0xff   ;memory base 16~23b
    db 0b_1_00_1_0010               ;type(4) segment(1) DPL(2) present(1) type: x|c/e|r/w|a (x:1 data x:0 code a:accessed)
    db 0b1_1_0_0_0000 | (memory_limit >> 16) & 0xf  ;memory limit 16~19b available(1) long mode(1) big(1) granularity(1)
    db (memory_base >> 24) & 0xff   ;memory base 24~31b
GDT_end:


ADRS_count:
    dw 0
ADRS_buffer: