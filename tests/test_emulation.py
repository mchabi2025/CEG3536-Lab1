"""Tests du vrai ELF ARM avec Unicorn; modele GPIO/EXTI simplifie.
Ne simule ni latence electrique, ni cycles Cortex-M33, ni NVIC complet.
Usage: python -m pip install unicorn pyelftools
       python tests/test_emulation.py [build/CEG3536_Lab1_Complet.elf]
"""
import sys, struct
from pathlib import Path
from unicorn import Uc, UC_ARCH_ARM, UC_MODE_THUMB, UC_MODE_MCLASS, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.arm_const import *
from elftools.elf.elffile import ELFFile

ELF=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]/'build/CEG3536_Lab1_Complet.elf'
A,B,C=0x42020000,0x42020400,0x42020800
EXTI=0x4002f400; STOP=0x0807f000
PRESERVED=[UC_ARM_REG_R4,UC_ARM_REG_R5,UC_ARM_REG_R6,UC_ARM_REG_R7,UC_ARM_REG_R8,UC_ARM_REG_R9,UC_ARM_REG_R10,UC_ARM_REG_R11]

class Board:
    def __init__(self,active=1):
        self.u=Uc(UC_ARCH_ARM,UC_MODE_THUMB|UC_MODE_MCLASS)
        for addr,size in [(0x08000000,0x80000),(0x20000000,0x40000),(0x40020000,0x10000),(0x42020000,0x1000),(0xe0000000,0x100000)]:self.u.mem_map(addr,size)
        with ELF.open('rb') as f:
            elf=ELFFile(f)
            self.sym={s.name:s['st_value'] for s in elf.get_section_by_name('.symtab').iter_symbols()}
            for seg in elf.iter_segments():
                if seg['p_type']=='PT_LOAD' and seg['p_filesz']:
                    self.u.mem_write(seg['p_vaddr'],seg.data())
                    if seg['p_paddr']!=seg['p_vaddr']:self.u.mem_write(seg['p_paddr'],seg.data())
        self.funcs={v&~1:k for k,v in self.sym.items() if k in ['button_raw','button_pressed','led_set','gpio_init','fsm_step','fsm_maj_del','blink_measure','blink_reset','timing_init','estop_init','fsm_init','delay_ms']}
        self.active=active; self.clear={};self.pending=False;self.in_isr=False;self.inject_at=None;self.executed=0;self.serviced=False
        self.max_masked=0;self.masked=0;self.trace=[];self.check_led=True
        self.u.reg_write(UC_ARM_REG_SP,0x2002f000)
        self.u.hook_add(UC_HOOK_MEM_WRITE,self.write)
        self.u.hook_add(UC_HOOK_CODE,self.code)
        for id in range(3): self.button(id,False)

    def rd(self,a):return struct.unpack('<I',self.u.mem_read(a,4))[0]
    def wr(self,a,v):self.u.mem_write(a,struct.pack('<I',v&0xffffffff))
    def get(self,n):return self.rd(self.sym[n])
    def set(self,n,v):self.wr(self.sym[n],v)
    def leds(self):return tuple(int(bool(self.rd(p+0x14)&(1<<pin))) for p,pin in [(A,9),(C,7),(B,7)])
    def button(self,id,pressed):
        p,pin=[(C,13),(B,2),(B,5)][id];bit=int(pressed)==self.active
        self.wr(p+0x10,(self.rd(p+0x10)&~(1<<pin))|(int(bit)<<pin))
    def write(self,u,access,a,size,v,data):
        if a in [A+0x18,B+0x18,C+0x18]:
            p=a-0x18;self.wr(p+0x14,(self.rd(p+0x14)&~(v>>16))|(v&65535))
            if self.check_led:assert sum(self.leds())<=1,('overlap',self.leds())
            if self.serviced and not self.in_isr:assert self.leds()[1:]==(0,0),'Mouvement apres ISR'
            self.trace.append(self.leds())
        if a in [EXTI+0xc,EXTI+0x10]:self.clear[a]=self.rd(a)&~v
    def code(self,u,a,size,data):
        for addr,v in self.clear.items():self.wr(addr,v)
        self.clear.clear()
        self.wr(0xe0001004,self.rd(0xe0001004)+1) # cycles SYNTHETIQUES
        if a in self.funcs:assert u.reg_read(UC_ARM_REG_SP)%8==0,('AAPCS alignment',self.funcs[a])
        if u.reg_read(UC_ARM_REG_PRIMASK):self.masked+=1;self.max_masked=max(self.max_masked,self.masked)
        else:self.masked=0
        if self.in_isr:return
        if self.inject_at is not None and self.executed==self.inject_at:
            self.pending=True;self.button(1,True);self.wr(EXTI+0xc,4)
        if self.pending and not u.reg_read(UC_ARM_REG_PRIMASK):u.emu_stop();return
        self.executed+=1
    def call(self,n,arg=0,inject=None):
        saved=[self.u.reg_read(r) for r in PRESERVED];sp=self.u.reg_read(UC_ARM_REG_SP)
        pm=self.u.reg_read(UC_ARM_REG_PRIMASK)
        self.u.reg_write(UC_ARM_REG_R0,arg);self.u.reg_write(UC_ARM_REG_LR,STOP|1)
        self.inject_at=inject;self.executed=0
        pc=self.sym[n]|1
        while True:
            self.u.emu_start(pc,STOP,count=200000)
            pc=self.u.reg_read(UC_ARM_REG_PC)
            if self.pending and not self.u.reg_read(UC_ARM_REG_PRIMASK):
                ctx=self.u.context_save();self.pending=False;self.inject_at=None
                self.in_isr=True;self.u.reg_write(UC_ARM_REG_LR,STOP|1)
                self.u.emu_start(self.sym['EXTI2_IRQHandler']|1,STOP,count=1000)
                assert self.u.reg_read(UC_ARM_REG_PC)==STOP
                self.in_isr=False;self.serviced=True;self.u.context_restore(ctx)
                assert self.leds()==(1,0,0)
                if pc==STOP:break
                pc|=1;continue
            assert pc==STOP,('function did not return',n,hex(pc))
            break
        assert [self.u.reg_read(r) for r in PRESERVED]==saved,('AAPCS registers',n)
        assert self.u.reg_read(UC_ARM_REG_SP)==sp,('stack',n)
        assert self.u.reg_read(UC_ARM_REG_PRIMASK)==pm,('PRIMASK',n)
        return self.u.reg_read(UC_ARM_REG_R0)
    def init(self):
        self.call('gpio_init');self.call('timing_init');self.call('fsm_init');self.call('estop_init')
    def tick(self,n=1):
        for _ in range(n):self.wr(0xe0001004,self.rd(0xe0001004)+4000);self.call('fsm_step')
    def press(self,id):self.button(id,True);self.tick(35);self.button(id,False);self.tick(35)
    def emergency(self):
        self.button(1,True);self.wr(EXTI+0xc,4);self.call('EXTI2_IRQHandler');assert self.leds()==(1,0,0);self.tick()

reports=[]
def check(name):
    reports.append(name);print('PASS',name)

b=Board();b.init()
assert b.get('etat')==0 and b.leds()==(1,0,0)
assert b.rd(0x4002104c)&7==7
for p,pin in [(A,9),(B,7),(C,7)]:
    assert (b.rd(p)>>(2*pin))&3==1
    assert (b.rd(p+4)>>pin)&1==0
for p,pin in [(B,2),(B,5),(C,13)]:assert (b.rd(p)>>(2*pin))&3==0
assert (b.rd(EXTI+0x60)>>16)&7==1
assert b.rd(EXTI)&4 and not b.rd(EXTI+4)&4 and b.rd(EXTI+0x80)&4
assert b.rd(0xe000e100)&(1<<13)
assert b.u.mem_read(0xe000e400+13,1)==b'\0'
vector=b.rd(b.sym['g_pfnVectors']+(16+13)*4)
assert vector==b.sym['EXTI2_IRQHandler']
check('T1 / RCC-GPIO / EXTI-NVIC / vecteur fort IRQ13')
for state,led in [(1,(0,1,0)),(0,(1,0,0)),(2,(0,0,1)),(0,(1,0,0))]:
    b.press(0);assert b.get('etat')==state and b.leds()==led
check('T2 cycle exact rouge-verte-rouge-bleue-rouge')
before=b.get('compteur_transitions')
for _ in range(20):b.press(0)
assert b.get('compteur_transitions')-before==20
before=b.get('compteur_transitions');b.button(0,True);b.tick(2000)
assert b.get('compteur_transitions')-before==1
b.button(0,False);b.tick(35)
before=b.get('compteur_transitions')
for _ in range(10):b.button(0,True);b.tick(12);b.button(0,False);b.tick(3)
assert b.get('compteur_transitions')==before
assert b.call('button_raw',99)==0 and b.call('button_pressed',0xffffffff)==0
check('T3 vingt appuis, maintien 2000 pas, rebonds courts et id invalide')
for state in [0,1,2]:
    b=Board();b.init();b.set('etat',state);b.call('fsm_maj_del');b.emergency()
    assert b.get('etat')==3 and b.get('estop_flag')==0
    assert b.rd(EXTI+0xc)==0 and b.rd(EXTI+0x10)==0
check('T5 mise en securite ISR dans tous les etats et W1C')
b=Board();b.init();b.emergency();b.tick(249);assert b.leds()==(1,0,0)
b.tick();assert b.leds()==(0,0,0)
b.tick(249);assert b.leds()==(0,0,0)
b.tick();assert b.leds()==(1,0,0)
assert b.get('blink_samples')==2 and b.get('blink_cycles')>0 and b.get('blink_period_cycles')>b.get('blink_cycles')
check('T6 demi-periodes 250 pas et instrumentation DWT (temps synthetique)')
b.press(2);assert b.get('etat')==3
b.button(1,False);b.tick(100);assert b.get('etat')==3
b.press(0);assert b.get('etat')==3
b.press(2);assert b.get('etat')==0 and b.leds()==(1,0,0)
check('T7-T8 refus E-Stop maintenu, aucune reprise, User ignore, acquittement')
b=Board();b.init();b.button(2,True);b.tick(30)
assert b.get('touch_enabled')==1 and b.leds()==(0,0,0)
b.tick(99);assert b.leds()==(0,0,0)
b.tick();assert b.leds()==(1,0,0)
b.button(2,False);b.tick(30);b.press(2);assert b.get('touch_enabled')==0
check('T9 bascule et extinction de 100 pas')
b=Board();b.init();b.button(0,True);b.button(2,True);b.tick(30)
assert b.get('etat')==1 and b.get('touch_enabled')==1 and b.leds()==(0,0,0)
b=Board();b.init();b.emergency();b.button(1,False);b.button(0,True);b.button(2,True);b.tick(30)
assert b.get('etat')==0 and b.get('touch_enabled')==0 and b.leds()==(1,0,0)
check('T10 User+Touch simultanes et acquittement+User sans redemarrage')
# Un appui User arrive a validation; injecter l'ISR a chaque frontiere instruction.
base=Board();base.init();base.button(0,True);base.tick(29);base.call('fsm_step');length=base.executed
maxmasked=0
for index in range(length):
    b=Board();b.init();b.button(0,True);b.tick(29);b.call('fsm_step',inject=index)
    assert b.serviced,('injection non servie',index)
    b.tick();assert b.get('etat')==3 and b.leds()[1:]==(0,0)
    maxmasked=max(maxmasked,b.max_masked)
check(f'T10 ISR injectee aux {length} frontieres instruction du pas de transition')
b=Board();b.init();b.set('etat',1);b.call('fsm_maj_del');b.call('delay_ms',3,inject=100)
assert b.serviced and b.leds()==(1,0,0) and b.get('estop_flag')==1
b.tick();assert b.get('etat')==3
b.call('delay_ms',0)
check('T5 interruption pendant delay_ms; duree zero retourne')
b=Board();b.button(1,True);b.init();assert b.rd(0xe000e200)&(1<<13)
check('E-Stop maintenu au reset: requete NVIC logicielle')
for n in ['led_set','fsm_step','fsm_maj_del']:
    b=Board();b.init()
    for i,r in enumerate(PRESERVED):b.u.reg_write(r,0x34560000+i)
    b.u.reg_write(UC_ARM_REG_PRIMASK,1);b.call(n)
check('AAPCS: r4-r11, SP aligne, PRIMASK preserve (controle a chaque appel)')
print(f'{len(reports)} groupes reussis. Masquage maximal observe, chemin transition: {maxmasked} instructions (PAS des cycles mesures).')
print('T4 et chronometrie physique T5/T6/E8 restent a verifier sur la carte.')
