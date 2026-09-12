# Studio: CommonMark per intero, e il formato di MacFarlane

Studio, non progetto: qui non si scrive niente. Due domande che sembrano
una sola e non lo sono.

> **CommonMark**: rendere questa applicazione conforme alla specifica che
> tutti gli altri seguono.
>
> **Djot**: sostenere anche la lingua che lo stesso autore di CommonMark ha
> scritto *dopo*, perché CommonMark gli è venuto complicato.

La prima è una riparazione. La seconda è una lingua in più. Costano cose
diverse e vanno decise separatamente.

---

## 1. Dove siamo, misurato

L'applicazione rende il Markdown con **hoedown 3.0.7** — un fork di sundown,
5 493 righe di C, ultimo movimento nel repository di origine nel **giugno
2020**, nessun rilascio mai pubblicato lì. È precedente a CommonMark e non
ha mai provato a seguirlo.

Ho passato a hoedown, con le estensioni che l'applicazione accende, tutti i
**652 esempi** della specifica CommonMark 0.31.2 e confrontato l'HTML che
esce con quello che la specifica dichiara.

| Confronto | Passati |
|---|---|
| esatto, com'esce dall'applicazione | **242 / 652** (37%) |
| ignorando gli spazi bianchi | **307 / 652** (47%) |
| il più generoso possibile (XHTML, `/>`, spazi) | **346 / 652** (53%) |

Circa **metà**. Il metodo è ripetibile e sta nel repository:

```bash
Tools/commonmark_score.sh            # i tre conteggi e le sezioni
Tools/commonmark_score.sh --esempi 5 # e cinque esempi falliti per sezione
```

Scarica `spec.json` dalla specifica, compila il renderer HTML di hoedown con
le estensioni che accende `MPDocument` — `AUTOLINK | FENCED_CODE |
FOOTNOTES | NO_INTRA_EMPHASIS | STRIKETHROUGH | TABLES | SPACE_HEADERS` — e
toglie dal confronto l'attributo `data-src`, che è nostro e non della
specifica.

### Dove sbaglia

Contate col confronto **più generoso** dei tre, cioè il caso migliore:

| Sezione | Prove | Fallite |
|---|---:|---:|
| Emphasis and strong emphasis | 132 | 57 |
| List items | 48 | 38 |
| Links | 90 | 36 |
| HTML blocks | 44 | 31 |
| Lists | 26 | 23 |
| Entity and numeric character references | 17 | 14 |
| Link reference definitions | 27 | 14 |
| Raw HTML | 20 | 12 |
| Setext headings | 27 | 12 |
| Fenced code blocks | 29 | 10 |
| Code spans | 22 | 9 |
| Autolinks · Block quotes · Images | 19 · 25 · 22 | 8 · 8 · 8 |
| … e altre otto sezioni | | 26 in tutto |

Quattro sezioni sole non hanno **un solo** errore: righe vuote, precedenza,
inline, interruzioni di riga morbide.

### Quattro esempi da provare adesso

```markdown
Foo *bar
baz*
====
```

La specifica dice un `<h1>` con dentro il corsivo. hoedown dà un paragrafo
e poi un titolo, spezzando il corsivo a metà.

```markdown
- foo
- bar
+ baz
```

La specifica dice **due elenchi** — cambiare il segno comincia un elenco
nuovo. hoedown ne fa uno con tre voci.

```markdown
1. foo
2. bar
3) baz
```

La specifica dice due elenchi, e il secondo `<ol start="3">`. hoedown ne fa
uno.

```markdown
&copy; &frac34; &Dcaron;
```

La specifica dice `© ¾ Ď`. hoedown lascia le entità scritte.

Non sono casi di laboratorio: il primo è un titolo con una parola in
corsivo, il secondo è un elenco a cui qualcuno ha cambiato il segno a metà.

## 2. E non è un parser: sono tre

Prima di scegliere cosa mettere al posto di hoedown va detto quanti ce ne
sono.

| Chi | Cosa legge | Dove |
|---|---|---|
| **hoedown** | l'anteprima, le esportazioni, l'indice | `Dependency/hoedown`, 5 493 righe |
| **hoedown, un'altra copia** | l'anteprima del Finder | l'estensione compila gli stessi `.c` per conto suo |
| **peg-markdown-highlight** | i colori nell'editor | `pmh_parser.c`, 6 809 righe generate |
| MPAttributedSpans | `[testo]{...}` prima di tutti | nostro, 700 righe |

Due dialetti diversi che leggono lo stesso file, e si vede: `##Titolo` senza
lo spazio era un titolo per l'editor e un paragrafo per l'anteprima, e c'è
voluta una correzione apposta perché i due si mettessero d'accordo. Ogni
cambio di parser va fatto **due volte** o il disaccordo aumenta.

Le chiamate a hoedown nel nostro codice sono **112, in 5 file**, più
`hoedown_html_patch.c` — 212 righe che sostituiscono quattro funzioni del
renderer: i blocchi di codice (numeri di riga, linguaggio), le voci di
elenco (le caselle dei to-do), l'indice, e l'attributo `data-src` su ogni
blocco, che è il modo in cui le due metà della finestra sanno di quale riga
sta parlando l'altra.

## 3. Strada A — cmark

La reimplementazione di riferimento, in C, dello stesso autore. Ne esistono
due, e la differenza fra le due è la vera decisione.

| | cmark | cmark-gfm |
|---|---|---|
| Licenza | BSD a 2 clausole | idem |
| Versione | **0.31.2**, febbraio 2026 | 0.29.0.gfm.13, **luglio 2023** |
| Sorgente | 19 file `.c` | 27 `.c` + 7 di estensioni |
| Tabelle, note, barrato, autolink | **no** | **sì** |
| API per estensioni | **no** | **sì** (`cmark_syntax_extension`) |
| Sulla specifica 0.31.2 | **652 / 652** | **641 / 652** |

Le ultime tre righe le ho misurate, non lette: ho scaricato tutti e due,
compilati con `clang` in questo albero e passati agli stessi 652 esempi.

### Quello che compilarli richiede — misurato

Nessuno dei due ha bisogno di CMake per stare qui dentro. cmark vuole due
header che il suo build genera (`cmark_export.h`, `cmark_version.h`),
cmark-gfm tre (`config.h` in più): sono venti righe scritte a mano, e poi è
`clang` sui `.c`. Nessun passo di generazione, nessuna catena nuova.

### Velocità — misurata

Un documento di 312 KB, cinque passaggi, il tempo medio:

| hoedown | cmark | cmark-gfm |
|---|---|---|
| 13,6 ms | 14,4 ms | 14,5 ms |

Un millisecondo. La velocità non è un argomento per nessuna delle tre.

### Quello che guadagniamo, oltre alla conformità

* le **posizioni nel sorgente** sono native: `CMARK_OPT_SOURCEPOS` mette su
  ogni blocco `data-sourcepos="3:1-3:13"` — riga **e colonna**, inizio e
  fine. È il lavoro che oggi fa a mano il nostro `hoedown_html_patch.c`
  con `data-src`, e lo fa meglio;
* un **albero**, invece di callback: l'indice, l'EPUB e la selezione
  condivisa oggi passano da renderer paralleli e da una seconda analisi del
  documento; con un albero si cammina una volta sola;
* un interruttore di **sicurezza**: `CMARK_OPT_UNSAFE` acceso lascia passare
  l'HTML grezzo, spento lo toglie. La nostra anteprima è una vista web e il
  documento è spesso di qualcun altro — è la stessa domanda che ci siamo già
  posti per gli attributi delle span, qui è una riga;
* una dipendenza **viva**: 0.31.2 è di sei mesi fa.

### Quello che perdiamo, e va riscritto

hoedown ci dà cinque cose che **nessuno dei due** cmark ha, e sono cinque
interruttori nelle impostazioni, cioè documenti già scritti così:

| Estensione | Sintassi |
|---|---|
| Highlight | `==evidenziato==` |
| Quote | `"virgolette"` → `<q>` |
| Superscript | `2^10` |
| Underline | `_sottolineato_` |
| Math | `$x$`, `$$x$$` |

Con **cmark-gfm** si scrivono come `cmark_syntax_extension` — l'API con cui
GitHub ha scritto le tabelle. Con **cmark nudo** non c'è un'API: si fa un
passaggio sull'albero che sostituisce i nodi di testo con
`CMARK_NODE_CUSTOM_INLINE`, che porta due stringhe, quella di apertura e
quella di chiusura. Funziona — ed è lo stesso mestiere che fa già
`MPAttributedSpans` per `[testo]{...}` — ma è codice nostro contro
un'estensione mantenuta da altri.

E con cmark nudo si perdono anche **tabelle, note, barrato e autolink**, che
oggi funzionano: sono quattro parser in più da scrivere, e le tabelle hanno
un editor sopra.

### Quanto costa davvero essere fermi alla 0.29

Era l'obiezione principale contro cmark-gfm. Misurata: **641 esempi su 652**
della specifica **0.31.2** — il 98%. Gli undici che sbaglia sono dieci casi
di enfasi annidata e uno di entità:

```markdown
__foo, __bar__, baz__          foo******bar*********baz
```

Nessuno scrive quelle righe per caso. Tre anni di specifica costano l'uno
per cento, e quell'uno per cento non somiglia a niente che qualcuno intenda.

### Quello che cambierebbe nei documenti veri — misurato

Ho reso i **49 documenti Markdown di questo repository** con hoedown e con
cmark-gfm e confrontato l'HTML, ignorando lo slash XHTML e l'apostrofo
scritto come entità, che non cambiano una pagina:

| | |
|---|---|
| identici | **29** |
| diversi davvero | **18** |

E le differenze sono di quattro tipi soli:

1. **liste larghe e strette**: `<li><p>Si adotta…</p>` contro
   `<li>Si adotta…`. È la regola di CommonMark, e hoedown la sbaglia;
2. **enfasi dentro la parola**: `dell'*intero*` e `«**concorso**»` oggi
   restano scritti così, con cmark diventano corsivo e grassetto. È quello
   che la specifica dice, ed è il nostro interruttore
   «no intra-word emphasis» che smette di esistere: le regole di CommonMark
   sono quelle e basta;
3. **allineamento delle tabelle**: `style="text-align: right"` contro
   `align="right"` — un foglio di stile da aggiornare;
4. **front matter**: differenze che spariscono nell'applicazione, che lo
   toglie prima di rendere; le vede solo il banco di prova.

Il numero che conta è il secondo: **diciotto documenti su quarantanove
cambierebbero aspetto**, e in due modi soli — le liste e l'enfasi.

### Cosa costa il nostro codice

112 chiamate in 5 file; `hoedown_html_patch.c`, 212 righe che sostituiscono
quattro funzioni del renderer (blocchi di codice, voci di elenco con le
caselle, indice, `data-src`); l'estensione del Finder che compila il parser
per conto suo; e i test di rendering, che vanno riverificati tutti.

### La raccomandazione, cambiata dalla misura

Cominciando questo studio avrei detto **cmark**, per non legarsi a una
dipendenza ferma. I numeri dicono il contrario: cmark-gfm rende il 98% della
specifica di oggi, porta già tabelle, note, barrato, autolink e to-do — che
qui servono tutti — e ha l'API con cui riscrivere le nostre cinque
estensioni. cmark nudo sarebbe più puro e vorrebbe **nove** parser scritti
da noi invece di cinque.

**cmark-gfm**, quindi, con una condizione dichiarata: è mantenuto da GitHub
per GitHub, e se un giorno smettesse davvero il passaggio a cmark nudo
resterebbe aperto — stessa API di base, stesso albero, stesse posizioni nel
sorgente.

## 4. Strada B — rattoppare hoedown

No, e vale la pena dire perché, perché è la strada che sembra più corta.

I punti dove fallisce non sono dettagli ai bordi: enfasi (57), voci di
elenco (38), collegamenti (38), blocchi HTML (31). Sono **il cuore del
parser**. L'algoritmo dell'enfasi di CommonMark — quello dei *delimiter
runs* — non è un rattoppo su quello di sundown: è un altro algoritmo. Le
liste sono un altro pezzo riscritto da capo.

Rifare quei quattro pezzi dentro hoedown significa riscrivere hoedown, con
in più il compito di non rompere le sue estensioni, e senza la suite di
prove che cmark si porta dietro. Riscrivere cmark male, insomma.

## 5. Djot, il formato di MacFarlane

Djot è la lingua che John MacFarlane ha scritto **dopo** CommonMark, con un
motivo dichiarato: CommonMark è difficile da analizzare, e la parte peggiore
è l'enfasi. La misura di questo studio lo conferma da sola — 132 dei 652
esempi della specifica riguardano `*` e `_`, e noi ne sbagliamo 57.

In Djot le regole sono più rigide e più semplici: i delimitatori non si
intrecciano, gli attributi sono parte della lingua, e quasi tutto ciò che in
Markdown è convenzione (tabelle, note, matematica, evidenziato, inserito,
cancellato) è **nella specifica** invece che in dieci estensioni che non
vanno d'accordo.

Una cosa la abbiamo già: `[testo]{style="color:#c00"}` — la sintassi degli
attributi che l'ultima versione ha aggiunto **è quella di Djot**.

### Le implementazioni che esistono

| | Linguaggio | Licenza | Vivo |
|---|---|---|---|
| `jgm/djot.js` | TypeScript | MIT | sì, settembre 2026 |
| `hellux/jotdown` | Rust | MIT | sì, settembre 2026 |
| `sivukhin/godjot` | Go | MIT | giugno 2025 |
| in C | — | — | **nessuna** |

Questo è il fatto che decide tutto: **non c'è un'implementazione in C**, e
questa applicazione è Objective-C con due parser C dentro.

### Le tre strade, e cosa costano davvero

**1. `djot.js` dentro JavaScriptCore.** L'applicazione già lo lega
(`JavaScriptCore.framework`), e il pacchetto npm sta in 349 KB. È la strada
corta: un file JavaScript, una funzione, HTML fuori.

Il costo vero non è il motore, è **dove serve il risultato**. L'anteprima
del Finder è un processo a parte che oggi costruisce la sua pagina in modo
sincrono e non ha JavaScriptCore fra le sue librerie; l'evidenziazione
dell'editor vuole *posizioni*, non HTML, e djot.js le dà come AST — quindi
andrebbe letto quello, non la pagina.

**2. Portare `jotdown` da Rust.** Si compila in una libreria statica con
un'interfaccia C. Costa una catena di compilazione Rust dentro un progetto
Xcode che oggi non ne ha, per ogni architettura, e una dipendenza che
nessuno qui sa aggiustare quando si rompe.

**3. Scriverne uno in Objective-C.** Djot è più semplice di CommonMark da
analizzare — è il suo scopo — ma «più semplice» significa qualche migliaio
di righe e una suite di conformità da inseguire. È il genere di cosa che si
comincia bene e si finisce a metà.

### E comunque: è un'altra lingua

Djot non è un'estensione di Markdown. `_sottolineato_`, `*corsivo*`, i
riferimenti dei collegamenti, le liste: le regole sono **diverse**. Un
documento è Markdown **o** Djot, e si decide dall'estensione del file
(`.dj`, `.djot`) o da una riga di front matter — non da un interruttore
nelle impostazioni, che vorrebbe dire cambiare il significato dei file di
qualcun altro da un pannello.

E tutto quello che oggi tocca il Markdown andrebbe insegnato di nuovo:
l'evidenziatore, i marcatori che si nascondono, l'indentazione dei blocchi,
il confronto per paragrafi, l'importazione, l'esportazione. Non è un
parser in più: è una seconda applicazione dentro la stessa finestra.

## 6. In che ordine, se si fa

| Fase | Cosa | Perché prima | Grandezza |
|---|---|---|---|
| 0 | ~~La suite di conformità come prova ripetibile~~ — fatta: `Tools/commonmark_score.sh` | senza un numero non si sa se si sta migliorando | fatta |
| 1 | cmark accanto a hoedown, dietro un interruttore da sviluppatore, e il numero misurato sulle **stesse** prove | si vede cosa cambia prima di cambiarlo | grande |
| 2 | Le cinque estensioni nostre come `cmark_syntax_extension` | sono impostazioni che esistono e documenti che esistono | grande |
| 3 | L'anteprima del Finder sullo stesso parser | due parser che non sono d'accordo sono peggio di uno vecchio | media |
| 4 | L'evidenziatore dell'editor sull'albero di cmark, al posto di pmh | i due dialetti diventano uno | grande |
| — | Djot | solo dopo che di parser Markdown ce n'è **uno** | — |

La riga che conta è l'ultima. Aggiungere Djot adesso vuol dire avere
quattro lettori di markup in una finestra sola.

## 7. Quello che non farei

* **Un interruttore «modalità CommonMark»** che lascia hoedown come
  alternativa: due parser da mantenere per sempre e due modi in cui lo
  stesso file si legge.
* **Djot al posto di Markdown.** Nessuno ha file in Djot, e questa
  applicazione apre file che già esistono.
* **cmark-gfm perché ha le tabelle già fatte.** Le tabelle sono un mese; una
  dipendenza ferma è per sempre.
* **Cominciare dall'editor.** L'anteprima è dove si vede l'errore; il
  colore di una parola nell'editor no.

## 8. Le domande da decidere

1. **Conformità o compatibilità?** Misurato sui documenti di questo
   repository: 29 su 49 identici, **18 diversi**, e in due modi soli — le
   liste strette e l'enfasi dentro la parola (`dell'*intero*` diventa
   corsivo). Più `_sottolineato_`, `"virgolette"` e `2^10`, che restano
   scritti finché le cinque estensioni non sono rifatte. Propendo per
   *conformità*, con le estensioni rifatte **prima** di spegnere hoedown.
2. **cmark o cmark-gfm?** Cominciando propendevo per *cmark*; la misura mi
   ha fatto cambiare idea. **cmark-gfm**: 641 esempi su 652 della specifica
   di oggi, e tabelle, note, barrato e autolink già scritti. Con cmark nudo
   i parser da scrivere passano da cinque a nove.
3. **L'evidenziatore dell'editor entra nel lavoro o resta fuori?** Propendo
   per *entra*, ma alla fine: è il pezzo che rende il cambio definitivo, ed
   è anche quello che si può fare senza fretta.
4. **Djot: una lingua in più o no?** Propendo per *non adesso*, e per
   guardarla di nuovo quando i parser Markdown saranno uno. Se si farà, la
   strada è `djot.js` in JavaScriptCore e i file riconosciuti
   dall'estensione, non un interruttore.

---

*Questo è uno studio: nessuna di queste è una promessa. I numeri sono stati
misurati il 12 settembre 2026 su hoedown 3.0.7, cmark 0.31.2 e cmark-gfm
0.29.0.gfm.13, contro la specifica CommonMark 0.31.2. Quelli di hoedown si
rimisurano con `Tools/commonmark_score.sh`; gli altri scaricando i due
sorgenti e compilandoli con `clang`, che è tutto quello che chiedono.*
