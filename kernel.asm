	bits 16

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
	call write_string

	mov ax, kernel_end
	mov di, os_output
	call string_int_to

	mov si, di
	call write_string

	mov al, `\n`
	call write_char

	mov si, os_memory_size
	call write_string

	int 12h
	mov di, os_output
	call string_int_to

	mov si, di
	call write_string

	mov al, `\n`
	call write_char
readcmd:
	mov si, os_prompt
	call write_string

	mov di, os_input
	call read_string

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

	mov si, os_cmd_unknown
	call write_string

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
	call write_string
	xchg si, di

	mov al, `\n`
	call write_char
.skip:
	call fs_next_file

	loop .loop
	jmp readcmd

	.filename times 13 db 0


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

	call write_limited_string

	jmp short .loop

.last:
	call write_limited_string

	call fs_close

	jmp readcmd

.no_file_error:
	mov si, .no_file
	call write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call write_string

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
	call write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call write_string

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
	call write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call write_string

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
	call write_string

	jmp readcmd

	.no_argument db `test: usage: test filename\n`, 0
	.filename    db `test.log`, 0

write_char:
	; IN: al: output char

	push ax

	mov ah, 0Eh

	cmp al, 10 ; '\n'
	je short .newline

	int 10h
	jmp short .return
.newline:
	mov al, 13
	int 10h
	mov al, 10
	int 10h
.return:
	pop ax
	ret


write_limited_string:
; IN: si: output string
; IN: cx: output string length

	push si
	push ax
	push cx

.loop:
	cmp cx, 0
	je short .return

	lodsb
	call write_char

	dec cx
	jmp short .loop
.return:

	pop cx
	pop ax
	pop si
	ret


write_string:
; IN: si: output string

	push ax
	push si

.loop:
	lodsb
	cmp al, 0
	je short .return
	call write_char
	jmp short .loop
.return:
	pop si
	pop ax
	ret


read_string:
; IN:  di: input buffer pointer
; OUT: modified buffer

	push ax
	push bx
	push di

	mov bx, di
.loop:
	mov ah, 00h
	int 16h

	cmp al, `\b`
	je short .backspace

	cmp al, `\r`
	je short .return

	call write_char

	stosb
	jmp short .loop

.backspace:
	cmp bx, di
	je short .loop

	mov al, `\b`
	call write_char
	mov al, ` `
	call write_char
	mov al, `\b`
	call write_char

	dec di
	jmp short .loop

.return:
	mov byte [di], 0

	mov al, 10
	call write_char

	pop di
	pop bx
	pop ax

	ret


os_fatal_error:
	mov si, .error
	call write_string
	jmp $

	.error db `kernel fatal error, halting.\n`, 0


; variables
	os_newline db 10, 0
	os_prompt  db "- ", 0
	os_input   times 30 db 0
	os_output  times 80 db 0

	os_memory  dw 0

	os_cmd_unknown db `unknown command\n`, 0
	os_cmd_none    db "", 0
	os_cmd_ls      db "ls", 0
	os_cmd_type    db "type", 0
	os_cmd_test    db "test", 0
	os_cmd_mk      db "mk", 0
	os_cmd_rm      db "rm", 0

	os_kernel_size db `Kernel size:  `, 0
	os_memory_size db `KB of memory: `, 0


%INCLUDE "fs.asm"
%INCLUDE "string.asm"

; memory management and kernel buffer
; (must be included as last)
; INCLUDE "mem.asm"

fat_buffer:
root_buffer equ fat_buffer+9*512 ; (size of FAT in the buffer)
kernel_end  equ root_buffer+14*512