bits 16
org 0x7c00

; --- Configuration ---
KERNEL_SEG      equ 0x1000      ; Load to 0x10000
SECTORS_TO_READ equ 64          ; Read 32KB (Plenty for now, safe for single read)

start:
    jmp 0:init

init:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    mov [boot_drive], dl        ; Save Boot Drive

    ; 1. Fast A20 Gate Enable (Port 0x92)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; 2. LBA Read Kernel (Optimized: Single Block Read)
    ; Check Extensions
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc error

    ; Read Disk
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jc error

    ; 3. Setup VBE (Graphics)
    mov ax, 0x4F00
    mov di, 0x9000
    int 0x10
    
    mov ax, 0x4F02
    mov bx, 0x4118 ; 1024x768x24 Linear
    int 0x10
    
    mov ax, 0x4F01
    mov cx, 0x118
    mov di, 0x8000
    int 0x10

    ; 4. Memory Map (E820)
    mov di, 0x8104
    xor ebx, ebx
    xor bp, bp
    mov edx, 0x534D4150
    mov eax, 0xE820
    mov ecx, 24
    int 0x15
    jc .pm_entry
.mem_loop:
    inc bp
    add di, 24
    test ebx, ebx
    jz .mem_done
    mov eax, 0xE820
    mov ecx, 24
    mov edx, 0x534D4150
    int 0x15
    jmp .mem_loop
.mem_done:
    mov [0x8100], bp

.pm_entry:
    ; 5. Enter Protected Mode
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pm_start

error:
    mov ah, 0x0e
    mov al, '!' ; Print '!' if error
    int 0x10
    cli
    hlt

; --- Data ---
boot_drive db 0
align 4
dap: 
    db 0x10, 0
    dw SECTORS_TO_READ
    dw 0x0000, KERNEL_SEG
    dd 1, 0  ; LBA Low, LBA High

; --- 32-bit Protected Mode ---
bits 32
pm_start:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Copy Kernel from 0x10000 to 1MB
    mov esi, 0x10000
    mov edi, 0x100000
    mov ecx, (SECTORS_TO_READ * 512) / 4
    rep movsd
    
    mov ebx, 0x8000 ; Pass Boot Params
    jmp 0x100000    ; Jump to Kernel

gdt_start: 
    dd 0, 0
    dw 0xFFFF, 0, 0x9A, 0xCF, 0
    dw 0xFFFF, 0, 0x92, 0xCF, 0
gdt_descriptor: 
    dw gdt_start - 1
    dd gdt_start

times 510-($-$$) db 0
dw 0xAA55