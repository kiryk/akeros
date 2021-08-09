#!/bin/sh

nasm -O0 -f bin -o bootloader.sys bootloader.asm
nasm -O0 -f bin -o kernel.sys kernel.asm
nasm -O0 -f bin -o calc.prg calc.asm

rm dev.img
dd if=/dev/zero bs=512 count=2880 > dev.img
dd if=bootloader.sys of=dev.img conv=notrunc

mkdir akeros
mount -o loop dev.img akeros
sleep 0.5

cp kernel.sys akeros/
cp README.md akeros/
cp *.prg akeros/
sleep 0.5

umount akeros
rm -r akeros

