[bits 32]
extern kernel_main

global _start

section .text
_start:
    ; 1. Save Boot Info Pointer (EBX)
    mov esp, 0x90000 ; Ensure stack is valid
    push ebx         ; Save pointer for later

    ; 2. Clear Page Tables Area (0x1000 - 0x4000)
    ; We use low memory that is no longer needed by the bootloader
    cld
    mov edi, 0x1000
    xor eax, eax
    mov ecx, 1024 * 3
    rep stosd

    ; 3. Setup Identity Paging (First 2MB)
    ; PML4T @ 0x1000 -> PDPT @ 0x2000
    mov eax, 0x2003      ; Present | RW
    mov [0x1000], eax

    ; PDPT @ 0x2000 -> PDT @ 0x3000
    mov eax, 0x3003      ; Present | RW
    mov [0x2000], eax

    ; PDT @ 0x3000 -> 2MB Page (Identity mapped 0-2MB)
    mov eax, 0x83        ; Present | RW | Huge Page (2MB)
    mov [0x3000], eax

    ; 4. Enable PAE (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; 5. Switch to Long Mode (Set LME bit in EFER MSR)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; 6. Enable Paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; 7. Load 64-bit GDT
    lgdt [gdt64_descriptor]

    ; 8. Jump to 64-bit Code Segment
    jmp 0x08:long_mode_start

[bits 64]
long_mode_start:
    ; Clear Segment Registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Restore Boot Params to RDI (First Argument in 64-bit ABI)
    ; We pushed EBX in 32-bit mode at 0x90000-4
    mov edi, [0x90000 - 4]

    call kernel_main
    
    cli
    hlt

section .data
align 8
gdt64_start:
    dq 0x0000000000000000 ; Null Descriptor
    dq 0x0020980000000000 ; Code: Exec/Read, 64-bit, Present, Ring 0
    dq 0x0000920000000000 ; Data: Read/Write, Present, Ring 0
gdt64_end:
gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start