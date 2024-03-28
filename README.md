Aleksander Kiryk, 2021


# Description

Akeros stands for _an assembly kernel & other software_. It's a project aiming to create a toy operating system featuring the most basic OS functionalities and tools; both for educational purposes and fun.

So far the kernel uses a flat FAT12 file system and has a built-in command interpreter. The project still lacks a text editor and some simple language interpreter. There are some plans for the kernel to eventually support cooperative multitasking.


# Usage

## Compilation and running

To create a disk image:
```
make
sudo make install
```

To run it:
```
make test
```

The `nasm` compiler is required for installation and `qemu-system-i386` for testing.

`make install` requires root permission level to mount the disk image and copy OS files onto it.

## Using the shell

The shell supports following commands:
- `[name]`:                   runs program `[name].prg`,
- `clear`                     clears the screen,
- `cp [name] [copy name]`:    copies a file,
- `ls`:                       lists files on the disk,
- `mk [name]`:                creates an empty file,
- `mv [old name] [new name]`: renames a file,
- `rm [name]`:                removes file,
- `type [name]`:              prints file contents.


# Development

## Project files

 File           | Description
----------------|---------------------
 README.md      | Contains main project information
 build.bat      | Compiles the sources with NASM and produces a raw floppy image
 test.bat       | Runs OS' floppy image with qemu-system-i386
 bootloader.asm | The bootloader's source code
 kernel.asm     | Kernel startup and shell routines
 fs.asm         | Disk, FAT12 and file management routines
 ui.asm         | User interface routines (mainly input and output)
 string.asm     | Most basic string routines
 calc.asm       | A simple calculator, compiled into an external program binary (calc.prg)
 user.inc       | The standard header file for user programs

## Architecture

### Booting routine

After the kernel binary is loaded to the memory, it sets all memory segments to the page number 0x2000, the only exception being the stack and its segment, which occupy lower parts of the memory.

When the above procedure is finished, the kernel initializes all of its 3 main buffers:

* _the FAT buffer_: up to date filesystem information,
* _the root buffer_: up to date root directory entries,
* _the file buffer_: a group of smaller buffers holding information about currently open files.

The first two are loaded from the disk, the latter one is initialized by zeroing.

After that, the kernel clears the screen, displays a welcome message and starts waiting for user commands.

### Memory map

As the kernel uses just one memory segment, it can only use 64kBs of memory, which is further split into two parts:

1. The first 20 480 bytes (0Fh-4FFFh) are reserved and used only by the kernel and its buffers.
2. The other 45 056 bytes (5000h-10000h) are left for external programs.

Every program, when it is run, is loaded at the memory address 5000h, and its internal references are expected to be adjusted to that address.

At this point, the size of the kernel got very close to 20 480 bytes, so the above numbers are expected to change soon.

### Handling system calls

As can be seen in both _user.inc_ and _kernel.asm_ the system services are called with the help of several jump instructions being grouped at the beginning of the kernel code (so they occupy the lowest addresses of the OS' memory).

```
bits 16

jmp os_start              ; Jump over the system call jumps

; System call vector:

	; System call name        ; Index (equals memory address)
	jmp fs_open_read          ; 3*1
	jmp fs_open_write         ; 3*2
	jmp fs_read               ; 3*3
	jmp fs_write              ; 3*4
	jmp fs_close              ; 3*5

...
```

External programs don't know where specific kernel routines are placed, furthermore the position of these routines may change as the kernel is developed. To help this, jump instructions to the most important routines are grouped together at the beginning of the kernel code, the routines can be accessed by calling addresses of these jumps with the regular CALL instruction. The user library (_user.inc_) assigns readable names to these addresses:

```
	fs_open_read          equ 3*1
	fs_open_write         equ 3*2
	fs_read               equ 3*3
	fs_write              equ 3*4
	fs_close              equ 3*5

	...
```

### Working with files

The kernel provides services for creating, renaming and removing files, but its main characteristic is the mechanism behind opening, reading and writing them.

There are two separate system calls for opening file in read and write mode, both return a file descriptor number in UNIX-like manner.

Opening a nonexistent file in write mode creates it, but if the file existed before, its contents _are not_ erased and new data is appended. When such behavior is not desired, the file should be deleted before opening.

Every open file obtains an entry in _the file buffer_, which contains a pointer to its directory entry, information on the mode in which the file is open, and most importantly a 512 bytes big buffer which contents are written to the disk only when the buffer gets full or if the file is open in read mode, the buffer always contains a block of 512 bytes loaded from the file, including the bytes not yet explicitly read by the user.

The user should be aware that if they won't close a file opened in write mode, its buffer contents won't be written on the disk and thus some data may be lost.

## Coding conventions

At the moment this document is written, `ui_write_int` is the most representative kernel routine, i.e. it contains almost all of the most characteristic coding conventions used in the kernel. It is also short, so it will be presented here as an example to be referred to.

```
ui_write_int:
; IN:  ax: output integer
; OUT: the integer in ax is printed on the screen

	.size   equ 7
	.string equ 0

	push ax
	push si
	push di
	push bp
	sub sp, .size
	mov bp, sp                  ; Allocate local variables

	mov di, bp
	call string_int_to          ; Convert ax to a string under bp

	mov si, bp
	call ui_write_string        ; Write the string under bp
.return:
	add sp, .size               ; Dealloc variables
	pop bp
	pop di
	pop si
	pop ax
	ret
```

### Documentation

To document a routine, a comment of the following form is placed after its label:

```
; General description of the job done by the routine.
;
; IN:  assumed circumstances (and arguments)
; IN:  other assumed circumstances for the routine to work correctly
; OUT: side effects
; OUT: other side effects
```

The general description is only required when the behavior can't be easily deduced from side effects of the routine.

Both assumed circumstances and side effect can be omitted in case there are none. Especially the assumptions don't need to be mentioned if they're a part of proper functioning of the OS (like the FAT buffer containing up-to-date information).

Regular comments should be placed between instructions or next to a instruction. In the first case the comments usually describe the stage of the computation at the point in which the comment is left. Such comments are indented at the same level as the code surrounding them.

Comments placed next to instructions describe specific steps, they're placed after 29th character in the line (assuming 2 char wide tabs). They begin with an uppercase letter, unless they're a continuation of a previous comment.

### Routines

Generally all labels are preceded by blank lines, but this rule can be ignored if the programmer wants to make it clear the code under the label can be entered directly (not just by jumps), which is handy in some cases.

If the routine uses branching instructions, the `.return` label is often used to mark the place where variables are deallocated and original registers are restored, but if the routine has a different return procedure on failure, the labels `.error` or `.success` can also be used.

Routines should not change any of the values not mentioned in their side effect, but they're never expected to save any of the flag bits. They quite often set carry flag to communicate an error or a positive effect of a logical test (like in `string_char_isdigit`). The zero flag is often modified by routines testing some structures for equality.

Local variables can only be kept in registers and stack allocated areas. Keeping variable values in a reserved hard-coded space is not accepted, but the exceptions are:

1. Main kernel routine
2. External (especially small) programs

The restriction does not apply if the value is constant, like a version number, or an error message.

To allocate variables on the stack, first calculate an offset of each variable, and declare them as local constants in the routine, just like in the `ui_write_int` routine shown above. You're also expected to add a `.size` constant expressing the total size of all local variables, like here:

```
	.size   equ 7
	.string equ 0
```

To actually allocate the variables, first push on the stack all the registers that require it, then subtract `.size` from the stack pointer (`sp`) and save its value in the base pointer register (`bp`):

```
	sub sp, .size
	mov bp, sp                  ; Allocate local variables
```

To deallocate variables, simply add `.size` to the stack pointer _before_ you pop the original register values. _Beware_ though, as the ADD instruction may affect the carry flag, it means if you want to leave the carry set or unset you have to do it _after_ deallocation.

If you want to use the flag to communicate a success or a failure, both the deallocation and carry modification should be done separately in `.success` and `.error` branches.

### Data structures

Labels and local labels are abused in order to create data structures. They're defined similarly to stack variables in routines, for instance:

```
bintree:
	.size  equ 6

	.value equ 0
	.left  equ 2
	.right equ 4
```

Where `.value`, `.left` and `.right` are field offsets expressed in bytes, and `.size` is a constant describing the size of the whole structure.

Assuming the structure is pointed by the `bx` register, its fields can be accessed in the following manner:

```
	mov bx, [bx+bintree.left]   ; Search in the left child
```

### Writing an external program

Every userspace program should start with the 3 directives shown below, after them the user can feel free to write a regular assembly program using system calls referred by the _user.inc_ file.

```
bits 16
org 5000h

%include "user.inc"
```

Every program should also terminate by a `ret` instruction used in its main routine, like in the full example here:

```
bits 16
org 5000h

%include "user.inc"

main:
	mov si, .string
	call ui_write_string

	ret

	.string db `hello, world\n`, 0
```

To compile a program and add it to a floppy image, please lookup the way it is done with _calc.asm_ in the script _build.bat_.
