# Progetto: MacDown Next su iOS

Questo documento non dice «si può fare». Dice **cosa attraversa davvero**,
misurato sul codice che c'è oggi, cosa va riscritto perché su iPhone e iPad
non esiste, e in che ordine conviene farlo perché a ogni passo ci sia
qualcosa che si apre e funziona.

Il dubbio — se questa applicazione debba esistere — sta in fondo, una volta.

---

## 1. Cosa vuol dire «versione iOS», e cosa no

| | Cosa si intende qui | Cosa **non** si intende |
|---|---|---|
| L'applicazione | un editor Markdown per iPhone e iPad, con la stessa resa e gli stessi formati | un porto dell'interfaccia del Mac |
| I documenti | file veri, nei Files, con la app che li apre e li salva | una libreria chiusa dentro l'app |
| L'anteprima | la stessa, stessi modelli e stesso CSS | una seconda resa «per il telefono» |
| Il codice | un nucleo solo, due interfacce | due programmi che si somigliano |

La riga che conta è l'ultima, ed è anche il rischio: due interfacce si
mantengono per sempre, un nucleo diviso in due si scopre rotto un anno dopo.

## 2. Cosa si porta, misurato

Contato sul codice di oggi (`MacDown/Code`, 173 file fra `.h` e `.m`):

| | File | Righe |
|---|---:|---:|
| Toccano AppKit | 88 | 29 291 |
| Non lo toccano | 85 | 14 362 |

E guardando solo i `.m`, per **quanto** AppKit ci sia dentro:

| Densità | File | Cosa sono |
|---|---:|---|
| Molto (≥ 20 riferimenti) | 21 | finestre, pannelli, il documento |
| Poco (1–19) | 25 | pezzi di logica con un colore o un font dentro |
| Niente | 38 | il motore: resa, differenze, importazioni, servizi |

Contato al contrario — quanti file si compilerebbero su iOS senza toccarli:

* **91 file** portabili così come sono;
* **9 file** portabili con un adattatore per colori, caratteri e immagini
  (`NSColor`/`NSFont`/`NSImage` → `UIColor`/`UIFont`/`UIImage`);
* il resto è interfaccia, e su iOS si riscrive perché su iOS **è** un'altra
  cosa.

Le dipendenze, che sono la parte che di solito ferma i porti, qui non lo
fanno:

| Dipendenza | Cos'è | Su iOS |
|---|---|---|
| hoedown | C | ✅ così com'è |
| peg-markdown-highlight | C | ✅ così com'è |
| LibYAML | C | ✅ |
| handlebars-objc, JJPluralForm, M13OrderedDictionary | Foundation | ✅ |
| PAPreferences | `NSUserDefaults` | ✅ |
| MASPreferences | AppKit | ❌ su iOS le impostazioni sono un'altra schermata |
| Prism, mermaid, MathJax, Viz.js | pagina web | ✅ (sono già dentro il `WKWebView`) |
| llama.cpp | C++ | ⚠️ compila, ma i modelli pesano — §7 |

L'anteprima usa già `WKWebView` con un `WKURLSchemeHandler` nostro:
**quella parte non si riscrive**, è la stessa classe su tutti e due i
sistemi.

## 3. Il nodo: `MPDocument`

Un file solo tiene 318 riferimenti ad AppKit: `MPDocument.m`. È il centro
dell'applicazione — testo, anteprima, esportazioni, il collegamento ai
servizi — ed è una sottoclasse di `NSDocument`, che su iOS non esiste:
c'è `UIDocument`, che è un'altra cosa (asincrona, con il browser dei
documenti davanti).

È il pezzo che decide la forma di tutto il resto, quindi la prima fase non
è «portiamo l'app», è **tagliare `MPDocument` in due**: il documento come
*stato* (testo, versione, da dove viene, cosa ne sappiamo) e il documento
come *finestra*. Il primo attraversa, il secondo no — e il taglio serve
anche al Mac, dove oggi quel file sa troppe cose.

## 4. L'architettura

```
MacDownKit  (Foundation, un target per due sistemi)
├─ resa:        MPRenderer, hoedown, i modelli, il CSS, lo schema handler
├─ testo:       MPAttributedSpans, MPCodeIndenter, MPTableSource, MPDiff
├─ formati:     docx/odt in entrata, epub/textbundle/HTML in uscita
├─ servizi:     MPCloudService (iCloud, Drive), MPCloudLedger
└─ adattatore:  MPColor/MPFont/MPImage — due righe di typedef, non un livello

MacDown Next (macOS)          MacDown Next (iOS)
├─ NSDocument, finestre       ├─ UIDocument + UIDocumentBrowserViewController
├─ NSTextView + stylers       ├─ UITextView + gli stessi stylers
└─ WKWebView                  └─ lo stesso WKWebView
```

L'adattatore va scritto come **due typedef**, non come un livello di
astrazione: `NSColor` e `UIColor` hanno la stessa forma per quello che ci
serve, e un livello in mezzo sarebbe codice da mantenere per non guadagnare
niente.

## 5. Le tre parti, su iOS

### I documenti

`UIDocumentBrowserViewController` è la schermata dei Files dentro l'app: e
i Files, su iOS, **sono già tutti i servizi** — iCloud Drive, Google Drive,
Dropbox, OneDrive, chiunque abbia un File Provider. Su iOS la
sincronizzazione che sul Mac ci è costata un ramo intero è, in buona parte,
già lì.

Il lavoro fatto sui servizi serve lo stesso, e per due ragioni: le API
servono dove il File Provider non arriva (elenchi, versioni, conflitti
raccontati a parole), e il codice è già scritto e portabile.

### L'editor

`UITextView` con TextKit 2, e gli stylers che ci sono già: lavorano su
`NSTextStorage` e attributi, non su `NSTextView`. Quello che va scritto
nuovo è la tastiera — una riga di comandi sopra i tasti (`inputAccessoryView`)
con titoli, elenchi, grassetto, collegamento, tabella — perché su un
telefono senza quella riga il Markdown si scrive due volte più lentamente.

Con una tastiera esterna, le scorciatoie tornano: `UIKeyCommand` le prende
tutte, e su iPad diventano anche le voci del menu di sistema.

### L'anteprima

Uguale. Stesso `WKWebView`, stessi modelli, stesso CSS, stesso schema
handler. Su iPad affiancata (`UISplitViewController`), su iPhone alternata
con un segmento — perché su 390 punti di larghezza due colonne non sono due
colonne, sono due strisce.

## 6. Cosa non attraversa, e va detto prima

| Cosa | Perché | Cosa si fa |
|---|---|---|
| I plug-in di terze parti | iOS non carica bundle di codice altrui | Drawio e Importa vengono **compilati dentro** |
| Il server MCP, `macdown-cmd` | sono programmi da riga di comando | restano al Mac |
| L'aggiornamento da GitHub | su iOS aggiorna l'App Store | via `MPUpdate` |
| La barra dei menu | non esiste | comandi in una barra, e `UIKeyCommand` |
| L'estensione Quick Look | su iOS l'anteprima nei Files arriva dal tipo di file dichiarato | si dichiarano i tipi, e basta |
| Le finestre multiple | su iPad sono scene | una scena per documento |

## 7. Le tre cose da misurare prima di decidere (I0)

Questa è mezza giornata, e cambia tutto quello che viene dopo:

1. **Il nucleo compila?** Un target iOS finto che compila i 91 file
   portabili più i 9 con l'adattatore. Quello che non compila si conta: è
   il costo vero della fase I1.
2. **La resa è la stessa?** Le 652 prove della specifica CommonMark
   (`Tools/commonmark_score.sh`) girate nel simulatore: se il numero è
   quello del Mac, hoedown attraversa senza sorprese.
3. **Quanto ci mette un iPhone?** Il documento da 312 KB che usiamo per le
   misure, reso su un telefono vero. Sul Mac sono ~14 ms; se su iPhone
   fossero 200 l'anteprima dal vivo va ripensata, non l'applicazione.

E una quarta, se le funzioni di scrittura devono attraversare: **llama.cpp
gira**, ma un modello da 2 GB su un telefono da 6 GB di RAM è un'altra
storia che si chiude in un pomeriggio di prove — o si decide che su iOS le
funzioni di scrittura passano da un'API, che è una scelta diversa e va
detta a chi usa l'app.

## 8. Le fasi

| Fase | Cosa | Quando è finita |
|---|---|---|
| **I0** | Le misure qui sopra | quando si sa cosa non compila, e quanto costa |
| **I1** | **MacDownKit**: il nucleo estratto, `MPDocument` tagliato in due, il Mac che continua a funzionare identico | quando le prove girano su due sistemi e il Mac non se n'è accorto |
| **I2** | **L'app che legge**: browser dei documenti, anteprima, esportazione in PDF e HTML | quando si può aprire un `.md` dai Files e leggerlo bene |
| **I3** | **L'editor**: `UITextView`, evidenziazione, riga dei comandi, scorciatoie | quando ci si scrive un documento intero senza rimpianti |
| **I4** | **I formati**: importazione docx/odt, textbundle, epub, foglio di condivisione | quando quello che entra ed esce sul Mac entra ed esce anche qui |
| **I5** | **I servizi**: iCloud e Drive dove i Files non bastano, conflitti raccontati come sul Mac | quando due dispositivi sullo stesso documento non perdono niente |
| **I6** | **Le rifiniture di sistema**: tipi dichiarati, anteprime, Spotlight, scene su iPad | quando l'app sembra nata lì |

**I1 è la fase che conta.** È l'unica che tocca il Mac, è quella che si può
sbagliare in modo costoso, ed è anche quella che il Mac guadagna comunque:
un documento che non sa cos'è una finestra è un documento più facile da
provare.

## 9. Quanto costa, onestamente

Non in giorni di calendario, in ordini di grandezza: **I1 è la metà del
lavoro**, I2 e I3 insieme un quarto, il resto l'ultimo quarto. Le cose che
possono raddoppiare il conto sono tre, e sono note: `MPDocument` tagliato
male, l'evidenziazione che su documenti lunghi va a scatti con TextKit 2, e
la revisione dell'App Store se qualcosa somiglia a caricare codice.

## 10. Il dubbio, una volta

Un editor Markdown su iOS lo hanno già scritto in trenta, alcuni bene, e
questa applicazione non ha su iPhone il vantaggio che ha sul Mac — dove il
suo pubblico è chi scrive documenti lunghi su uno schermo grande, con
l'anteprima accanto e le esportazioni che servono in ufficio.

La versione onesta di questo progetto potrebbe essere più piccola: **I0,
I1, I2** — il nucleo condiviso e un'app che *legge* benissimo quello che si
è scritto sul Mac, con la stessa resa e le stesse anteprime. Sarebbe un
quarto del lavoro, non lascerebbe un'interfaccia a metà da mantenere per
sempre, e il giorno in cui l'editor servisse davvero il nucleo sarebbe già
pronto.

Scritto il dubbio, la strada è quella sopra, nell'ordine dato.
