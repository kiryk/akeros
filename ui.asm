ui_write_char:
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


ui_write_newline:
; IN: N/A

	push ax

	mov al, `\n`
	call ui_write_char

	pop ax
	ret


ui_write_lim_string:
; IN: si: output string
; IN: cx: output string length

	push si
	push ax
	push cx

.loop:
	cmp cx, 0
	je short .return

	lodsb
	call ui_write_char

	dec cx
	jmp short .loop
.return:
	pop cx
	pop ax
	pop si
	ret


ui_write_string:
; IN: si: output string

	push ax
	push si

.loop:
	lodsb
	cmp al, 0
	je short .return
	call ui_write_char
	jmp short .loop
.return:
	pop si
	pop ax
	ret


ui_write_int:
	; IN: ax: output integer

	.size   equ 7
	.string equ 0

	push ax
	push si
	push di
	push bp
	sub sp, .size
	mov bp, sp

	mov di, bp
	call string_int_to

	mov si, bp
	call ui_write_string
.return:
	add sp, .size
	pop bp
	pop di
	pop si
	pop ax
	ret


ui_read_string:
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

	call ui_write_char

	stosb
	jmp short .loop

.backspace:
	cmp bx, di
	je short .loop

	mov al, `\b`
	call ui_write_char
	mov al, ` `
	call ui_write_char
	mov al, `\b`
	call ui_write_char

	dec di
	jmp short .loop

.return:
	mov byte [di], 0

	mov al, 10
	call ui_write_char

	pop di
	pop bx
	pop ax

	ret


ui_hide_cursor:
; IN:  N/A
; OUT: the cursor is invisible

	push ax
	push bx

	mov ah, 1
	mov ch, 32
	int 10h

	pop bx
	pop ax

	ret


ui_set_std_cursor:
; IN:  N/A
; OUT: the cursor is in the standard underscore form

	push ax
	push bx

	mov ah, 1
	mov ch, 6
	mov cl, 7
	int 10h

	pop bx
	pop ax

	ret


ui_set_box_cursor:
; IN: N/A
; OUT: the cursor is in the box-shaped form

	push ax
	push bx

	mov ah, 1
	mov ch, 0
	mov cl, 7
	int 10h

	pop bx
	pop ax

	ret


ui_move_cursor:
; IN:  al: column
; IN:  ah: row
; OUT: the cursos is on the al,ah position in the screen
;
; Note that the top-left corner of the screen is (al=0, ah=0).

	push ax
	push bx
	push dx

	mov dl, al
	mov dh, ah
	mov bh, 0
	mov ah, 2
	int 10h

	pop dx
	pop bx
	pop ax

	ret


ui_clear_screen:
; IN:  N/A
; OUT: the screen is cleared

	pusha

	mov al, 0
	mov ah, 07h
	mov bh, 07h
	mov bl, 00h
	mov ch, 0
	mov cl, 0
	mov dh, 24
	mov dl, 79
	int 10h

	mov al, 0
	mov ah, 0
	call ui_move_cursor

	popa

	ret
