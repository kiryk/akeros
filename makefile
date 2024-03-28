IMAGE ?= akeros.img

SYSTEM = \
	bootloader.sys\
	kernel.sys

PROGRAMS = \
	calc.prg

build: $(IMAGE) $(SYSTEM) $(PRORGAMS)

install: $(IMAGE)
	$(eval DIR := $(shell mktemp -d))
	mount -o loop $< $(DIR)
	sleep 0.5
	cp kernel.sys $(DIR)/
	cp README.md $(DIR)/
	cp $(PROGRAMS) $(DIR)/
	umount $(DIR)
	rm -r $(DIR)

.PHONY: test
test:
	qemu-system-i386 -drive format=raw,file=$(IMAGE),index=0,if=floppy

.PHONY: clean
clean:
	rm $(IMAGE) $(SYSTEM) $(PROGRAMS)

$(IMAGE): $(SYSTEM) $(PROGRAMS)
	dd if=/dev/zero bs=512 count=2880 > $(IMAGE)
	dd if=bootloader.sys of=$(IMAGE) conv=notrunc

%.sys:
	nasm -O0 -f bin -o $@ $(@:sys=asm)

%.prg:
	nasm -O0 -f bin -o $@ $(@:prg=asm)
