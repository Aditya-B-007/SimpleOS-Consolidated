# --- Toolchain Configuration ---
# You must use a cross-compiler targeting generic ELF.
# MinGW (i686-w64-mingw32) targets Windows PE and cannot produce kernel ELF binaries.
TOOLCHAIN_PREFIX = i686-elf-

CC      = $(TOOLCHAIN_PREFIX)gcc
LD      = $(TOOLCHAIN_PREFIX)gcc
NASM    = nasm
OBJCOPY = $(TOOLCHAIN_PREFIX)objcopy
MKISOFS = mkisofs
DD      = dd
CAT     = cat

# --- Flags ---
CFLAGS = -m32 -ffreestanding -O2 -Wall -Wextra -I. -std=gnu99

# -f elf32 is required for ELF linking. -f win32 produces COFF which is incompatible here.
NASMFLAGS = -f elf32

# -T linker.ld tells the linker where to place code/data.
# -nostdlib is crucial for kernel development.
# -lgcc provides some compiler helper functions that your code might implicitly use.
LDFLAGS = -T linker.ld -ffreestanding -O2 -nostdlib -lgcc

# --- Source Files ---
# Since you have a consolidated project, we list the files explicitly.
C_SOURCES   = kernel.c
ASM_SOURCES = kernel_entry.asm interrupt.asm
BOOT_SOURCE = boot.asm

# --- Object Files ---
OBJ_FILES = $(C_SOURCES:.c=.o) $(ASM_SOURCES:.asm=.o)

# --- Main Target ---
all: simpleos.iso disk.img

# --- Build Rules ---

# 1. Create the final ISO from a bootable floppy image.
simpleos.iso: disk.img
	@echo "Creating ISO image..."
	@mkdir -p iso_root
	@cp disk.img iso_root/
	@$(MKISOFS) -quiet -o simpleos.iso -b disk.img iso_root/
	@echo "Build Complete: simpleos.iso is ready for VirtualBox."

# 2. Create a 32MB Hard Disk image.
disk.img: os-image.bin
	@echo "Creating 32MB disk image..."
	@$(DD) if=/dev/zero of=disk.img bs=1M count=32 >/dev/null 2>&1
	@$(DD) if=os-image.bin of=disk.img conv=notrunc >/dev/null 2>&1

# 3. Concatenate the bootloader and kernel to create a raw bootable image.
os-image.bin: boot.bin kernel.bin
	@echo "Concatenating bootloader and kernel..."
	@$(CAT) boot.bin kernel.bin > os-image.bin

# 4. Create the flat binary kernel from the ELF file.
kernel.bin: kernel.elf
	@echo "Extracting kernel binary..."
	@$(OBJCOPY) -O binary kernel.elf kernel.bin

# 5. Link all kernel object files into an ELF file.
kernel.elf: $(OBJ_FILES) linker.ld
	@echo "Linking kernel..."
	@$(LD) $(LDFLAGS) -o kernel.elf $(OBJ_FILES)

# 6. Assemble the 16-bit bootloader.
boot.bin: $(BOOT_SOURCE)
	@echo "Assembling bootloader..."
	@$(NASM) -f bin $(BOOT_SOURCE) -o boot.bin

# --- Generic Compilation Rules ---
%.o: %.c kernel.h
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.asm
	$(NASM) $(NASMFLAGS) $< -o $@

# --- Housekeeping ---
clean:
	@echo "Cleaning up build files..."
	@rm -rf *.o *.bin *.elf os-image.bin floppy.img simpleos.iso iso_root

.PHONY: all clean
