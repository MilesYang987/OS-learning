BUILD:=build
SRC:=.
C_SOURCES = $(wildcard kernel/*.c drivers/*.c)
HEADERS = $(wildcard kernel/*.h drivers/*.h)

OBJ = ${C_SOURCES:.c=.o}

INCLUDE = -i boot

CC = gcc
GDB = gdb

CFLAGS = -g

ENTRYPOINT:=0x10000

.PHONY: run build test clean

os-image.bin: $(BUILD)/boot.bin $(BUILD)/loader.bin \
	$(BUILD)/system.bin $(BUILD)/system.map
	dd if=/dev/zero of=$@ bs=512 count=500
	dd if=$(BUILD)/boot.bin of=$@ bs=512 count=1 conv=notrunc
	dd if=$(BUILD)/loader.bin of=$@ bs=512 seek=1 count=4 conv=notrunc
	dd if=$(BUILD)/system.bin of=$@ bs=512 seek=10 count=200 conv=notrunc


run: os-image.bin
	qemu-system-i386 \
	-drive format=raw,media=disk,file=$< \
	-vga std

build: os-image.bin

debug: os-image.bin $(BUILD)/boot.elf
	qemu-system-i386 \
	-drive format=raw,media=disk,file=$< \
	-vga std &
	${GDB} -ex "target remote localhost:1234" -ex "symbol-file $(BUILD)/boot.elf"


%.o: %.c ${HEADERS}
	${CC} ${CFLAGS} -ffreestanding -c $< -o $@ -fno-pic -m32

$(BUILD)/kernel/%.o: $(SRC)/kernel/%.asm
	$(shell mkdir -p $(dir $@))
	nasm -f elf32 $< -o $@ ${INCLUDE}

$(BUILD)/kernel.bin: $(BUILD)/kernel/start.o
	ld -m elf_i386 -static $^ -o $@ -Ttext $(ENTRYPOINT)

$(BUILD)/%.bin: boot/%.asm
	$(shell mkdir -p $(dir $@))
	nasm $< -f bin -o $@ ${INCLUDE}

$(BUILD)/system.bin: $(BUILD)/kernel.bin
	objcopy -O binary $^ $@

$(BUILD)/system.map: $(BUILD)/kernel.bin
	nm $^ | sort > $@

test: os-image.bin

clean:
	rm -rf $(BUILD) *.bin
