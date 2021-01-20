bits 16
org 5000h

%include "user.inc"

main:
	call string_parse
	jc short end

	xchg si, di
	call ui_write_string

	xchg si, di

	mov al, ` `
	call ui_write_char

	jmp short main

end:
	call ui_write_newline

	ret
