lil r1 , 2                  ; r1  <- 2          : number of which factorial is currently calculated
lil r2 , 8                  ; r2  <- 8          : highest number of which factorial is calculated
lil r3 , 1                  ; r3  <- 1          : constant, used to decrement 
addpci r14, 0x14            ; r14 <- _factorial : position independent code to compute absolute address of _factorial
lil r15, 0                  ;                   : writeback address in dmem
;=========================================
; _loop_start:
;=========================================
jalr r4 , r14               ; r4  <- pc  + 4    : jump to factorial function (address is in r14)
incl r1 , 1                 ; r1  <- r1  + 1    : increment number we want the factorial of
incl r15, 2                 ; r15 <- r15 + 2    : increment address we want the factorial stored at
blt  r2, r1, 0x18           ;                   : while loop condition check and potential exit (jmp to label _end)
beq r0, r0, 0xfff6          ;                   : while loop jump back (unconditioned) to label _loop_start
;=========================================
; _factorial:
;=========================================
add  r5, r1, r0             ; r5 <- r1          : will hold the result
sub  r6, r1, r3             ; r6 <- r1 - 1      : factor variable
mul  r5, r5, r6             ; r5 <- r5 * r6
incl r6, -1                 ; r6 <- r6 - 1
bneq r6, r0, 0xFFFC         ;                   : loop until r6 is zero
sh r5, (r15)                ; dmem[r15] <- r5   : write result to memory
jalr r0, r4                 ;                   : jump back to main loop (address in r4)
;=========================================
; _end:
;=========================================
nop r0, r0, r0              ;                   : this line is label _end
