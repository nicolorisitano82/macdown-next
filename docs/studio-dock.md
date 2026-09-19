# Studio: un plug-in per l'icona nel Dock

`NSDockTilePlugIn` è il pezzo di un'applicazione che **gira quando
l'applicazione non c'è**: il Dock lo carica per conto suo e gli lascia due
cose, il badge sull'icona e il menu che compare col tasto destro.

La domanda non è se si può fare — si può, ed è poco codice. La domanda è
**cosa ci si mette dentro**, perché quel menu è uno dei tre o quattro posti
in cui si finisce quando non si ha ancora aperto niente, e un badge che dice
sempre zero è rumore su un'icona.

Quello che segue è misurato sul sistema di questo Mac e sul codice che c'è,
non ricordato.

---

## 1. Com'è fatto

Dall'intestazione dell'SDK (`AppKit/NSDockTile.h`, SDK di macOS 26):

> *An application may customize its dock tile when not running via a plugin
> whose principal class implements the NSDockTilePlugIn protocol. […] The
> plugin is loaded in a system process at login time or when the application
> tile is added to the Dock.*

Il protocollo è di due metodi, e uno è facoltativo:

```objc
@protocol NSDockTilePlugIn <NSObject>
@required
- (void)setDockTile:(nullable NSDockTile *)dockTile;
@optional
- (nullable NSMenu *)dockMenu;
@end
```

* `-setDockTile:` arriva quando il plug-in viene caricato, e arriva di nuovo
  **con nil** quando l'icona esce dal Dock: è lì che si smette.
* `-dockMenu` viene chiamato ogni volta che il menu si apre, e le voci che
  torna finiscono **prima** di quelle standard. L'intestazione avverte di
  una trappola precisa: il menu va tenuto in una proprietà forte, perché
  autoreleased viene deallocato prima che l'utente scelga e **le selezioni
  vengono ignorate**.

Il pacchetto è un bundle come gli altri:

| | |
|---|---|
| Dove | `MacDown Next.app/Contents/PlugIns/<nome>.docktileplugin` |
| Cos'è | `CFBundlePackageType = BNDL` |
| Chi risponde | `NSPrincipalClass` nell'Info.plist del plug-in |
| Come lo si dichiara | chiave `NSDockTilePlugIn` nell'Info.plist **dell'app**, col nome del bundle |

## 2. Chi ce l'ha, su questo Mac

Cercata la chiave `NSDockTilePlugIn` negli Info.plist di `/Applications` e
`/System/Applications`:

* di Apple: **Calendario** (il giorno di oggi disegnato sull'icona),
  **Orologio**, **Telefono**, **FaceTime**, **Comandi Rapidi**, **App
  Store**, **Impostazioni**;
* di terzi, uno solo installato qui: **Cyberduck**, con
  `Cyberduck Dock Plugin.docktileplugin` — identificatore
  `ch.sudo.cyberduck.docktile`, classe principale `CDDockTilePlugin`,
  firmato Developer ID con hardened runtime.

Dentro non c'è niente di esotico: `Info.plist`, un eseguibile, `Resources`,
`_CodeSignature`. Trecento byte di firma e un binario universale.

## 3. Il perimetro, che qui conta più del solito

Il codice **gira dentro il processo del Dock** (che ha accanto un
`DockHelper.xpc`). Non è casa nostra, e questo detta tutto:

* **niente finestre, niente pannelli**: si può disegnare sul tile e basta;
* **niente attese**: una lettura lenta blocca il menu del Dock di chi sta
  usando il Mac. Tutto quello che si fa lì dentro dev'essere una lettura di
  file locale e finire in millisecondi;
* **niente rete e niente portachiavi**: una richiesta di permessi a nome
  «Dock» è inaccettabile, e comunque fallirebbe. Questo **esclude Google
  Drive** da qualunque idea che segue: gettoni e chiamate HTTP non entrano
  nel Dock;
* **niente stato nostro**: il plug-in vive e muore quando decide il Dock.
  Quello che sa, lo legge da un file che ha scritto l'applicazione.

E una condizione che non dipende da noi: **l'applicazione dev'essere tenuta
nel Dock**. Chi la lancia da Spotlight e non la tiene lì non vedrà mai
niente di tutto questo.

## 4. La domanda che decide, e va misurata per prima

MacDown Next è firmata **ad-hoc** (nessun certificato Apple). Il Dock, a
sua volta, gira con `flags=0x0` — niente hardened runtime, niente library
validation — quindi *in teoria* carica anche un bundle che non è Developer
ID. In teoria.

Due cose da verificare, e sono mezza giornata:

1. il Dock carica un `.docktileplugin` firmato ad-hoc?
2. lo carica ancora dopo che l'app è passata per un DMG scaricato, con la
   quarantena addosso?

Si risponde con un plug-in di venti righe che mette il badge `1`. Se la
risposta è no, tutto il resto di questo documento è teoria, e va detto
subito invece che dopo aver scritto il menu.

## 5. Cosa ci metterei

### a. Il badge di cosa si è mosso nella cartella collegata

È l'unica idea che sfrutta lavoro già fatto. Il registro della
sincronizzazione è già un file locale, e contiene esattamente quello che
serve:

```
~/Library/Application Support/MacDown/sync/icloud.plist
{
  "documents" => { "<id>" => { "name" => "prova.md", "revision" => "…" } }
  "startToken" => "256"
}
```

Il plug-in elenca la cartella di iCloud Drive — che su un Mac è una cartella
e basta — la confronta col registro, e mette il numero: *tre documenti sono
cambiati mentre non c'eri*. Letture di file, niente rete, niente permessi.

Per **Google Drive non si fa**, e la ragione è il §3: senza gettoni non si
sa niente, e i gettoni nel Dock non ci vanno. Meglio un badge che parla di
una cartella sola che un badge che mente sulle altre.

### b. Il menu ad applicazione chiusa

Oggi, a freddo, il Dock offre «Apri» e i documenti recenti che mette lui.
Potrebbe offrire, prima di quelli:

* **Nuovo documento**
* **Nuovo da modello ▸** — i modelli sono già file in
  `~/Library/Application Support/MacDown/Templates`
* **Nella cartella collegata ▸** — i nomi presi dal registro o dalla
  cartella

Il gancio per farli partire **esiste già**: l'applicazione registra lo
schema `x-macdown` e risponde a `x-macdown://open?url=file:///…`. Vanno
aggiunti due comandi (`new`, `new?template=…`), che sono poche righe nello
stesso posto.

### c. La voce che ha guardato gli appunti

Questa è quella che rende il menu diverso da un elenco di scorciatoie. Il
plug-in può leggere la pasteboard, che costa niente:

* se dentro c'è un **indirizzo**: *«Ritaglia questa pagina»* — il ritaglio
  web c'è già;
* se c'è **testo**: *«Nuovo documento dagli appunti»*.

Premi, l'applicazione parte e il documento è già lì. È il momento in cui il
Dock smette di essere un pulsante di avvio e diventa una scorciatoia.

Serve un comando in più (`x-macdown://clip?url=…`), e una regola: se negli
appunti non c'è niente di utile, **la voce non compare**. Una voce disattiva
è una promessa non mantenuta scritta in grigio.

### d. Lo stato del server MCP

`macdownext-mcp` gira anche ad applicazione chiusa, e il suo diario è un
file locale: si potrebbe dire se sta servendo qualcuno e quante richieste ha
fatto oggi. È onesto e insolito, ma è diagnostica: viene per ultimo, se
viene.

### Cosa non ci metterei

Contatori di parole scritte, giorni di fila, medaglie. Un editor non deve
fare il tifo per chi scrive. E niente che voglia rete, portachiavi o
tempo: nel processo del Dock sono tre modi diversi di fare danno a casa
d'altri.

## 6. Le fasi

| Fase | Cosa | Quando è finita |
|---|---|---|
| **D0** | Il plug-in minimo che mette `1`, firmato come lo firmiamo noi, provato anche dopo il giro nel DMG | quando si sa se questa strada esiste per un'app non firmata Developer ID |
| **D1** | Il menu: nuovo documento, modelli, appunti. Nessuno stato, niente che possa dire il falso | quando ad app chiusa il tasto destro offre qualcosa che prima non c'era |
| **D2** | Il badge dal registro, solo per iCloud Drive | quando il numero è vero anche il lunedì mattina — e quando non si sa, non c'è numero |

## 7. Il dubbio, una volta

Il Dock è un posto che si guarda per **lanciare**, non per leggere. Un badge
che dice quasi sempre zero non aggiunge niente e toglie un po' di pulizia
all'icona; e tutta questa roba la vede soltanto chi l'applicazione la tiene
nel Dock.

La parte che vale da sola, secondo me, è **il menu** — e dentro il menu, la
voce che ha già guardato gli appunti: risolve un gesto vero (ho un indirizzo,
voglio farne un documento) senza chiedere a nessuno di guardare un'icona.
Il badge è la parte che farei per seconda, e solo se D0 dice di sì.
