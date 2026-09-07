# Cosa prendere da Bear

Studio di Bear 2.9 e di Bear Pro, con una domanda sola: **cosa ha senso
portare dentro MacDown Next, e cosa no.** Non è un elenco di desideri — per
ogni voce c'è cosa costa e cosa cambia davvero per chi scrive verbali e
documentazione in una cartella di file.

Fonti guardate il 3 settembre 2026: la [pagina delle
funzioni](https://bear.app/), [What's new in Bear
2](https://bear.app/faq/whats-new-in-bear-2/), il [blog degli
aggiornamenti](https://blog.bear.app/category/updates/), la [pagina del
CLI](https://bear.app/faq/command-line-interface/).

> Una precisazione, perché la richiesta diceva 2.9.3: la riga documentata è
> **2.9 (16 luglio 2026)** — «Use Tag as Workspace» e lo scoping del server
> MCP — più i rilasci minori successivi, di cui non ho trovato note
> pubblicate voce per voce. Quello che segue vale per la 2.9 e per quanto è
> stato aggiunto dopo: **Mermaid** (28 luglio 2026), **formule
> matematiche** (agosto 2025), **Web Clipper 2.0**, **modalità sola
> lettura** (2.3.11), **to-do più intelligenti** e cifratura degli allegati
> (2.4).

---

## Il fatto che decide tutto il resto

**Bear è un'app di note; noi siamo un editor di file.** Bear tiene i testi
in un database suo, li organizza con i tag, li sincronizza con iCloud e li
cifra. Noi apriamo un `.md` che sta in una cartella, e chi lo apre dopo di
noi può essere `git`, un altro editor, o nessuno.

Da qui il criterio, che uso per tutto l'elenco:

> **Si porta ciò che vive dentro un documento o dentro una cartella. Non si
> porta ciò che ha bisogno di un database.**

Metà delle funzioni di Bear cade sul lato sbagliato di quella riga. Non è un
difetto di Bear: è che risolve un altro problema.

---

## Quello che abbiamo già — e in due casi da prima

Prima di guardare cosa manca, conviene sapere cosa non manca. Bear ha
aggiunto di recente cose che qui ci sono da mesi:

| | Bear | Noi |
|---|---|---|
| Mermaid | luglio 2026 | Mermaid 11.17, con zoom e pan, disegnato anche negli export |
| Formule matematiche | agosto 2025 | editor TeX con anteprima, MathJax incluso, senza rete |
| Blocchi di codice | evidenziazione e modifica | 113 linguaggi, scelta del linguaggio nel foglio, rientro secondo il linguaggio |
| Tabelle | «Markdown-friendly» | comandi su righe, colonne, allineamento, riparazione della riga dei trattini |
| Indice del documento | ToC live dai titoli 1-6 | la barra laterale con la struttura |
| Cerca e sostituisci dentro la nota | Bear 2 | ⌘F e ⌥⌘F, i Find di sistema |
| Note collegate | wiki link | `[[Altro documento]]`, e dice quando il file non c'è |
| Statistiche | «live in-note stats» | conteggio parole/caratteri nella barra |
| Export | TXT, MD, RTF, PDF, HTML, DOCX, ePub | HTML, PDF, DOCX riparato, EPUB 3.3, con le immagini di rete recuperate |
| CLI | `bearcli` | `macdownext` (apre file: molto meno) |
| Temi | 28 + 15 icone | temi editor e anteprima, chiaro/scuro |

Su diagrammi ed export siamo avanti. Su organizzazione e ricerca, no — ed è
esattamente dove Bear è un'app di note.

---

## Da portare, in ordine di quanto rende

### 1. Backlink — «chi punta a questo documento» — **fatto**

**In Bear:** un elenco delle note che collegano quella aperta.

**Da noi:** i `[[wikilink]]` e i link relativi ci sono già; manca la
domanda inversa. Un pannello che scandisce la cartella del documento e
mostra chi lo cita — con la riga, come l'elenco della prosa.

Per una cartella di verbali che si citano fra loro è **la cosa che cambia
di più**: oggi per sapere chi rimanda a `VERBALE_2026-09-02.md` bisogna
fare `grep`.

*Costo: medio.* **Fatto**, ⌃⌥⌘B: la cartella viene riletta a ogni domanda
invece di essere tenuta d'occhio — la risposta serve qualche volta al
giorno, e un osservatore su un albero di documenti è una cosa da sbagliare.
Contano sia i `[[wikilink]]` che i link relativi, `%20` e `..` compresi;
quello che sta dentro il codice non conta.

### 2. Piegare le sezioni

**In Bear:** «Folding — collapse note sections».

**Da noi:** piegare per titolo nell'editor, come già facciamo sparire i
marcatori: il file non cambia di un carattere. Un verbale di collaudo di
quaranta pagine si legge per sezioni o non si legge.

*Costo: medio.* La macchina per nascondere glifi c'è già
(`MPMarkerHider`); serve il modello delle sezioni e i triangolini.

### 3. Modalità sola lettura

**In Bear:** aggiunta nella 2.3.11.

**Da noi:** aprire un documento senza poterlo modificare per sbaglio, con
una fascia che lo dice. Per un'evidenza già firmata o un verbale chiuso è
proprio il caso d'uso — e oggi l'unica difesa è ricordarsi di non scrivere.

*Costo: basso.* `editor.editable = NO`, una voce di menù, un indicatore.

### 4. Scrittura senza distrazioni: fuoco e macchina da scrivere

**In Bear:** focus mode e typewriter scrolling.

**Da noi:** attenuare i paragrafi che non si stanno scrivendo, e tenere la
riga corrente al centro invece che in fondo. Chi scrive un verbale lungo lo
sente subito.

*Costo: basso.* Attributi di colore sul resto del testo e uno
`scrollRangeToVisible` centrato.

### 5. To-do che si riordinano

**In Bear:** i completati scendono in fondo alla lista, e si può spegnere.

**Da noi:** un comando su una lista di attività, non un automatismo — il
file è di chi lo scrive, e riordinargli le righe mentre digita è invadente.
Voce di menù, un annullamento solo.

*Costo: basso.* Il modello delle liste c'è già per le tabelle e i rientri.

### 6. Anteprima di quello che c'è dall'altra parte del link

**In Bear:** link preview, e anteprima dei PDF.

**Da noi:** passando su un `[[wikilink]]` o su un link relativo, il titolo e
le prime righe del documento collegato. Trasforma una cartella di file in
qualcosa che si naviga.

*Costo: basso-medio.* Legge la prima riga utile del file, popover.

### 7. Un server MCP sulla cartella

**In Bear (2.8 e 2.9):** `bearcli` — cerca, leggi, crea, aggiungi, tagga,
allega, archivia — e sopra ci sta un server MCP, con lo **scoping** della
2.9: quali note l'assistente può vedere, per tag inclusi o esclusi.

**Da noi:** l'equivalente onesto non sono i tag, è **la cartella**: cerca,
leggi, crea, aggiungi in coda, dentro una radice dichiarata e con cartelle
escluse. Il nostro `macdownext` oggi apre file e basta.

Vale la pena dirlo chiaramente: per una cartella di evidenze ISO 27001,
poter chiedere «trovami i verbali di collaudo di agosto che citano il
firewall» **senza aprire l'app** è più utile di dieci funzioni di editor.

*Costo: medio-alto,* ed è l'unica voce dell'elenco che va progettata prima
di scriverla — soprattutto il perimetro: cosa può leggere, cosa può
scrivere, e come si dice di no.

### 8. Ritaglio dal web

**In Bear:** Web Clipper 2.0.

**Da noi:** salvare una pagina come Markdown nella cartella del documento,
con l'indirizzo e la data in cima. Per raccogliere evidenze è pane
quotidiano; il convertitore HTML→Markdown lo abbiamo già (serve per
incollare).

*Costo: medio.* Il grosso è la ripulitura della pagina, non la conversione.

---

## Aggiornamento: il ponte c'è

Da quando questo è stato scritto, l'applicazione **scrive e legge Textbundle
e Textpack**. È il formato che Bear stesso usa per esportare e importare, e
significa che una nota con le sue immagini passa nei due sensi senza perdere
niente e senza che nessuna delle due app debba conoscere l'altra.

Vale la pena dirlo qui perché cambia il tono di metà della lista: non serve
*portare via* niente da Bear, se un documento può andare e tornare.

---

## Quello che non prenderei

| | Perché no |
|---|---|
| **Tag come organizzazione** | I tag di Bear sono un database. Su file l'equivalente è il front-matter, che già leggiamo: caso mai un pannello che elenca la cartella per campo, non un albero di tag |
| **Sincronizzazione iCloud** (Pro) | I file stanno in una cartella: sincronizzarli è mestiere di iCloud Drive, Dropbox o `git`. Rifarlo dentro l'app significa poterlo rompere |
| **Cifratura delle note** (Pro) | FileVault cifra il disco e i contenitori cifrati esistono. Una cifratura per documento renderebbe il file illeggibile a tutto il resto, che è il contrario del motivo per cui si scrive in Markdown |
| **OCR dentro immagini e PDF** (Pro) | Spotlight già lo fa sulla cartella |
| **Scansione documenti, schizzi a penna** | Roba da iOS e da iPad |
| **Archivio e cestino** | Sono il Finder |
| **Workspace per tag** (2.9) | Ha senso quando tutte le note stanno in un mucchio solo. Da noi il workspace è la cartella, e ce l'ha già il sistema |

---

## Se dovessi sceglierne tre

**Backlink, piegatura delle sezioni, sola lettura.** Sono le tre che
servono a chi tiene una cartella di documenti che si citano, che sono
lunghi, e che a un certo punto non vanno più toccati — cioè esattamente il
lavoro per cui questo fork esiste.

Il server MCP è più grosso di tutti e tre messi insieme e probabilmente
rende di più, ma è un progetto a sé: prima si decide il perimetro, poi si
scrive.
