# Studio: cosa serve al pannello Confronta

Studio, e in fondo (sezione 10) il diario della prima fase, che è stata
scritta. Serviva a decidere **cosa aggiungere al pannello e in che ordine**,
con una misura in testa invece di un elenco di desideri.

Oggi il pannello fa questo: mette il documento accanto a un altro file — a
sinistra quello che sta **nell'editor**, non quello sul disco — segna in una
riga sola quello che è cambiato, e dentro quella riga le parole che
differiscono; tiene le due colonne allineate con i numeri di riga di
ciascuna, le fa scorrere insieme, salta da una differenza all'altra, piega
via quello che è uguale lasciando tre righe di contesto, scambia i lati e
rilegge i file quando qualcun altro li ha salvati.

---

## 1. La misura che decide le priorità

Il documento [anteprime.md](anteprime.md), 298 righe. Una parola cambiata:

| Confronto | Righe toccate |
|---|---|
| Una parola cambiata | **1 cambiata** |
| La stessa parola, ma il documento è stato riavvolto a 72 colonne | **166 cambiate, 14 aggiunte, 1 tolta** |

La modifica vera è una. Le altre centottanta sono il ritorno a capo. Un
editor che riavvolge i paragrafi — il proprio, quello di un altro, quello di
un agente che ha riscritto un file — trasforma **una** differenza in
centottanta, e il pannello diventa inservibile proprio nel caso in cui
serviva.

Lo stesso confronto fatto **per paragrafi** invece che per righe: 9 righe in
tutto, cioè le modifiche vere più le liste che il mio riavvolgimento grezzo
ha spostato davvero. Un ordine di grandezza meno rumore.

Da qui in poi l'ordine è deciso: **il rumore prima di tutto il resto.**

## 2. Cosa si legge: la granularità e il rumore

### A. Confronto per paragrafi — *la cosa che manca di più*

Un interruttore, e forse quello di serie per il Markdown: due paragrafi
sono lo stesso paragrafo se dicono le stesse parole, comunque siano andati a
capo. Le righe che non sono prosa — titoli, tabelle, blocchi di codice,
voci di elenco — restano righe, perché lì il ritorno a capo **è** il
contenuto.

Costo: piccolo, e tutto nella parte pura. Il confronto per righe che c'è
diventa un confronto di blocchi, con i blocchi costruiti come li costruisce
già il resto dell'applicazione.

### B. Ignora gli spazi, ignora le maiuscole

Due interruttori piccoli che tolgono il resto del rumore: l'indentazione
cambiata, il doppio spazio dopo il punto, il titolo scritto in maiuscolo.
Costo: minimo, e sono attese.

### C. Il testo **reso**, non il sorgente — *scartata*

L'idea era: «cosa è cambiato per chi legge», con `**grassetto**` e
`__grassetto__` che contano uguale. Scartata, ed è la risposta alla domanda
4 in fondo.

Il motivo regge: qui si scrive Markdown, e chi confronta due documenti sta
guardando **quello che ha scritto**, non quello che ne esce. Un confronto
che dice «uguali» a due sorgenti diversi nasconde proprio le modifiche che
solo il pannello può far vedere — un link cambiato, un marcatore spostato,
un commento tolto — e quelle non sono rumore: sono il lavoro.

### D. Blocchi spostati

Una sezione spostata oggi si legge come «tolta qui, aggiunta là», che è
vero e non è quello che è successo. Riconoscere uno spostamento è un lavoro
vero (bisogna cercare le corrispondenze fra i blocchi tolti e quelli
aggiunti) e va dopo A, B e C: è più bello, ma è meno urgente.

## 3. Da dove vengono i due lati

Oggi: l'editor e un file scelto a mano. Tutto il resto del valore del
pannello sta nelle altre provenienze, e ognuna ha già il suo pezzo pronto
da qualche parte nell'applicazione.

| Da confrontare con | Cosa c'è già | Quanto serve |
|---|---|---|
| **Una versione di macOS** (Archivio ▸ Torna a) | `NSFileVersion`, già usato: teniamo una versione prima di ogni riscrittura | **alta** — «cos'ha cambiato l'aiuto alla scrittura» ha già la sua versione salvata |
| **La copia sul disco**, quando l'editor ha modifiche non salvate | niente da fare: il file è lì | **alta**, ed è una riga di codice |
| **Una copia in conflitto** di un provider | la conoscerà la [sincronizzazione](progetto-sync.md), fase 1 | alta, quando quella fase c'è |
| **Una revisione git** | la fase 2 della stessa | alta, idem |
| **Quello che ha cambiato un agente** | il server MCP scrive nel diario cosa ha toccato e quando | media — e diventa alta il giorno che qualcuno lascia un agente scrivere davvero |
| **Un altro documento aperto** | l'elenco delle finestre | media, ed è comodo |
| **Gli appunti** | niente da fare | bassa, ma costa un menu |

Nota su una di queste: «confronta con la copia sul disco» è la risposta alla
domanda *cosa ho cambiato da quando ho aperto*, ed è probabilmente la voce
di menu più usata di tutte. Oggi bisogna scegliere il file a mano, che è la
stessa cosa detta peggio.

## 4. Dal leggere al fare

Il pannello oggi si legge e basta. Le tre cose che seguono sono il passo
successivo, in ordine di quanto sono sicure:

1. **Copia questa riga** (o questo blocco) — la differenza sotto il
   puntatore finisce negli appunti. Innocuo, utile, subito.
2. **Prendi questa versione** — la riga di destra sostituisce quella di
   sinistra *nell'editor*. Qui bisogna stare attenti: la sinistra è testo
   vivo, non salvato, e una sostituzione è una modifica del documento. Va
   fatta come un passo solo di annulla, e va rifiutata quando la sinistra
   non è l'editor (dopo uno scambio dei lati, per esempio).
3. **Esporta le differenze** — un `diff` unificato da incollare altrove, o
   un Markdown con le parti segnate. Piccolo, e chiude il cerchio con chi
   deve mandare a qualcuno «ecco cosa ho cambiato».

Quello che **non** va fatto qui: un merge a tre vie (base, mio, loro).
Serve, ma serve alla sincronizzazione, e va progettato con quella — non
inventato dentro un pannello che oggi confronta due file e basta.

## 5. Come ci si muove dentro

* **Una mappa delle differenze** a lato della finestra: una striscia alta
  quanto il documento, con un segno dove ci sono le modifiche. In un file
  lungo è l'unico modo di sapere *dove* sono le differenze senza scorrere
  tutto.
* **⌘G e ⇧⌘G** per la differenza dopo e prima, che sono i tasti che tutti
  hanno già nelle dita, invece dei due bottoni soltanto.
* **Vai alla riga nell'editor**: doppio clic su una riga a sinistra e
  l'editor ci si porta e la seleziona. Il ponte fra i pannelli che c'è già
  fa esattamente questo mestiere, dall'altra parte.
* **Il conteggio nel titolo della finestra**, così si sa cosa si sta
  guardando anche dal menu Finestra.
* **Ritorno a capo morbido**, a scelta: oggi le righe lunghe scorrono di
  lato perché le due colonne devono restare allineate. Con il confronto per
  paragrafi (A) il problema si sposta e questa scelta diventa necessaria.

## 6. Cosa non farei

* **Il confronto di due cartelle.** È un'altra applicazione, non un'altra
  funzione: elenco dei file che differiscono, filtri, ricorsione. Se un
  giorno servisse, servirebbe per la sincronizzazione — e allora sarebbe un
  elenco, non un pannello di confronto.
* **Il confronto di immagini o di binari.** Qui si scrive Markdown.
* **Un algoritmo più furbo di Myers.** Misurato: 7 millisecondi su un
  documento di 298 righe, 9 con tutto riavvolto; trentamila righe contro
  altrettante, tutte diverse, stanno nel limite di sforzo e rispondono
  comunque. Non è lì il problema.
* **Le tre vie**, come sopra: con la sincronizzazione, non prima.

## 7. Accessibilità e aspetto

Due cose che oggi mancano e che si notano solo quando mancano:

* **Non solo il colore.** Verde e rosso non li distinguono tutti: ci vuole
  un segno nel margine — `+`, `−`, `~` — accanto al numero di riga.
* **La dimensione del carattere** del confronto segue oggi un numero scritto
  nel codice. Dovrebbe seguire quella dell'editor, che una persona ha già
  scelto una volta.

## 8. In che ordine

| Fase | Cosa | Perché |
|---|---|---|
| 1 | Confronto per paragrafi, ignora spazi e maiuscole; segni nel margine | è la misura della sezione 1: senza questo il pannello non regge un documento riavvolto |
| 2 | «Confronta con la copia sul disco» e «con una versione»; ⌘G; conteggio nel titolo | le provenienze che esistono già, e i tasti che tutti hanno nelle dita |
| 3 | Copia la differenza; prendi questa versione (un passo di annulla); mappa laterale | il passo dal leggere al fare, il pezzo sicuro per primo |
| 4 | Vai alla riga nell'editor; esporta le differenze | il resto, quando i primi tre sono in uso |
| — | Copie in conflitto, revisioni git, tre vie | con la [sincronizzazione](progetto-sync.md), non prima |

## 9. Le domande da decidere

1. **Il confronto per paragrafi va di serie o a scelta?** Propendo per *di
   serie sul Markdown*, con l'interruttore per tornare alle righe: chi
   confronta codice dentro un `.md` vuole le righe, tutti gli altri no.
2. **«Prendi questa versione» modifica il documento dall'interno del
   pannello?** Propendo di sì, ma **solo verso l'editor** e solo quando il
   lato sinistro è l'editor: in tutti gli altri casi la voce non compare.
3. **La mappa laterale o il conteggio nel titolo, se se ne può fare una
   sola?** La mappa: il conteggio lo si vede già nel pannello.
4. **Confrontare il testo reso è una modalità del pannello o un'altra voce
   di menu?** → **né l'una né l'altra: non si fa.** Chi confronta due
   documenti Markdown guarda il sorgente, che è quello che ha scritto; un
   confronto che pareggia due sorgenti diversi perché «si leggono uguali»
   nasconde le modifiche che solo un confronto può mostrare. Il controllo
   del pannello resta a due: per righe, per paragrafi.

---

## 10. La fase 1, com'è andata

Scritta. Il pannello ha tre controlli in più — **per righe / per paragrafi**,
**ignora gli spazi**, **ignora maiuscole e minuscole** — e un segno nel
margine accanto al numero di riga: `~` cambiata, `+` aggiunta, `−` tolta,
per chi il verde dal rosso non lo separa.

Per paragrafi, di serie no: le righe restano il modo normale di confrontare,
come chiedeva la risposta alla domanda 1. Quello che non è prosa resta una
riga anche a paragrafi — titoli, voci di elenco, righe di tabella, tutto
quello che sta dentro un recinto — perché lì il ritorno a capo **è** il
contenuto.

### I numeri, sullo stesso documento dello studio

| Confronto | Righe toccate |
|---|---|
| Per righe | 166 cambiate, 14 aggiunte, 1 tolta |
| **Per paragrafi** | **4 cambiate, 1 aggiunta, 4 tolte** |
| Una parola cambiata, per paragrafi | 1 cambiata |

Centottantuno differenze diventano nove, e le nove che restano sono le
liste che il riavvolgimento ha spostato davvero.

### I due difetti che le fotografie hanno tirato fuori

Fotografare il pannello per il sito ha trovato in dieci minuti quello che
guardarlo non aveva trovato in un pomeriggio.

**Le colonne erano strizzate**: due strisce da duecento punti in una finestra
da milleduecento, e metà finestra vuota. Una pila orizzontale dà a ogni
vista la larghezza che *chiede*, e una vista di testo chiede pochissimo:
serviva dire che le colonne prendono quello che avanza e la striscia no.

**La striscia non corrispondeva alle righe**: disegnava una banda per riga a
spaziatura fissa, che è giusto solo se tutte le righe sono alte uguale —
cioè mai, in modalità paragrafo. Adesso ogni banda sta dove sta davvero il
suo paragrafo nel testo impaginato, la cornice di «cosa è sullo schermo»
viene dallo scorrevole invece che da un conteggio, e un clic sulla striscia
cerca la riga che si trova a quell'altezza. Si ricalcola anche quando la
finestra cambia forma, perché ridimensionare riavvolge i paragrafi e sposta
tutto. Una prova tiene le bande legate alle righe.

### Il difetto che ha tirato fuori

Il primo tentativo dava 107 differenze anche per paragrafi: i paragrafi non
venivano uniti affatto, da metà documento in poi. La causa era una riga che
dice come si scrive un recinto:

```
Un recinto ```` ```mermaid ```` in anteprima era codice
```

Quattro apici per citarne tre. Presa per un recinto, apre un blocco di
codice che non si chiude più, e da lì in giù ogni riga «sta per conto suo».
La regola giusta è di CommonMark e stava scritta lì: **dopo un recinto di
apici non ci sono apici**.

Lo stesso errore stava in `MPMarkdownCodeRanges`, la funzione che l'intera
applicazione usa per sapere cosa è codice — quindi in questo documento i
backlink dopo quella riga non venivano contati, e nemmeno gli import dei
file di istruzioni. Corretta lì, con la sua prova.

### Come scorre adesso

Un paragrafo va a capo da solo, e le due colonne non sono più alte uguali:
lo scorrimento non insegue più i punti ma **le righe**. Chi muove una parte
mette in cima all'altra *la stessa riga del confronto*, qualunque altezza
abbia. Lo stesso vale per «differenza successiva», che adesso tiene la riga
a un terzo dall'alto invece che appiccicata in cima.

## 11. La fase 2, com'è andata

Le provenienze che esistevano già da qualche altra parte, e i tasti che
tutti hanno nelle dita.

**Archivio ▸ Confronta** è adesso un sottomenu di tre voci:

| Voce | Con cosa |
|---|---|
| **Con un file…** (⌃⌥⌘D) | quello di prima |
| **Con la copia sul disco** | quello che è stato salvato — *cosa ho cambiato da quando ho aperto*, che lo studio dava per la voce più usata di tutte |
| **Con una versione…** | una delle versioni che tiene macOS, comprese quelle che l'applicazione tiene **prima** che l'aiuto alla scrittura o un file cambiato sotto riscrivano qualcosa |

La scelta della versione è un elenco con la data — «oggi 00:16» — e dice in
chiaro che non si ripristina niente: la versione va a destra e si legge.

**⌘G e ⇧⌘G** camminano le differenze. Con questa finestra davanti «Trova
successivo» nel menu è spento, quindi il tasto arriva ai due bottoni; ma il
pannello risponde anche a `performFindPanelAction:`, perché le due colonne
sono viste di testo e una vista di testo, quel messaggio, se lo prenderebbe
per sé — «trova la prossima occorrenza in questa colonna» non è quello che
⌘G vuol dire in una finestra che parla di differenze.

**Il titolo dice cosa c'è dentro**:

```
nota.md (nell'editor, non salvato) ↔ nota.md (sul disco) — una differenza
```

Il menu Finestra con tre confronti aperti torna leggibile, e «una
differenza» non è «1 differenze».

Provato: nell'applicazione vera, con un documento modificato e non salvato,
salvato due volte per avere le versioni; e nella suite, dove una voce di
menu che punta a un selettore che nessuno implementa — invisibile finché
qualcuno non ci clicca — viene ora cercata **sia nel nib sia nel binario**.

## 12. Le fasi 3 e 4, com'è andata

Fatte insieme, meno il testo reso che è stato scartato (sezione 2.C).

**Dal leggere al fare.** Tasto destro su una riga del confronto:

* **Copia questa differenza** — il testo della riga *nel documento*, non
  quello che si vede: senza il numero di riga e senza il segno nel margine,
  che sono nostri;
* **Prendi la versione di destra** — quella riga sostituisce la sinistra
  **nell'editor**, in un passo solo di annulla, con una versione tenuta
  prima. Offerta solo quando a sinistra c'è un documento vivo: dopo uno
  scambio dei lati la voce non c'è;
* **Mostralo nell'editor** — e lo stesso lo fa il doppio clic a sinistra.

Il pannello non tocca il documento da sé: gli vengono dati **due blocchi** e
non ha altro modo di scrivere. Il blocco che sostituisce riceve anche
*quello che il pannello crede ci sia*, e se il documento nel frattempo è
cambiato risponde di no — il pannello lo dice, invece di scrivere in un
punto calcolato su un testo che non esiste più.

**La mappa** è una striscia a destra: una banda per riga, del colore di
quello che è, con una cornice intorno a quello che è sullo schermo. Un clic
ci porta. In un documento lungo è l'unico modo di sapere se la prossima
differenza è due schermate più giù o duecento.

**Esporta…** scrive un diff unificato — misurato carattere per carattere
contro `diff -U2` sullo stesso paio di file: identico. Per paragrafi il
diff lo dice in un commento, perché è roba da leggere e non da dare in pasto
a `patch`.

### Il difetto che ha tirato fuori

Le due colonne erano diventate una sottoclasse di `NSTextView` (serve per
lasciar passare ⌘G e per sapere su che riga si è cliccato), ma la riga che
le crea non era stata cambiata: restavano `NSTextView`, e alla prima
`setIsTheLeftSide:` partiva un'eccezione che AppKit **si mangia**. Effetto
visibile: la voce di menu non faceva assolutamente niente. Adesso c'è una
prova che apre la finestra e le chiede il titolo, che è il modo più corto di
accorgersene.

### Cosa resta

Niente di questo studio: le quattro fasi sono fatte e il testo reso è
scartato. Quello che resta è nella sezione 3 — le provenienze che aspettano
la [sincronizzazione](progetto-sync.md): una copia in conflitto, una
revisione git, le tre vie.

---

*Le quattro fasi sono fatte, l'11 e il 12 settembre 2026. Quello che resta
aspetta la sincronizzazione.*
