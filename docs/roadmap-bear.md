# Roadmap: le funzioni di Bear, e cosa ne facciamo

Seguito dello [studio di Bear](da-bear.md), messo in ordine di lavoro. Ogni
voce dice **dove siamo** e **quanto costa**, e le fasi sono in ordine di
quanto cambiano la giornata di chi tiene una cartella di verbali.

Stato al 4 settembre 2026: master con le due anteprime dentro, 243 prove; la
piegatura sul ramo `piegatura`, con un difetto aperto. Tutto il resto è su
master: il web clipper, la sola lettura, il fuoco e il riordino dei to-do
arrivano con la 0.23.0.

---

## Il quadro

| Funzione di Bear | Da noi | Dove | Costo |
|---|---|---|---|
| Backlink | **fatto** — ⌃⌥⌘B, con riga e frase | master | — |
| Piegatura delle sezioni | **fatta**, difetto aperto sul sync dello scorrimento | ramo `piegatura` | — |
| Tabelle | fatto, per comandi | master | — |
| Blocchi di codice + evidenziazione | fatto, 113 linguaggi, rientro per linguaggio | master | — |
| Indice del documento (ToC) | fatto, barra laterale | master | — |
| Cerca e sostituisci nella nota | fatto (⌘F, ⌥⌘F) | master | — |
| Note collegate (wiki link) | fatto | master | — |
| Mermaid | fatto **prima di Bear** (loro: luglio 2026) | master | — |
| Formule matematiche | fatto **prima di Bear** (loro: agosto 2025) | master | — |
| Statistiche in linea | fatto: parole, caratteri e tempo di lettura | master | — |
| Export (PDF, DOCX, HTML, ePub) | fatto, e più curato del loro | master | — |
| Temi | fatto, editor e anteprima | master | — |
| CLI | `macdownext`: apre file, e basta | master | media |
| Modalità sola lettura | **fatta** — ⌥⌘L | master | — |
| Fuoco / macchina da scrivere | **fatti** — ⌃⌥⌘F e ⌃⌥⌘T | master | — |
| To-do che si riordinano | **fatto**, a comando | master | — |
| Anteprima del documento collegato | **fatta** — cartolina dopo cinque secondi sul link | master | — |
| Anteprima nel Finder (Quick Look) | **fatta** — estensione dentro l'app | master | — |
| Server MCP con perimetro | **fasi 1, 2 e 3 fatte** — lettura, e scrittura a richiesta | master | alta |
| Web clipper | **fatto** — Archivio ▸ Salva una pagina come Markdown… | master | — |
| Tag come organizzazione | **no** — l'equivalente su file è il front-matter | — | — |
| Sync iCloud, cifratura per nota, OCR, scanner, schizzi, archivio/cestino, workspace per tag | **no** | — | — |

---

## Fase 0 — chiudere la piegatura

Un ramo aperto è lavoro che invecchia.

* **Il sync dello scorrimento con le sezioni piegate.** Pista già in mano, ed
  è la stessa trappola che ha morso quattro volte: `editorTopForCharacterIndex:`
  misura il rettangolo di un glifo, e per un carattere dentro una sezione
  piegata quel rettangolo è vuoto — l'editor salta a zero. La direzione
  editor → anteprima passa invece per il carattere in cima e regge; è
  `syncScrollers`, che interpola sulle posizioni dei titoli, quella da
  ricalcolare quando una piega cambia.
* Poi **fusione su master** e un rilascio.

---

## Fase 1 — ~~tre cose piccole che si sentono ogni giorno~~ fatta

Tutte e tre su master dalla 0.23.0:

1. **Sola lettura**, ⌥⌘L: lucchetto nella barra del titolo, testo ancora
   selezionabile, comandi che modificano rifiutati.
2. **Fuoco e macchina da scrivere**, ⌃⌥⌘F e ⌃⌥⌘T: attenuazione fatta con gli
   attributi temporanei del layout manager, quindi non tocca il file.
3. **To-do che si riordinano**, a comando e non da soli: una voce si porta
   dietro le sue righe di continuazione e i suoi to-do annidati.

---

## Fase 2 — navigare una cartella come si navigano le note

I backlink hanno aperto la strada: la cartella diventa qualcosa che si
percorre. Queste due la completano.

1. ~~**Anteprima del documento collegato.**~~ **Fatta**, su master,
   nell'anteprima invece che nell'editor: puntatore fermo cinque secondi su un
   link e si apre una cartolina con titolo e prime righe. Insieme è arrivata
   l'anteprima dei `.md` nel Finder. Diario: [le due anteprime](anteprime.md).
2. **Elenco della cartella per front-matter.** L'equivalente onesto dei tag
   di Bear: il front-matter Jekyll lo leggiamo già, manca un pannello che
   mostri i documenti vicini per campo — `stato: bozza`, `cliente: X`.
   Niente database, solo quello che c'è scritto nei file. *Media.*

---

## Fase 3 — il pezzo grosso: un server MCP sulla cartella

Bear 2.8 ha messo `bearcli` e un server MCP; la 2.9 ha aggiunto lo
**scoping** — quali note l'assistente vede, per tag inclusi o esclusi.

Da noi l'unità non è il tag, è **la cartella**: cerca, leggi, crea, aggiungi
in coda, dentro una radice dichiarata e con esclusioni. Per una cartella di
evidenze ISO 27001 poter chiedere «i verbali di agosto che citano il
firewall» senza aprire l'app vale più di dieci funzioni di editor.

**Va progettato prima di essere scritto**, e la parte da progettare non è il
protocollo: è il perimetro. Cosa può leggere, cosa può scrivere, come si
dice di no, e come si vede cosa ha fatto — il diario delle azioni che c'è
già è il posto giusto dove farlo comparire. *Alta.*

Prima tappa utile e piccola: portare `macdownext` da «apre file» a
«cerca/leggi/aggiungi», che è la stessa base su cui il server poi si appoggia.

**Le fasi 1 e 2 adesso ci sono**: [un server MCP sulla
cartella](progetto-mcp.md) — `macdownext-mcp`, accanto a `macdownext` dentro
l'app, che cerca, legge, elenca, dà l'indice dei titoli, dice chi cita un
documento, legge il front matter e trova i documenti che dichiarano un
campo, dentro **una** cartella dichiarata da cui non esce. Le citazioni e il
front matter li calcola con lo stesso codice dell'editor. Con `--append` o
`--write` aggiunge in coda, crea documenti nuovi e sostituisce testo che
trova — mai cancella, mai rinomina, mai scrive sopra — e ogni chiamata
finisce in `~/Library/Logs/MacDown Next/mcp.log`. Resta la fase 4: il
pannello nelle impostazioni.

---

## Fase 4 — accessori — **fatta** (ramo `fase4`)

* **Web clipper** — *fatto*. **File › Salva una pagina web come Markdown…**:
  il file finisce accanto al documento, con indirizzo e data nel
  front-matter, e si apre in un tab. Quello che circonda la pagina (script,
  stili, navigazione, intestazioni, piedi, colonne laterali) resta fuori, e
  se la pagina dichiara quale parte è l'articolo si prende quella. La
  conversione è la stessa dell'incollare, quindi arriva quello che
  arriverebbe copiando la pagina — provato su una pagina vera: 45 KB di
  HTML, 5,3 KB di Markdown, titolo, elenchi e grassetti al loro posto.
* **Tempo di lettura** — *fatto*, nel contatore accanto a parole e
  caratteri. Duecento parole al minuto: una cifra, non una misura, e serve
  a distinguere una pagina da un capitolo.

---

## Quello che non faremo, e perché

| | |
|---|---|
| **Tag come organizzazione** | Sono un database. Su file l'equivalente è il front-matter, che già leggiamo |
| **Sync iCloud** | I file stanno in una cartella: sincronizzarli è mestiere di iCloud Drive, Dropbox o `git`. Rifarlo dentro l'app significa poterlo rompere |
| **Cifratura per nota** | Renderebbe il file illeggibile a tutto il resto, che è il contrario del motivo per cui si scrive in Markdown. FileVault cifra il disco |
| **OCR dentro immagini e PDF** | Lo fa Spotlight sulla cartella |
| **Scanner, schizzi a penna** | Roba da iPhone e iPad |
| **Archivio e cestino** | Sono il Finder |
| **Workspace per tag** | Da noi il workspace è la cartella, e ce l'ha già il sistema |

---

## Fatte per strada, dopo che la lista era scritta

Non erano in nessuna fase, e sono arrivate perché servivano.

* **Textbundle e Textpack**, scritti *e* letti. È il punto di contatto vero
  con Bear: il formato è suo quanto nostro — lo leggono anche Ulysses, iA
  Writer e Marked — e un documento con le sue immagini passa da un'app
  all'altra senza perdere niente. Che è esattamente la cosa che i tag e il
  sync di Bear non sanno fare.
* **L'anteprima del Finder disegna tutto**: mermaid, i sei motori di
  Graphviz, le formule TeX, e i `[[WikiLink]]` come collegamenti. Un
  documento si legge chiuso come si legge aperto.
* **Una selezione sola nei due pannelli**, nei due versi, con canc che
  cancella dal sorgente quello che hai preso nella pagina. Diario:
  [la selezione fra i due pannelli](selezione.md).

---

## Una regola che vale per tutta la lista

> Si porta ciò che vive dentro un documento o dentro una cartella. Non si
> porta ciò che ha bisogno di un database.

È il criterio con cui è stata scritta questa roadmap, ed è anche il motivo
per cui è corta: metà delle funzioni di Bear risolvono un problema che noi
non abbiamo.
