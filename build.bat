nasm -O0 -f bin -o bootloader.sys bootloader.asm
nasm -O0 -f bin -o kernel.sys kernel.asm
nasm -O0 -f bin -o calc.prg calc.asm

del dev.img
copy bootloader.sys dev.img

rem 1474560B = 1440K
fsutil file seteof dev.img 1474560

imdisk -a -f dev.img -s 1440K -m B:
copy kernel.sys B:\
copy calc.prg B:\
copy readme.md B:\
imdisk -D -m B:
