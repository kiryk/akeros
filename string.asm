string_compare:
; Compares two strings.
;
; IN:  si, di: strings to be compared
;
; OUT: zf:     set if equal

	push si
	push di
	push ax

	call string_difference
	cmp ax, 0

	pop ax
	pop di
	pop si
	ret


string_difference:
; Difference between ASCII codes of the first pair of different
; characters on corresponding positions in the given strings.
;
; IN:  si, di: strings to be compared
;
; OUT: ax: a negative value if the char in si has a lower ASCII code
;          than that in di, a positive value if the code is higher,
;          zero if both strings are identical.

	push bx
	push si
	push di

.loop:
	mov al, [si]                ; Compare the values that are currently
	cmp [di], al                ; under [si] and [di]

	jne short .return           ; If a difference was found, go to .return

	cmp byte al, 0              ; If [si] is terminated here, go to .return
	je short .return

	inc si                      ; Increment both pointers and loop
	inc di
	jmp short .loop
.return:
	mov bh, 0
	mov bl, [di]

	mov ah, 0
	sub ax, bx

	pop bx
	pop di
	pop si
	ret


string_copy:
; Copies all chars from si to di.
;
; IN:  si: source string
; IN:  di: destination
;
; OUT: di: contains the same chars as si

	push si
	push di
	push ax

.loop:
	lodsb                       ; Load [si] to al
	stosb                       ; Store al in [di]

	cmp al, 0                   ; Was the char NUL?
	jne .loop                   ; If not, continue
.return:
	pop ax
	pop di
	pop si
	ret


string_parse:
; Finds the first word in a given string and null-terminates it,
; pointer to the rest of the string is preserved.
;
; IN:  si: pointer to a string
;
; OUT: di: pointer to a token
; OUT: si: pointer to the rest of the string
; OUT: cf: set if no tokens in [si]

	push ax

.loop1:
	mov al, [si]                ; Save for the incoming cmp
                                    ; and string_char_iswhite call

	cmp al, 0                   ; If the string terminated before any word
	je short .empty             ; was found, end the routine with .empty

	call string_char_iswhite    ; If we found a word, go to .cut in order to
	jnc short .cut              ; find its end and null-terminate it

	inc si                      ; If none of the above, go for the next
	jmp short .loop1            ; character and loop

.cut:
	mov di, si                  ; Save the begginig of the word in di
.loop2:
	inc si                      ; Go for the next character and save in
	mov al, [si]                ; al for cmp and  string_char_is_white

	cmp al, 0                   ; If the words already ends with a null,
	je short .done              ; then we're just done

	call string_char_iswhite    ; Loop if we still haven't found the end
	jnc short .loop2            ; of the word, otherwise break the loop

	mov byte [si], 0            ; Terminate the string

	inc si                      ; Make si point to the rest of the string
.done:
	clc                         ; We found a word, clear carry just in case

	jmp short .return

.empty:
	stc
.return:
	pop ax
	ret


string_to_int:
; Converts a string to integer.
;
; IN:  si: pointer to a string
;
; OUT: ax: its numerical value

	push si
	push di
	push bx
	push cx
	push dx

	mov ax, 0                   ; We'll build the number starting from 0
	mov bx, 10                  ; Set bx to the base of decimal system

	mov di, si                  ; We'll remember the first char

	cmp byte [si], '-'
	jne short .loop

	inc si                      ; Skip the minus

.loop:
	xchg cx, ax                 ; Save original ax before lodsb
	lodsb
	call string_char_isdigit    ; If the character isn't a digit, .return
	jnc short .done

	xchg ax, cx                 ; Otherwise restore the ax for mul by 10
	mov dx, 0
	mul bx

	mov ch, 0
	sub cl, '0'                 ; Convert the digit char to a number
	add ax, cx                  ; and add it to the result we've got so far

	jmp short .loop             ; Go for the next character
.done:
	xchg ax, cx                 ; Restore the ax, so it contained
                                    ; the resulting positive integer
	cmp byte [di], '-'
	jne short .return           ; If the first char wasn't -, we can return

	mov bx, 0                   ; Otherwise make the number negative
	sub bx, ax
	mov ax, bx

.return:
	pop dx
	pop cx
	pop bx
	pop di
	pop si
	ret


string_int_to:
; Converts an integer to string.
;
; IN:  ax: value to be converted
; IN:  di: pointer where the result will be stored
;
; OUT: di: contains a string representing the value in ax

	pusha

	cmp ax, 0                   ; Is the number negative?
	jge short .nonnegative

	mov byte [di], '-'          ; If it is, add - to di
	inc di

	mov bx, 0                   ; Then make ax positive, and don't
	sub bx, ax                  ; mind it anymore
	mov ax, bx

.nonnegative:
	mov si, di                  ; Save the original di
	mov bx, 10                  ; Set bx to decimal base
.loop:
	mov dx, 0                   ; Zero the remainder register
	div bx                      ; Divide ax by 10
	add dx, '0'                 ; Convert remainder to an ASCII digit

	mov byte [di], dl           ; Save the digit in di string
	inc di                      ; Make di point to the next byte

	cmp ax, 0                   ; If nothing is left, exit the loop
	ja short .loop

	mov byte [di], 0            ; End the string with a NUL char

	call string_reverse         ; So far the least significant digit
	                            ; is first, so reverse the string
	popa
	ret


string_find_char:
; Returns pointer to first occurence of a character in al,
; sets carry if found, clears if not.
;
; IN: si: pointer to a string
; IN: al: a character
;
; OUT: di: pointer to the character
; OUT: cf: set if the character was found

	push si

.loop:
	cmp byte [si], al           ; Is it the character we want?
	je short .found             ; If so, note it

	cmp byte [si], 0            ; Is it the end of the string?
	je short .notfound          ; If so, we found nothing

	inc si                      ; If none of the above,
	jmp short .loop             ; go for the next character and loop

.notfound:
	clc                         ; We found nothing interesting, clear carry
	jmp short .return

.found:
	stc                         ; The character was there, set carry
.return:
	mov di, si                  ; Save si in di,
                                    ; before we restore the old si
	pop si
	ret


string_length:
; Numbers of characters in a given string, terminating
; character not included.
;
; IN:  si: pointer to a string
;
; OUT: ax: length of the string

	push di

	mov al, 0
	call string_find_char

	mov ax, di
	sub ax, si

	pop di
	ret


string_reverse:
; Reverses a string pointed by si.
;
; IN:  si: pointer to a string
; OUT: string in si is reversed

	push ax
	push si
	push di

	call string_length

	mov di, si
	add di, ax
	dec di

.loop:
	cmp si, di
	jae short .return

	mov  byte al, [si]
	xchg byte [di], al
	mov  byte [si], al

	inc si
	dec di

	jmp short .loop

.return:
	pop di
	pop si
	pop ax
	ret


string_char_isbetween:
; Checks whether a given character's is in the [bl; bh] range.
;
; IN:  al: a character
; IN:  bl: lower bound
; IN:  bh: upper bound
;
; OUT: cf: set if the character is in the range

	cmp al, bl                  ; Is its code smaller than that of bl?
	jnae short .isnot           ; If so, it's not in the range
	cmp al, bh                  ; Is its code greater than that of bh?
	ja short .isnot             ; If so, it's not in the range

	stc                         ; If none of the above, it is in the range
	ret                         ; so set carry and return

.isnot:
	clc                         ; It was outside the range, clear carry
	ret


string_char_iswhite:
; Checks whether a given character is white.
;
; IN:  al: a character
;
; OUT: cf: set if the character is white

	cmp al, ` `                 ; Is it a space?
	je short .is
	cmp al, `\t`                ; Is it a tab?
	je short .is
	cmp al, `\v`                ; Is it a vertical tab?
	je short .is
	cmp al, `\r`                ; Is it a carriage return?
	je short .is
	cmp al, `\n`                ; Is it a new line?
	je short .is

	clc                         ; If none of the above, clear carry
	ret

.is:
	stc                         ; If any of the above, set carry
	ret


string_char_isdigit:
; Checks whether a given character is a digit.
;
; IN:  al: a character
;
; OUT: cf: set if the character is a digit

	push bx

	mov bl, '0'                 ; Is it between '0' and '9'
	mov bh, '9'                 ; or one of these?

	call string_char_isbetween  ; If so, it's a digit and cf is set
                                    ; by string_char_isbetween
	pop bx
	ret


string_char_isalpha:
; Checks whether a given character is a digit.
;
; IN:  al: a character
;
; OUT: cf: set if the character is a digit

	push bx

	mov bl, 'a'                 ; Is it between 'a' and 'z'
	mov bh, 'z'                 ; or is it one of these?
	call string_char_isbetween  ; If so, return and
	jc .return                  ; the carry will remain set

	mov bl, 'A'                 ; Is it between 'A' and 'Z'
	mov bh, 'Z'                 ; or is it one of these?
	call string_char_isbetween  ; If so, return and
	jc .return                  ; the carry will remain set
.return:
	pop bx                      ; If both test failed, the carry
	ret                         ; will be cleared


string_char_islower:
; Checks whether a given character is lowercase.
;
; IN:  al: a character
;
; OUT: cf: set if the character is lowercase

	push bx

	mov bl, 'a'                 ; Is it between 'a' and 'z'
	mov bh, 'z'                 ; or is it one of these?

	call string_char_isbetween  ; If so, it's lowercase and cf is set
                                    ; by string_char_isbetween
	pop bx
	ret


string_char_isupper:
; Checks whether a given character is uppercase.
;
; IN:  al: a character
;
; OUT: cf: set if the character is uppercase

	push bx

	mov bl, 'A'                 ; Is it between 'A' and 'Z'
	mov bh, 'Z'                 ; or is it one of these?

	call string_char_isbetween  ; If so, it's uppercase and cf is set
                                    ; by string_char_isbetween
	pop bx
	ret
