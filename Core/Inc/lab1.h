#ifndef LAB1_H
#define LAB1_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
enum { LED_AUCUNE=0, LED_ROUGE=1, LED_VERTE=2, LED_BLEUE=3 };
enum { BTN_USER=0, BTN_ESTOP=1, BTN_TOUCH=2 };
enum { ETAT_ARRET=0, ETAT_MARCHE_AVANT=1, ETAT_MARCHE_ARRIERE=2, ETAT_ARRET_URGENCE=3 };
void gpio_init(void);
void led_set(uint32_t led);
uint32_t button_raw(uint32_t id);
uint32_t button_pressed(uint32_t id);
void delay_ms(uint32_t ms);
void estop_init(void);
void EXTI2_IRQHandler(void);
void fsm_init(void);
void fsm_step(void);
void fsm_maj_del(void);
void timing_init(void);
void blink_reset(void);
void blink_measure(void);
extern volatile uint32_t etat;
extern volatile uint32_t prochain_sens;
extern volatile uint32_t touch_enabled;
extern volatile uint32_t compteur_transitions;
extern volatile uint32_t clignote_compteur;
extern volatile uint32_t clignote_phase;
extern volatile uint32_t touch_signal_compteur;
extern volatile uint32_t estop_flag;
extern volatile uint32_t delay_boucles_par_ms;
extern volatile uint32_t dwt_ready;
extern volatile uint32_t blink_last_cycle;
extern volatile uint32_t blink_cycles;
extern volatile uint32_t blink_period_cycles;
extern volatile uint32_t blink_samples;
extern volatile uint32_t btn_valide[3], btn_compteur[3];
#ifdef __cplusplus
}
#endif
#endif
