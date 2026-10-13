<p align="center">
  <img src="assets/brand/Punto.png" width="96" alt="Icona di Punto">
</p>

<h1 align="center">Punto</h1>

<p align="center">
  Il tuo Mac, dal controller.<br>
  Mouse, shortcut e app launcher per il DualSense della PS5.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-12%2B-202024?logo=apple&amp;logoColor=white" alt="macOS 12 o successivo">
  <img src="https://img.shields.io/badge/UI-SwiftUI-F05259" alt="Interfaccia SwiftUI">
  <img src="https://img.shields.io/badge/Input-C-555555" alt="Input in C">
  <img src="https://img.shields.io/badge/status-in%20sviluppo-F05259" alt="In sviluppo">
</p>

<p align="center">
  <a href="#cosa-fa">Funzioni</a> ·
  <a href="#screenshot">Screenshot</a> ·
  <a href="#avvio">Avvio</a> ·
  <a href="docs/DEVELOPMENT.md">Sviluppo</a>
</p>

---

## Cosa fa

| | Funzione |
| :--- | :--- |
| **Mouse** | Muovi il cursore con il joystick destro o il touchpad. |
| **Scroll** | Tieni premuto R1 e usa il joystick destro. Sensibilità regolabile. |
| **Shortcut** | Registra la tua combinazione, anche solo modificatori come ⌥⇧. |
| **Push-to-talk** | La combinazione resta premuta finché tieni premuto il pulsante. |
| **Pressione lunga** | Assegna una seconda shortcut allo stesso pulsante. |
| **Launcher** | Quattro direzioni, fino a due app per direzione. Apertura immediata. |

Interfaccia **nativa SwiftUI**, temi scuro/chiaro/sistema e preferenze salvate automaticamente. Nessun server, account o servizio web richiesto dall’app.

## Screenshot

### Un launcher come un HUD

Premi una freccia: l’app si apre subito e l’overlay mostra la selezione. Ripremi la stessa freccia mentre è visibile per passare alla seconda app. Il feedback scompare dopo **1,2 secondi**: nessun pulsante di conferma.

<p align="center">
  <img src="docs/screenshots/launcher-overlay.png" width="640" alt="Overlay compatto di Punto: due applicazioni per ciascuna delle quattro direzioni">
</p>

<p align="center"><sub>Overlay reale con applicazioni dimostrative. Nessuna app viene preconfigurata all’installazione.</sub></p>

### Ogni pulsante, la tua azione

Shortcut registrate, applicazioni da richiamare e una colonna separata per la pressione lunga.

<p align="center">
  <img src="docs/screenshots/buttons.png" width="960" alt="Configurazione dei pulsanti: azione principale e shortcut per la pressione lunga">
</p>

<details>
<summary><strong>Mouse e configurazione del launcher</strong></summary>

### Mouse e scroll

Velocità del cursore, zona morta e sensibilità dello scroll sono configurabili. Lo scroll è indipendente dalla velocità del mouse.

<img src="docs/screenshots/mouse.png" width="960" alt="Impostazioni mouse con slider dedicato alla sensibilità dello scroll">

### Le tue app nelle quattro direzioni

Scegli fino a **otto applicazioni**, distribuite tra su, destra, giù e sinistra.

<img src="docs/screenshots/launcher-settings.png" width="960" alt="Configurazione del launcher direzionale con due slot applicazione per direzione">

</details>

## Controlli

| Controller | Azione |
| :--- | :--- |
| Joystick destro | Muove il cursore |
| Touchpad | Muove il cursore con un dito |
| **R1 + joystick destro** | Scroll verticale e orizzontale |
| **R2** | Click sinistro; mantieni premuto per trascinare |
| **L2** | Click destro; mantieni premuto per trascinare |
| **↑ → ↓ ←** | Aprono l’app nella direzione; ripremi per la seconda |
| **○ nell’overlay** | Chiude il feedback visivo |
| **Options** | Attiva o sospende il controllo |
| Altri pulsanti | Shortcut o applicazioni personalizzabili |

> **Pressione lunga:** senza Hold, la shortcut parte subito e resta premuta fino al rilascio. Con Hold, un tap esegue l’azione principale al rilascio; dopo **0,45 s** si attiva solo la shortcut lunga.

## Avvio

### Requisiti

- **macOS 12+** e DualSense standard, via USB o Bluetooth.
- **Command Line Tools di Apple** con Swift e SDK macOS. Xcode completo non serve.
- Un certificato locale per la firma: vedi [configurazione della build](docs/DEVELOPMENT.md#firma-locale).

### Compila e apri

```sh
git clone git@github.com:guglielmobartelloni/Punto.git
cd Punto
make
open build/PadMac.app
```

La repository è privata: serve un account GitHub autorizzato per clonarla.

### Prima configurazione

1. Collega il controller. Per Bluetooth, tieni premuti **PS + Create** fino al lampeggio e abbinalo nelle impostazioni di macOS.
2. In Punto, apri **Permessi → Apri impostazioni Accessibilità** e autorizza l’app. Concedi anche **Monitoraggio input** se richiesto da macOS.
3. Configura **Pulsanti**, **Launcher** e **Mouse**, poi premi **Attiva**.

Punto parte sempre sospeso. Chiudere le impostazioni lo lascia nella barra dei menu; il Dock compare solo mentre la configurazione è aperta.

## Da sapere

- È una versione **in sviluppo**, non ancora distribuita con firma Developer ID e notarizzazione.
- Sono supportati **un controller alla volta** e il DualSense standard, non il DualSense Edge.
- R1, Options e le frecce hanno ruoli riservati. Gli altri pulsanti restano personalizzabili.
- Alcune combinazioni riservate da macOS potrebbero non essere registrabili o riproducibili.
- Il bundle si chiama ancora `PadMac.app` per conservare percorso, identità di firma, permessi e preferenze. Il nome visualizzato è **Punto**.

## Sviluppo

```sh
make test                 # Input, shortcut, scroll e selezione direzionale
make test-dock            # Ciclo di vita della finestra e del Dock
make test-launcher-ui     # Overlay, routing e preview con app dimostrative
```

I due test UI richiedono una sessione grafica macOS. Non avviano le app dimostrative e non modificano le assegnazioni del launcher.

→ [Architettura, firma locale e verifiche manuali](docs/DEVELOPMENT.md)
