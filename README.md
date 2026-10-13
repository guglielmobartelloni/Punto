# Punto

App macOS nativa: SwiftUI per le impostazioni, C per HID e generazione eventi, Objective-C/AppKit per il ciclo di vita, i selettori e la registrazione shortcut. Non richiede Xcode completo, solo i Command Line Tools con Swift e l’SDK macOS. Compatibile con macOS 12 o successivo.

## Avvio

```sh
make
open build/PadMac.app
```

Collega un DualSense standard tramite USB o Bluetooth (tieni premuti PS + Create fino al lampeggio e abbinalo nelle impostazioni Bluetooth). Apri Punto, seleziona «Permessi» nella sidebar, premi «Apri impostazioni Accessibilità» e autorizza Punto. Se macOS lo richiede, autorizza anche Monitoraggio input e riavvia l'app.

- Joystick destro: cursore, con velocità e zona morta regolabili.
- Touchpad DualSense: movimento relativo con un dito; solleva il dito per riposizionarlo senza spostare il cursore. Sensibilità iniziale fissa a 0,8 punti per unità del sensore. Sono decodificati i report USB 0x01 e Bluetooth completi 0x31; i report Bluetooth semplificati non contengono il touchpad.
- R2: click sinistro; L2: click destro. Mantieni premuto per trascinare. L1 e R1 non sono assegnati.
- Pulsanti (escluse frecce e Options): azione selezionabile nelle impostazioni, incluse «Registra shortcut…», nessuna azione e «Apri applicazione…». Scegli un bundle .app dal Finder: viene avviato o richiamato in primo piano se già aperto. Le assegnazioni sono persistenti. PS/Mute dipendono dagli eventi resi disponibili da macOS e dal firmware.
- R2 e L2 mantengono il click come azione predefinita, ma possono essere riassegnati. Options rimane riservato alla sospensione per sicurezza.
- Cambiare un’assegnazione sospende il controllo e rilascia gli eventuali click mantenuti: premi «Attiva» al termine.
- Il menu nella colonna «Pressione lunga» accanto a ogni pulsante configura una seconda shortcut per la pressione lunga (0,45 secondi). La combinazione lunga resta premuta fino al rilascio; l’azione breve non viene eseguita. Se rilasci prima della soglia, l’azione principale viene eseguita come un tap al rilascio. Senza assegnazione Hold, il comportamento immediato precedente resta invariato, incluso push-to-talk. Il menu «Pressione lunga» permette di registrare nuovamente o rimuovere l’assegnazione. Options resta riservato. Assegnare Hold a R2/L2 sostituisce il normale trascinamento con distinzione tap/pressione lunga.
- Frecce del D-pad: aprono il Launcher e selezionano una delle due app configurate nella direzione premuta.
- Options: attiva o sospende il controllo e chiude l’eventuale Launcher.
- Menu 🎮: impostazioni, attiva/sospendi, esci.

Il controllo parte sempre sospeso e si disattiva alla disconnessione. Le preferenze vengono salvate tramite NSUserDefaults.

Il nome visualizzato è **Punto**, con icona personalizzata. Il progetto rimane in `Projects/PadMac` e il bundle in `build/PadMac.app`: percorso, eseguibile `PadMac`, identificativo `local.padmac.controller` e certificato di firma originali vengono mantenuti per preservare preferenze e autorizzazioni. Le vecchie voci di Accessibilità possono ancora apparire come PadMac. Nessun certificato o chiave privata è incluso nel repository.

## Interfaccia SwiftUI

La finestra apre direttamente «Pulsanti», senza Panoramica: elenco compatto con colonne per azione principale e pressione lunga, ricerca per nome/app/shortcut e filtro per gruppo. La sidebar contiene Pulsanti, Launcher, Mouse e Permessi. Il tema predefinito è scuro; il menu «Tema» permette di selezionare Chiaro o Sistema. La scelta viene salvata. L’interfaccia aggiorna connessione, permesso e stato del controllo in tempo reale, preservando tutte le preferenze delle versioni precedenti.

`UIController.h` definisce il contratto tra SwiftUI (`UI.swift`) e il runtime Objective-C (`main.m`). Le modifiche alle assegnazioni sospendono il controllo prima di aprire il selettore o il registratore. Il bundle e il requisito di firma restano invariati. Quando la configurazione è aperta, Punto compare nel Dock e in ⌘Tab; alla chiusura della finestra torna nella sola barra dei menu, senza interrompere il controllo. Il click sull’icona nel Dock riporta la configurazione in primo piano.

## Launcher direzionale

Configura le app nella sezione «Launcher»: due slot per ciascuna direzione (su, destra, giù, sinistra), per un massimo di otto app. I percorsi vengono salvati automaticamente. Le eventuali app già assegnate alle frecce nelle versioni precedenti vengono migrate nel primo slot; shortcut e Hold precedenti restano conservati ma le frecce sono ora riservate al Launcher.

Con il controllo attivo:

1. Premi una freccia: si apre l’overlay scuro e si seleziona la prima app disponibile in quella direzione.
2. Ripremi la stessa freccia per alternare tra le due app, saltando gli slot vuoti. Cambiando direzione, selezioni la prima app disponibile della nuova direzione.
3. Premi ✕ per aprire/richiamare l’app e chiudere l’overlay. Uno slot vuoto non apre nulla.
4. Premi ○ per annullare. Options sospende il controllo e chiude l’overlay.

Non viene avviata nessuna app alla sola pressione della freccia. Mantenere premuta una freccia non ripete la navigazione: occorre rilasciarla e ripremerla. Mentre l’overlay è aperto, gli altri pulsanti vengono consumati e joystick/touchpad non muovono il mouse. All’apertura vengono rilasciate eventuali shortcut/click mantenuti e cancellate le pressioni lunghe in attesa. Alla chiusura si ripristina il controllo normale.

L’overlay è un pannello non attivante: non ruba il focus alla finestra in uso, non porta la configurazione in primo piano e da solo non aggiunge l’app al Dock. Non usa asset di videogiochi. `LauncherUI.swift` contiene la vista e `launcher.c` la macchina a stati di selezione.

## Limiti attuali

Il filtro HID riconosce il DualSense standard Sony (054c:0ce6), non il DualSense Edge. Mapping HID e comportamento USB/Bluetooth devono essere verificati con un controller reale. È gestito un controller alla volta. Le shortcut si registrano premendo la combinazione nella finestra «Registra shortcut…» e cliccando «Salva». Sono supportati tasti singoli e combinazioni con Command, Control, Option, Shift e Fn, comprese frecce, Escape e tasti funzione. Annulla e Salva si usano con il mouse, così Invio ed Escape sono registrabili. Le shortcut sono un singolo tasto con modificatori oppure una combinazione di soli modificatori (es. Option + Shift), non macro/sequenze. Per registrare soli modificatori, premili insieme, rilasciali e clicca Salva: il rilascio conserva la combinazione completa. I soli modificatori vengono riprodotti come eventi flagsChanged: la pressione resta attiva per tutta la durata della pressione del pulsante del controller, e il rilascio avviene soltanto quando lo lasci. Lo stesso vale per le shortcut con un tasto normale. È quindi possibile usare push-to-talk con Option + Shift. Le app, invece, vengono aperte una sola volta alla pressione. Sospensione, cambio assegnazione, perdita del permesso Accessibilità, disconnessione e uscita normale rilasciano tutti i tasti sintetici mantenuti. Le combinazioni condivise da più pulsanti usano conteggi di riferimento per evitare rilasci anticipati. Alcune combinazioni intercettate direttamente da macOS (per esempio shortcut globali o tasti multimediali) potrebbero non arrivare alla finestra o non essere riproducibili tramite CGEvent. I keycode sono fisici: cambiando layout di tastiera può cambiare il carattere prodotto. Le vecchie assegnazioni vengono migrate senza rimuovere le app configurate; le nuove installazioni non hanno shortcut preimpostate. Le app sono salvate per percorso: se vengono spostate o rimosse, occorre selezionarle nuovamente. Non sono inclusi profili per applicazione, avvio automatico, firma Developer ID o notarizzazione. La compilazione usa il certificato «PadMac Local Development» nel Portachiavi login, con un requisito di firma stabile legato al certificato e all’identificativo dell’app. Al passaggio dalla precedente firma ad-hoc è necessario concedere nuovamente Accessibilità. Le compilazioni successive mantengono la stessa identità: non eliminare il certificato o la relativa chiave privata dal Portachiavi. Il certificato è locale, non è una firma Developer ID e non consente la notarizzazione. Su un altro Mac occorre configurare un nuovo certificato e aggiornare il requisito nel Makefile.

La lettura controller usa IOKit/HID non esclusivo. Se si avvia un gioco, sospendere Punto per evitare input simultanei. Non è necessario autorizzare Terminale per l'avvio del bundle tramite `open`.

## Verifica manuale

1. Verificare connessione e disconnessione USB e Bluetooth.
2. Concedere Accessibilità e attivare il controllo.
3. Verificare direzioni del joystick, assenza di deriva e limiti del cursore. Provare il touchpad via USB e Bluetooth: movimento nelle quattro direzioni, sollevamento/riposizionamento del dito, trascinamento con R2, sospensione tramite Options.
4. Provare click sinistro con R2, destro con L2 e trascinamento con ciascun grilletto; verificare il rilascio anche premendoli entrambi.
5. Provare shortcut in un documento non importante.
6. Verificare sospensione tramite Options, disconnessione durante un trascinamento e persistenza delle preferenze.
7. Assegnare un’app innocua a un pulsante e due app per direzione nel Launcher. Riattivare il controllo: verificare apertura alla prima freccia, cambio slot alla seconda, cambio direzione, ✕ per confermare e ○ per annullare. Verificare che le shortcut normali di ✕/○ non vengano eseguite nell’overlay.
8. Chiudere e riaprire Punto: verificare che le assegnazioni siano conservate. Provare annullamento del selettore app e ritorno al click predefinito su R2/L2.
9. Registrare una combinazione personalizzata (es. ⇧⌘S), un tasto singolo, Escape e una freccia; salvare e verificare l’esecuzione con il controller in un documento non importante. Verificare annullamento, nuova registrazione sulla stessa assegnazione e persistenza al riavvio.
10. Assegnare una shortcut Hold diversa dalla principale: verificare tap rapido (solo principale) e pressione oltre 0,45 s (solo Hold, mantenuta fino al rilascio). Provare Options e disconnessione sia prima sia dopo la soglia. Rimuovere Hold e verificare il ritorno al push-to-talk immediato.

## Test automatici

`make test` verifica il dispatch dei 19 slot, l’assenza di ripetizioni su pressione mantenuta, la sospensione e la riserva di Options. Verifica inoltre acquisizione di combinazioni arbitrarie, tasti speciali, filtri sui modificatori e migrazione delle preferenze, nonché mantenimento e rilascio delle shortcut, combinazioni condivise e rilascio di sicurezza alla sospensione/disconnessione/uscita. Verifica anche distinzione tra tap e pressione lunga, soglia, pressioni simultanee e cancellazione delle azioni in attesa. Non sostituisce il test fisico del mapping HID, della finestra di registrazione, della riproduzione delle shortcut o dell’apertura delle app.

`make test` include anche la selezione direzionale, il ciclo tra due app, gli slot vuoti e il reset del Launcher. `make test-launcher-ui` verifica il routing dei pulsanti, conferma/annullamento, pulizia alla sospensione e assenza di attivazione del Dock. Usa preferenze volatili isolate e intercetta l’apertura delle app: non modifica le assegnazioni e non avvia app reali. Salva una preview dell’overlay in `build/ui-launcher.png`.

`make test-dock` è un test nativo opzionale che apre e chiude una finestra di prova: verifica il cambio della activation policy, la riapertura e che chiudere le impostazioni non sospenda il controllo. Richiede una sessione grafica macOS.

## Verifica visiva locale

L’app supporta un’opzione di sviluppo che salva solo il contenuto della propria finestra, senza catturare il desktop:

```sh
open build/PadMac.app --args --ui-page buttons --ui-dark --ui-preview "$PWD/build/ui-buttons-dark.png"
```

L’app deve essere chiusa prima dell’avvio con questi argomenti. Le pagine disponibili sono `buttons`, `launcher`, `mouse`, `permissions`; `--ui-group Dorsali` permette di controllare i gruppi in fondo all’elenco. Per una preview chiara, omettere `--ui-dark`. Queste opzioni non cambiano le assegnazioni e non vengono usate nell’avvio normale.
