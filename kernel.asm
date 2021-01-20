	bits 16

	jmp os_start

	jmp fs_open_read            ; 3
	jmp fs_open_write           ; 6
	jmp fs_read                 ; 9
	jmp fs_write                ; 12
	jmp fs_close                ; 15
	jmp fs_create_file          ; 18
	jmp fs_remove_file          ; 21
	jmp fs_find_file            ; 24
	jmp string_compare          ; 27
	jmp string_copy
	jmp string_parse            ; 30
	jmp string_to_int           ; 33
	jmp string_int_to           ; 36
	jmp string_find_char        ; 39
	jmp string_length           ; 42
	jmp string_reverse          ; 45
	jmp string_char_isbetween   ; 48
	jmp string_char_iswhite     ; 51
	jmp string_char_isdigit     ; 54
	jmp string_char_isalpha     ; 57
	jmp string_char_islower     ; 60
	jmp string_char_isupper     ; 63
	jmp ui_write_char           ; 66
	jmp ui_write_newline        ; 69
	jmp ui_write_lim_string     ; 72
	jmp ui_write_string         ; 75
	jmp ui_write_int            ; 78
	jmp ui_read_string          ; 81

os_start:
; IN: al: device number from bootloader

	cld

	cli
	mov bx, 1000h
	mov ss, bx
	mov sp, 0FFFFh
	sti

	mov bx, 2000h
	mov ds, bx
	mov es, bx
	mov fs, bx
	mov gs, bx

	mov [fs_device], al

init:
	call fs_read_fat
	call fs_read_root

welcome:
	mov si, os_kernel_size
	call ui_write_string

	mov ax, kernel_end
	mov di, os_output
	call string_int_to

	mov si, di
	call ui_write_string

	mov al, `\n`
	call ui_write_char

	mov si, os_memory_size
	call ui_write_string

	int 12h
	mov di, os_output
	call string_int_to

	mov si, di
	call ui_write_string

	mov al, `\n`
	call ui_write_char
readcmd:
	mov si, os_prompt
	call ui_write_string

	mov di, os_input
	call ui_read_string

	mov si, di
	call string_parse
	mov ax, si

	mov si, os_cmd_none
	call string_compare
	mov si, ax
	je readcmd

	mov si, os_cmd_ls
	call string_compare
	mov si, ax
	je cmd_ls

	mov si, os_cmd_type
	call string_compare
	mov si, ax
	je cmd_type

	mov si, os_cmd_test
	call string_compare
	mov si, ax
	je cmd_test

	mov si, os_cmd_mk
	call string_compare
	mov si, ax
	je cmd_mk

	mov si, os_cmd_rm
	call string_compare
	mov si, ax
	je cmd_rm

	mov si, di
	jmp cmd_run

	mov si, os_cmd_unknown
	call ui_write_string

	jmp short readcmd


cmd_ls:
	call fs_read_root

	mov si, root_buffer
	mov cx, MaxRootEntries
.loop:
	cmp byte [si], 000h
	je short readcmd
	cmp byte [si], 0E5h
	je short .skip

	mov di, .filename
	call fs_tag_to_filename

	xchg si, di
	call ui_write_string
	xchg si, di

	mov al, `\n`
	call ui_write_char
.skip:
	call fs_next_file

	loop .loop
	jmp readcmd

	.filename times 13 db 0


cmd_run:
	mov di, .filename
	call string_copy

	call string_length
	add di, ax

	mov si, .ext
	call string_copy

	mov si, .filename
	call fs_find_file
	jc .no_file_error

	mov bx, 5000h
	call fs_read_file

	call 5000h

	jmp readcmd

.no_file_error:
	call ui_write_string

	mov si, .no_file
	call ui_write_string

	jmp readcmd

	.no_file     db `: program not found\n`, 0
	.ext         db `.prg`, 0
	.filename    times 15 db 0


cmd_type:
	call string_parse
	jc .no_argument_error
	mov si, di

	call fs_open_read
	jc short .no_file_error

	mov di, .buffer
	mov si, .buffer
.loop:
	mov cx, 32
	call fs_read
	jc short .last

	call ui_write_lim_string

	jmp short .loop

.last:
	call ui_write_lim_string

	call fs_close

	jmp readcmd

.no_file_error:
	mov si, .no_file
	call ui_write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call ui_write_string

	jmp readcmd

	.no_file     db `type: file not found\n`, 0
	.no_argument db `type: usage: type filename\n`, 0
	.buffer      times 32 db 0


cmd_mk:
	call string_parse
	jc .no_argument_error
	mov si, di

	call fs_create_file
	jc short .cant_make_error

	jmp readcmd

.cant_make_error:
	mov si, .cant_make
	call ui_write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call ui_write_string

	jmp readcmd

	.cant_make   db `mk: could not create\n`, 0
	.no_argument db `mk: usage: mk filename\n`, 0


cmd_rm:
	call string_parse
	jc .no_argument_error
	mov si, di

	call fs_remove_file
	jc short .cant_remove_error

	jmp readcmd

.cant_remove_error:
	mov si, .cant_remove
	call ui_write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call ui_write_string

	jmp readcmd

	.cant_remove db `mk: could not remove\n`, 0
	.no_argument db `mk: usage: mk filename\n`, 0


cmd_test:
	call string_parse
	jc .no_argument_error

	mov si, .filename
	call fs_open_write

	mov cx, ax

	mov si, di
	call string_length
	xchg cx, ax

	call fs_write
	call fs_close

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call ui_write_string

	jmp readcmd

	.no_argument db `test: usage: test filename\n`, 0
	.filename    db `test.log`, 0


os_fatal_error:
	mov si, .error
	call ui_write_string
	jmp $

	.error db `kernel fatal error, halting.\n`, 0


; variables
	os_newline db 10, 0
	os_prompt  db "% ", 0
	os_input   times 30 db 0
	os_output  times 80 db 0

	os_memory  dw 0

	os_cmd_unknown db `unknown command\n`, 0
	os_cmd_none    db "", 0
	os_cmd_run     db "run", 0
	os_cmd_ls      db "ls", 0
	os_cmd_type    db "type", 0
	os_cmd_test    db "test", 0
	os_cmd_mk      db "mk", 0
	os_cmd_rm      db "rm", 0

	os_kernel_size db `Kernel size:  `, 0
	os_memory_size db `KB of memory: `, 0


%INCLUDE "fs.asm"
%INCLUDE "string.asm"
%INCLUDE "ui.asm"

; memory management and kernel buffer
; (must be included as last)
; INCLUDE "mem.asm"

fat_buffer:
root_buffer equ fat_buffer+9*512 ; (size of FAT in the buffer)
kernel_end  equ root_buffer+14*512
