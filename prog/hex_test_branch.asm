lil r1, 7
lil r2, 8
lil r3, 8
lil r4, 9
lil r5, 1
;=====================================================
; Test #1: BEQ should not take branch  => dmem[ 0] = 0
;=====================================================
sho r5, 0x0(r0)  ; set dmem[0x0] to 1 (r5)
beq r1, r2, 8    ; if r1 == r2, jump +8 bytes
sho r0, 0x0(r0)  ; set dmem[0x0] back to 0 (r0) if branch not taken
;=====================================================
; Test #2: BEQ should take branch      => dmem[ 2] = 1
;=====================================================
sho r5, 0x2(r0)  ; set dmem[0x2] to 1
beq r2, r3, 8    ; if r2 == r3, jump +8 bytes
sho r0, 0x2(r0)  ; set dmem[0x2] back to 0 if branch not taken
;=====================================================
; Test #3: BNEQ should not take branch => dmem[ 4] = 0
;=====================================================
sho  r5, 0x4(r0) ; set dmem[0x4] to 1
bneq r2, r3, 8   ; if r2 != r3, jump +8 bytes
sho  r0, 0x4(r0) ; set dmem[0x4] back to 0 if branch not taken
;=====================================================
; Test #4: BNEQ should take branch     => dmem[ 6] = 1
;=====================================================
sho  r5, 0x6(r0) ; set dmem[0x6] to 1
bneq r1, r2, 8   ; if r1 != r2, jump +8 bytes
sho  r0, 0x6(r0) ; set dmem[0x6] back to 0 if branch not taken
;=====================================================
; Test #5: BGE should not take branch  => dmem[ 8] = 0
;=====================================================
sho r5, 0x8(r0) ; set dmem[0x8] to 1
bge r1, r2, 8   ; if r1 >= r2, jump +8 bytes
sho r0, 0x8(r0) ; set dmem[0x8] back to 0 if branch not taken
;=====================================================
; Test #6: BGE should take branch      => dmem[10] = 1
;=====================================================
sho r5, 0xA(r0) ; set dmem[0xA] to 1
bge r3, r1, 8   ; if r3 >= r1, jump +8 bytes
sho r0, 0xA(r0) ; set dmem[0xA] back to 0 if branch not taken
;=====================================================
; Test #7: BLT should not take branch  => dmem[12] = 0
;=====================================================
sho r5, 0xC(r0) ; set dmem[0xC] to 1
blt r4, r3, 8   ; if r4 < r3, jump +8 bytes
sho r0, 0xC(r0) ; set dmem[0xC] back to 0 if branch not taken
;=====================================================
; Test #8: BLT should take branch      => dmem[14] = 1
;=====================================================
sho r5, 0xE(r0) ; set dmem[0xE] to 1
blt r3, r4, 8   ; if r3 < r4, jump +8 bytes
sho r0, 0xE(r0) ; set dmem[0xE] back to 0 if branch not taken
