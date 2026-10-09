#include "registres.inc"
.syntax unified
.cpu cortex-m33
.thumb

.bss
.balign 4
.global btn_valide
.type btn_valide, %object
.size btn_valide, 12
btn_valide: .space 12
.global btn_compteur
.type btn_compteur, %object
.size btn_compteur, 12
btn_compteur: .space 12

.section .rodata
.balign 4
btn_table:
 .word GPIOC_BASE, BTN_USER_PIN, BTN_USER_ACTIF_HAUT
 .word GPIOB_BASE, BTN_ESTOP_PIN, BTN_ESTOP_ACTIF_HAUT
 .word GPIOB_BASE, BTN_TOUCH_PIN, BTN_TOUCH_ACTIF_HAUT
.data
.balign 4
.global delay_boucles_par_ms
.type delay_boucles_par_ms, %object
.size delay_boucles_par_ms, 4
delay_boucles_par_ms: .word DELAY_BOUCLES_PAR_MS
.text
.balign 4

/* R0=id -> R0=appuye 0/1; id invalide -> 0. Detruit r0-r3. */
.global button_raw
.type button_raw, %function
.thumb_func
button_raw:
cmp r0, #BTN_TOUCH
    bhi 1f
    add r1, r0, r0, lsl #1
    ldr r2, =btn_table
    add r1, r2, r1, lsl #2
    ldr r2, [r1]
    ldr r3, [r1, #4]
    ldr r0, [r1, #8]
    ldr r2, [r2, #GPIO_IDR]
    lsr r2, r2, r3
    and r2, r2, #1
    eor r0, r0, r2
    eor r0, r0, #1
    bx lr
1:  movs r0, #0
    bx lr
.size button_raw, .-button_raw
.ltorg

/* R0=id -> front appui valide 0/1. Appeler une fois/ms/bouton; relachement aussi filtre. Detruit r0-r3; preserve r4-r6,LR; pile 16 octets. */
.global button_pressed
.type button_pressed, %function
.thumb_func
button_pressed:
cmp r0, #BTN_TOUCH
    bhi 4f
    push {r4, r5, r6, lr}
    mov r4, r0
    bl button_raw
    ldr r5, =btn_valide
    ldr r6, =btn_compteur
    ldr r1, [r5, r4, lsl #2]
    cmp r0, r1
    beq 2f
    ldr r1, [r6, r4, lsl #2]
    adds r1, r1, #1
    cmp r1, #(ANTIREBOND_MS / PERIODE_SCRUTATION_MS)
    blo 1f
    str r0, [r5, r4, lsl #2]
    movs r1, #0
    str r1, [r6, r4, lsl #2]
    pop {r4, r5, r6, pc}
1:  str r1, [r6, r4, lsl #2]
    b 3f
2:  movs r1, #0
    str r1, [r6, r4, lsl #2]
3:  movs r0, #0
    pop {r4, r5, r6, pc}
4:  movs r0, #0
    bx lr
.size button_pressed, .-button_pressed
.ltorg

/* R0=ms, 0 retourne immediatement. Detruit r0-r2. IRQ autorisees. Boucle a calibrer par DWT; 1000 est une hypothese, pas une mesure. */
.global delay_ms
.type delay_ms, %function
.thumb_func
delay_ms:
cbz r0, 3f
    ldr r2, =delay_boucles_par_ms
    ldr r2, [r2]
    cmp r2, #1
    bhs 1f
    movs r2, #1
1:  mov r1, r2
2:  subs r1, r1, #1
    bne 2b
    subs r0, r0, #1
    bne 1b
3:  bx lr
.size delay_ms, .-delay_ms
.ltorg
