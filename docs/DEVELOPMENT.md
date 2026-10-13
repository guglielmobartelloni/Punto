# Sviluppo di Punto

[← Torna al README](../README.md)

Esegui i comandi dalla radice del progetto. La compilazione usa i Command Line Tools: non è necessario Xcode completo.

## Architettura

| File | Responsabilità |
| :--- | :--- |
| `UI.swift` | Impostazioni SwiftUI, temi, ricerca e filtri |
| `LauncherUI.swift` | Overlay direzionale compatto |
| `UIController.h` | Contratto tra SwiftUI e runtime Objective-C |
| `main.m` | Ciclo di vita, preferenze, apertura app e routing del controller |
| `input.c` | Lettura HID, cursore, click, touchpad e scroll |
| `keyboard.c` | Shortcut mantenute e conteggi di riferimento dei tasti |
| `longpress.c` | Distinzione tra tap e pressione lunga |
| `launcher.c` | Selezione e ciclo dei due slot per direzione |
| `ShortcutRecorder.m` | Registrazione delle combinazioni e migrazione delle preferenze |
| `scripts/generate-brand-icon.swift` | Generazione dell’icona macOS |

Il filtro HID riconosce il DualSense standard Sony, **VID 054c / PID 0ce6**. La lettura è non esclusiva: sospendi Punto quando giochi per evitare input simultanei.

## Firma locale

La build del repository è configurata per il certificato **PadMac Local Development**, presente nel Portachiavi del Mac di sviluppo. Il certificato e la chiave privata **non sono inclusi** nel repository.

Su un altro Mac:

1. Crea o importa nel tuo Portachiavi un’identità locale valida per il code signing.
2. Elenca le identità disponibili:

   ```sh
   security find-identity -v -p codesigning
   ```

3. Nel `Makefile`, aggiorna `SIGN_IDENTITY` con il nome del tuo certificato e il valore `certificate leaf = H"…"` con il suo fingerprint.
4. Compila e verifica:

   ```sh
   make
   codesign --verify --strict build/PadMac.app
   codesign -d -r- build/PadMac.app
   ```

Mantieni **certificato, bundle ID e requisito di firma stabili** tra le compilazioni. Un nuovo certificato o il passaggio dalla firma ad-hoc possono richiedere di rimuovere e riaggiungere l’app in Accessibilità.

La firma locale non sostituisce Developer ID e notarizzazione per la distribuzione ad altri utenti.

### Identità mantenuta

| Elemento | Valore |
| :--- | :--- |
| Nome visualizzato | Punto |
| Bundle | `build/PadMac.app` |
| Eseguibile | `PadMac` |
| Bundle ID | `local.padmac.controller` |

Il nome interno originale evita una migrazione non necessaria di preferenze e permessi. Le vecchie voci in Accessibilità possono ancora apparire come PadMac.

## Comportamento degli input

### Mouse e scroll

- Tick del cursore a **120 Hz**, con accelerazione progressiva e zona morta radiale.
- R1 cambia il joystick destro da cursore a scroll; il touchpad continua a muovere il mouse.
- Scroll continuo in pixel, con accumulo delle frazioni per non perdere i movimenti lenti.
- Sensibilità scroll: **100–3000 px/s**, valore iniziale **900**, indipendente dalla velocità del cursore.
- Touchpad: movimento relativo, sensibilità fissa **0,8 punti/unità**. Sono decodificati i report USB `0x01` e Bluetooth completi `0x31`.
- I report Bluetooth semplificati non contengono il touchpad.

### Shortcut

- Un tasto con modificatori oppure una combinazione di soli modificatori, non macro o sequenze.
- I soli modificatori sono riprodotti con eventi `flagsChanged`.
- Le combinazioni restano attive fino al rilascio del pulsante.
- I conteggi di riferimento evitano il rilascio anticipato di tasti condivisi tra più pulsanti.
- I keycode sono fisici: cambiando layout di tastiera può cambiare il carattere prodotto.
- Invio ed Escape sono registrabili; usa i pulsanti del dialogo per salvare o annullare.

### Tap e pressione lunga

- Senza Hold: pressione immediata, rilascio al rilascio del controller.
- Con Hold: tap sotto **0,45 s** → azione principale al rilascio; oltre la soglia → solo la shortcut lunga, mantenuta fino al rilascio.
- Un Hold su R2/L2 sostituisce il normale trascinamento con questa distinzione.

### Launcher

- Due slot per ciascuna delle quattro direzioni, salvati per percorso.
- Una freccia seleziona e **apre immediatamente** la prima app disponibile.
- Ripremere la stessa freccia mentre l’overlay è visibile alterna i due slot, saltando quelli vuoti.
- Una nuova direzione seleziona la sua prima app disponibile.
- L’overlay si chiude **1,2 s** dopo l’ultima freccia; la pressione successiva riparte dal primo slot.
- ○ chiude solo il feedback visivo: l’app già aperta non viene chiusa.
- Pannello non attivante, massimo **560 × 400 punti**: non ruba il focus e da solo non aggiunge Punto al Dock.
- Durante l’overlay gli altri pulsanti sono consumati e il cursore è fermo.

Le vecchie app assegnate alle frecce vengono migrate nel primo slot. Le precedenti shortcut/Hold delle frecce e di R1 sono conservate, ma non eseguite perché questi input sono ora riservati.

### Sicurezza e preferenze

Punto parte sospeso. Sospensione, disconnessione, perdita di Accessibilità e uscita normale rilasciano i tasti sintetici mantenuti. Cambiare un’assegnazione sospende il controllo prima di aprire un selettore; il Launcher annulla click/shortcut mantenuti e pressioni lunghe in attesa.

Le preferenze sono salvate con `NSUserDefaults`. Le app sono memorizzate per percorso: se spostate o rimosse, vanno selezionate nuovamente.

## Test

```sh
make test
make test-dock
make test-launcher-ui
```

| Suite | Verifica |
| :--- | :--- |
| `buttons` | Dispatch, deduplicazione delle pressioni, sospensione |
| `shortcuts` | Registrazione, tasti speciali, modificatori e migrazione |
| `keyboard` | Mantenimento, combinazioni condivise e rilasci di sicurezza |
| `longpress` | Soglia, esclusione tap/Hold e cancellazione |
| `launcher` | Direzioni, due slot, slot vuoti e reset |
| `scroll` | Direzioni, sensibilità, limiti, frazioni e ritorno al cursore |
| `dock` | Dock alla configurazione aperta, chiusura e riapertura |
| `launcher-ui` | Routing, apertura automatica, chiusura e preview dell’overlay |

Le suite UI richiedono una sessione grafica macOS. Il test del Launcher usa preferenze volatili isolate e intercetta le aperture: **non modifica le assegnazioni e non avvia le app di esempio**.

## Verifica manuale

- [ ] Connessione e disconnessione USB e Bluetooth.
- [ ] Direzioni del cursore, zona morta e monitor multipli.
- [ ] Touchpad, sollevamento e riposizionamento del dito.
- [ ] R2/L2: click e trascinamento; rilascio corretto premendoli insieme.
- [ ] R1: scroll nei quattro sensi, cambio sensibilità e ritorno al mouse.
- [ ] Shortcut normali e ⌥⇧ mantenute, anche con un assistente vocale.
- [ ] Tap/Hold e sospensione prima/dopo la soglia.
- [ ] Launcher: apertura automatica, secondo slot, cambio direzione e timeout.
- [ ] Nessuna shortcut normale di ✕/○ durante l’overlay.
- [ ] Persistenza delle preferenze al riavvio.
- [ ] Annullamento dei selettori senza modificare l’assegnazione precedente.

I test automatici non sostituiscono la verifica con un controller reale e nelle applicazioni destinatarie.

## Screenshot

Per salvare solo il contenuto della finestra, senza catturare il desktop:

```sh
# Chiudi prima l’app, poi avviala con gli argomenti di preview.
open build/PadMac.app --args \
  --ui-page mouse --ui-dark \
  --ui-preview "$PWD/build/ui-mouse.png"
```

Pagine: `buttons`, `launcher`, `mouse`, `permissions`. `--ui-group Dorsali` filtra i pulsanti. Ometti `--ui-dark` per una preview chiara. Le opzioni non cambiano le assegnazioni.

`make test-launcher-ui` genera `build/ui-launcher.png` con app dimostrative. Le immagini pubblicate nel README sono in `docs/screenshots/`.

## Limiti attuali

- Un controller alla volta; DualSense Edge non supportato.
- Nessun profilo per applicazione, avvio automatico o pacchetto notarizzato.
- PS e Mute dipendono dagli eventi resi disponibili da macOS e firmware.
- Le combinazioni intercettate direttamente da macOS e alcuni tasti multimediali potrebbero non essere catturati o riproducibili.
