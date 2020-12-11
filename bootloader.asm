	bits 16
	jmp short start
	nop

	OEMLabel          db "BOOTLOAD"
	BytesPerSector    dw 512
	SectorsPerCluster db 1
	ReservedSectors   dw 1
	FATs              db 2
	MaxRootEntries    dw 224
	Sectors           dw 2880
	Medium            db 0F0h
	SectorsPerFAT     dw 9
	SectorsPerTrack   dw 18
	Heads             dw 2
	HiddenSectors     dd 0
	LargeSectors      dd 0
	DriveNo           dw 0
	BootSignature     db 41
	VolumeId          dd 00000000h
	VolumeLabel       db "BOOTLOAD   "
	FileSystem        db "FAT12   "

start:
	mov ax, 07C0h
	mov ds, ax

	add ax, 544
	cli
	mov ss, ax
	mov sp, 4096
	sti

	; read drive parameters
	mov [device], dl
	mov ah, 08h
	stc
	int 13h
	jc fatal_error

	movzx dx, dh
	add dx, 1
	mov [Heads], dx
	and cx, 3Fh
	mov [SectorsPerTrack], cx

; read root directory
	mov ax, 19
	mov cl, 14
	mov bx, ds
	mov es, bx
	mov bx, buffer
	call read_sectors

; read FAT
	call find_kernel
	xchg dx, ax

	mov ax, 1
	mov cl, 9
	mov bx, ds
	mov es, bx
	mov bx, buffer
	call read_sectors

; read kernel
	xchg ax, dx
	mov cl, 1
	mov bx, 2000h
	mov es, bx
	mov bx, 0
.loop:
	call read_sectors

	mov si, still		; debug
	call print_string	; debug

	call get_next_sector
	cmp ax, 0FF0h
	jae .break

	add bx, 512
	jmp .loop
.break:
	mov si, done		; debug
	call print_string	; debug
	mov al, [device]
	jmp 2000h:0000h

find_kernel:
	; OUT: ax: kernel's first logical sector

	push si
	push di
	push bx
	push es
	push cx
	push dx

	mov bx, ds
	mov es, bx

	mov cx, [MaxRootEntries]
	mov ax, buffer
.loop:
	mov si, kernel
	mov di, ax

	cmp byte [di], 0
	je .notfound
	cmp byte [di], 0E5h
	je .continue

	xchg cx, dx
	mov cx, 11
	rep cmpsb
	je .found
	xchg cx, dx
.continue:
	add ax, 32
	loop .loop
.notfound:
	mov si, kernerr
	call print_string
	call fatal_error
.found:
	mov si, kernfound
	call print_string

	add ax, 26
	mov si, ax
	mov ax, [si]
	add ax, 31

	pop dx
	pop cx

	pop bx
	mov es, bx

	pop bx
	pop di
	pop si

	ret

get_next_sector:
	; IN:  FAT table in the buffer
	; IN:  ax: current logical sector
	;
	; OUT: ax: next logical sector

	push bx
	push cx
	push dx
	push si

	sub ax, 31
	mov bx, ax

	mov dx, 0
	mov cx, 3
	mul cx

	mov cx, 2
	div cx

	mov si, buffer
	add si, ax
	mov ax, [si]

	cmp dx, 0
	je .even_record
.odd_record:
	shr ax, 4
	jmp .return
.even_record:
	and ax, 0FFFh
.return:
	pop si
	pop dx
	pop cx
	pop bx

	add ax, 31
	ret

read_sectors:
	; IN:  ax:    logical sector
	; IN:  es:bx: destination
	;
	; OUT: cl:    sector count

	pusha

	push cx
	call ltolhs
	pop ax

	mov ah, 2h
.try:
	stc
	int 13h
	jnc .continue ; no need to retry

	call reset_disk
	jc fatal_error
	jmp .try
.continue:
	popa
	ret

ltolhs:
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

	mov dl, byte [device]

	pop ax
	ret


reset_disk:
	; OUT: c: error flag

	push ax
	push dx
	mov ah, 0
	mov dl, [device]
	stc
	int 13h
	pop dx
	pop ax

	ret


print_string:
	; IN: si: output string

	pusha

	mov ah, 0Eh
.loop:
	lodsb
	cmp al, 0
	je .return
	int 10h
	jmp short .loop
.return:
	popa
	ret


fatal_error:
	mov si, diskerr
	call print_string
	jmp $


; variables
	kernel    db "KERNEL  SYS"
	diskerr   db "disk error", 13, 10, 0
	kernerr   db "no kernel file", 13, 10, 0
	kernfound db "found kernel entry", 13, 10, 0
	newline   db 13, 10, 0
	device    db 0

	still db "o", 0
	done  db "k", 13, 10, 0

; bootloader padding and sigature
	times 510-($-$$) db 0
	dw 0AA55h

buffer:
