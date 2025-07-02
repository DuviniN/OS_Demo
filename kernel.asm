; ==================================================================
; TestOS -- An Operating System kernel written in Assembly
; by Duvini Nimethra. This OS is inspired by MikeOS.
; Extended by ChatGPT: added reboot, shutdown, time, and about commands
; ==================================================================

    BITS 16
    ORG 0000h

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    call clear_screen
    mov si, welcome_string
    call print_string
    call print_newline

main_loop:
    call print_newline
    mov si, prompt_string
    call print_string

    mov di, command_buffer
    call read_string

    mov si, command_buffer
    mov di, info_cmd
    call string_compare
    je handle_info_cmd

    mov si, command_buffer
    mov di, help_cmd
    call string_compare
    je handle_help_cmd

    mov si, command_buffer
    mov di, clear_cmd
    call string_compare
    je handle_clear_cmd

    mov si, command_buffer
    mov di, reboot_cmd
    call string_compare
    je handle_reboot_cmd

    mov si, command_buffer
    mov di, about_cmd
    call string_compare
    je handle_about_cmd

    mov si, unknown_cmd_string
    call print_newline
    call print_string
    jmp main_loop

handle_info_cmd:
    call show_hardware_info
    jmp main_loop

handle_help_cmd:
    call print_newline
    mov si, help_menu_string
    call print_string
    call print_newline
    jmp main_loop

handle_clear_cmd:
    call clear_screen
    jmp main_loop

handle_reboot_cmd:
    mov ax, 0x40
    mov es, ax
    mov word [es:72], 0x1234  ; Warm reboot flag
    jmp 0FFFFh:0  ; Far jump to BIOS reset

handle_about_cmd:
    call print_newline
    mov si, about_string
    call print_string
    call print_newline
    jmp main_loop

; ==================================================================
; MAIN HARDWARE INFO ROUTINE
; ==================================================================

show_hardware_info:
    pusha
    call print_newline
    call detect_memory
    call detect_cpu
    call detect_drives
    call detect_mouse
    call detect_serial_ports
    call detect_cpu_features
    popa
    ret

; --- Specialized Detection Subroutines ---

detect_memory:
    ; --- Base Memory ---
    mov si, mem_base_label
    call print_string
    int 12h             ; Returns base memory size in KB in AX
    mov [base_mem_kb], ax
    call print_decimal
    call print_k_suffix

    ; --- Extended Memory (1M - 16M) ---
    mov si, mem_ext_label
    call print_string
    mov ah, 0x88
    int 0x15            ; Returns extended memory in KB in AX
    mov [ext_mem_kb], ax
    call print_decimal
    call print_k_suffix

    ; --- Extended Memory (Above 16M) ---
    mov si, mem_ext2_label
    call print_string
    mov ax, 0xE801
    int 0x15
    jc .no_e801         ; Jump if this function is not supported
    mov [ext2_mem_16k_blocks], cx   ; CX/DX has mem > 16M in 16KB blocks
    mov [ext2_mem_64k_blocks], dx
    ; For simplicity, we'll use the 64KB block value. Convert to MB (DX / 16)
    mov dx, 0
    mov ax, [ext2_mem_64k_blocks]
    mov cx, 16
    div cx
    mov [ext2_mem_mb], ax
    call print_decimal
    call print_M_suffix
    jmp .sum_total

	.no_e801:
		mov si, not_supported_str
		call print_string
		mov word [ext2_mem_mb], 0

		; --- Total Memory ---
	.sum_total:
		mov si, mem_total_label
		call print_string

		; Calculate total KB first using EAX for 32-bit arithmetic
		mov eax, 0                      ; Clear EAX for total KB
		movzx ebx, word [base_mem_kb]   ; Load base_mem_kb into EBX (zero-extended)
		add eax, ebx                    ; Add to EAX

		movzx ebx, word [ext_mem_kb]    ; Load ext_mem_kb into EBX (zero-extended)
		add eax, ebx                    ; Add to EAX. EAX now holds (base_mem_kb + ext_mem_kb) in KB.

		; Convert ext2_mem_mb to KB and add to the running total in EAX
		movzx ebx, word [ext2_mem_mb]   ; Load ext2_mem_mb (in MB) into EBX
		mov ecx, 1024                   ; Multiplier for MB to KB
		imul ebx, ecx                   ; EBX = EBX * ECX (ext2_mem_mb * 1024) -> EBX now holds ext2_mem_kb
		add eax, ebx                    ; Add ext2_mem_kb (now in EBX) to total KB in EAX

		; Now convert total KB in EAX to MB for printing
		mov edx, 0                      ; Clear EDX for 32-bit division
		mov ecx, 1024                   ; Divisor
		div ecx                         ; EAX = EAX / ECX (total KB / 1024). Result (MB) is in EAX.
										; EDX will contain remainder (not needed for printing MB).
		
		call print_decimal              ; Print the final value in EAX (total MB)
		call print_M_suffix
		ret

detect_cpu:
    ; --- CPU Vendor ---
    mov si, cpu_vendor_label
    call print_string
    mov eax, 0
    cpuid
    mov [cpu_vendor_str+0], ebx
    mov [cpu_vendor_str+4], edx
    mov [cpu_vendor_str+8], ecx
    mov si, cpu_vendor_str
    call print_string
    call print_newline

    ; --- CPU Brand String ---
    mov si, cpu_desc_label
    call print_string
    mov eax, 0x80000002
    cpuid
    mov [cpu_type_str+0], eax
    mov [cpu_type_str+4], ebx
    mov [cpu_type_str+8], ecx
    mov [cpu_type_str+12], edx
    mov eax, 0x80000003
    cpuid
    mov [cpu_type_str+16], eax
    mov [cpu_type_str+20], ebx
    mov [cpu_type_str+24], ecx
    mov [cpu_type_str+28], edx
    mov eax, 0x80000004
    cpuid
    mov [cpu_type_str+32], eax
    mov [cpu_type_str+36], ebx
    mov [cpu_type_str+40], ecx
    mov [cpu_type_str+44], edx
    mov si, cpu_type_str
    call print_string
    call print_newline
    ret

detect_drives:
    mov si, hdd_label
    call print_string
    push es
    mov ax, 0x0040
    mov es, ax
    mov al, [es:0x0075]     ; BIOS Data Area holds number of HDDs in one byte
    mov ah, 0               ; Clear the upper byte of AX to prevent garbage
    pop es
    call print_decimal      ; Print the correct value from AX
    call print_newline
    ret

detect_mouse:
    mov si, mouse_label
    call print_string
    mov ax, 0               ; Setting AX to 0000h selects Function 0(Initialize Mouse System) for the BIOS Mouse Services(0x33)
    int 0x33                ; Call BIOS interrupt to detect mouse
    cmp ax, 0
    je .no_mouse
    mov si, mouse_found_str
    call print_string
    jmp .mouse_done

	.no_mouse:
		mov si, mouse_notfound_str
		call print_string

	.mouse_done:
		call print_newline
		ret

detect_serial_ports:
    mov si, serial_count_label
    call print_string
    push es
    mov ax, 0x0040
    mov es, ax
    mov cx, 0
    mov si, 0
	.loop:
		mov dx, [es:si]
		cmp dx, 0
		je .next
		inc cx
	.next:
		add si, 2
		cmp si, 8
		jne .loop
		mov ax, cx
		call print_decimal
		call print_newline
		mov si, serial_addr_label
		call print_string
		mov ax, [es:0]
		pop es
		call print_decimal
		call print_newline
		ret

detect_cpu_features:
    mov si, features_label
    call print_string
    mov eax, 1
    cpuid
    mov [feature_flags_edx], edx
    test edx, 1 << 0
    jz .no_fpu
    mov si, fpu_str
    call print_string
	.no_fpu:
		test edx, 1 << 23
		jz .no_mmx
		mov si, mmx_str
		call print_string
	.no_mmx:
		test edx, 1 << 25
		jz .no_sse
		mov si, sse_str
		call print_string
	.no_sse:
		test edx, 1 << 26
		jz .no_sse2
		mov si, sse2_str
		call print_string
	.no_sse2:
		call print_newline
		ret

; ==================================================================
; HELPER & KERNEL SUBROUTINES
; ==================================================================
print_string:
    mov ah, 0Eh		; AH+AL=AX. We use 0Eh to print characters in teletype mode
	.repeat:
		lodsb		; Load byte at DS:SI into AL and increment SI
		cmp al, 0	; Check if that character is null (end of string)
		je .done	
		int 10h		; Print character in AL
		jmp .repeat
	.done:
		ret

print_newline:
    push ax			; Saves the current value of the AX register onto the stack
    mov ah, 0Eh		; AH+AL=AX. We use 0Eh to print characters in teletype mode
    mov al, 0Dh		; 0Dh is the ASCII value for "Carriage Return" (CR). Moves the cursor to the beginning of the current line.
    int 10h			; Print character in AL
    mov al, 0Ah		; 0Ah is the ASCII value for "Line Feed" (LF). Moves the cursor down one line.
    int 10h
    pop ax			; Restores the value of the AX register from the stack
    ret				; Returns from the subroutine

print_k_suffix:	
    pusha					; Saves the current values of all general-purpose 16-bit registers onto the stack.
    mov si, k_str			; Load the address of the 'k' string into SI
    call print_string	
    call print_newline
    popa					; Restores the values of all general-purpose 16-bit registers from the stack.	
    ret

print_M_suffix:
    pusha
    mov si, M_str
    call print_string
    call print_newline
    popa
    ret

read_string:
    pusha
    mov bx, di				; Need for backspace handling to prevent deleting characters before the buffer's beginning.
	.read_loop:
		mov ah, 00h 		; BIOS function to read a character from the keyboard of BIOS Interrupt 16h
		int 16h			 	; AL contains the ASCII code of the key pressed, and AH contains the scan code of the key.
		cmp al, 0Dh			; 0Dh is the ASCII value for "Carriage Return" (Enter key)
		je .done_reading
		cmp al, 08h			; 08h is the ASCII value for "Backspace" key
		je .backspace
		mov [di], al		; Store the character in the buffer at DI
		mov ah, 0Eh
		int 10h				; Print the character on the screen
		inc di			 	; Increment DI to point to the next position in the buffer
		jmp .read_loop

	.backspace:
		cmp di, bx			; Check if DI is at the start of the buffer
		je .read_loop
		dec di			    ; Move DI back to the previous character
		mov byte [di], 0	; Clear the character from the buffer
		mov ah, 0Eh			; AH+AL=AX. We use 0Eh to print characters in teletype mode
		mov al, 08h			; 08h is the ASCII value for "Backspace" key
		int 10h
		mov al, ' '
		int 10h
		mov al, 08h			; After printing the space, the cursor has moved one position right. 
		int 10h				; We need to move it back to the left so that the next character typed appears correctly.
		jmp .read_loop

	.done_reading:
		mov byte [di], 0	; Null-terminate the string in the buffer
		popa				; Restore the values of all general-purpose 16-bit registers from the stack.
		ret

string_compare:
    pusha

	.loop:
		mov al, [si]        ; Here SI points to the command buffer
		mov ah, [di]        ; Here DI points to the command to compare such as "info", "help", etc.
		cmp al, ah
		jne .notequal
		cmp al, 0           ; Check if we reached the end of the both string. Which means they are completely equal.
		je .equal
		inc si              ; Increment SI to point to the next character in the command buffer
		inc di              ; Increment DI to point to the next character in the command to compare
		jmp .loop
	.notequal:

		popa
		cmp ax, bx          ; Set the ZF if the strings are not equal (0). This helps to execute "je handle_info_cmd" and etc.
		ret

	.equal:
		popa
		cmp ax, ax          ; Set the ZF if the strings are equal (1). This helps to execute "je handle_info_cmd" and etc.
		ret

print_decimal:              
    pusha
    mov cx, 0               ; Use this to count how many digits we push onto the stack.
    mov ebx, 10             ; EBX will serve as the divisor(10)
	.div_loop:
		mov edx, 0          ; Clears the EDX
		div ebx             ; Divide EDX by EBX, The result of the division is stored in EAX, remainder is stored in EDX
		push edx            ; Push remainder(current) onto the stack
		inc cx              ; Increment the digit count
		cmp eax, 0          
		jne .div_loop
	.print_loop:
		pop eax             ; Pop a digit into EAX
		add al, '0'         ; Convert the digit to ASCII by adding '0'
		mov ah, 0Eh
		int 10h
		loop .print_loop    ; Loop until all digits are printed
		popa                
		ret

clear_screen:
    pusha
    mov ah, 0x00        
    mov al, 0x03        
    int 10h             
    popa
    ret


welcome_string      db 'Welcome to TestOS by Duvini Nimethra!', 0
prompt_string       db 'TestOS>> ', 0
unknown_cmd_string  db 'Unknown command', 0
info_cmd            db 'info', 0
help_cmd            db 'help', 0                  
clear_cmd           db 'clear', 0  
reboot_cmd          db 'reboot', 0
about_cmd           db 'about', 0
about_string        db 'TestOS v1.1 by Duvini Nimethra',0
help_menu_string    db 'info - Hardware Info',0Dh,0Ah,'clear - Clear screen',0Dh,0Ah,'reboot - Reboot system',0Dh,0Ah,'about - About this OS',0Dh,0Ah,0

mem_base_label      db 'Base Memory size: ', 0
mem_ext_label       db 'Extended memory between (1M - 16M): ', 0
mem_ext2_label      db 'Extended memory above 16M: ', 0
mem_total_label     db 'Total memory: ', 0

cpu_vendor_label    db 'CPU Vendor: ', 0
cpu_desc_label      db 'CPU description: ', 0
hdd_label           db 'Number of hard drives: ', 0
mouse_label         db 'Mouse Status: ', 0
serial_count_label  db 'Number of serial port: ', 0
serial_addr_label   db 'Base I/O address for serial port 1: ', 0
features_label      db 'CPU Features: ', 0

mouse_found_str     db 'The Mouse Found', 0
mouse_notfound_str  db 'Not Found', 0
not_supported_str   db 'Not Supported', 0

k_str               db 'k', 0			
M_str               db 'M', 0			
fpu_str             db 'FPU ', 0
mmx_str             db 'MMX ', 0
sse_str             db 'SSE ', 0
sse2_str            db 'SSE2 ', 0

command_buffer      times 64 db 0		
cpu_vendor_str      times 13 db 0
cpu_type_str        times 49 db 0

base_mem_kb         dw 0				
ext_mem_kb          dw 0
ext2_mem_16k_blocks dw 0
ext2_mem_64k_blocks dw 0
ext2_mem_mb         dw 0
feature_flags_edx   dd 0
