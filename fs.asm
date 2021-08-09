; CONSTANTS SECTION:

	FirstFATSector    equ 1
	FATSectors        equ 9
	FirstRootSector   equ 19
	RootSectors       equ 14

	SecondFATSector   equ FirstFATSector + FATSectors

	BytesPerSector    equ 512

	Sectors           equ 2880
	DataSectors       equ Sectors - 33 ; total - predefined
	FirstDataSector   equ 33

	MaxRootEntries    dw 224
	SectorsPerTrack   dw 18
	Heads             dw 2

	MaxOpenFiles      equ 5
	ModeNone          equ 0
	ModeRead          equ 1
	ModeWrite         equ 2


; STRUCTURES SECTION:

fs_dir_entry:
	.size     equ 32
	.basesize equ 8
	.extsize  equ 3
	.namesize equ .basesize + .extsize

	.name     equ 0
	.ext      equ 8
	.attribs  equ 11
	.reserved equ 12
	.cr_time  equ 14
	.cr_date  equ 16
	.rd_date  equ 18
	.wr_time  equ 20
	.wr_date  equ 22
	.cluster  equ 26
	.length   equ 28

fs_buffer:
	.size   equ BytesPerSector + 2 + 2 + 2 + 2 + 1

	.buffer equ 0
	.sector equ BytesPerSector
	.offset equ BytesPerSector + 2
	.pos    equ BytesPerSector + 4
	.dirent equ BytesPerSector + 6
	.mode   equ BytesPerSector + 8


; CODE SECTION:
fs_init_buffers:
	push ax
	push cx
	push si

	mov ax, 0
	mov cx, MaxOpenFiles*fs_buffer.size
	mov di, fs_buffer_index
	rep stosb

	pop si
	pop cx
	pop ax

	ret


fs_read_root:
; OUT: root buffer loaded from the disk and ready
;          to work with

	push ax
	push bx
	push cx

	mov ax, FirstRootSector     ; Starting with the FirstRootSector
	mov bx, root_buffer         ; read the whole series of blocks
	mov cl, RootSectors         ; and save them in the root_buffer
	call fs_read_sectors

	pop cx
	pop bx
	pop ax

	ret


fs_write_root:
; OUT: changes in the root buffer saved on the disk

	push ax
	push bx
	push cx

	mov ax, FirstRootSector     ; Starting with the FirstRootSector
	mov bx, root_buffer         ; write the whole series of blocks
	mov cl, RootSectors         ; taking them from the root_buffer
	call fs_write_sectors

	pop cx
	pop bx
	pop ax

	ret


fs_read_fat:
; OUT: FAT buffer loaded from the disk and ready
;          to work with

	push ax
	push bx
	push cx

	mov ax, FirstFATSector      ; Starting with the FirstFATSector
	mov bx, fat_buffer          ; read the whole series of blocks
	mov cl, FATSectors          ; and save them in the fat_buffer
	call fs_read_sectors

	pop cx
	pop bx
	pop ax

	ret


fs_write_fat:
; OUT: changes in the FAT buffer saved on the disk

	push ax
	push bx
	push cx

	mov ax, FirstFATSector      ; Starting with the FirstFATSector
	mov bx, fat_buffer          ; write the whole series of blocks
	mov cl, FATSectors          ; taking them from the fat_buffer
	call fs_write_sectors

	mov ax, SecondFATSector     ; Repeat the same, but start saving
	call fs_write_sectors       ; with the first SecondFATSector instead

	pop cx
	pop bx
	pop ax

	ret


fs_open_read:
; IN: si: filename pointer
;
; OUT: ax: file descriptor
; OUT: cf: set on file not found
; OUT:     the file is ready to be read

	push di
	push cx
	push bx

	call fs_find_file           ; Does the file exist?
	jc short .error             ; If it doesn't, return with error

	; If everything is fine, look for a free buffer

	mov bx, fs_buffer_index     ; Use bx as current buffer base pointer
	mov cx, 0                   ; Use cx as current buffer number
.loop:
	cmp byte [bx+fs_buffer.mode], ModeNone
	je short .success           ; Finish if we found a free buffer

	add bx, fs_buffer.size      ; Make bx point to the next buffer
	inc cx                      ; Update cx

	cmp cx, MaxOpenFiles        ; If we've reached the last buffer
	jae short .error            ; return with error

	jmp short .loop             ; Otherwise repeat the loop

.success:
	; Now we are goint to initialize the buffer for the file.
	; Notice that fs_find_file left its first sector number in ax,
	; and it's directory entry pointer in di.

	mov word [bx+fs_buffer.sector], ax
	mov word [bx+fs_buffer.offset], 0
	mov word [bx+fs_buffer.pos], 0
	mov word [bx+fs_buffer.dirent], di

	mov byte [bx+fs_buffer.mode], ModeRead ; Mark the buffer as used

	clc
	jmp short .return

.error:
	stc
.return:
	mov ax, cx                  ; Return the buffer number using ax

	pop bx
	pop cx
	pop di

	ret


fs_open_write:
; IN: si: filename pointer
;
; OUT: ax: file descriptor
; OUT: cf: set on file not found
; OUT:     the file is ready to receive data
;
; VARS:
	.size equ 4
	.base equ 0
	.fd   equ 2

	push bp
	push di
	push cx
	push bx
	push dx
	sub sp, .size               ; Allocate variables
	mov bp, sp                  ;

	; First we're going to check whether the file already exists,
	; if it doesn't, an empty file with the requested name is created.
	; Then we try to detect if the requested file is already open,
	; if it is, the same fd will be used. In the case the file was
	; not open, we look for a free buffer and return its number as fd.


	call fs_find_file           ; Does the file already exist?
	jnc short .check_if_open    ; If it does, check wheter its alraedy open

	mov di, 0                   ; If it doesn't, make sure di is zeroed
	jmp short .get_fd           ; Then try to find a free file buffer

.check_if_open:
	mov bx, fs_buffer_index     ; Use bx as current buffer base pointer
	mov cx, 0                   ; Use cx as current buffer number
.loop1:
	cmp byte [bx+fs_buffer.mode], ModeWrite
	jne .skip                   ; If the buffer is not in write mode, skip
	cmp word [bx+fs_buffer.dirent], di
	jne .skip                   ; If it doesn't refer to our file, skip

	mov [bp+.fd], cx            ; Otherwise remember cx,
	jmp .success                ; as it will be returned

.skip:
	add bx, fs_buffer.size      ; Try with the next buffer
	inc cx

	cmp cx, MaxOpenFiles        ; If we haven't reached the last buffer
	jnae short .loop1           ; continue the loop

	; If the above loop ended and we're here, it means the file
	; isn't open. Now we're going to find a free buffer to use for
	; our file.

.get_fd:
	mov bx, fs_buffer_index     ; Use bx as current buffer base pointer
	mov cx, 0                   ; Use cx as current buffer number
.loop2:
	cmp byte [bx+fs_buffer.mode], ModeNone
	je short .found_fd          ; If we found the buffer, break the loop

	add bx, fs_buffer.size      ; Otherwise try with the next buffer
	inc cx

	cmp cx, MaxOpenFiles        ; If we haven't reached the last buffer
	jnae short .loop2           ; continue the loop

	; If we got here, it means all buffers are busy
	; so we are going to communicate failure

	jmp .error

.found_fd:
	mov [bp+.fd], cx            ; Save buffer number in .fd
	mov [bp+.base], bx          ; Save buffer base pointer in .base

	cmp di, 0                   ; di is zeroed if the file doesn't exist
	jne short .get_last_sector  ; If it does, get its last sector

	; If it doesn't:

	call fs_create_file         ; Create the file
	jc short .error

	; Make the required registers ready for buffer initialization:

	; di - is a directory entry pointer
	mov ax, 0
	mov dx, 0
	mov cx, 0

	jmp short .init             ; Go to initialization

.get_last_sector:
.loop3:
	mov dx, ax                  ; Save the current sector
	call fs_get_next_sector
	jnc short .loop3            ; If the next sector exists, repeat loop

	; Load the last sector into the buffer:

	mov ax, dx
	; bx - fine
	mov cl, 1
	call fs_read_sectors

	; Make the required registers ready for buffer initialization:

	; First we are going to calculate the sector offset, and save it in dx

	mov cx, ax                  ; Save ax, we'll need it later
	mov dx, 0
	mov bx, 512
	mov ax, [di+fs_dir_entry.length]
	div bx
	mov ax, cx                  ; Restore ax

	; Then we're going to obtain the length of the file, and save it in cx
	mov cx, [di+fs_dir_entry.length]

	cmp cx, 0                   ; If the file is empty, we're done
	je .init

	; Otherwise check if the offset equals 0

	cmp dx, 0
	ja .init

	; If it does, make it 512, as required by fs_read

	mov dx, 512

.init:
	; Now were going to initialize the buffer with the
	; values we've prepared

	mov bx, [bp+.base]

	mov [bx+fs_buffer.sector], ax
	mov [bx+fs_buffer.offset], dx
	mov [bx+fs_buffer.pos],    cx
	mov [bx+fs_buffer.dirent], di
	mov [bx+fs_buffer.mode],   byte ModeWrite

.success:
	mov ax, [bp+.fd]            ; Save the descriptor in ax

	add sp, .size               ; Dealloc the variables
	clc
	jmp short .return

.error:
	add sp, .size               ; Dealloc the variables
	stc

.return:
	pop dx
	pop bx
	pop cx
	pop di
	pop bp

	ret


fs_read:
; IN: ax: file descriptor
; IN: di: buffer to load the data to
; IN: cx: number of bytes to be read
;
; OUT: di: contains at least cx bytes of read data
; OUT: cx: number of bytes actually read
; OUT: cf: set on error or end of file
;
; VARS:
	.size equ 4
	.base equ 0
	.max  equ 2

	push bp
	push di
	push si
	push ax
	push bx
	push dx
	sub sp, .size               ; Allocate variables
	mov bp, sp                  ;

	; Now convert the file descriptor to buffer pointer

	mov dx, 0
	mov bx, fs_buffer.size
	mul bx
	add ax, fs_buffer_index

	; Save the values in variables, and appropriate registers

	mov [bp+.base], ax          ; .base points to the buffer we use
	mov [bp+.max], cx           ; .max is the number of bytes to write
	mov bx, ax                  ; bx points to the buffer we use
	mov dx, 0                   ; dx are the actual bytes written

	cmp byte [bx+fs_buffer.mode], ModeRead
	jne short .error            ; Return error if it's not in read mode

	cmp word [bp+.max], 0       ; Are there any bytes to be read?
	je short .return            ; If none, return immediately

	mov si, bx                  ; Make si point to the start of
	add si,[bx+fs_buffer.offset]; the buffer and increase it by offset

.loop:
	mov bx, [bx+fs_buffer.dirent]    ; Save dirent pointer in bx
	mov ax, [bx+fs_dir_entry.length] ; Save file's length in ax
	mov bx, [bp+.base]               ; Restore bx

	cmp ax, [bx+fs_buffer.pos]       ; Does ax equal our pos in the file?
	je short .error                  ; If so, we're asked to read too much

	; If we reached the end of the sector, calculate the next one:

	cmp word [bx+fs_buffer.offset], BytesPerSector
	jae short .next_sector
.nexted:
	; If we start reading a new sector, load it into memory:

	cmp word [bx+fs_buffer.offset], 0
	je short .load_sector
.loaded:
	movsb                            ; Move a byte from buffer to user's di

	inc dx                           ; Increment dx (read-bytes count)
	inc word [bx+fs_buffer.offset]   ; Increment the offset
	inc word [bx+fs_buffer.pos]      ; Increment the pos

	cmp dx, [bp+.max]                ; Have we read everything we need?
	je short .success                ; If so, success

	jmp .loop                        ; Otherwise continue the loop

.next_sector:
	mov ax, [bx+fs_buffer.sector]    ; Get the next sector number
	call fs_get_next_sector
	jc short .error

	mov [bx+fs_buffer.sector], ax    ; Save the number in the buffer
	jc short .error

	mov word[bx+fs_buffer.offset], 0 ; Set buffer's offset to 0

	jmp short .nexted                ; Return to the main loop

.load_sector:
	mov ax, [bx+fs_buffer.sector]
	; bx - fine
	mov cl, 1
	call fs_read_sectors             ; Load the next sector

	mov word[bx+fs_buffer.offset], 0 ; Zero the offset
	mov si, bx                       ; Move si to the base of the buffer

	jmp short .loaded                ; Return to the main loop

.error:
	add sp, .size                    ; Dealloc variables
	stc
	jmp short .return

.success:
	add sp, .size                    ; Dealloc variables
	clc

.return:
	mov cx, dx                       ; Save dx in cx

	pop dx
	pop bx
	pop ax
	pop si
	pop di
	pop bp

	ret


fs_write:
; IN: ax: file descriptor
; IN: si: buffer to load the data from
; IN: cx: number of bytes to be written
;
; OUT: cx: number of bytes actually written
; OUT: cf: set on error
;
; VARS:
	.size equ 4
	.base equ 0
	.max  equ 2

	push bp
	push di
	push si
	push ax
	push bx
	push dx
	sub sp, .size               ; Allocate variables
	mov bp, sp                  ;

	; Now convert the file descriptor to buffer pointer

	mov dx, 0
	mov bx, fs_buffer.size
	mul bx
	add ax, fs_buffer_index

	; Save the values in variables, and appropriate registers

	mov [bp+.base], ax          ; .base points to the buffer we use
	mov [bp+.max], cx           ; .max is the number of bytes to write
	mov bx, ax                  ; bx points to the buffer we use
	mov dx, 0                   ; dx are the actual bytes written

	cmp byte [bx+fs_buffer.mode], ModeWrite
	jne .error                  ; Return error if it's not in write mode

	cmp cx, 0                   ; If we're asked to write 0 bytes, return
	je .return

	mov di, bx                  ; Set di to the start of the buffer
	add di,[bx+fs_buffer.offset]; Increment di by the offset

.loop:
	; If we've filled the buffer, write the contents to the disk:

	cmp word [bx+fs_buffer.offset], BytesPerSector
	jae short .store_sector
.stored:
	; If we start writing a new sector, get it's number:

	cmp word [bx+fs_buffer.offset], 0
	je short .next_sector
.nexted:
	movsb                            ; Move a byte from user's si to buffer

	inc dx                           ; Increment dx (written-bytes count)
	inc word [bx+fs_buffer.offset]   ; Increment the offset
	inc word [bx+fs_buffer.pos]      ; Increment the pos

	cmp dx, [bp+.max]                ; Have we written everything we need?
	je short .success                ; If so, success

	jmp short .loop                  ; Otherwise continue the loop

.next_sector:
	mov bx, [bx+fs_buffer.dirent]    ; Move dirent pointer to bx
	mov bx, [bx+fs_dir_entry.length] ; Move file length to bx
	cmp bx, 0                        ; Is the file empty?
	mov bx, [bp+.base]               ; Restore the bx, but...
	je .first_sector                 ; if the file is empty yet,
	                                 ; it's a special case

	mov ax, [bx+fs_buffer.sector]    ; Move the current sector number to ax

	mov bx, ax                       ; Save ax in bx for later
	call fs_find_free_sector         ; Find a free sector after ax
	; TODO: handle it more gently:
	jc os_fatal_error                ; If there are no sectors left, panic

	xchg bx, ax                      ; Move the new number to bx
	                                 ; and the old to ax
	call fs_set_next_sector          ; Then make bx the next sector of ax

	mov ax, bx
	mov bx, 0FFFh
	call fs_set_fat_entry            ; Make ax the last sector

	mov bx, [bp+.base]               ; Restore bx as the buffer pointer

	mov [bx+fs_buffer.sector], ax    ; Set ax as the current sector

	jmp short .nexted                ; Return to the main loop

.first_sector:

	; Here we're going to attach first sector to an empty file

	mov ax, FirstDataSector
	call fs_find_free_sector         ; Search for the first free sector

	mov bx, 0FFFh
	call fs_set_fat_entry
	mov bx, [bp+.base]               ; Mark the sector as the last one

	mov [bx+fs_buffer.sector], ax    ; Set ax as the current sector

	sub ax, 31                       ; Translate ax to FAT entry number
	mov bx,[bx+fs_buffer.dirent]     ; Save dirent pointer to bx
	mov [bx+fs_dir_entry.cluster],ax ; Save the entry as first
	                                 ; one of our file

	mov bx, [bp+.base]               ; Restore bx as the buffer pointer

	jmp short .nexted                ; Return to the main loop

.store_sector:
	mov ax, [bx+fs_buffer.sector]
	; bx - fine
	mov cl, 1
	call fs_write_sectors            ; Store the buffer on the disk

	mov word[bx+fs_buffer.offset], 0 ; Zero the offset
	mov di, bx                       ; Move di to the base of the buffer

	; Now increment the file's length by the number bytes we've written

	mov bx, [bx+fs_buffer.dirent]
	add word [bx+fs_dir_entry.length], BytesPerSector

	mov bx, [bp+.base]               ; Restore bx as the buffer pointer

	jmp .stored                      ; Return to the main loop

.error:
	add sp, .size                    ; Dealloc variables
	stc
	jmp short .return

.success:
	add sp, .size                    ; Dealloc variables
	clc
.return:
	mov cx, dx                       ; Save dx in cx

	pop dx
	pop bx
	pop ax
	pop si
	pop di
	pop bp

	ret


fs_close:
; IN:  ax: file descriptor
;
; OUT: the file is closed
; OUT: all buffered changes written to the disk

	pusha

	; Convert the file descriptor to buffer pointer

	mov dx, 0
	mov bx, fs_buffer.size
	mul bx
	add ax, fs_buffer_index
	mov bx, ax

	cmp byte [bx+fs_buffer.mode], ModeNone
	je short .return                       ; Return if it's already closed

	cmp byte [bx+fs_buffer.mode], ModeRead
	je short .return                       ; Return if it was in read mode

	cmp word [bx+fs_buffer.offset], 0      ; Are there bytes in the buffer?
	je short .stored                       ; If so, skip storing them

	; Now we're going to store the bytes left

	; First save our position in the file in ax
	mov ax, [bx+fs_buffer.pos]

	mov cx, bx                             ; Save bx for later
	mov bx, [bx+fs_buffer.dirent]          ; Move dirent pointer to dx
	mov [bx+fs_dir_entry.length], ax       ; Save ax as the new file length
	mov bx, cx                             ; Restore bx

	mov ax, [bx+fs_buffer.sector]
	; bx - fine
	mov cl, 1                              ; Write the buffered bytes
	call fs_write_sectors                  ; to the disk
.stored:
	call fs_write_fat                      ; Store the updated FAT buffer
	call fs_write_root                     ; Store the updated root buffer
.return:
	mov byte [bx+fs_buffer.mode], ModeNone ; Mark the buffer as unused

	popa

	ret


fs_filename_to_tag:
; IN:  si: pointer to the filename string
; IN:  di: pointer where the tag will be stored
;
; OUT: di: contains the tag
; OUT: cf: set on error (like an unproper filename)

	pusha

	mov bx, di
	mov dx, di

	mov al, '.'
	call string_find_char
	jnc short .error            ; If there's no dot in the name, error

	; di points to the dot in the name now

	mov cx, di
	sub cx, si                  ; Make cx the num of chars before the dot

	mov di, dx                  ; Make di point to the given filename

	mov dx,fs_dir_entry.basesize; Calculate the number of unused chars
	sub dx, cx                  ; before the dot and save in dx

	cmp cx,fs_dir_entry.basesize; If the base name is longer than
	ja short .error             ; the maximal allowed length, error

	rep movsb                   ; Now rewrite the cx chars from si to di

	mov al, ' '
	mov cx, dx                  ; Now place a space in di for every
	rep stosb                   ; unused character in the filename

	; We have done everything we had to do with the base name, so
	; now we will deal with the extension, but first - skip the dot:

	inc si

	call string_length          ; How long the extension is?
	mov cx, ax                  ; Store the result in cx

	mov dx,fs_dir_entry.extsize ; Calc the difference between max ext. len
	sub dx, cx                  ; and the actual one, save it in dx

	cmp cx,fs_dir_entry.extsize
	ja short .error             ; If the extension is too long, error

	cmp cx, 0
	jna short .error            ; If the extension is empty, error

	rep movsb                   ; Rewrite the extension chars

	mov al, ' '
	mov cx, dx
	rep stosb                   ; Now fill the rest with spaces

	mov di, bx                  ; Move di back to the beggining of the tag

	; Now we're going to make all the tag chars uppercase

	mov cx,fs_dir_entry.namesize
.toupper:
	mov al, byte [di]           ; Read a di char to al

	call string_char_islower
	jnc short .skip             ; If it's not lowercase, don't bother

	add byte [di], `A`-`a`      ; Otherwise make it uppercase
.skip:
	inc di                      ; Go for the next character

	loop .toupper               ; Continue the loop if there are chars left
.success:
	clc
	jmp short .return

.error:
	stc
.return:
	popa
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

	; We'll just take evey char in the tag, and skip it if it's a space,
	; we'll also add a dot after having moved over 8 tag chars.

	mov cx,fs_dir_entry.namesize
.loop:
	cmp cx,fs_dir_entry.extsize ; Is only the extension left?
	jne short .skipdot          ; If no, don't bother

	mov al, '.'
	stosb                       ; But otherwise add a dot to the name
.skipdot:
	lodsb                       ; Load the tag char to ax

	cmp al, ` `                 ; Is it a space?
	je short .continue          ; If so, skip it

	call string_char_isupper    ; Is it uppercase?
	jnc short .islower          ; If not, skip it

	add al, `a`-`A`             ; Otherwise make it lowecase
.islower:
	stosb                       ; Add the char to the name
.continue:
	loop .loop                  ; Repeat the loop if there are chars left

	mov byte [di], 0            ; Mark the end of the name

	pop cx
	pop ax
	pop di
	pop si
	ret


fs_create_file:
; IN:  si: pointer to the filename
; IN:      root directory in buffer
;
; OUT: di: entry pointer
; OUT: cf: set if could not create
; OUT:     changes written to the disk

	.size equ fs_dir_entry.namesize+2
	.tag  equ 0

	push ax
	push bx
	push cx
	push si
	push bp
	sub sp, .size               ; Allocate variables
	mov bp, sp                  ; bp points to .tag string

	call fs_find_file
	jnc short .error            ; If the file exists, error

	mov di, bp
	call fs_filename_to_tag     ; Save the tag in .tag
	jc short .error             ; If the filename wasn't correct, error

	; Now we're going to look for a free directory entry

	mov cx, [MaxRootEntries]
	mov bx, root_buffer
.loop:
	cmp byte [bx], 0
	je short .create            ; We've found the entry

	cmp byte [bx], 0E5h
	je short .create            ; We've found the entry

	add bx, fs_dir_entry.size   ; Go for the next entry
	loop .loop                  ; Repeat the loop if there are entires left

	; If we've come to this point, it means no free entry was found

.error:
	add sp, .size               ; Dealloc vars
	stc
	jmp short .return

.create:
	; Set the file's name in the dir entry to .tag

	mov cx, fs_dir_entry.namesize
	mov si, di
	mov di, bx
	add di, fs_dir_entry.name
	rep movsb

	; Now zero all the attributes in the entry

	mov byte [bx+fs_dir_entry.attribs],  0
	mov word [bx+fs_dir_entry.reserved], 0
	mov word [bx+fs_dir_entry.cr_time],  0
	mov word [bx+fs_dir_entry.cr_date],  0
	mov word [bx+fs_dir_entry.rd_date],  0
	mov word [bx+fs_dir_entry.wr_time],  0
	mov word [bx+fs_dir_entry.wr_date],  0
	mov word [bx+fs_dir_entry.cluster],  0
	mov word [bx+fs_dir_entry.length],   0

	mov di, bx                  ; Save the entry pointer in di

	call fs_write_root          ; Write the changes to the disk

	add sp, .size               ; Dealloc vars
	clc
.return:
	pop bp
	pop si
	pop cx
	pop bx
	pop ax

	ret


fs_remove_file:
; IN:  si: pointer to the filename
;
; OUT: cf: set if could not remove
; OUT:     changes written to the disk

	push ax
	push bx
	push di

	; We're going to mark the file's dir entry as unused, then go through
	; all of its FAT entries and mark them as unused

	call fs_find_file           ; But if the file doesn't exist,
	jc short .error             ; don't even try

	mov byte [di], 0E5h         ; Okay, mark the file as unused

	; Thanks to fs_find file ax already contains the file's firt sector,
	; now notice bx is the register used by fs_set_fat_entry, and we'll
	; set the register to 0 only once

	mov bx, 0
.loop:
	call fs_set_fat_entry       ; Set entry to 0
	call fs_get_next_sector     ; Get the next sector
	jnc short .loop             ; If sectors are left, repeat
.success:
	call fs_write_fat           ; Save FAT buffer to the disk
	call fs_write_root          ; Save root buffer to the disk
	clc
	jmp short .return

.error:
	stc
.return:
	pop di
	pop bx
	pop ax
	ret


fs_rename_file:
; IN:  si: original filename pointer
; IN:  di: new filename pointer
;
; OUT: the desired file is renamed
; OUT: changes are written to the disk
;
; VARS:
	.size equ fs_dir_entry.namesize
	.tag  equ 0

	pusha
	sub sp, .size
	mov bp, sp

	mov bx, si                  ; Save original si
	mov cx, di                  ; Save original di

	mov si, cx
	call fs_find_file           ; If the new filename belongs to an
	jnc short .error            ; existing file, return with error

	mov di, bp
	call fs_filename_to_tag     ; Translate the filename to tag
	jc short .error             ; Is the filename correct?

	mov si, bx
	call fs_find_file
	jc short .error             ; Does the file we want to rename exist?

	; Now di contains the file's directory entry pointer

	mov cx, fs_dir_entry.namesize
	mov si, bp
	rep movsb                   ; Insert the new tag to the file data

	call fs_write_root
.success:
	add sp, fs_dir_entry.namesize
	clc

	jmp short .return

.error:
	add sp, fs_dir_entry.namesize
	stc
.return:
	popa
	ret


fs_read_file:
; IN:  ax:    first physical sector
; IN:  es:bx: buffer to load the file to
;
; OUT:        the buffer under es:bx contains bytes of the file

	pusha

	mov cl, 1                   ; Read only one sector at a time

.loop:
	call fs_read_sectors        ; Read the sector

	; jmp short .return
	call fs_get_next_sector     ; Get the next sector
	jc short .return            ; If none are left, return

	add bx, BytesPerSector      ; Increment the addres by the sector size
	jmp short .loop             ; Repeat the loop

.return:
	popa
	ret


fs_skip_special:
; Increment directory pointer to the next entry,
; if the current is a special or an empty one.
;
; IN:      root directory in buffer
; IN:  cx: current directory entity number (zero-based)
; IN:  si: current directory entity pointer
;
; OUT: cx: next directory entity pointer
; OUT: si: next directory entity pointer
; OUT: cf: set if no next dir

.loop:
	cmp cx, MaxRootEntries
	jae short .error
	cmp byte [si], 000h
	je short .error
	cmp byte [si+11], 00Fh
	je short .skip
	cmp byte [si], 0E5h
	je short .skip

	clc
	jmp short .return

.skip:
	inc cx
	add si, fs_dir_entry.size

	jmp short .loop

.error:
	stc

.return:
	ret


fs_find_file:
; IN:  si: filename pointer
; IN:      root directory in buffer
;
; OUT: ax: file's first physical sector
; OUT: di: entry pointer
; OUT: cf: set on file not found

	.size     equ fs_dir_entry.namesize+2
	.tag equ 0

	push bx
	push cx
	push dx
	push si
	push bp
	sub sp, .size
	mov bp, sp                  ; Make bp point to .tag

	mov di, bp
	call fs_filename_to_tag     ; Save the filename's tag form in .tag
	jc short .notfound

	; Now we're going to browse all the files

	mov cx, 0
	mov ax, root_buffer

.loop:
	mov si, ax
	call fs_skip_special        ; Skip special directory entries
	jc short .notfound          ; Or give up if none are left

	; TODO: implement a strncmp-like routine and use it instead

	mov si, bp                  ; Make si point to our .tag
	mov di, ax                  ; Make di point to name in the entry

	mov dx, cx
	mov cx, fs_dir_entry.namesize
	repe cmpsb                  ; Compare the strings
	je short .found             ; If they're the same, we found the file
	mov si, bp
	mov cx, dx

.continue:

	add ax, fs_dir_entry.size   ; Go for the next entry
	inc cx
	jmp .loop

.notfound:
	add sp, .size               ; Dealloc variables
	stc
	jmp short .return

.found:
	mov di, ax
	mov ax, [di+fs_dir_entry.cluster]
	add ax, 31                  ; Translate ax to physical sector

	add sp, .size               ; Dealloc variables
	clc
	jmp short .return

.return:
	pop bp
	pop si
	pop dx
	pop cx
	pop bx

	ret


fs_find_free_sector:
; IN:  ax: physical sector for which we search
;
; OUT: ax: free physical sector number
; OUT: cf: on error or no free sector found

	push bx
	push cx
	push dx
	push si

	; We will look for a free sector, but the search is mainly done for
	; a sector that is already taken. So to speed up the search and
	; limit the fragmentation, we'll start the search just after the old
	; sector, and if we find nothing, we'll continue the search before it

	mov bx, ax                  ; Save the first sector in bx

	mov cx, Sectors             ; Let cx contain the number of sectors
	sub cx, bx                  ; after ax

	jmp short .continue_after   ; Start the following loop,
	                            ; but in the middle
.loop_after:
	mov dx, ax                  ; Save  the old sector in dx
	call fs_get_next_sector     ; Get the value of the FAT entry no. ax
	xchg ax, dx                 ; Save old sect. in ax and the value in dx

	jnc short .continue_after   ; If the value was above the max. allowed
	                            ; then it's not the sector we want
	cmp dx, 0                   ; Is the sector free?
	je short .found             ; If so, we got it
.continue_after:
	inc ax                      ; Otherwise increase the sector number
	loop .loop_after            ; And repeat the loop if sectors are left

	; If we're here, it means no free sector was found after ax,
	; now we'll search before it

	mov ax, FirstDataSector
	mov cx, bx                  ; Make cx contain the number of sectors
	sub cx, FirstDataSector     ; before the sector ax.
.loop_before:
	mov dx, ax                  ; Save  the old sector in dx
	call fs_get_next_sector     ; Get the value of the FAT entry no. ax
	xchg ax, dx                 ; Save old sect. in ax and the value in dx

	jnc short .continue_before  ; If the value was above the max. allowed
	                            ; then it's not the sector we want
	cmp dx, 0                   ; Is the sector free?
	je short .found             ; If so, we got it
.continue_before:
	inc ax                      ; Otherwise increase the sector number
	loop .loop_before           ; And repeat the loop if sectors are left

	; If we're here, it means no free sector was found at all,
	; so we must return an error

.error:
	stc
	jmp short .return

.found:
	clc
.return:
	pop si
	pop dx
	pop cx
	pop bx


fs_set_fat_entry:
; IN:  ax: physical sector
; IN:  bx: new FAT entry value
;
; OUT: sector ax is attached bx as its value
;      in the FAT table

	push ax
	push bx
	push cx
	push dx
	push si

	sub ax, 31                  ; Convert ax to FAT entry number

	; Now we're going to convert the FAT entry number to the pointer
	; of that entry. Since every entry occupies 3/2 of a byte, we'll
	; first multiply ax by 3 and then divide by 2.

	mov dx, 0
	mov cx, 3
	mul cx

	mov dx, 0
	mov cx, 2
	div cx

	; Now dx contains important information: the parity of the
	; entry number, which affects the way we'll mask the 3/2 of a byte
	; before updating its value.

	mov si, fat_buffer
	add si, ax
	mov ax, word [si]           ; Move the unmasked entry value to ax

	cmp dx, 0                   ; Was the record even?
	je short .even_record
.odd_record:                        ; Masking for odd records
	and ax, 0000Fh
	shl bx, 4                   ; Shift bx to fit the record
	and bx, 0FFF0h
	jmp short .insert

.even_record:                       ; Masking for even records
	and ax, 0F000h
	and bx, 00FFFh
.insert:
	or ax, bx                   ; Insert bx to the register
	mov word [si], ax           ; Insert the register in the FAT buffer

	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	ret


fs_set_next_sector:
; IN:  ax: physical sector
; IN:  bx: next physical sector
;
; OUT: sector ax is attached bx as its next sector
;      in the FAT table

	; We're going to do the same job the routine fs_set_fat_entry does,
	; only here we assume the value in bx is a sector number, not the
	; value that we're expected to directly insert into FAT.

	push bx
	sub bx, 31                  ; Convert bx to FAT entry number
	call fs_set_fat_entry
	pop bx

	ret


fs_get_next_sector:
; IN:  ax: current physical sector
; IN:      FAT table in the buffer
;
; OUT: ax: next physical sector
; OUT: cf: set if no next sector

	push bx
	push cx
	push dx
	push si

	; Now we're going to convert the FAT entry number to the pointer
	; of that entry. Since every entry occupies 3/2 of a byte, we'll
	; first multiply ax by 3 and then divide by 2.


	sub ax, 31                  ; Convert ax to FAT entry number
	mov bx, ax                  ; Save ax in bx for later

	; Now we're going to convert the FAT entry number to the pointer
	; of that entry. Since every entry occupies 3/2 of a byte, we'll
	; first multiply ax by 3 and then divide by 2.

	mov dx, 0
	mov cx, 3
	mul cx

	mov dx, 0
	mov cx, 2
	div cx

	; Now dx contains important information: the parity of the
	; entry number, which affects the way we'll unpack the 3/2 of a byte
	; when moving it to a register.

	mov si, fat_buffer
	add si, ax
	mov ax, [si]                ; Move the unmasked entry value to ax

	cmp dx, 0
	je short .even_record       ; Was the sector even?
.odd_record:                        ; Masking for odd records
	shr ax, 4
	jmp short .check
.even_record:                       ; Masking for even records
	and ax, 0FFFh
.check:
	cmp ax, 0FF0h               ; Is it the last sector in the chain?
	jae short .error
	cmp ax, 0001                ; Is it a free sector?
	jna short .error

	add ax, 31                  ; Convert ax to a physical sector number

	clc
	jmp short .return

.error:
	stc
.return:
	pop si
	pop dx
	pop cx
	pop bx

	ret


fs_read_sectors:
; IN: ax:    physical sector
; IN: es:bx: destination
; IN: cl:    sector count

	; The code in this routine is simply an interface between
	; the kernel and BIOS services.

	pusha

	push cx
	call fs_ltolhs              ; Convert physical adressing to a format
	pop ax                      ; expected by BIOS

	mov ah, 2h
.try:
	stc
	int 13h
	jnc .continue ; no need to retry

	call fd_reset_disk          ; If there's an error when reading sectors
	jc os_fatal_error           ; we'll try reseting the disk once.
	jmp .try
.continue:
	popa
	ret


fs_write_sectors:
; IN: ax:    physical sector
; IN: es:bx: source
; IN: cl:    sector count

	; The code in this routine is simply an interface between
	; the kernel and BIOS services.

	pusha

	push cx
	call fs_ltolhs              ; Convert physical adressing to a format
	pop ax                      ; expected by BIOS

	mov ah, 3h
.try:
	stc
	int 13h
	jnc .continue ; no need to retry

	call fd_reset_disk          ; If there's an error when reading sectors
	jc os_fatal_error           ; we'll try reseting the disk once.
	jmp .try
.continue:
	popa
	ret


fs_ltolhs:
	; IN:  ax:     physical sector
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

	; The code in this routine is simply an interface between
	; the kernel and BIOS services.

	push ax
	push dx
	mov ah, 0
	mov dl, [fs_device]
	stc
	int 13h
	pop dx
	pop ax

	ret                         ; The carry will be set on error

; variables
	fs_device db 0
