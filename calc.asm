bits 16
org 5000h

%include "user.inc"

	Number equ 'n'
	Error  equ 'e'

main:
	mov si, hello_msg
	call ui_write_string

.repl:
	mov si, prompt
	call ui_write_string

	mov di, buffer
	call ui_read_string

	mov si, exit_cmd
	call string_compare
	je short .return

	mov si, help_cmd
	call string_compare
	je short .help

	mov word [lexer_pos], buffer
	call next_token

	call calc_sum
	jc short .repl

	mov ax, bx
	call ui_write_int
	call ui_write_newline

	jmp short .repl

.help:
	mov si, help_msg
	call ui_write_string

	jmp short .repl

.return:
	ret


calc_sum:
	push ax
	push cx

	call calc_prod
	jc short .return

	mov ax, bx

.loop:
.try_add:
	mov cl, '+'
	call accept_token
	jc short .try_sub

	call calc_prod
	jc short .error

	add ax, bx
	jmp short .done

.try_sub:
	mov cl, '-'
	call accept_token
	jc short .success

	call calc_prod
	jc short .error

	sub ax, bx
	jmp short .done

.done:
	jmp short .loop

.success:
	mov bx, ax
	clc
	jmp short .return

.error:
	stc

.return:
	pop cx
	pop ax
	ret


calc_prod:
	push ax
	push cx
	push dx

	call calc_subexp
	jc short .return

	mov ax, bx

.loop:
.try_mul:
	mov cl, '*'
	call accept_token
	jc short .try_div

	call calc_subexp
	jc short .error

	mov dx, 0
	imul bx
	jmp short .done

.try_div:
	mov cl, '/'
	call accept_token
	jc short .try_mod

	call calc_subexp
	jc short .error

	mov dx, 0
	idiv bx
	jmp short .done

.try_mod:
	mov cl, '%'
	call accept_token
	jc short .success

	call calc_subexp
	jc short .error

	mov dx, 0
	idiv bx
	mov ax, dx
	jmp short .done

.done:
	jmp short .loop

.success:
	mov bx, ax
	clc
	jmp short .return

.error:
	stc

.return:
	pop dx
	pop cx
	pop ax
	ret


calc_subexp:
	push ax
	push cx

.try_number:
	cmp byte [last_type], Number
	jne .try_minus

	mov bx, [last_value]

	call next_token
	jc short .error

	jmp short .success

.try_minus:
	mov cl, '-'
	call accept_token
	jc .try_parens

	call calc_subexp
	jc short .error

	mov ax, 0
	sub ax, bx
	mov bx, ax
	jmp short .success

.try_parens:
	mov cl, '('
	call accept_token
	jc short .error

	call calc_sum
	jc short .error

	mov cl, ')'
	call expect_token
	jc short .error

	jmp short .success

.success:
	clc
	jmp short .return

.error:
	mov cl, Number
	call expect_token
	stc

.return:
	pop cx
	pop ax
	ret


accept_token:
	cmp cl, [last_type]
	jne short .error

	call next_token

	clc
	jmp short .return

.error:
	stc

.return:
	ret


expect_token:
	call accept_token
	jnc short .return

.expect_error:
	push ax
	push si

	mov si, no_token
	call ui_write_string

	mov al, cl
	call ui_write_char
	call ui_write_newline

	pop si
	pop ax

	stc

.return:
	ret


next_token:
	push ax
	push bx
	push si
	push di

	mov si, [lexer_pos]

.skip_space_loop:
	mov al, [si]
	call string_char_iswhite
	jnc short .read_token

	inc si
	jmp short .skip_space_loop

.read_token:
	call is_special
	jnc short .its_digit

	mov [last_type], al
	inc si
	jmp short .success

.its_digit:
	call string_char_isdigit
	jnc short .expect_digit

	mov di, .digits

.read_digits:
	stosb

	inc si

	mov al, [si]
	call string_char_isdigit
	jc short .read_digits

	mov byte [di], 0

.to_number:
	mov di, si ; save si

	mov si, .digits

	call string_to_int

	mov si, di ; restore si

	mov [last_value], ax
	mov [last_type], byte Number

	jmp short .success

.expect_digit:
	push si
	mov si, no_digit
	call ui_write_string
	pop si

	mov byte [last_type], Error

.error:
	stc
	jmp short .return

.success:
	clc

.return:
	mov [lexer_pos], si

	pop di
	pop si
	pop bx
	pop ax
	ret

	.digits times 12 db 0


is_special:
	push si

	mov si, special
	call string_find_char

	pop si

	ret

	hello_msg  db `help, exit\n`, 0
	help_msg   db `supported operations: +, -, *, /, % (modulo division)\n`
	           db `parentheses are also supported, use infix notation\n`, 0

        help_cmd   db `help`, 0
	exit_cmd   db `exit`, 0

	prompt     db `> `, 0

	special    db `+-*/%()`, 0
	no_digit   db `error: expected a digit\n`, 0
	no_token   db `error: expected token: `, 0

	last_type  db 0
	last_value dw 0

	lexer_pos  dw buffer

	buffer:
		db 0
