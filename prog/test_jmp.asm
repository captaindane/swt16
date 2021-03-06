lil    r1, 0xF      ; r1        <- 0xF
addpci r2, 0x20     ; r2        <- 0x20 + 0x02 (pc) = 0x22
li     r3, 0x22     ; r3        <- 0x22
addpc  r4, r3       ; r4        <- pc + 0x22
sho    r1, 0x0(r0)  ; dmem[0x0] <- 0xF
jal    r5, _label   ; r5        <- pc+4 = 0x18
;=====================================================
; We jump over the next two lines: dmem[0x0] = 0xF
;=====================================================
sho r0, 0x0(r0)     ; dmem[0x0] <- 0x0 (not executed)
;=====================================================
_label:
sho  r1, 0x2(r0)    ; dmem[0x2] <- 0xF
jalr r6, r2         ; r6        <- pc+2 = 0x1E
;=====================================================
; We jump over the next two lines: dmem[0x2] = 0xF
;=====================================================
sho r0, 0x2(r0)     ; dmem[0x2] <- 0x0 (not executed)
;=====================================================
sho  r1, 0x4(r0)    ; dmem[0x4] <- 0xF
jalr r7, r4         ; r7 <- pc+2 = 0x28
;=====================================================
; We jump over the next two lines: dmem[0x4] = 0xF
;=====================================================
sho r0, 0x4(r0)     ; dmem[0x4] <- 0x0 (not executed)
;=====================================================
sho r5, 0x6(r0)     ; dmem[0x6] <- r5 = 0x14
sho r6, 0x8(r0)     ; dmem[0x8] <- r6 = 0x1E
sho r7, 0xA(r0)     ; dmem[0xA] <- r7 = 0x28
