Aleksander Kiryk, 2021

# Requirements

The build.bat script uses:
- NASM to compile the sources,
- ImDisk to binaries on a floppy image.

The test.bat script uses:
- QEMU (`qemu-system-i386`) as an emulator for the OS.

# The shell

The shell supports following commands:
- `[filename]`:      run program `[filename].prg`
- `type [filename]`: prints filename contents,
- `rm [filename]`:   remove file,
- `mk [filename]`:   create an empty file,
- `ls`:              list files on the disk.
