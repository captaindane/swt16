lil r1, 2       ; r1        <= 2
lil r2, 4       ; r2        <= 4
lh r3, r1       ; r3        <= dmem[r1]   = dmem[2] = 0xBEEF
sh r3 (r2)      ; dmem[r2]  <= dmem[ 4]   = r3      = 0xBEEF
lh r4, r2       ; r4        <= dmem[r2]   = dmem[4] = 0xBEEF
li r5, 0xDEAD   ; r5        <= 0xDEAD
lho r6, 6(r1)   ; r6        <= dmem[r1+6] = dmem[8] = 0xABBA
sho r6, 8(r1)   ; dmem[r1+8] = dmem[10]  <= r6 = 0xABBA
