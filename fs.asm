; constants
	FirstFATSector    equ 1
	FATSectors        equ 9
	FirstRootSector   equ 19
	RootSectors       equ 14

	BytesPerSector    equ 512

	MaxRootEntries    dw 224
	SectorsPerTrack   dw 18
	Heads             dw 2

; structures
fs_dir_entry:
	.size     equ 32
	.namesize equ 11

	.name     equ 0
	.ext      equ 8
	.cluster  equ 26
	.length   equ 28

fs_file_buffer:
	.size   equ BytesPerSector + 2 + 2 + 2

	.buffer equ BytesPerSector
	.sector equ 512
	.offset equ 514
	.left   equ 516

; EXP -- this might end up in io_ -----------------------------------
fs_buffer: times fs_file_buffer.size db 0

fs_open_file:
; IN: si: filename pointer
;
;; OUT: ax: file descriptor
; OUT: cf: set on file not found
; OUT:     fs buffer is ready to read the file

	push di
	push ax
	push bx

	call fs_read_root
	call fs_find_file
	jc short .error

	mov word [fs_buffer+fs_file_buffer.sector], ax
	mov word [fs_buffer+fs_file_buffer.offset], 0

	mov bx, [di+fs_dir_entry.length]
	mov word [fs_buffer+fs_file_buffer.left], bx
.success:
	clc
	jmp short .return

.error:
	stc
.return:
	pop bx
	pop ax
	pop di

	ret


fs_read:
;; IN: ax: file descriptor
; IN: di: buffer to load the data to
; IN: cx: number of bytes to be read
;
; OUT: di: contains at least cx bytes of read data
; OUT: cx: number of bytes actually read
; OUT: cf: set on error and end of file

	push di
	push si
	push ax
	push bx
	push dx

	mov dx, 0

	cmp cx, 0
	je short .error

	mov si, fs_buffer
	add si, [fs_buffer+fs_file_buffer.offset]
.loop:
	cmp word [fs_buffer+fs_file_buffer.left], 0
	je short .error

	cmp word [fs_buffer+fs_file_buffer.offset], 512
	jge short .next_sector
.nexted:
	cmp word [fs_buffer+fs_file_buffer.offset], 0
	je short .load_sector
.loaded:
	movsb

	inc dx
	inc word [fs_buffer+fs_file_buffer.offset]
	dec word [fs_buffer+fs_file_buffer.left]

	loop .loop

	jmp short .success

.next_sector:
	push ax
	mov word ax, [fs_buffer+fs_file_buffer.sector]
	call fs_get_next_sector
	mov word [fs_buffer+fs_file_buffer.sector], ax
	pop ax
	jc short .error

	mov word [fs_buffer+fs_file_buffer.offset], 0
	jmp short .nexted

.load_sector:
	push ax
	push cx

	mov ax, [fs_buffer+fs_file_buffer.sector]
	mov bx, fs_buffer+fs_file_buffer.buffer
	mov cl, 1
	call fs_read_sectors

	pop cx
	pop ax

	mov word [fs_buffer+fs_file_buffer.offset], 0

	mov si, fs_buffer
	add si, [fs_buffer+fs_file_buffer.offset]

	jmp short .loaded

.error:
	stc
	jmp short .return

.success:
	clc
.return:
	mov cx, dx

	pop dx
	pop bx
	pop ax
	pop si
	pop di

	ret

; EXP ---------------------------------------------------------------


fs_filename_to_tag:
; IN:  si: pointer to the filename string
; IN:  di: pointer where the tag will be stored
;
; OUT: di: contains the tag
; OUT: cf: set on error (like unproper filename)

	push si
	push di
	push ax
	push bx
	push cx
	push dx

	mov bx, di
	mov dx, di

	mov al, '.'
	call string_find_char
	jnc short .error

	mov cx, di
	sub cx, si

	mov di, dx

	mov dx, 8
	sub dx, cx

	cmp cx, 8
	jg short .error

	rep movsb

	mov al, ' '
	mov cx, dx
	rep stosb

	inc si

	call string_length
	mov cx, ax

	mov dx, 3
	sub dx, cx

	cmp cx, 3
	jg short .error
	cmp cx, 0
	jle short .error

	rep movsb

	mov al, ' '
	mov cx, dx
	rep stosb

	mov di, bx
.toupper:
	mov al, byte [di]

	cmp al, 0
	je short .success

	call string_char_islower
	jnc short .isupper

	add byte [di], `A`-`a`
.isupper:
	inc di

	jmp short .toupper

.error:
	stc
	jmp short .return

.success:
	clc
.return:
	pop dx
	pop cx
	pop bx
	pop ax
	pop di
	pop si
	ret


; code
fs_read_root:
	push ax
	push bx
	push cx

	mov ax, FirstRootSector
	mov bx, buffer
	mov cl, RootSectors
	call fs_read_sectors

	pop cx
	pop bx
	pop ax

	ret


fs_read_fat:
	push ax
	push bx
	push cx

	mov ax, FirstFATSector
	mov bx, fat_buffer
	mov cl, FATSectors
	call fs_read_sectors

	mov [fat_buffer_uptodate], byte 1

	pop cx
	pop bx
	pop ax

	ret


fs_tag_to_filename:
; It is assumed that the tag is correct.
;
; IN:  si: pointer to the tag string
; IN:  di: pointer where the filename will be stored
;
; OUT: di: contains the tag

	push si
	push di
	push ax
	push cx

	mov cx, 11
.loop:
	cmp cx, 3
	jne short .skipdot

	mov al, '.'
	stosb
.skipdot:
	lodsb

	cmp al, ` `
	je short .continue

	call string_char_isupper
	jnc short .islower

	sub al, `A`-`a`
.islower:
	stosb
.continue:
	loop .loop

	mov word [di], 0

	pop cx
	pop ax
	pop di
	pop si
	ret


fs_read_file_by_name:
; IN:  si: filename pointer
; IN:  bx: buffer to load the file to
;
; OUT:     the buffer under bx contains the file
; OUT:     updated FAT buffer
; OUT: cf: set on error

	pusha

	call fs_read_root
	call fs_find_file
	jc short .return

	call fs_read_file
.return:
	popa
	ret


fs_read_file:
; IN:  ax: first logical sector
; IN:  bx: buffer to load the file to
; OUT:     the buffer under bx contains the file
; OUT:     updated FAT buffer

	pusha

	cmp [fat_buffer_uptodate], byte 1
	je short .fine

	call fs_read_fat

.fine:
	mov cl, 1

.loop:
	call fs_read_sectors

	jmp short .return
	call fs_get_next_sector
	jc short .return

	add bx, 512
	jmp short .loop

.return:
	popa
	ret


fs_next_file:
; IN:      root directory in buffer
; IN:  si: current directory entity pointer
;
; OUT: si: next directory entity pointer

	add si, fs_dir_entry.size

	ret


fs_find_file:
; IN:  si: filename pointer
; IN:      root directory in buffer
;
; OUT: ax: file's first logical sector
; OUT: di: entry pointer
; OUT: cf: set on file not found

	.size     equ 13
	.filename equ 0

	push bx
	push cx
	push dx
	push si
	sub sp, .size

	mov di, sp
	call fs_filename_to_tag
	jc short .notfound

	mov si, sp

	mov cx, [MaxRootEntries]
	mov ax, buffer

.loop:
	mov di, ax

	cmp byte [di], 0
	je short .notfound

	cmp byte [di], 0E5h
	je short .continue

	mov dx, cx
	mov cx, fs_dir_entry.namesize
	repe cmpsb
	je short .found
	mov si, sp
	mov cx, dx
.continue:

	add ax, fs_dir_entry.size
	loop .loop

.notfound:
	add sp, .size
	stc
	jmp short .return

.found:
	mov di, ax
	mov ax, [di+fs_dir_entry.cluster]
	add ax, 31

	add sp, .size
	clc
	jmp short .return

.return:
	pop si
	pop dx
	pop cx
	pop bx

	ret


fs_get_next_sector:
; IN:  ax: current logical sector
; IN:      FAT table in the buffer
;
; OUT: ax: next logical sector
; OUT: cf: set if no next sector

	push bx
	push cx
	push dx
	push si

	cmp [fat_buffer_uptodate], byte 1
	je short .fine

	call fs_read_fat

.fine:
	sub ax, 31
	mov bx, ax

	mov dx, 0
	mov cx, 3
	mul cx

	mov cx, 2
	div cx

	mov si, fat_buffer
	add si, ax
	mov ax, [si]

	cmp dx, 0
	je short .even_record
.odd_record:
	shr ax, 4
	jmp short .check
.even_record:
	and ax, 0FFFh
.check:
	cmp ax, 0FF0h
	jae short .nonext
	cmp ax, 0001
	jle short .nonext

	add ax, 31

	jmp short .return
.nonext:
	stc
.return:
	pop si
	pop dx
	pop cx
	pop bx

	ret

fs_read_sectors:
; IN: ax: logical sector
; IN: bx: destination
; IN: cl: sector count

	pusha

	push cx
	call fs_ltolhs
	pop ax

	mov ah, 2h
.try:
	stc
	int 13h
	jnc .continue ; no need to retry

	call fd_reset_disk
	jc os_fatal_error
	jmp .try
.continue:
	popa
	ret


fs_ltolhs:
	; IN:  ax:     logical sector
	; OUT: cx, dx: parameters to int 13h

	push ax

	mov dx, 0
	div word [SectorsPerTrack]
	mov cl, dl
	add cl, 1

	mov dx, 0
	div word [Heads]
	mov ch, al
	mov dh, dl

	mov dl, byte [fs_device]

	pop ax
	ret


fd_reset_disk:
; OUT: cf: error flag

	push ax
	push dx
	mov ah, 0
	mov dl, [fs_device]
	stc
	int 13h
	pop dx
	pop ax

	ret

; variables
	fs_device db 0
