ui_write_char:
; IN:  al: output char
; OUT: the ASCII character in al is printed on the screen

	push ax

	mov ah, 0Eh                 ; BIOS putchar routine number

	cmp al, `\n`                ; Is the character a newline?
	je short .newline           ; If so, start a new line

	int 10h                     ; Otherwise just draw the character
	jmp short .return
.newline:
	mov al, `\r`
	int 10h                     ; Move cursor to the beginning of the line

	mov al, `\n`
	int 10h                     ; Move cursor down
.return:
	pop ax
	ret


ui_write_newline:
; IN: N/A
; OUT: a newline is printed on the screen


	push ax

	mov al, `\n`
	call ui_write_char          ; Print the newline using ui_write_char

	pop ax
	ret


ui_write_lim_string:
; IN:  si: output string
; IN:  cx: output string length
; OUT: the first cx characters of si are printed on the screen
;
; Note that there is no end of string check except the limit in cx

	push si
	push ax
	push cx

.loop:
	cmp cx, 0                   ; Are there no more chars to be printed?
	je short .return            ; If so, return

	lodsb                       ; Move [si] to al, then increment si
	call ui_write_char          ; Print the character in al

	dec cx                      ; Decrement cx, since a character was printed
	jmp short .loop
.return:
	pop cx
	pop ax
	pop si
	ret


ui_write_string:
; IN:  si: output string
; OUT: the NUL terminated string in si is printed on the screen

	push ax
	push si

.loop:
	lodsb                       ; Move [si] to al, then increment si
	cmp al, 0                   ; Is is NUL?
	je short .return            ; If so, return

	call ui_write_char          ; Otherwise print the character
	jmp short .loop             ; Proceed to printing the next one
.return:
	pop si
	pop ax
	ret


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


ui_read_char:
; IN:  N/A
; OUT: al: ASCII charater code
; OUT: ah: scan code

	mov ah, 10h
	int 16h

	ret


ui_read_string:
; IN:  di: input buffer pointer
; OUT: modified buffer

	push ax
	push bx
	push di

	mov bx, di                  ; Save di in bx for later
.loop:
	mov ah, 00h                 ; Use a bios interrupt to get a char
	int 16h

	cmp al, `\b`                ; If it's a backspace, draw it
	je short .backspace

	cmp al, `\r`                ; If it's an enter, stop reading
	je short .return

	call ui_write_char          ; Show the character on the screen

	stosb                       ; Store the character in the buffer
	jmp short .loop

.backspace:
	cmp bx, di                  ; Is the buffer empty?
	je short .loop              ; If so, don't draw the backspace

	mov al, `\b`                ; Move the cursor back
	call ui_write_char

	mov al, ` `                 ; Draw a blank space to hide the old char
	call ui_write_char

	mov al, `\b`                ; Move the cursor back again
	call ui_write_char

	dec di                      ; Decrement the buffer pointer
	jmp short .loop             ; Continue reading characters

.return:
	mov byte [di], 0            ; NUL terminate the character

	call ui_write_newline       ; Go to a new line

	pop di
	pop bx
	pop ax

	ret


ui_hide_cursor:
; IN:  N/A
; OUT: the cursor is invisible

	push ax
	push cx

	mov ah, 1                   ; Cursor shape routine number
	mov ch, 32                  ; Cursor hidden
	int 10h

	pop cx
	pop ax

	ret


ui_set_std_cursor:
; IN:  N/A
; OUT: the cursor is in the standard underscore form

	push ax
	push cx

	mov ah, 1                   ; Cursor shape routine number
	mov ch, 6                   ; The cursor starts at the height of 6th pixel
	mov cl, 7                   ; And ends at 7th
	int 10h

	pop cx
	pop ax

	ret


ui_set_box_cursor:
; IN: N/A
; OUT: the cursor is in the box-shaped form

	push ax
	push cx

	mov ah, 1                   ; Cursor shape routine number
	mov ch, 0                   ; The cursor starts at the height of zero pixels
	mov cl, 7                   ; And ends at 7th
	int 10h

	pop cx
	pop ax

	ret


ui_move_cursor:
; IN:  al: column
; IN:  ah: row
; OUT: the cursor is on the al,ah position in the screen
;
; Note that the top-left corner of the screen is (al=0, ah=0).

	push ax
	push bx
	push dx

	mov dl, al                  ; Take the required col from al
	mov dh, ah                  ; Take the required row from ah
	mov bh, 0                   ; Set screen page number to 0 (current)
	mov ah, 2                   ; Set BIOS routine number to 2 (move cursor)
	int 10h

	pop dx
	pop bx
	pop ax

	ret


ui_find_cursor:
; IN:  N/A
; OUT: al: column
; OUT: ah: row

	push bx
	push cx
	push dx

	mov ah, 03h
	mov bh, 0
	int 0h

	mov ax, dx

	pop dx
	pop cx
	pop bx
	ret


ui_clear_screen:
; IN:  N/A
; OUT: the screen is cleared

	pusha

	mov ah, 07h                 ; Scroll down routine number
	mov al, 0                   ; al = 0 clears entire window
	mov ch, 0                   ; Row of window's upper right corner
	mov cl, 0                   ; Column of window's upper right corner
	mov dh, 24                  ; Row of window's lower right corner
	mov dl, 79                  ; Column of window's lower right corner
	mov bh, 07h                 ; The text color will be light gray
	mov bl, 00h                 ; The background color will be black
	int 10h

	mov al, 0                   ; Move cursor to the beginning of the screen
	mov ah, 0
	call ui_move_cursor

	popa

	ret
