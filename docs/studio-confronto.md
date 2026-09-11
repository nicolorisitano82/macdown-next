# Studio: cosa serve al pannello Confronta

Studio, non progetto: il pannello è appena stato scritto e funziona; questo
serve a decidere **cosa aggiungerci e in che ordine**, con una misura in
testa invece di un elenco di desideri.

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

Lo stesso confronto fatto **per paragrafi** invece che per righe: 6 cambiati
e 11 aggiunti, cioè le modifiche vere più le liste che il mio riavvolgimento
grezzo ha spostato. Un ordine di grandezza meno rumore.

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

### C. Il testo **reso**, non il sorgente

«Cosa è cambiato per chi legge»: `**grassetto**` e `__grassetto__` sono la
stessa cosa; un `<!-- commento -->` non è niente. Lo sappiamo già fare — la
funzione che toglie i marcatori è quella che il ponte fra i due pannelli usa
per il verso opposto — quindi è una modalità in più, non un motore in più.

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
| 4 | Testo reso invece del sorgente; vai alla riga nell'editor; esporta le differenze | il resto, quando i primi tre sono in uso |
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
   di menu?** Propendo per una modalità, accanto a «solo le differenze».

---

*Questo è uno studio: nessuna di queste è promessa. Quando la fase 1 sarà
scritta, diventerà un diario, con i numeri veri invece delle intenzioni.*
