;=========================================
; Test setup (prepare inputs)
;=========================================
lil r1, 1          ; r1  <- 1
lil r2, 2          ; r2  <- 2
li  r3, 0x8000     ; r3  <- 0x8000
li  r14, 0x8000    ; r14 <- 0x8000
;=========================================
; Test arithmetic operations
;=========================================
add  r4, r1, r2    ; r4  <- r1 + r2           =  3 = 0x0003
sub  r5, r1, r2    ; r5  <- r1 - r2           = -1 = 0xFFFF
sub  r6, r2, r1    ; r6  <- r2 - r1           =  1 = 0x0001
mul  r7, r2, r2    ; r7  <- r2 * r2           =      0x0004
sll  r8, r2, r1    ; r8  <- r2 <<  r1         =  4 = 0x0004
srl  r9, r3, r1    ; r9  <- r3 >>  r1         =      0x4000
sra r10, r3, r1    ; r10 <- r3 >>> r1         =  4 = 0xC000
and r11, r1, r2    ; r11 <- r1 & r2           =      0x0000
or  r12, r1, r2    ; r12 <- r1 | r2           =      0x0003
xor r13, r5, r1    ; r13 <- r5 ^ r1           =      0xFFFE
incl r1, +1        ; r1  <- r1 + 1            =      0x0002
incl r3, -1        ; r3  <- r3 - 1            =      0x7FFF
inc  r14, 0x0888   ; r14 <- r14 + 0x0888      =      0x8888
;=========================================
; Store results in memory
;=========================================
lil  r15, 0        ; r15 <- 0
sh   r4, [r15]     ; dmem[r15 (0x00)]  <-  r4 =     0x0003
add  r15, r15, r2  ; r15+=2
sh   r5, [r15]     ; dmem[r15 (0x02)]  <-  r5 =     0xFFFF
add  r15, r15, r2  ; r15+=2
sh   r6, [r15]     ; dmem[r15 (0x04)]  <-  r6 =     0x0001
add  r15, r15, r2  ; r15+=2
sh   r7, [r15]     ; dmem[r15 (0x06)]  <-  r7 =     0x0004
add  r15, r15, r2  ; r15+=2
sh   r8, [r15]     ; dmem[r15 (0x08)]  <-  r8 =     0x0004
add  r15, r15, r2  ; r15+=2
sh   r9, [r15]     ; dmem[r15 (0x0A)]  <-  r9 =     0x4000
add  r15, r15, r2  ; r15+=2
sh   r10, [r15]    ; dmem[r15 (0x0C)]  <- r10 =     0xC000
add  r15, r15, r2  ; r15+=2
sh   r11, [r15]    ; dmem[r15 (0x0E)]  <- r11 =     0x0000
add  r15, r15, r2  ; r15+=2
sh   r12, [r15]    ; dmem[r15 (0x10)]  <- r12 =     0x0003
add  r15, r15, r2  ; r15+=2
sh   r13, [r15]    ; dmem[r15 (0x12)]  <- r13 =     0xFFFE
add  r15, r15, r2  ; r15+=2
sh   r1 , [r15]    ; dmem[r15 (0x14)]  <- r1  =     0x0002
add  r15, r15, r2  ; r15+=2
sh   r3 , [r15]    ; dmem[r15 (0x16)]  <- r3  =     0x7FFF
add  r15, r15, r2  ; r15+=2
sh   r14, [r15]    ; dmem[r15 (0x18)]  <- r14 =     0x8888
add  r15, r15, r2  ; r15+=2
