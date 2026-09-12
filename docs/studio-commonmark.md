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

La reimplementazione di riferimento, in C, dello stesso autore.

| | cmark | cmark-gfm |
|---|---|---|
| Licenza | BSD a 2 clausole | idem |
| Versione | **0.31.2**, febbraio 2026 | 0.29.0.gfm.13, **luglio 2023** |
| Segue la specifica | sì, per costruzione | ferma a 0.29 |
| Sorgente | ~392 KB di `.c` | ~532 KB |
| In più | — | tabelle, barrato, autolink, note, to-do, filtro tag |

**Cosa guadagniamo**, oltre ai 652 su 652:

* le **posizioni nel sorgente** sono native (`sourcepos`). Oggi ce le
  scriviamo da soli con il patch `data-src`: sparirebbe un pezzo di codice
  nostro dentro una dipendenza, che è il genere di cosa che rende doloroso
  aggiornare;
* un **albero**, invece di callback. L'indice, l'esportazione EPUB e la
  selezione condivisa oggi passano da renderer paralleli; con un albero si
  cammina una volta sola;
* una dipendenza **viva**: 0.31.2 è di sei mesi fa.

**Cosa perdiamo.** hoedown ci dà cinque cose che né cmark né cmark-gfm
hanno, e sono cinque interruttori nelle impostazioni — cioè documenti già
scritti così:

| Estensione | Sintassi | In cmark |
|---|---|---|
| Highlight | `==evidenziato==` | no |
| Quote | `"virgolette"` → `<q>` | no |
| Superscript | `2^10` | no |
| Underline | `_sottolineato_` | no (e in CommonMark quello è corsivo) |
| Math | `$x$`, `$$x$$` | no |

cmark ha un'API per le estensioni — è come cmark-gfm aggiunge le tabelle —
quindi si possono riscrivere. Ma vanno riscritte: sono cinque parser
inline, non cinque interruttori.

**Cosa costa**, contato: 112 chiamate in 5 file, 212 righe di patch da
rifare come estensioni o come passeggiata sull'albero, l'estensione del
Finder che compila il parser per conto suo, e i test di rendering che
vanno riverificati **tutti** — sono la rete che dice se il cambio ha rotto
qualcosa.

**La scelta dentro la scelta**: cmark (la specifica pulita, e ci scriviamo
tabelle e note) oppure cmark-gfm (tabelle e note già fatte, ma fermo alla
0.29 e mantenuto da GitHub per GitHub). Propendo per **cmark**, con le
nostre estensioni: la ragione di fare tutto questo è smettere di dipendere
da un parser fermo, e cmark-gfm è già fermo da tre anni.

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
| 2 | Le cinque estensioni nostre come estensioni di cmark | sono impostazioni che esistono e documenti che esistono | grande |
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

1. **Conformità o compatibilità?** Passare a cmark cambia come vengono resi
   documenti che oggi funzionano: `_sottolineato_` diventa corsivo,
   `"virgolette"` restano virgolette, `2^10` resta `2^10` finché le
   estensioni non sono riscritte. Propendo per *conformità*, con le cinque
   estensioni rifatte prima di spegnere hoedown, e non dopo.
2. **cmark o cmark-gfm?** Propendo per *cmark*: la ragione di muoversi è non
   dipendere da un parser fermo.
3. **L'evidenziatore dell'editor entra nel lavoro o resta fuori?** Propendo
   per *entra*, ma alla fine: è il pezzo che rende il cambio definitivo, ed
   è anche quello che si può fare senza fretta.
4. **Djot: una lingua in più o no?** Propendo per *non adesso*, e per
   guardarla di nuovo quando i parser Markdown saranno uno. Se si farà, la
   strada è `djot.js` in JavaScriptCore e i file riconosciuti
   dall'estensione, non un interruttore.

---

*Questo è uno studio: nessuna di queste è una promessa. I numeri sono stati
misurati il 12 settembre 2026 su hoedown 3.0.7 e sulla specifica CommonMark
0.31.2, e si rimisurano in un minuto.*
