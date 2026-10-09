#include "registres.inc"
.syntax unified
.cpu cortex-m33
.thumb

/* Code applicatif original; conserver le startup et le linker CubeIDE.
 * SystemInit garde MSI 4 MHz du reset. Aucun HAL, aucun SysTick. */
.text
.balign 4

/* Sans parametre. Aucun registre modifie. Horloge de reset conservee. */
.global SystemInit
.type SystemInit, %function
.thumb_func
SystemInit:
bx lr
.size SystemInit, .-SystemInit
.ltorg

/* Point entree sans retour. Initialiser FSM AVANT activation EXTI pour ne pas effacer une urgence. */
.global main
.type main, %function
.thumb_func
main:
bl gpio_init
    bl timing_init
    bl fsm_init
    bl estop_init
1:  bl fsm_step
    movs r0, #PERIODE_SCRUTATION_MS
    bl delay_ms
    b 1b
.size main, .-main
.ltorg
