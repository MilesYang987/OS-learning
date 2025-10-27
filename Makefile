C_SOURCES = $(wildcard kernel/*.c drivers/*.c)
HEADERS = $(wildcard kernel/*.h drivers/*.h)

OBJ = ${C_SOURCES:.c=.o}

INCLUDE = -i boot

CC = gcc
GDB = gdb

CFLAGS = -g


os-image.bin: make/boot.bin make/loader.bin
	dd if=/dev/zero of=$@ bs=512 count=10
	dd if=make/boot.bin of=$@ bs=512 conv=notrunc count=1
	dd if=make/loader.bin of=$@ bs=512 seek=1 count=4 conv=notrunc


.PHONY: run
run: os-image.bin
	qemu-system-i386 \
	-drive format=raw,media=disk,file=$< \
	-vga std

.PHONY: build
build: os-image.bin

debug: os-image.bin make/boot.elf
	qemu-system-i386 \
	-drive format=raw,media=disk,file=$< \
	-vga std &
	${GDB} -ex "target remote localhost:1234" -ex "symbol-file make/boot.elf"

# Generic rules for wildcards
# To make an object, always compile from its .c
%.o: %.c ${HEADERS}
	${CC} ${CFLAGS} -ffreestanding -c $< -o $@ -fno-pic -m32

make/%.elf: boot/%.asm
	nasm $< -f elf -o $@ ${INCLUDE}

make/%.bin: boot/%.asm
	nasm $< -f bin -o $@ ${INCLUDE}

.PHONY: clean
clean:
	rm -rf make/*.bin *.o os-image.bin *.elf
	rm -rf kernel/*.o drivers/*.o boot/*.o
