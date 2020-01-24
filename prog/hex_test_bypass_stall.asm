lil r2, 1            ; r2 <- 1
lh  r1, (r0)         ; r1 <- dmem[0] = 0x0008
add r1, r1, r2       ; r1 <- r1 + r2 = 0x0009
add r1, r2, r1       ; r1 <- r2 + r1 = 0x000A
add r1, r1, r2       ; r1 <- r1 + r2 = 0x000B
sho r1, 0x2(r0)      ; dmem[2] <- r1 = 0x000B
