# Validation effectuée le 25 septembre 2026

## Compilation réelle

Commande : `build.ps1 -ToolchainBin <dossier GNU Arm>/bin`.

Compilateur : **xPack GNU Arm Embedded GCC 15.2.1 20251203**, cible Cortex-M33 Thumb, FPU fpv5-sp-d16, ABI hard comme le projet fourni. Sources assemblées avec `-x assembler-with-cpp -g3 -Wall -Werror`; support C compilé avec `-Wall -Werror`. Liaison avec le script STM32 fourni, nano.specs et nosys.specs.

Résultat : **succès, aucun avertissement ni erreur**. Taille rapportée par GNU size : text 2100 octets, data 4 octets, bss 1644 octets. La valeur bss inclut les réservations de pile/tas du script de liaison; elle ne correspond pas uniquement aux variables applicatives.

ELF, BIN, HEX, MAP et désassemblage LIST fournis dans `build/`. Ce sont des résultats de compilation; leur présence ne signifie pas qu'ils ont été exécutés sur une Nucleo. Le projet graphique CubeIDE n'a pas été ouvert ici; la construction a été réalisée en ligne de commande avec les options équivalentes.

## Tests du code machine ARM

Exécution du véritable ELF avec **Unicorn 2.1.4** et **pyelftools 0.33**. Les GPIO IDR/ODR/BSRR et l'effacement EXTI sont modélisés. Les injections d'ISR préservent le contexte CPU et respectent PRIMASK; elles ne constituent pas une simulation complète du NVIC ni de l'empilement matériel d'exception. Les valeurs de cycle sont synthétiques et servent uniquement à tester le calcul des différences DWT.

Résultats : **12 groupes réussis**.

1. Initialisation rouge, champs RCC/GPIO, EXTI/NVIC; entrée IRQ13 de la table des vecteurs liée au gestionnaire fort.
2. Cycle User exact rouge → verte → rouge → bleue → rouge.
3. Vingt appuis → vingt transitions; maintien 2000 pas → une transition; rebonds courts ignorés; identifiants invalides refusés.
4. ISR dans les trois états normaux : mise en sécurité, drapeau, effacement des requêtes.
5. Clignotement : demi-périodes de 250 pas, mesures de demi-période et de période complète calculées.
6. Acquittement refusé si E-Stop maintenu, pas de reprise au seul relâchement, User ignoré, nouvel appui Touch accepté après relâchement.
7. Touch hors urgence : bascule 0→1→0 et extinction de 100 pas.
8. User+Touch simultanés; acquittement+User ne provoque pas un redémarrage.
9. Injection d'un E-Stop aux **142 frontières d'instruction** du pas validant une transition User : pas de réallumage verte/bleue après l'ISR, état urgent au plus tard au pas suivant. Au plus une DEL vérifiée après chaque écriture BSRR.
10. Interruption pendant `delay_ms`; durée zéro retourne immédiatement.
11. E-Stop maintenu au démarrage : requête logicielle NVIC programmée.
12. AAPCS : registres R4–R11 préservés, SP restauré et aligné aux appels, PRIMASK restauré, y compris lorsqu'il était déjà positionné.

Le plus long masquage observé sur le chemin de transition testé est de **89 instructions**. Ce nombre n'est ni une mesure de temps sur carte ni une preuve exhaustive du pire temps d'exécution.

Reproduction facultative :

```powershell
python -m pip install unicorn==2.1.4 pyelftools==0.33
python tests/test_emulation.py build/CEG3536_Lab1_Complet.elf
```

## Intégrité du projet

- XML de `.project`, `.cproject`, du lancement Debug et de `language.settings.xml` analysé avec succès.
- Le startup, le script de liaison, syscalls.c et sysmem.c sont identiques octet pour octet aux pièces jointes originales.
- Les noms du projet, les chemins Debug et les métadonnées de fréquence sont cohérents avec `CEG3536_Lab1_Complet` et 4 MHz.

## Vérifications restantes sur la carte

- T4 : niveaux actifs réels et résistances de rappel, notamment PB2/PB5.
- E1/T1 : comportement au reset et délai réel d'initialisation.
- E4/T5 : démonstration avec EXTI réelle et justification temporelle sur le matériel.
- E8/T6 : fréquence réelle, fonctionnement DWT, calibration et période dans la tolérance.
- T1–T10 : captures et résultats de la démonstration sur Leafy/Nucleo, particulièrement rebonds physiques et appuis simultanés.

Aucun verdict matériel positif n'est prérempli dans `preuves/RESULTATS_CARTE.csv`.
