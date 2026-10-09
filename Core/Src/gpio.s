#include "registres.inc"
.syntax unified
.cpu cortex-m33
.thumb

.text
.balign 4

/* RCC et GPIO. Sans parametre. Detruit r0-r1; r4-r11 preserves. Appeler au demarrage. */
.global gpio_init
.type gpio_init, %function
.thumb_func
gpio_init:
ldr r0, =RCC_BASE
    ldr r1, [r0, #RCC_AHB2ENR]
    orr r1, r1, #RCC_GPIOABC_EN
    str r1, [r0, #RCC_AHB2ENR]
    ldr r1, [r0, #RCC_AHB2ENR]
    dsb
    ldr r0, =GPIOA_BASE
    ldr r1, =(1 << (LED_ROUGE_PIN+16))
    str r1, [r0, #GPIO_BSRR]
    ldr r1, [r0, #GPIO_MODER]
    bic r1, r1, #(3 << (LED_ROUGE_PIN*2))
    orr r1, r1, #(1 << (LED_ROUGE_PIN*2))
    str r1, [r0, #GPIO_MODER]
    ldr r1, [r0, #GPIO_OTYPER]
    bic r1, r1, #(1 << (LED_ROUGE_PIN))
    str r1, [r0, #GPIO_OTYPER]
    ldr r1, [r0, #GPIO_OSPEEDR]
    bic r1, r1, #(3 << (LED_ROUGE_PIN*2))
    str r1, [r0, #GPIO_OSPEEDR]
    ldr r1, [r0, #GPIO_PUPDR]
    bic r1, r1, #(3 << (LED_ROUGE_PIN*2))
    str r1, [r0, #GPIO_PUPDR]

    ldr r0, =GPIOB_BASE
    ldr r1, =(1 << (LED_BLEUE_PIN+16))
    str r1, [r0, #GPIO_BSRR]
    ldr r1, [r0, #GPIO_MODER]
    bic r1, r1, #(3 << (LED_BLEUE_PIN*2))
    orr r1, r1, #(1 << (LED_BLEUE_PIN*2))
    bic r1, r1, #(3 << (BTN_ESTOP_PIN*2))
    bic r1, r1, #(3 << (BTN_TOUCH_PIN*2))
    str r1, [r0, #GPIO_MODER]
    ldr r1, [r0, #GPIO_OTYPER]
    bic r1, r1, #(1 << (LED_BLEUE_PIN))
    str r1, [r0, #GPIO_OTYPER]
    ldr r1, [r0, #GPIO_OSPEEDR]
    bic r1, r1, #(3 << (LED_BLEUE_PIN*2))
    str r1, [r0, #GPIO_OSPEEDR]
    ldr r1, [r0, #GPIO_PUPDR]
    bic r1, r1, #(3 << (LED_BLEUE_PIN*2))
    bic r1, r1, #(3 << (BTN_ESTOP_PIN*2))
    orr r1, r1, #(BTN_ESTOP_PUPDR << (BTN_ESTOP_PIN*2))
    bic r1, r1, #(3 << (BTN_TOUCH_PIN*2))
    orr r1, r1, #(BTN_TOUCH_PUPDR << (BTN_TOUCH_PIN*2))
    str r1, [r0, #GPIO_PUPDR]

    ldr r0, =GPIOC_BASE
    ldr r1, =(1 << (LED_VERTE_PIN+16))
    str r1, [r0, #GPIO_BSRR]
    ldr r1, [r0, #GPIO_MODER]
    bic r1, r1, #(3 << (LED_VERTE_PIN*2))
    orr r1, r1, #(1 << (LED_VERTE_PIN*2))
    bic r1, r1, #(3 << (BTN_USER_PIN*2))
    str r1, [r0, #GPIO_MODER]
    ldr r1, [r0, #GPIO_OTYPER]
    bic r1, r1, #(1 << (LED_VERTE_PIN))
    str r1, [r0, #GPIO_OTYPER]
    ldr r1, [r0, #GPIO_OSPEEDR]
    bic r1, r1, #(3 << (LED_VERTE_PIN*2))
    str r1, [r0, #GPIO_OSPEEDR]
    ldr r1, [r0, #GPIO_PUPDR]
    bic r1, r1, #(3 << (LED_VERTE_PIN*2))
    bic r1, r1, #(3 << (BTN_USER_PIN*2))
    orr r1, r1, #(BTN_USER_PUPDR << (BTN_USER_PIN*2))
    str r1, [r0, #GPIO_PUPDR]

    bx lr
.size gpio_init, .-gpio_init
.ltorg

/* R0=0..3, hors plage: eteint. Detruit r0-r3. Priorite urgence sur demande verte/bleue. Restaure PRIMASK. */
.global led_set
.type led_set, %function
.thumb_func
led_set:
mrs r3, PRIMASK
    cpsid i
    /* BSRR est atomique par port, PAS pour toute la sequence trois ports.
       Une section critique courte empeche ISR puis reallumage obsolete. */
    ldr r1, =estop_flag
    ldr r2, [r1]
    cbnz r2, 1f
    ldr r1, =etat
    ldr r2, [r1]
    cmp r2, #ETAT_ARRET_URGENCE
    bne 2f
    cmp r0, #LED_ROUGE
    bls 2f
1:  movs r0, #LED_ROUGE
2:  ldr r1, =GPIOA_BASE
    ldr r2, =(1 << (LED_ROUGE_PIN+16))
    str r2, [r1, #GPIO_BSRR]
    ldr r1, =GPIOC_BASE
    ldr r2, =(1 << (LED_VERTE_PIN+16))
    str r2, [r1, #GPIO_BSRR]
    ldr r1, =GPIOB_BASE
    ldr r2, =(1 << (LED_BLEUE_PIN+16))
    str r2, [r1, #GPIO_BSRR]
    cmp r0, #LED_ROUGE
    beq 3f
    cmp r0, #LED_VERTE
    beq 4f
    cmp r0, #LED_BLEUE
    bne 5f
    ldr r1, =GPIOB_BASE
    movs r2, #(1 << LED_BLEUE_PIN)
    b 6f
3:  ldr r1, =GPIOA_BASE
    mov r2, #(1 << LED_ROUGE_PIN)
    b 6f
4:  ldr r1, =GPIOC_BASE
    movs r2, #(1 << LED_VERTE_PIN)
6:  str r2, [r1, #GPIO_BSRR]
5:  dsb
    msr PRIMASK, r3
    bx lr
.size led_set, .-led_set
.ltorg
