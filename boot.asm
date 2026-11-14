; boot.asm  —— MyOS v1
org 0x7c00
bits 16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    mov si, msg_real
    call print16

    ; 打开 A20 地址线（fast A20）
    in  al, 0x92
    or  al, 2
    out 0x92, al

    cli                     ; 切换期间不能被中断打断
    lgdt [gdt_desc]         ; 加载 GDT
    mov eax, cr0
    or  eax, 1              ; CR0.PE = 1，进入保护模式
    mov cr0, eax
    jmp 0x08:pm_entry       ; 远跳转：刷新流水线并装入代码段选择子

; 实模式打印：同时输出到串口和 BIOS 屏幕
print16:
    lodsb
    or  al, al
    jz  .done
    mov dx, 0x3f8
    out dx, al              ; 串口
    ; mov ah, 0x0e
    ; int 0x10                ; BIOS 屏幕
    jmp print16
.done:
    ret

; ---------- GDT：空描述符 + 平坦代码段 + 平坦数据段 ----------
align 8
gdt:
    dq 0x0000000000000000   ; 0x00 空描述符（必须有）
    dq 0x00cf9a000000ffff   ; 0x08 代码段：基址0，界限4GB，可读可执行，ring0
    dq 0x00cf92000000ffff   ; 0x10 数据段：基址0，界限4GB，可读写，ring0
gdt_end:

gdt_desc:
    dw gdt_end - gdt - 1    ; GDT 界限
    dd gdt                  ; GDT 线性基址

; ---------- 32 位保护模式 ----------
bits 32
pm_entry:
    mov ax, 0x10            ; 数据段选择子
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    mov esi, msg_pm
    mov edi, 0xb8000 + 160 * 10   ; 显存第 10 行
    call print32

.halt:
    hlt
    jmp .halt

; 保护模式打印：直接写显存 0xb8000 + 串口
print32:
    mov ah, 0x0a            ; 属性：黑底亮绿字
.loop:
    lodsb
    test al, al
    jz  .done
    mov dx, 0x3f8
    out dx, al
    mov [edi], ax           ; 低字节=字符，高字节=属性
    add edi, 2
    jmp .loop
.done:
    mov dx, 0x3f8
    mov al, 13
    out dx, al
    mov al, 10
    out dx, al
    ret

msg_real db "[v1] real mode ok", 13, 10, 0
msg_pm   db "[v1] protected mode ok", 0

times 510-($-$$) db 0
dw 0xaa55