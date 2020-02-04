; Registers holding the pixel indices involved in the convolutional filter
;
;  +----+----+----+
;  |    | r6 |    |
;  +----+----+----+
;  | r7 | r5 | r8 |
;  +----+----+----+
;  |    | r9 |    |
;  +----+----+----+
;
;-----------------------------------------
; Initialization
;-----------------------------------------
li   r1, 240          ; r1: Number of pixels per row
add  r2, r1, r0       ; r2: Index of row after last valid anchor row (239)
incl r2, -1           ; ...
lil  r3,  2           ; current row idx (of bottom-most support points)
lil  r4,  2           ; current col idx (of right-most support points)
lil  r15, 1           ; r15 <= 1
;
;-----------------------------------------
; Main loop: iterate over anchor pixels
;-----------------------------------------
_row_loop_start:
; initialize pointers to support pixels
sub  r5, r3, r15
mul  r5, r5, r1
incl r5, 1
sub  r6, r5, r1
sub  r7, r5, r15
add  r8, r5, r15
add  r9, r5, r1
;-----------------------------------------
_col_loop_start:
;-----------------------------------------
; FILTER HERE !!!
incl r5, 1
incl r6, 1
incl r7, 1
incl r8, 1
incl r9, 1
incl r4, 1            ; increment col idx
bneq r4, r1, _col_loop_start
;-----------------------------------------
incl r3, 1            ; increment row idx
bneq r3, r1, _row_loop_start
;

