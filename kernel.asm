 ; ===============================
;  TestOS v1.1
;  By Duvini Nimethra
; ===============================

[BITS 16]
[ORG 0x7C00]

boot_start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    call scr_clear
    mov si, msg_welcome
    call puts
    call newline

cmd_loop:
    call newline
    mov si, msg_prompt
    call puts

    mov di, input_buf
    call getline

    mov si, input_buf
    mov di, cmd_info
    call str_equal
    je do_info

    mov si, input_buf
    mov di, cmd_help
    call str_equal
    je do_help

    mov si, input_buf
    mov di, cmd_clear
    call str_equal
    je do_clear

    mov si, input_buf
    mov di, cmd_reboot
    call str_equal
    je do_reboot

    mov si, input_buf
    mov di, cmd_about
    call str_equal
    je do_about

    ; if no command matched
    call newline
    mov si, msg_unknown
    call puts
    jmp cmd_loop


; ------------------------
; Command Handlers
; ------------------------

do_info:
    call hw_info
    jmp cmd_loop

do_help:
    call newline
    mov si, msg_help
    call puts
    call newline
    jmp cmd_loop

do_clear:
    call scr_clear
    jmp cmd_loop

do_reboot:
    mov ax, 0x40
    mov es, ax
    mov word [es:72], 0x1234
    jmp 0FFFFh:0

do_about:
    call newline
    mov si, msg_about
    call puts
    call newline
    jmp cmd_loop


; ------------------------
; Hardware Info
; ------------------------

hw_info:
    pusha
    call newline
    call mem_info
    call cpu_info
    call drive_info
    call mouse_info
    call serial_info
    call cpu_features
    popa
    ret


; --- Memory ---
mem_info:
    mov si, str_mem_base
    call puts
    int 12h
    mov [var_base_kb], ax
    call print_num
    mov si, str_k
    call puts
    call newline

    mov si, str_mem_ext
    call puts
    mov ah, 0x88
    int 15h
    mov [var_ext_kb], ax
    call print_num
    mov si, str_k
    call puts
    call newline

    mov si, str_mem_high
    call puts
    mov ax, 0xE801
    int 15h
    jc .no_e801
    mov [var_ext16], cx
    mov [var_ext64], dx

    mov dx, 0
    mov ax, [var_ext64]
    mov cx, 16
    div cx
    mov [var_mem_mb], ax
    call print_num
    mov si, str_M
    call puts
    call newline
    jmp .sum

.no_e801:
    mov si, str_not_sup
    call puts
    mov word [var_mem_mb], 0
    call newline

.sum:
    mov si, str_mem_total
    call puts

    xor eax, eax
    movzx ebx, word [var_base_kb]
    add eax, ebx
    movzx ebx, word [var_ext_kb]
    add eax, ebx
    movzx ebx, word [var_mem_mb]
    imul ebx, 1024
    add eax, ebx

    xor edx, edx
    mov ecx, 1024
    div ecx

    call print_num
    mov si, str_M
    call puts
    call newline
    ret


; --- CPU Vendor + Desc ---
cpu_info:
    mov si, str_cpu_vendor
    call puts
    xor eax, eax
    cpuid
    mov [buf_vendor+0], ebx
    mov [buf_vendor+4], edx
    mov [buf_vendor+8], ecx
    mov si, buf_vendor
    call puts
    call newline

    mov si, str_cpu_desc
    call puts
    mov eax, 0x80000002
    cpuid
    mov [buf_cpu+0], eax
    mov [buf_cpu+4], ebx
    mov [buf_cpu+8], ecx
    mov [buf_cpu+12], edx
    mov eax, 0x80000003
    cpuid
    mov [buf_cpu+16], eax
    mov [buf_cpu+20], ebx
    mov [buf_cpu+24], ecx
    mov [buf_cpu+28], edx
    mov eax, 0x80000004
    cpuid
    mov [buf_cpu+32], eax
    mov [buf_cpu+36], ebx
    mov [buf_cpu+40], ecx
    mov [buf_cpu+44], edx
    mov si, buf_cpu
    call puts
    call newline
    ret


; --- Drives ---
drive_info:
    mov si, str_hdd
    call puts
    push es
    mov ax, 0x40
    mov es, ax
    mov al, [es:0x75]
    xor ah, ah
    pop es
    call print_num
    call newline
    ret


; --- Mouse ---
mouse_info:
    mov si, str_mouse
    call puts
    xor ax, ax
    int 33h
    cmp ax, 0
    je .no_mouse
    mov si, str_mouse_found
    call puts
    jmp .done

.no_mouse:
    mov si, str_mouse_none
    call puts

.done:
    call newline
    ret


; --- Serial Ports ---
serial_info:
    mov si, str_serial_count
    call puts
    push es
    mov ax, 0x40
    mov es, ax
    xor cx, cx
    xor si, si
.loop:
    mov dx, [es:si]
    cmp dx, 0
    je .skip
    inc cx
.skip:
    add si, 2
    cmp si, 8
    jne .loop
    mov ax, cx
    call print_num
    call newline

    mov si, str_serial_addr
    call puts
    mov ax, [es:0]
    pop es
    call print_num
    call newline
    ret


; --- CPU Features ---
cpu_features:
    mov si, str_features
    call puts
    mov eax, 1
    cpuid
    mov [var_feat], edx
    test edx, 1<<0
    jz .fpu_done
    mov si, str_fpu
    call puts
.fpu_done:
    test edx, 1<<23
    jz .mmx_done
    mov si, str_mmx
    call puts
.mmx_done:
    test edx, 1<<25
    jz .sse_done
    mov si, str_sse
    call puts
.sse_done:
    test edx, 1<<26
    jz .sse2_done
    mov si, str_sse2
    call puts
.sse2_done:
    call newline
    ret


; ------------------------
; Helper Routines
; ------------------------

puts:                   ; print string at DS:SI
    mov ah, 0x0E
.next:
    lodsb
    cmp al, 0
    je .end
    int 10h
    jmp .next
.end:
    ret

newline:
    push ax
    mov ah, 0x0E
    mov al, 0x0D
    int 10h
    mov al, 0x0A
    int 10h
    pop ax
    ret

getline:                ; read user string into ES:DI
    pusha
    mov bx, di
.read:
    mov ah, 0
    int 16h
    cmp al, 0Dh
    je .done
    cmp al, 08h
    je .bksp
    mov [di], al
    mov ah, 0Eh
    int 10h
    inc di
    jmp .read
.bksp:
    cmp di, bx
    je .read
    dec di
    mov byte [di], 0
    mov ah, 0Eh
    mov al, 08h
    int 10h
    mov al, ' '
    int 10h
    mov al, 08h
    int 10h
    jmp .read
.done:
    mov byte [di], 0
    popa
    ret

str_equal:              ; compare SI and DI strings
    pusha
.loop:
    mov al, [si]
    mov ah, [di]
    cmp al, ah
    jne .ne
    cmp al, 0
    je .eq
    inc si
    inc di
    jmp .loop
.ne:
    popa
    mov ax, 1
    ret
.eq:
    popa
    xor ax, ax
    ret

print_num:              ; print AX/EAX as decimal
    pusha
    mov cx, 0
    mov ebx, 10
.next:
    xor edx, edx
    div ebx
    push dx
    inc cx
    cmp eax, 0
    jne .next
.print:
    pop ax
    add al, '0'
    mov ah, 0Eh
    int 10h
    loop .print
    popa
    ret

scr_clear:
    pusha
    mov ah, 0
    mov al, 3
    int 10h
    popa
    ret


; ------------------------
; Strings & Buffers
; ------------------------

msg_welcome db 'Welcome to TestOS (Modified Edition)!',0
msg_prompt  db 'TestOS>> ',0
msg_unknown db 'Unknown command!',0
msg_about   db 'TestOS v1.1 - Written by Duvini Nimethra',0
msg_help    db 'info - Hardware Info',0Dh,0Ah,'clear - Clear screen',0Dh,0Ah,'reboot - Reboot system',0Dh,0Ah,'about - About this OS',0Dh,0Ah,0

cmd_info    db 'info',0
cmd_help    db 'help',0
cmd_clear   db 'clear',0
cmd_reboot  db 'reboot',0
cmd_about   db 'about',0

str_mem_base db 'Base memory: ',0
str_mem_ext  db 'Extended (1M-16M): ',0
str_mem_high db 'Memory above 16M: ',0
str_mem_total db 'Total memory: ',0

str_cpu_vendor db 'CPU Vendor: ',0
str_cpu_desc   db 'CPU Type: ',0
str_hdd        db 'Hard drives: ',0
str_mouse      db 'Mouse: ',0
str_serial_count db 'Serial ports: ',0
str_serial_addr  db 'Port1 I/O: ',0
str_features     db 'Features: ',0

str_mouse_found db 'Mouse Present',0
str_mouse_none  db 'No Mouse',0
str_not_sup     db 'Not supported',0

str_k db 'K',0
str_M db 'M',0
str_fpu  db 'FPU ',0
str_mmx  db 'MMX ',0
str_sse  db 'SSE ',0
str_sse2 db 'SSE2 ',0

input_buf times 64 db 0
buf_vendor times 13 db 0
buf_cpu    times 49 db 0

var_base_kb dw 0
var_ext_kb  dw 0
var_ext16   dw 0
var_ext64   dw 0
var_mem_mb  dw 0
var_feat    dd 0

times 510-($-$$) db 0
dw 0xAA55
