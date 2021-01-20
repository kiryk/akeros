org 5000h

%include "user.inc"

main:
	mov si, .string
	call ui_write_string

	ret

	.string db `hello, world\n`, 0
