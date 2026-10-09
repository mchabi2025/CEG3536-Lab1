#include "registres.inc"
.syntax unified
.cpu cortex-m33
.thumb

.bss
.balign 4
.global estop_flag
.type estop_flag, %object
.size estop_flag, 4
estop_flag: .space 4

.text
.balign 4

/* Sans parametre. Configure PB2 -> EXTI2, priorite 0. Detruit r0-r3; preserve r4,LR et PRIMASK. */
.global estop_init
.type estop_init, %function
.thumb_func
estop_init:
push {r4, lr}
    mrs r4, PRIMASK
    cpsid i
    ldr r0, =NVIC_ICER0
    mov r1, #(1 << EXTI2_IRQn)
    str r1, [r0]
    ldr r0, =EXTI_BASE
    ldr r1, [r0, #EXTI_IMR1]
    bic r1, r1, #EXTI2_MASK
    str r1, [r0, #EXTI_IMR1]
    ldr r1, [r0, #EXTI_EXTICR1]
    bic r1, r1, #EXTI2_PORT_MASK
    orr r1, r1, #EXTI2_PORT_B
    str r1, [r0, #EXTI_EXTICR1]
    ldr r1, [r0, #EXTI_RTSR1]
    bic r1, r1, #EXTI2_MASK
.if BTN_ESTOP_ACTIF_HAUT
    orr r1, r1, #EXTI2_MASK
.endif
    str r1, [r0, #EXTI_RTSR1]
    ldr r1, [r0, #EXTI_FTSR1]
    bic r1, r1, #EXTI2_MASK
.if !BTN_ESTOP_ACTIF_HAUT
    orr r1, r1, #EXTI2_MASK
.endif
    str r1, [r0, #EXTI_FTSR1]
    movs r1, #EXTI2_MASK
    str r1, [r0, #EXTI_RPR1]
    str r1, [r0, #EXTI_FPR1]
    ldr r2, =NVIC_ICPR0
    mov r3, #(1 << EXTI2_IRQn)
    str r3, [r2]
    ldr r2, =NVIC_IPR_BASE
    movs r1, #0
    strb r1, [r2, #EXTI2_IRQn]
    ldr r1, [r0, #EXTI_IMR1]
    orr r1, r1, #EXTI2_MASK
    str r1, [r0, #EXTI_IMR1]
    ldr r2, =NVIC_ISER0
    str r3, [r2]
    /* E-Stop maintenu au reset: declencher aussi l'ISR sans attendre un front. */
    movs r0, #BTN_ESTOP
    bl button_raw
    cbz r0, 1f
    ldr r0, =NVIC_ISPR0
    mov r1, #(1 << EXTI2_IRQn)
    str r1, [r0]
1:  dsb
    isb
    msr PRIMASK, r4
    pop {r4, pc}
.size estop_init, .-estop_init
.ltorg

/* ISR dediee EXTI2 (ou pending logiciel au reset). r0-r1 empiles par materiel. Securite, drapeau, W1C seulement; aucun delai, aucun changement etat. */
.global EXTI2_IRQHandler
.type EXTI2_IRQHandler, %function
.thumb_func
EXTI2_IRQHandler:
ldr r0, =GPIOC_BASE
    ldr r1, =(1 << (LED_VERTE_PIN+16))
    str r1, [r0, #GPIO_BSRR]
    ldr r0, =GPIOB_BASE
    ldr r1, =(1 << (LED_BLEUE_PIN+16))
    str r1, [r0, #GPIO_BSRR]
    ldr r0, =GPIOA_BASE
    mov r1, #(1 << LED_ROUGE_PIN)
    str r1, [r0, #GPIO_BSRR]
    ldr r0, =estop_flag
    movs r1, #1
    str r1, [r0]
    ldr r0, =EXTI_BASE
    movs r1, #EXTI2_MASK
    str r1, [r0, #EXTI_RPR1]
    str r1, [r0, #EXTI_FPR1]
    dsb
    bx lr
.size EXTI2_IRQHandler, .-EXTI2_IRQHandler
.ltorg
