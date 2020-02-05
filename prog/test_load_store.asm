lil r1, 2         ; r1          <= 2
lil r2, 4         ; r2          <= 4
lh r3, r1         ; r3          <= dmem[r1]   = dmem[2] = 0xBEEF
sh r3 (r2)        ; dmem[r2]    <= dmem[ 4]   = r3      = 0xBEEF
lh r4, r2         ; r4          <= dmem[r2]   = dmem[4] = 0xBEEF
li r5, 0xDEAD     ; r5          <= 0xDEAD
lho r6, 6(r1)     ; r6          <= dmem[r1+6] = dmem[8] = 0xABBA
sho r6, 8(r1)     ; dmem[r1+8]   = dmem[10]  <= r6 = 0xABBA
;=========================================
; Testing byte-wise load
;=========================================
lbu  r7,    (r2)  ; r7          <=               dmem[r2  ][7:0]         = 0x00EF
lbuo r8,   1(r2)  ; r8          <=               dmem[r2+1][7:0]         = 0x00BE
lb   r9,    (r2)  ; r9          <= sign_extend ( dmem[r2  ][7:0] )       = 0xFFEF
lbo  r10,  1(r2)  ; r10         <= sign_extend ( dmem[r2+1][7:0] )       = 0xFFBE
sho  r7,  10(r1)  ; dmem[r1+10]  = dmem[12]                       <= r7  = 0x00EF
sho  r8,  12(r1)  ; dmem[r1+12]  = dmem[14]                       <= r8  = 0x00BE
sho  r9,  14(r1)  ; dmem[r1+14]  = dmem[16]                       <= r9  = 0xFFEF
sho  r10, 16(r1)  ; dmem[r1+16]  = dmem[18]                       <= r10 = 0xFFBE
