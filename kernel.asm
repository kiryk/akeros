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

readcmd:
	mov si, os_prompt
	call write_string

	mov di, os_input
	call read_string

	mov si, di
	call string_parse
	mov ax, si

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

	mov si, os_cmd_unknown
	call write_string

	jmp short readcmd

cmd_ls:
	call fs_read_root

	mov si, buffer
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

	mov al, `\n`
	call write_char
.skip:
	mov si, di
	call fs_next_file

	loop .loop
	jmp short readcmd

	.filename times 13 db 0


cmd_type:
	call string_parse
	jc short .no_argument_error
	mov si, di

	call fs_open_file
	jc short .no_file_error

	mov di, buffer
	mov si, buffer
.loop:
	mov cx, 128
	call fs_read
	jc short .last

	call write_limited_string

	jmp short .loop

.last:
	call write_limited_string

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


cmd_test:
	mov di, .tag
	call fs_tag_to_filename

	mov si, di
	call write_string

	mov al, `\n`
	call write_char

	jmp readcmd

	.tag times 15 db 0


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

	os_cmd_unknown db `unknown command\n`, 0
	os_cmd_ls      db "ls", 0
	os_cmd_type    db "type", 0
	os_cmd_test    db "test", 0

	fat_buffer_uptodate db 0

%INCLUDE "fs.asm"
%INCLUDE "string.asm"

; memory management and kernel buffer
; (must be included as last)
; INCLUDE "mem.asm"

fat_buffer:
buffer equ fat_buffer+4608 ; 9*512 (size of FAT in the buffer)