# CEG3536 — Laboratoire 1 complet

Projet **CEG3536_Lab1_Complet**, NUCLEO-L552ZE-Q / Leafy, assembleur GNU ARM, sans HAL. Réalisé à partir des fichiers de démarrage fournis et de l'énoncé **v1.2 du 23 septembre 2026**. Les modules applicatifs couvrent E1 à E9; le guide détaille la démonstration T1 à T10.

**État de validation : compilation GNU Arm réussie sans avertissement; essais du code machine en émulation réussis. La carte physique n'a pas été programmée ni testée ici.** Les polarités/PUPDR de T4 et la calibration de E8 restent à confirmer sur votre matériel. `1000` itérations/ms est la valeur de départ du cours, pas une mesure validée.

## Ouvrir et exécuter

1. Décompresser le ZIP dans un dossier local. Dans STM32CubeIDE : **File > Import > General > Existing Projects into Workspace**; choisir le dossier `CEG3536_Lab1_Complet` contenant `.project` et `.cproject`.
2. Choisir **Debug**, puis **Project > Clean** et **Build Project**. Le projet produit `Debug/CEG3536_Lab1_Complet.elf`. Les fichiers `.s` doivent être assemblés avec le préprocesseur (`-x assembler-with-cpp`), comme dans le projet de départ.
3. Brancher la carte par ST-LINK. Utiliser la configuration **CEG3536_Lab1_Complet Debug**, ou **Debug As > STM32 C/C++ Application**. Reprendre avec **F8** après l'arrêt sur `main`.
4. User : **rouge → verte → rouge → bleue → rouge**. E-Stop : urgence, rouge clignotante. Relâcher E-Stop puis faire un nouvel appui Touch En pour revenir à l'arrêt. Touch En hors urgence : bascule de `touch_enabled` et extinction brève.
5. Suivre **GUIDE_DEMONSTRATION.md** pour les réglages et les preuves. Le moteur n'est pas commandé par ce projet.

Hypothèses du projet : **TZEN=0**, MSI de reset **4 MHz**, DEL actives à 1. Ne pas changer les options TrustZone sur la seule base de cette notice; ce projet reprend la configuration matérielle de l'énoncé. Les boutons sont initialement configurés actifs à 1, sans rappel interne : confirmer T4.

## Fichiers

| Fichier | Rôle |
|---|---|
| `Core/Src/main.s` | Initialisation et boucle de scrutation |
| `Core/Src/gpio.s` | RCC, GPIO, commande exclusive des DEL, protection contre E-Stop concurrent |
| `Core/Src/buttons.s` | Lecture normalisée, anti-rebond 30 échantillons, front d'appui, délai calibrable |
| `Core/Src/estop.s` | EXTI2/NVIC et ISR de mise en sécurité |
| `Core/Src/fsm.s` | Machine à états, acquittement, Touch En, signalisation |
| `Core/Src/timing.s` | Activation DWT et mesures du clignotement pour T6 |
| `Core/Src/registres.inc` | Constantes originales et extensions nommées |
| `Core/Inc/lab1.h` | Interface C pour le laboratoire 3 |
| `GUIDE_DEMONSTRATION.md` | Procédures, expressions Watch, calibration, explications pour le rapport |
| `preuves/RESULTATS_CARTE.csv` | Tableau à remplir avec les résultats réellement observés |
| `VALIDATION.md` | Portée des vérifications effectuées ici |

Les fichiers générés `startup_stm32l552zetxq.s`, `STM32L552ZETXQ_FLASH.ld`, `syscalls.c` et `sysmem.c` sont conservés **à l'identique**. Les trois pièces jointes `download`, `download (1)` et `download (2)` ont été rétablies en `.cproject`, `.gitignore` et `.project`. Le nom du projet et les métadonnées de fréquence du débogueur ont été adaptés; la fréquence matérielle n'est pas modifiée.

## Construire sans CubeIDE, sous Windows

Avec un compilateur GNU Arm installé par CubeIDE, CubeCLT ou une distribution compatible :

```powershell
.\build.ps1 -ToolchainBin 'C:\chemin\vers\GNU-tools-for-STM32\bin'
```

`build.ps1` produit ELF, BIN et HEX dans `build/`, sans programmer la carte. Le dossier `build/` livré contient déjà les résultats de compilation de cette version, avec les hypothèses initiales de polarité et de calibration. **Recompiler après toute modification des constantes.** La configuration Debug de CubeIDE construit sa propre version dans `Debug/`.

Le Makefile original reste disponible pour un environnement GNU Make avec les outils POSIX utilisés par ses commandes (`mkdir -p`, `rm`). Adapter `CLT` à l'installation locale. Le script PowerShell évite cette dépendance.

## Sources et traçabilité

- Projet `CEG3536_Lab1_Demarrage` fourni par le cours; PDF explicatif associé.
- Énoncé `CEG3536_Lab1_Automne_2026_v1.2.pdf`, notamment E1–E9 et T1–T10. Cette version remplace les anciennes demandes de mesures aux broches par IDR, DWT et analyse logicielle.
- [ST, RM0438](https://www.st.com/resource/en/reference_manual/dm00346336-stm321552xx-and-stm321562xx-advanced-arm-based-32-bit-mcus-stmicroelectronics.pdf).
- [ST, définitions CMSIS du STM32L552](https://github.com/STMicroelectronics/cmsis-device-l5/blob/master/Include/stm32l552xx.h), vérification des adresses, du champ EXTI2 et de IRQ13.
- Assistance : OpenAI Codex, modèle GPT-6, génération/intégration du code, revue, compilation, essais simulés et rédaction de ce guide. Reprendre cette utilisation dans la déclaration du rapport; renseigner la version précise affichée par votre application si demandée.

Le `JOURNAL.md` fourni conserve les champs d'identité, de rôles et d'historique à remplir par l'équipe. Aucun résultat matériel, rôle, capture ou historique Git n'a été inventé.
