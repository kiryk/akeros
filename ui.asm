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
