# Due anteprime: quella sotto il puntatore e quella nel Finder

Diario breve, nella serie del [WYSIWYG](wysiwyg-testo.md), dei
[blocchi di codice](blocchi-codice.md) e del [plugin drawio](drawio.md).
Due funzioni che sembrano lontane e chiedono la stessa cosa: **sapere cosa
c'è dall'altra parte senza aprire niente**.

---

## Ferma il puntatore su un link, e te lo dico

Nell'anteprima, tenendo il puntatore su un link per **cinque secondi**, si
apre una cartolina piccola: titolo del documento vicino e le sue prime
righe, l'immagine se il link è un'immagine, i pezzi dell'indirizzo se è un
indirizzo, o la frase che dice che il file non c'è ancora. Si sposta il
puntatore e la cartolina va via.

I cinque secondi sono un tempo lungo di proposito. Un'anteprima che scatta
subito è un impiccio mentre si legge: appare mentre l'occhio passa. A cinque
secondi il puntatore fermo è una domanda, non un incidente.

Il conto lo tiene la pagina, non l'applicazione: uno `setTimeout` messo con
un `WKUserScript`, annullato da `mouseout`, dallo scorrimento, dal perdere
il fuoco e dal passare a un altro link. Quando scade, la pagina manda un
messaggio con l'`href` e il rettangolo del link; l'applicazione lo converte
in coordinate della vista — attenzione al `pageZoom` e al fatto che la vista
web non è capovolta come quella di testo — e ci appoggia il popover.

### Quello che non fa

**Non scarica niente.** Un indirizzo `https://` viene *smontato*: host,
percorso con la sua query, schema. Tre righe di testo che c'erano già
nell'`href`. Bastano a dire dove porta un link, e nessuno scopre che stai
leggendo un documento perché il puntatore ci è passato sopra.

Dal disco legge solo un file che hai già: il documento vicino a cui il link
punta. Un `[[wikilink]]` senza estensione lo cerca come `md`, `markdown`,
`txt`; un percorso relativo lo risolve sulla cartella del documento, e
un'ancora `#qualcosa` non è un posto dove andare, quindi non apre nulla.

Il titolo è il primo titolo del file, e il corpo le prime righe **saltando
quel titolo**: ripeterlo due volte in una cartolina alta cinque righe è
spreco.

---

## Lo stesso documento, visto dal Finder

Barra spaziatrice su un `.md` nel Finder: prima si vedeva il sorgente in
carattere a spaziatura fissa, cancelletti e asterischi compresi. Ora si vede
il documento **come si legge**, con lo stesso foglio di stile con cui si
apre nell'applicazione (`GitHub2`), titoli, tabelle, blocchi di codice e le
caselle dei to-do disegnate come caselle.

È un'estensione a parte, `MacDownQuickLook.appex`, dentro l'app. Compila i
sorgenti di hoedown per conto suo: la conversione è la stessa, ma
l'estensione non porta con sé preferenze, plugin, evidenziazione. Il
montaggio della pagina — titolo, stile, caselle, figure — sta in
`MDPreviewPage`, che è codice Foundation puro e per questo ha le sue prove.

### Il front-matter non è il documento

Un documento che comincia con `---\ntitle: …\n---` mostrava, in anteprima,
una riga orizzontale e un titolo `title: scartato`. Ora il front-matter
viene lasciato fuori. Ma non basta guardare il primo `---`: **un documento
può cominciare con una riga orizzontale**, e prenderla per front-matter
significa mangiarsi il titolo vero fino al `---` successivo. Quindi la
riga dopo l'apertura deve *somigliare* a una voce (`chiave: valore`), e un
blocco che non si chiude non era front-matter.

### La sabbia, e le figure che ci restano dentro

Qui la parte che valeva il pomeriggio. Quick Look carica **solo estensioni
in sandbox**: senza `com.apple.security.app-sandbox` l'estensione non viene
nemmeno registrata — `pluginkit -a` risponde `invalid plugin path` e non
spiega altro. Dentro la sandbox arriva il documento e **basta**: le immagini
tenute accanto sono fuori portata. Misurato, non supposto: una riga di log
temporanea diceva `pictures wanted 1, sent 0`.

Due conseguenze nel codice:

* le figure viaggiano **con la risposta**, come allegati `cid:`, perché la
  pagina disegnata da Quick Look non ha accesso al disco;
* prima di rinominare una `src` in `cid:` l'estensione **apre davvero il
  file**. Vedere un file non è poterlo leggere, e una `cid:` senza allegato
  è un'immagine rotta garantita.

Per far vedere le figure serve un'eccezione: lettura, in sola lettura, della
cartella utente. Il perimetro resta stretto — non scrive niente, e la pagina
ha una `Content-Security-Policy` `default-src 'none'` che le vieta la rete.
Un documento ostile, al massimo, si fa mostrare un file che l'utente ha già:
niente script, niente immagini remote, nessun modo di mandare fuori quello
che ha letto. E il tempo di lettura ha un tetto: due megabyte di testo, poi
la pagina dice che il resto non è mostrato.

### I diagrammi e le formule, disegnati prima di consegnare la pagina

Un recinto ```` ```mermaid ```` in anteprima era codice: la pagina non ha
script — `default-src 'none'` e niente da eseguire — quindi il diagramma non
può disegnarsi lì. Adesso lo disegna **l'estensione**, in una web view sua,
e quello che arriva nella pagina è SVG finito.

Vale per **tutto** quello che nell'applicazione si disegna: i recinti
```` ```mermaid ````, quelli dei sei motori di **Graphviz** (`dot`, `neato`,
`fdp`, `circo`, `twopi`, `osage`) e le **formule** TeX, typesettate con
MathJax.

Come funziona, in ordine: si trovano i lavori nell'HTML (`MDDrawingJobsInHTML`),
si disfa l'escaping che hoedown ci ha messo — `A --&gt; B` non è un diagramma
per mermaid —, si carica una pagina con **soltanto le librerie che servono**
e si chiede un disegno per volta con `callAsyncJavaScript`. Poi ogni recinto
viene sostituito dal suo SVG, ripulito di tutto quello che potrebbe girare:
`<script>`, attributi `on*`, `href="javascript:"`. mermaid non ne mette, ma
il diagramma viene da un documento che arriva da qualunque parte, e quella
pagina è l'unico posto dell'estensione dove il markup non è scappato.

**Solo quelle che servono**: mermaid è 3,4 MB, viz.js 3,6, MathJax 2. Un
documento con un diagramma di flusso non paga Graphviz né MathJax, e uno
senza niente da disegnare non apre nemmeno la web view.

I numeri, misurati dentro la sandbox:

| Documento | Pagina caricata | Disegnato |
|---|---|---|
| Un `dot` | 267 ms | 1 su 1 in **364 ms** |
| Tre formule | 260 ms | 3 su 3 in **336 ms** |
| mermaid + `dot` + formula | 388 ms | 3 su 3 in **528 ms** |

Il tetto è **2,5 secondi per tutti** i disegni, al massimo **quaranta** per
documento e 16 KB di sorgente ciascuno: un'anteprima che arriva tardi non è
arrivata, e quello che non si disegna in tempo resta il suo sorgente — cioè
quello che l'anteprima mostrava prima.

### Che cosa è una formula lo dice l'applicazione

`$$…$$` è inequivocabile e si typesetta sempre. Un dollaro **singolo** no:
misurato, con `MATH_EXPLICIT` acceso hoedown legge «Il pezzo costa $5 e la
scatola $7» come `\(5 e la scatola \)7`, cioè come algebra. Ed è per questo
che nell'applicazione è un interruttore, spento di serie.

Le due viste devono concordare, quindi l'estensione **legge quell'interruttore**:
`com.apple.security.temporary-exception.shared-preference.read-only` sul solo
dominio dell'applicazione a cui appartiene, in sola lettura, per due chiavi —
`htmlMathJax` e `htmlMathJaxInlineDollar`. Se l'applicazione dice di non
mostrare formule, l'anteprima non ne mostra; se dice che il dollaro singolo
conta, conta anche qui.

Una cosa che Markdown si mangia: `\(a^2\)` scritto a mano **non** arriva
all'HTML — la barra rovesciata è un escape, e diventa `(a^2)`. L'unica strada
per una formula nella riga è il dollaro.

**E qui il pedaggio**: WebKit non chiude un caricamento senza
`com.apple.security.network.client`, nemmeno per una pagina costruita in
memoria. Misurato: con il permesso, disegnati due diagrammi su due; senza,
`didFinishNavigation` non arriva mai e dopo 2,7 secondi il conto è zero su
due. Quindi l'estensione ha il permesso di rete e **non lo usa**: mermaid è
letto dal bundle, la pagina del disegno è una stringa, e la pagina che il
Finder riceve continua a portare `default-src 'none'`.

Restano sorgente, in anteprima, solo i recinti di un linguaggio che
l'applicazione non disegna nemmeno.

---

## Tre inciampi da ricordare, se l'estensione «non compare»

Sono tutti e tre nella registrazione, non nel codice.

1. **`codesign --force --deep` toglie i diritti alle cose annidate.** Firmato
   così il pacchetto dell'app, l'`appex` dentro perde `app-sandbox` e Quick
   Look lo ignora in silenzio. Si firma l'estensione con i suoi diritti, e
   *poi* l'app senza `--deep`.
2. **`lsregister -f` da solo non basta** quando un record vecchio è già lì.
   La sequenza che funziona è `lsregister -u` e poi
   `lsregister -f -R -trusted` sul pacchetto dell'app.
3. **`QLIsDataBasedPreview` non è opzionale.** Senza quella chiave in
   `NSExtensionAttributes` il sistema tratta l'estensione come se avesse una
   vista da mostrare, e muore su
   `Assertion failure in QLPreviewExtensionViewController.m:139` — che è
   l'unico posto dove lo dice.

E un'ultima cosa che fa perdere tempo: Quick Look **tiene in cache**
l'anteprima. Se stai provando una modifica sullo stesso file e non cambia
niente, non è la modifica: copia il file con un altro nome.

---

## Un pannello per una cosa che si registra da sola

L'estensione non si «installa» come un plugin: sta dentro l'app, e installarla
vuol dire **far sì che macOS la noti**. Il guaio è che quel passaggio va
storto in silenzio — una copia dell'app rimasta in Download può tenersi la
registrazione, un aggiornamento può lasciare registrata la build vecchia, e
un'anteprima che non compare non dice niente.

Quindi **Impostazioni › Anteprima Finder**: una frase con un pallino colorato,
il percorso e la versione registrata, la versione che c'è in questa copia, e
tre pulsanti — **Installa**, **Aggiorna** quando la registrata è più vecchia
di quella in mano, **Rimuovi**. Sotto, il collegamento al pannello delle
estensioni di Impostazioni di Sistema, per chi preferisce spegnerla da lì.

Non esiste un'API per questo, quindi il pannello parla agli stessi strumenti
che usa il sistema: `pluginkit -m -i … -vvv` per sapere come stanno le cose,
`lsregister -u` e poi `-f -R -trusted` per installare o aggiornare,
`pluginkit -r` (con `-e ignore`) per rimuovere. Le due parti che vale la pena
provare sono separate dal resto e hanno le loro prove: **leggere l'elenco** di
`pluginkit` — il segno a inizio riga è tutto ciò che distingue «spenta a mano»
(`-`) da «nessuno l'ha mai chiesto» (spazio) — e **decidere lo stato** dalle
tre cose che si sanno (dov'è registrata, quale versione, cosa c'è nell'app).
Diciannove prove, di cui quattro costruiscono il pannello vero e leggono che
cosa offre.

### La versione, e lo stampo che rompe il sigillo

Per confrontare le versioni, l'estensione deve **portare** la versione
dell'app: nata con `1.0` fisso nel suo `Info.plist`, avrebbe offerto un
aggiornamento per sempre. Il primo tentativo — una fase di build
nell'estensione che stampa la versione col `PlistBuddy` — ha prodotto la
trappola documentata sopra al contrario: il sistema di build **riscrive** il
suo `Info.plist` alla fine del proprio target, e in Release il risultato era
un'estensione col sigillo rotto. L'ha trovato la suite di controllo, alla
riga «firmata».

Quindi lo stampo va dove non passa più nessuno: sulla copia in `dist/`, quella
che finisce nel DMG, e subito dopo l'estensione **viene firmata di nuovo con i
suoi diritti** (`Tools/stamp_extension.sh`). Nella copia che gira da Xcode la
versione resta il segnaposto, e non è un problema: il pannello confronta la
registrata con quella dentro l'app, che lì sono lo stesso file.

---

## Dove sta il conto

| Cosa | Dove |
|---|---|
| Cartolina del link | `MacDown/Code/Utility/MPLinkPreview.{h,m}`, `MacDown/Code/View/MPLinkPreviewViewController.{h,m}` |
| Attesa e posizione | `MPHoverWatchScript()` in `MPLinkPreview.m`; `showLinkPreviewFor:` in `MPDocument.m` |
| Pagina del Finder | `QuickLook/MDPreviewPage.{h,m}` |
| Estensione | `QuickLook/MDQuickLookProvider.{h,m}`, `QuickLook/Info.plist`, `QuickLook/MacDownQuickLook.entitlements` |
| Prove | `MacDownTests/MPLinkPreviewTests.m` (9), `MacDownTests/MDPreviewPageTests.m` (18), `MacDownTests/MPHoverWatchTests.m` (7) |
| Pannello nelle impostazioni | `MacDown/Code/Preferences/MPQuickLookPreferencesViewController.{h,m}` |
| Stato dell'estensione | `MacDown/Code/Utility/MPQuickLookExtension.{h,m}`, prove in `MacDownTests/MPQuickLookExtensionTests.m` (19) |
| Versione dell'estensione | `Tools/stamp_extension.sh`, chiamato dalla copia in `dist/` |
| Controllo di tutto | `Tools/verify_features.sh`, con il banco `Tools/quicklook_page.m` |

---

## Come si controlla

Le prove unitarie non arrivano dove sta il rischio vero di queste due
funzioni: l'attesa di cinque secondi vive **nella pagina**, e l'estensione
del Finder vive **in un altro processo**, in sandbox, e solo se macOS
accetta di registrarla.

Per la prima il rimedio è stato spostare lo script in
`MPHoverWatchScript(secondi)`: l'applicazione lo inietta con cinque secondi,
`MPHoverWatchTests` lo inietta con un quarto di secondo in una `WKWebView`
vera e muove il puntatore con eventi sintetici. Sono lo stesso script, non
una copia semplificata. Sette prove: che risponda, che **non** risponda
prima del tempo, che l'uscita dal link, lo scorrimento e il passaggio a un
altro link annullino l'attesa, e che il testo che non è un link non apra
niente.

Per la seconda c'è `Tools/verify_features.sh`: costruisce, esegue la suite,
poi guarda il **prodotto** (l'`appex` è dentro l'app? è firmata? in sandbox?
dichiara l'anteprima a dati?), costruisce la pagina che il Finder riceverebbe
e la legge riga per riga, e alla fine registra l'app e chiede a Quick Look
un'anteprima vera, controllando nel log di sistema che l'abbia servita la
nostra estensione. Esce col numero di controlli falliti.

La prima volta che l'ho eseguita ha trovato subito qualcosa: dopo un
`xcodebuild test` con `CODE_SIGNING_ALLOWED=NO` l'estensione nei prodotti
era **non firmata**, quindi quattro controlli rossi e la registrazione
rifiutata. Il difetto era nella suite di controllo, non nell'app — ma è
esattamente il genere di cosa che una suite verde non vede.

Una nota fuori tema, trovata dalla stessa esecuzione:
`MPDocumentTabsTests` era intermittente. Una finestra nuova entra nel gruppo
di tab della finestra **davanti**, e in una sessione di prove davanti può non
esserci nulla; ora il test mette davanti la prima finestra prima di aprire la
seconda, e misura la configurazione dell'app invece dell'umore del window
server.
