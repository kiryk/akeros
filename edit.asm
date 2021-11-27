bits 16
org 5000h

%include "user.inc"

main:
	call load_file
	jc short .error ; ERRINF

	call render_view

.loop:
	call ui_read_char

	cmp ah, escape
	je short .return

	cmp ah, arrow_left
	je short .move_left

	cmp ah, arrow_right
	je short .move_right

.move_left:
	call move_left
	jmp short .loop

.move_right:
	call move_right
	jmp short .loop

.return:
	call ui_clear_screen

	ret

.error:
	mov si, .errmsg
	call ui_write_string

	jmp short .return

	.errmsg db `error\n`, 0


render_view:
	push ax
	push si

	call ui_clear_screen

	mov ax, 0
	mov si, [viewptr]

	dec si
	call get_next_char
	jc short .return

.loop:
	call render_line
	jc short .break

	cmp ah, 23
	je short .break

	inc ah
	jmp short .loop

.break:
	mov ah, 24
	call ui_move_cursor

	mov ax, si
	mov al, ah
	mov ah, 0
	call ui_write_int

	mov al, ','
	call ui_write_char

	mov ax, si
	mov ah, 0
	call ui_write_int

	mov ax, 0
	call ui_move_cursor

.return:
	pop si
	pop ax
	ret


render_line:
; IN:  si: text pointer
; IN:  ah: row
; OUT: si: pointer of the next line,
;          NULL if nonexistent

	push ax
	push cx

	mov al, 0
	call ui_move_cursor

	mov cx, 80

.loop:
	mov al, [si]

	cmp al, `\n`
	je short .gotnext

	cmp cx, 0
	jna short .dontprint

	dec cx
	call ui_write_char

.dontprint:
	call get_next_char
	jnc short .loop

.nonext:
	stc
	jmp short .return

.gotnext:
	call get_next_char

.return:
	pop cx
	pop ax
	ret


scroll_up:
	push ax
	push si

	mov si, [viewptr]

	call get_prev_char
	jc short .return

.loop:
	call get_prev_char
	jc short .beginning

	mov al, [si]
	cmp al, `\n`
	jne short .loop

	call get_next_char
	jmp short .save

.beginning:
	mov si, buffer

.save:
	mov [viewptr], si
	clc

.return:
	pop si
	pop ax
	ret


scroll_down:
	push ax
	push si

	mov si, [viewptr]

.loop:
	mov al, [si]
	cmp al, `\n`
	je short .break

	call get_next_char
	jc short .return

	jmp short .loop

.break:
	call get_next_char
	jc short .return

	jmp short .save

.ending:
	mov si, buffer

.save:
	mov [viewptr], si
	clc

.return:
	pop si
	pop ax
	ret


move_right:
	push si
	push ax

	call ui_find_cursor

	mov si, [viewptr]

	call get_next_char
	jc short .return

	cmp al, 79
	je short .find_newline

	cmp byte [si], `\n`
	je short .newline

.find_newline:
	call to_head
	call get_next_char

	cmp byte [si], `\n`
	jne short .find_newline

.newline:
	cmp ah, 23
	je

	mov al, 0


	call ui_move_cursor

.scroll_down:

	call render_view

.return:
	pop ax
	pop si
	ret


; move_left


get_next_line:
; IN:  si: position
; OUT: si: start of the next line
.loop:
	cmp byte [si], `\n`
	je short .break

	call get_next_char
	jc short .return

  jmp short .loop

.break:
	clc
	inc si

.return:
	ret


get_prev_line:
; IN:  si: position
; OUT: si: start of the prev line if si points
;          to a start of the current line
;          or start of the current line otherwise
	call get_prev_char
	jc short .return

.loop:
	call get_prev_char
	jc short .return

	cmp byte [si], `\n`
	je short .break

	jmp short .loop

.break:
	clc
	inc si

.return:
	ret


get_next_char:
	cmp si, 0xffff
	je short .nonext

	cmp si, [headptr]
	je short .skip

	inc si
	cmp si, [headptr]
	jne short .found

.skip:
	mov si, [tailptr]
	cmp si, 0xffff
	je short .nonext

	inc si

	jmp short .found

.nonext:
	stc
	jmp short .return

.found:
	clc

.return:
	ret


get_prev_char:
	cmp si, buffer
	jna short .noprev

	cmp si, [tailptr]
	je short .skip

	dec si
	cmp si, [tailptr]
	jne short .found

.skip
	mov si, [headptr]
	cmp si, buffer
	je short .noprev

	dec si

	jmp short .found

.noprev:
	stc
	jmp short .return

.found:
	clc

.return:
	ret


move_gap_to_point:
; IN: si: the new headptr
	push cx
	push si
	push di

	cmp si, buffer
	jnae short .error

	cmp si, 0xffff
	ja short .error

	cmp si, word [headptr]
	jna short .move_left

	cmp si, word [tailptr]
	jae short .move right

.move_left:
	mov cx, [headptr]
	sub cx, si

	sub word [headptr], cx
	sub word [tailptr], cx

	mov di, [tailptr]
	inc di

	rep movsb

	clc
	jmp short .return

.move_right:
	mov cx, si
	sub cx, [tailptr]

	mov di, [headptr]
	mov si, [tailptr]
	inc si

	add word [headptr], cx
	add word [tailptr], cx

	rep movsb

	clc
	jmp short .return

.error:
	stc

.return:
	pop di
	pop si
	pop cx
	ret


move_gap_right:
	push ax

	cmp word [tailptr], 0xffff
	je short .error

	inc word [tailptr]

	mov al, [tailptr]
	mov [headptr], al

	inc word [headptr]

	clc
	jmp short .return

.error:
	stc

.return:
	pop ax
	ret


move_gap_left:
	push ax

	cmp word [headptr], buffer
	je short .error

  dec word [headptr]

	mov al, [headptr]
	mov [tailptr], al

	dec word [tailptr]

	clc
	jmp short .return

.error:
	stc

.return:
	pop ax
	ret


load_file:
; IN: si: filename

	push ax
	push cx
	push si
	push di

	call fs_open_read
	jc short .error

	mov di, buffer
	mov cx, buffer_size
	call fs_read
	call fs_close

	mov di, 0xffff
	sub di, cx

	mov word [viewptr], buffer
	mov word [headptr], buffer
	mov word [tailptr], di

	inc di
	mov si, buffer
	rep movsb

	jmp short .success

.error:
	stc
	jmp short .return

.success:
	clc

.return:
	pop di
	pop si
	pop cx
	pop ax
	ret


	buffer_size  equ 0xffff - buffer + 1

	arrow_ascii  equ 224
	arrow_left   equ 75
	arrow_right  equ 77
	arrow_up     equ 72
	arrow_down   equ 80

	escape_ascii equ 27
	escape       equ 1


;	filename times 15 db 0

	headptr  dw buffer
	tailptr  dw 0xffff

	viewptr  dw buffer

buffer:
