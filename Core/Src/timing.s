#include "registres.inc"
.syntax unified
.cpu cortex-m33
.thumb

.bss
.balign 4
.global dwt_ready
.type dwt_ready, %object
.size dwt_ready, 4
dwt_ready: .space 4
.global blink_last_cycle
.type blink_last_cycle, %object
.size blink_last_cycle, 4
blink_last_cycle: .space 4
.global blink_cycles
.type blink_cycles, %object
.size blink_cycles, 4
blink_cycles: .space 4
.global blink_period_cycles
.type blink_period_cycles, %object
.size blink_period_cycles, 4
blink_period_cycles: .space 4
.global blink_samples
.type blink_samples, %object
.size blink_samples, 4
blink_samples: .space 4

.text
.balign 4

/* Active DWT pour mesures seulement. Sans parametre; detruit r0-r2. dwt_ready=1 si CYCCNT avance. */
.global timing_init
.type timing_init, %function
.thumb_func
timing_init:
ldr r0, =DEMCR
    ldr r1, [r0]
    orr r1, r1, #DEMCR_TRCENA
    str r1, [r0]
    dsb
    isb
    ldr r0, =DWT_CTRL
    ldr r1, [r0]
    tst r1, #DWT_NOCYCCNT
    bne 2f
    orr r1, r1, #DWT_CYCCNTENA
    str r1, [r0]
    dsb
    isb
    ldr r0, =DWT_CYCCNT
    ldr r1, [r0]
    nop
    nop
    nop
    ldr r2, [r0]
    cmp r1, r2
    beq 2f
    movs r1, #1
    b 3f
2:  movs r1, #0
3:  ldr r0, =dwt_ready
    str r1, [r0]
    bx lr
.size timing_init, .-timing_init
.ltorg

/* Debut urgence: origine et mesures remises a zero. Detruit r0-r1. */
.global blink_reset
.type blink_reset, %function
.thumb_func
blink_reset:
ldr r0, =DWT_CYCCNT
    ldr r1, [r0]
    ldr r0, =blink_last_cycle
    str r1, [r0]
    movs r1, #0
    ldr r0, =blink_cycles
    str r1, [r0]
    ldr r0, =blink_period_cycles
    str r1, [r0]
    ldr r0, =blink_samples
    str r1, [r0]
    bx lr
.size blink_reset, .-blink_reset
.ltorg

/* A chaque basculement: demi-periode et somme de deux demi-periodes en cycles. Detruit r0-r2; soustraction modulo 2^32. */
.global blink_measure
.type blink_measure, %function
.thumb_func
blink_measure:
ldr r0, =dwt_ready
    ldr r1, [r0]
    cbz r1, 1f
    ldr r0, =DWT_CYCCNT
    ldr r1, [r0]
    ldr r0, =blink_last_cycle
    ldr r2, [r0]
    str r1, [r0]
    subs r1, r1, r2
    ldr r0, =blink_cycles
    ldr r2, [r0]
    str r1, [r0]
    cbz r2, 2f
    adds r2, r2, r1
    ldr r0, =blink_period_cycles
    str r2, [r0]
2:  ldr r0, =blink_samples
    ldr r1, [r0]
    adds r1, r1, #1
    str r1, [r0]
1:  bx lr
.size blink_measure, .-blink_measure
.ltorg
