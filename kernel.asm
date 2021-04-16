	bits 16

	jmp os_start              ; Jump over the system call jumps

; System call vector:

	; System call name        ; Index
	jmp fs_open_read          ; 3*1
	jmp fs_open_write         ; 3*2
	jmp fs_read               ; 3*3
	jmp fs_write              ; 3*4
	jmp fs_close              ; 3*5
	jmp fs_create_file        ; 3*6
	jmp fs_remove_file        ; 3*7
	jmp fs_rename_file        ; 3*8
	jmp fs_find_file          ; 3*9
	jmp string_compare        ; 3*10
	jmp string_difference     ; 3*11
	jmp string_copy           ; 3*12
	jmp string_parse          ; 3*13
	jmp string_to_int         ; 3*14
	jmp string_int_to         ; 3*15
	jmp string_find_char      ; 3*16
	jmp string_length         ; 3*17
	jmp string_reverse        ; 3*18
	jmp string_char_isbetween ; 3*19
	jmp string_char_iswhite   ; 3*20
	jmp string_char_isdigit   ; 3*21
	jmp string_char_isalpha   ; 3*22
	jmp string_char_islower   ; 3*23
	jmp string_char_isupper   ; 3*24
	jmp ui_write_char         ; 3*25
	jmp ui_write_newline      ; 3*26
	jmp ui_write_lim_string   ; 3*27
	jmp ui_write_string       ; 3*28
	jmp ui_write_int          ; 3*29
	jmp ui_read_string        ; 3*30
	jmp ui_hide_cursor        ; 3*31
	jmp ui_set_std_cursor     ; 3*32
	jmp ui_set_box_cursor     ; 3*33
	jmp ui_move_cursor        ; 3*34
	jmp ui_clear_screen       ; 3*35

os_start:
; IN: al: device number from bootloader

	cld

	cli                         ; Disallow interrupts, as we're altering stack
	mov bx, 1000h
	mov ss, bx
	mov sp, 0FFFFh
	sti                         ; Allow interrupts

	mov bx, os_kernel_base      ; Set all segments to kernel segment
	mov ds, bx
	mov es, bx
	mov fs, bx
	mov gs, bx

	mov [fs_device], al         ; Save our disk number

init:
	call fs_read_fat            ; Initialize FAT buffer
	call fs_read_root           ; Initialize root directory buffer
	call fs_init_buffers        ; Initialize file buffers
welcome:
	call ui_clear_screen

	mov si, os_kernel_size      ; Show current kernel size
	call ui_write_string

	mov ax, kernel_end          ; The adress of the end of kernel space
	call ui_write_int           ; equals its size in memory
	call ui_write_newline

	mov si, os_memory_size      ; Show current memory size
	call ui_write_string

	int 12h                     ; Get memory size
	call ui_write_int

	call ui_write_newline
	call ui_write_newline
readcmd:
	mov si, os_prompt           ; Print shell prompt
	call ui_write_string

	mov di, os_input            ; Wait for a command
	call ui_read_string

	mov si, di                  ; Cut the first word of the command
	call string_parse           ; make di point to it
	mov ax, si                  ; Save the adress of the rest in ax

	mov si, os_cmd_none         ; Is the command empty?
	call string_compare
	je readcmd                  ; If so, await another

	mov si, os_cmd_mv           ; Is it the mv command?
	call string_compare
	mov si, ax                  ; Save the cmd args in si
	je cmd_mv                   ; And if it is, jump to command's routine

	mov si, os_cmd_cp           ; Is it the cp command?
	call string_compare
	mov si, ax                  ; Save the cmd args in si
	je cmd_cp                   ; And if it is, jump to command's routine

	mov si, os_cmd_ls           ; Is it the ls command?
	call string_compare
	mov si, ax                  ; Save the cmd args in si
	je cmd_ls                   ; And if it is, jump to command's routine

	mov si, os_cmd_type         ; Is it the type command?
	call string_compare
	mov si, ax                  ; Save the cmd args in si
	je cmd_type                 ; And if it is, jump to command's routine

	mov si, os_cmd_clear        ; Is it the clear command?
	call string_compare
	mov si, ax                  ; Save the cmd args in si
	je cmd_clear                ; And if it is, jump to command's routine

	mov si, os_cmd_mk           ; Is it the mk command?
	call string_compare
	mov si, ax                  ; Save the cmd args in si
	je cmd_mk                   ; And if it is, jump to command's routine

	mov si, os_cmd_rm           ; Is it the rm command?
	call string_compare
	mov si, ax                  ; Save the cmd args in si
	je cmd_rm                   ; And if it is, jump to command's routine

	; If we're here, none of the above worked
	; so the user probably wants to run an external program

	jmp cmd_run                 ; Run the external program

	jmp short readcmd           ; Loop


cmd_mv:
	call string_parse           ; Save the first arg in ax
	jc short .arg_error         ; If not given, complain
	mov ax, di

	call string_parse           ; Save the second in bx
	jc short .arg_error         ; If not given, complain
	mov bx, di

	mov si, ax                  ; Find the file of the name in ax
	mov di, bx                  ; And rename it with a string under bx
	call fs_rename_file
	jc short .rename_error      ; If something went wrong, communicate it

	jmp readcmd                 ; Return to the main shell loop

.arg_error:
	mov si, .arg_msg
	call ui_write_string

	jmp readcmd                 ; Return to the main shell loop

.rename_error:
	mov si, .rename_msg
	call ui_write_string

	jmp readcmd                 ; Return to the main shell loop

	.arg_msg    db `mv: usage: filename [old name] [new name]\n`, 0
	.rename_msg db `mv: could not rename the file\n`, 0


cmd_cp:
	call string_parse           ; Save the first arg in bx
	jc short .arg_error         ; If not given, complain
	mov bx, di

	call string_parse           ; Save the second in dx
	jc short .arg_error         ; If not given, complain
	mov dx, di

	mov si, bx                  ; Open the first file in read mode
	call fs_open_read
	jc short .file_error        ; If something went wrong, communicate it
	mov bx, ax

	mov si, dx                  ; Remove the destination file if it existed
	call fs_remove_file         ; Don't mind errors; there may be no such file

	call fs_open_write          ; Open the destination file in write mode
	jc short .file_error        ; If there was an error, communicate it
	mov dx, ax                  ; Save the file descriptor in dx

	mov si, .buf                ; Make di and si point to the local buffer,
	mov di, .buf                ; we'll use it to rewrite the file content
.loop:
	mov ax, bx                  ; Read .length bytes from the source file
	mov cx, .length             ; and save them in the buffer
	call fs_read

	cmp cx, 0                   ; If we've read 0 bytes, stop copying
	je short .close

	mov ax, dx                  ; Write the bytes we've just read to the
	call fs_write               ; destination file
	jc .write_error

	jmp short .loop             ; Repeat

.close:
	mov ax, bx                  ; Close the source file
	call fs_close

	mov ax, dx                  ; Close the destination file
	call fs_close

	jmp readcmd                 ; Go back to the main shell routine

.arg_error:
	mov si, .arg_msg
	call ui_write_string

	jmp .close

.write_error:
	mov si, .write_msg
	call ui_write_string

	jmp .close

.file_error:
	mov ax, si

	mov si, .file_msg
	call ui_write_string

	mov si, ax
	call ui_write_string

	call ui_write_newline

	jmp .close

	.arg_msg   db `cp: not enough arguments given\n`, 0
	.file_msg  db `cp: could not open file: `, 0
	.write_msg db `cp: a write error occured during copying\n`, 0

	.buf  times 32 db 0
	.length equ 32


cmd_ls:
	mov si, root_buffer         ; Start browsing the root firectory
	mov cx, MaxRootEntries
.loop:
	cmp byte [si], 000h         ; Is it the last entry in the dir?
	je readcmd                  ; If so, return to the main routine
	cmp byte [si], 0E5h         ; Is it empty but not last?
	je short .skip              ; If so, skip it

	mov di, .filename           ; But if it isn't empty, convert
	call fs_tag_to_filename     ; file's tag to its user-friendly name

	xchg si, di                 ; Move di to si, and save si in di
	call ui_write_string        ; Print the converted name
	xchg si, di                 ; Get the original si back

	call ui_write_newline       ; Print a newline after the end of each name
.skip:
	call fs_next_file           ; Increment si by the size of a directory entry

	loop .loop                  ; If any files are left, repeat
	jmp readcmd                 ; Otherwise ask for a next command

	.filename times 13 db 0


cmd_run:
	mov cx, si                  ; Save the program arguments pointer

	mov si, di                  ; Save the requested program's name
	mov di, .filename
	call string_copy

	call string_length          ; Get the length of the name
	add di, ax

	mov si, .ext                ; Make si point to the default program extension
	call string_copy            ; and append the program name with it

	mov si, .filename           ; Check if the program's file exists
	call fs_find_file
	jc .no_file_error           ; If no, communicate it

	; But otherwise

	mov bx, 5000h               ; Load the programs contents under 5000h
	call fs_read_file

	mov si, cx                  ; Save cmd args string in si, for program's usage
	call 5000h                  ; Jump where the program's code was loaded

	jmp readcmd                 ; After it finished, get a next command

.no_file_error:
	call ui_write_string

	mov si, .no_file
	call ui_write_string

	jmp readcmd

	.no_file     db `: program not found\n`, 0
	.ext         db `.prg`, 0
	.filename    times 15 db 0


cmd_type:
	call string_parse           ; Get the first argument
	jc .no_argument_error       ; If not given, complain
	mov si, di

	call fs_open_read           ; Open the file for reading
	jc short .no_file_error

	mov di, .buffer             ; Save local buffer address to di and si
	mov si, .buffer
.loop:
	mov cx, 32                  ; Read 32 bytes of the file
	call fs_read                ; saving them in the buffer
	jc short .last              ; If there was an error, assume little was left

	; At this poin cx contains the number of bytes actually read,
	; ideally for ui_write_lim_string

	call ui_write_lim_string    ; Now print the contents of the buffer

	jmp short .loop

.last:
	call ui_write_lim_string    ; Write the last portion of bytes

	call fs_close               ; Close the file

	jmp readcmd                 ; Read the next command

.no_file_error:
	mov si, .no_file
	call ui_write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call ui_write_string

	jmp readcmd

	.no_file     db `type: file not found\n`, 0
	.no_argument db `type: usage: type filename\n`, 0
	.buffer      times 32 db 0


cmd_mk:
	call string_parse           ; Get the first argument
	jc .no_argument_error       ; If not given, complain

	mov si, di                  ; Otherwise save its pointer in si
	call fs_create_file         ; Create the file
	jc short .cant_make_error   ; If cannot be done, communicate it

	jmp readcmd                 ; Read the next command

.cant_make_error:
	mov si, .cant_make
	call ui_write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call ui_write_string

	jmp readcmd

	.cant_make   db `mk: could not create\n`, 0
	.no_argument db `mk: usage: mk filename\n`, 0


cmd_rm:
	call string_parse           ; Get the first argument
	jc .no_argument_error       ; If not given, complain

	mov si, di                  ; Otherwise remove it
	call fs_remove_file
	jc short .cant_remove_error ; If cannot be done, communicate it

	jmp readcmd                 ; Read the next command

.cant_remove_error:
	mov si, .cant_remove
	call ui_write_string

	jmp readcmd

.no_argument_error:
	mov si, .no_argument
	call ui_write_string

	jmp readcmd

	.cant_remove db `mk: could not remove\n`, 0
	.no_argument db `mk: usage: mk filename\n`, 0


cmd_clear:
	call ui_clear_screen        ; There's a routine for that

	jmp readcmd                 ; Read the next command


os_fatal_error:
	mov si, .error
	call ui_write_string
	jmp $

	.error db `kernel fatal error, halting.\n`, 0


; variables
	os_kernel_base equ 2000h

	os_newline db 10, 0
	os_prompt  db "% ", 0
	os_input   times 160 db 0
	os_output  times 80 db 0

	os_memory  dw 0

	os_cmd_unknown db `unknown command\n`, 0
	os_cmd_none    db "", 0
	os_cmd_cp      db "cp", 0
	os_cmd_ls      db "ls", 0
	os_cmd_mk      db "mk", 0
	os_cmd_mv      db "mv", 0
	os_cmd_rm      db "rm", 0
	os_cmd_run     db "run", 0
	os_cmd_clear   db "clear", 0
	os_cmd_type    db "type", 0

	os_kernel_size db `Kernel size:  `, 0
	os_memory_size db `KB of memory: `, 0


%INCLUDE "fs.asm"
%INCLUDE "string.asm"
%INCLUDE "ui.asm"

; memory management and kernel buffer
; (must be included as last)
; INCLUDE "mem.asm"

fs_buffer_index:
fat_buffer  equ fs_buffer_index+MaxOpenFiles*fs_buffer.size
root_buffer equ fat_buffer+9*512 ; (size of FAT in the buffer)
kernel_end  equ root_buffer+14*512
