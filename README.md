Aleksander Kiryk, 2021

# Requirements

The build.bat script uses:
- NASM to compile the sources,
- ImDisk to save binaries on a floppy image.

The test.bat script uses:
- QEMU (`qemu-system-i386`) as an emulator for the OS.

# The shell

The shell supports following commands:
- `[name]`:                   run program `[name].prg`
- `type [name]`:              prints file contents,
- `rm [name]`:                remove file,
- `mk [name]`:                create an empty file,
- `mv [old name] [new name]`: rename a file,
- `ls`:                       list files on the disk.
