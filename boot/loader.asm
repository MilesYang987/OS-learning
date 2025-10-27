[org 0x1000]

dw 0x9871

mov si, loading
call bios_print

call detect_memory

mov ax, [ADRS_count]
mov [print_data], ax
call bios_print_hex

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

outstr: db "0x0000", 0
hexstr: db "0123456789ABCDEF"
print_data: dw 0

loading:
    db "Loading OS...",10,13,0
detecting:
    db "Detect memory successful!",10,13,0
error:
    db "Error in detecting memory!",10,13,0

ADRS_count:
    dw 0
ADRS_buffer: