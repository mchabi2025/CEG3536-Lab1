#include "registres.inc"
.syntax unified
.cpu cortex-m33
.thumb

.bss
.balign 4
fsm_bss_debut:
.global etat
.type etat, %object
.size etat, 4
etat: .space 4
.global prochain_sens
.type prochain_sens, %object
.size prochain_sens, 4
prochain_sens: .space 4
.global touch_enabled
.type touch_enabled, %object
.size touch_enabled, 4
touch_enabled: .space 4
.global compteur_transitions
.type compteur_transitions, %object
.size compteur_transitions, 4
compteur_transitions: .space 4
.global clignote_compteur
.type clignote_compteur, %object
.size clignote_compteur, 4
clignote_compteur: .space 4
.global clignote_phase
.type clignote_phase, %object
.size clignote_phase, 4
clignote_phase: .space 4
.global touch_signal_compteur
.type touch_signal_compteur, %object
.size touch_signal_compteur, 4
touch_signal_compteur: .space 4
fsm_bss_fin:
.section .rodata
etat_vers_del: .byte LED_ROUGE, LED_VERTE, LED_BLEUE, LED_ROUGE
.text
.balign 4

/* Initialisation au demarrage AVANT estop_init. Etat arret, sens avant. Detruit r0-r3; pile 8 octets. */
.global fsm_init
.type fsm_init, %function
.thumb_func
fsm_init:
push {r4, lr}
    ldr r0, =fsm_bss_debut
    ldr r1, =fsm_bss_fin
    movs r2, #0
1:  str r2, [r0], #4
    cmp r0, r1
    blo 1b
    ldr r0, =prochain_sens
    movs r1, #ETAT_MARCHE_AVANT
    str r1, [r0]
    bl fsm_maj_del
    pop {r4, pc}
.size fsm_init, .-fsm_init
.ltorg

/* Un pas ~1 ms; aucun delai. Detruit r0-r3; preserve r4-r6,LR,PRIMASK. Urgence prioritaire; Touch acquitte sans depart automatique. */
.global fsm_step
.type fsm_step, %function
.thumb_func
fsm_step:
push {r4, r5, r6, lr}
    /* Lire les deux boutons meme en urgence: pas d'evenement differe. */
    movs r0, #BTN_USER
    bl button_pressed
    mov r4, r0
    movs r0, #BTN_TOUCH
    bl button_pressed
    mov r5, r0
    /* Transaction courte: consommer drapeau, transitions, sorties.
       Aucune attente ici; interruption pendante servie a la restauration. */
    mrs r6, PRIMASK
    cpsid i
    ldr r0, =estop_flag
    ldr r1, [r0]
    cbz r1, .Lnormal_check
    movs r1, #0
    str r1, [r0]
    ldr r0, =etat
    ldr r1, [r0]
    cmp r1, #ETAT_ARRET_URGENCE
    beq .Lrender
    movs r1, #ETAT_ARRET_URGENCE
    str r1, [r0]
    ldr r0, =compteur_transitions
    ldr r1, [r0]
    adds r1, r1, #1
    str r1, [r0]
    ldr r0, =clignote_compteur
    movs r1, #(CLIGNOTEMENT_DEMI_MS / PERIODE_SCRUTATION_MS)
    str r1, [r0]
    ldr r0, =clignote_phase
    movs r1, #1
    str r1, [r0]
    ldr r0, =touch_signal_compteur
    movs r1, #0
    str r1, [r0]
    bl blink_reset
    b .Lrender
.Lnormal_check:
    ldr r0, =etat
    ldr r1, [r0]
    cmp r1, #ETAT_ARRET_URGENCE
    bne .Luser
    cmp r5, #0
    beq .Lrender
    movs r0, #BTN_ESTOP
    bl button_raw
    cmp r0, #0
    bne .Lrender
    /* Nouveau pending pendant la section critique: refuser acquittement. */
    ldr r0, =EXTI_BASE
    ldr r1, [r0, #EXTI_RPR1]
    ldr r2, [r0, #EXTI_FPR1]
    orrs r1, r1, r2
    tst r1, #EXTI2_MASK
    bne .Lrender
    ldr r0, =etat
    movs r1, #ETAT_ARRET
    str r1, [r0]
    ldr r0, =prochain_sens
    movs r1, #ETAT_MARCHE_AVANT
    str r1, [r0]
    ldr r0, =compteur_transitions
    ldr r1, [r0]
    adds r1, r1, #1
    str r1, [r0]
    /* User simultane ignore; acquittement laisse toujours rouge fixe. */
    b .Lrender
.Luser:
    cmp r4, #0
    beq .Ltouch
    cmp r1, #ETAT_ARRET
    bne .Lstop
    ldr r2, =prochain_sens
    ldr r1, [r2]
    str r1, [r0]
    eor r1, r1, #3
    str r1, [r2]
    b .Lcount
.Lstop:
    movs r1, #ETAT_ARRET
    str r1, [r0]
.Lcount:
    ldr r0, =compteur_transitions
    ldr r1, [r0]
    adds r1, r1, #1
    str r1, [r0]
.Ltouch:
    cmp r5, #0
    beq .Lrender
    ldr r0, =touch_enabled
    ldr r1, [r0]
    eor r1, r1, #1
    str r1, [r0]
    ldr r0, =touch_signal_compteur
    movs r1, #(TOUCH_SIGNAL_MS / PERIODE_SCRUTATION_MS)
    str r1, [r0]
.Lrender:
    bl fsm_maj_del
    dsb
    msr PRIMASK, r6
    pop {r4, r5, r6, pc}
.size fsm_step, .-fsm_step
.ltorg

/* Unique appel applicatif led_set; ISR ecrit BSRR directement. Detruit r0-r3; preserve r4,LR et PRIMASK. Aucun delai. */
.global fsm_maj_del
.type fsm_maj_del, %function
.thumb_func
fsm_maj_del:
push {r4, lr}
    mrs r4, PRIMASK
    cpsid i
    ldr r0, =etat
    ldr r1, [r0]
    cmp r1, #ETAT_ARRET_URGENCE
    beq .Lblink
    ldr r0, =touch_signal_compteur
    ldr r2, [r0]
    cbz r2, .Lsteady
    subs r2, r2, #1
    str r2, [r0]
    movs r0, #LED_AUCUNE
    b .Lwrite
.Lsteady:
    cmp r1, #ETAT_MARCHE_ARRIERE
    bhi .Lsafe
    ldr r0, =etat_vers_del
    ldrb r0, [r0, r1]
    b .Lwrite
.Lblink:
    ldr r0, =clignote_compteur
    ldr r1, [r0]
    cbz r1, .Ltoggle
    subs r1, r1, #1
    str r1, [r0]
    b .Lphase
.Ltoggle:
    movs r1, #(CLIGNOTEMENT_DEMI_MS / PERIODE_SCRUTATION_MS - 1)
    str r1, [r0]
    ldr r0, =clignote_phase
    ldr r1, [r0]
    eor r1, r1, #1
    str r1, [r0]
    bl blink_measure
.Lphase:
    ldr r0, =clignote_phase
    ldr r0, [r0]
    b .Lwrite
.Lsafe:
    movs r0, #LED_ROUGE
.Lwrite:
    bl led_set
    msr PRIMASK, r4
    pop {r4, pc}
.size fsm_maj_del, .-fsm_maj_del
.ltorg
