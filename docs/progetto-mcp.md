# Progetto: un server MCP sulla cartella

Progetto, non diario: qui non c'è ancora codice. Viene da due studi già
scritti — la [strada C dello studio su Claude e GPT](studio-claude-gpt.md) e
la [fase 3 della roadmap](roadmap-bear.md) — e serve a decidere **prima di
scrivere** la sola cosa che conta davvero:

> Va progettato prima di essere scritto, e la parte da progettare non è il
> protocollo: è **il perimetro**.

L'integrazione è al contrario di quella ovvia. Non è l'applicazione che
manda il documento a un motore: è il motore che **chiede** — cerca, leggi,
elenca chi cita questo — dentro una cartella dichiarata, con strumenti
espliciti, e senza che l'applicazione debba nemmeno essere aperta.

---

## 1. Che forma ha

Un **secondo eseguibile** accanto a quello che c'è già:

```
MacDown Next.app/Contents/SharedSupport/bin/
├── macdownext        ← quello di oggi: apre file nell'applicazione
└── macdownext-mcp    ← il server: JSON-RPC su stdio
```

Il client (Claude Code, Claude Desktop, o qualunque altro che parli MCP) lo
**avvia lui**, gli parla su standard input e output, e lo spegne quando ha
finito. Conseguenze, tutte volute:

* **non serve che MacDown Next sia in esecuzione**: lo stato è la cartella,
  non l'applicazione;
* **non c'è una porta aperta**: niente rete, niente socket, niente da
  proteggere da qualcuno che non sia già dentro questo Mac;
* si spegne da solo quando il client chiude, e non lascia niente in giro.

Il binario riusa i pezzi puri che l'applicazione ha già — i backlink, il
front matter, l'indice dei titoli, i Textbundle — compilando gli stessi
sorgenti. Nessuna libreria nuova: il protocollo è JSON su due tubi, e sono
duecento righe.

## 2. Il perimetro

Questa è la parte del progetto che va letta due volte.

### La radice si dichiara, non si indovina

```
macdownext-mcp --root ~/Verbali --root ~/Progetti/ISO
```

Senza `--root` **non parte**. Non esiste un valore predefinito, non esiste
«la cartella corrente», non esiste «tutta la home». Una radice sbagliata la
sceglie una persona, una volta, in un file di configurazione che può
rileggere.

### Ogni percorso viene ricondotto dentro la radice

Prima di ogni apertura: percorso normalizzato, link simbolici risolti,
confronto con le radici. Un `..`, un percorso assoluto, un link che punta
fuori — **rifiutati**, e l'intera chiamata fallisce invece di fare metà
lavoro. È la stessa regola con cui si scompatta un Textpack, e per lo stesso
motivo.

### Solo testo, e con un tetto

`.md`, `.markdown`, `.txt`, e un `.textbundle` trattato come un documento
solo. Niente binari, niente immagini, niente `.git`. File oltre **2 MB**:
rifiutati con un messaggio che dice quanto pesa. Lettura più lunga di N
righe: **tagliata, dicendolo**, come fa l'anteprima del Finder.

### Escluso di serie

`.git`, `node_modules`, `.build`, i file che cominciano con un punto, il
Cestino. In più `--exclude <glob>` e, se c'è, un file `.macdownignore` nella
radice, con la sintassi di `.gitignore` perché non serve inventarne un'altra.

### Tre livelli di scrittura, e la cancellazione non c'è

| Livello | Cosa può fare |
|---|---|
| `--read-only` (**di serie**) | cercare, leggere, elencare |
| `--append` | e aggiungere in coda a un file che esiste |
| `--write` | e creare file nuovi, e sostituire testo trovato |

**Non esiste uno strumento che cancella**, non esiste uno che rinomina, non
esiste uno che scrive un file intero da zero sopra uno che c'era. Cancellare
è mestiere del Finder, che ha un Cestino; un `write(path, testo)` è un `rm`
con un altro nome, perché il modo normale di sbagliarlo è passare il testo
di un altro file.

### Tutto finisce nel diario

Ogni chiamata — strumento, percorso, esito, quanti byte — va nel registro
delle azioni, `~/Library/Logs/MacDown Next/mcp.log`. Non è telemetria:
non esce dal Mac, e serve a rispondere alla domanda che conta il giorno
dopo, *chi ha toccato questo file e quando*.

## 3. Gli strumenti

Pochi, espliciti, con lo schema scritto. Nomi in inglese perché li legge un
motore, descrizioni che dicono anche cosa **non** fanno.

| Strumento | Argomenti | Risposta |
|---|---|---|
| `search` | `query`, `regex?`, `limit?` | file, riga, testo della riga |
| `read` | `path`, `from?`, `lines?` | il testo, e se è stato tagliato |
| `outline` | `path` | i titoli con il loro livello e la loro riga |
| `list` | `folder?`, `glob?` | nome, dimensione, data |
| `backlinks` | `path` | chi cita quel documento, con riga e frase |
| `frontmatter` | `path` | i campi del front matter, come mappa |
| `find_by_field` | `field`, `value` | i documenti che lo dichiarano |
| `append` * | `path`, `text` | byte aggiunti |
| `create` * | `path`, `text` | rifiuta se esiste già |
| `replace` * | `path`, `find`, `with`, `count?` | quante volte, e dove |
| `open_in_macdown` | `path` | lo apre nell'editor, se c'è |

`*` solo ai livelli di scrittura corrispondenti.

Due scelte da difendere:

* **`search` e `backlinks` sono due strumenti diversi.** Cercare una parola
  e chiedere chi cita un documento sono domande diverse, e la seconda ha già
  una risposta scritta e provata dentro l'applicazione.
* **`replace` cerca e sostituisce, non riscrive.** Il motore deve dire
  *cosa* sta cambiando; se il testo da trovare non c'è, la chiamata
  fallisce. È la differenza fra una modifica che si può raccontare e una che
  si può solo subire.

## 4. Cosa mostra l'applicazione

Il server gira anche senza di lei, ma l'applicazione è il posto dove si
guarda cosa è successo:

* un pannello **Impostazioni ▸ Agenti** con: le radici dichiarate, il
  livello di scrittura, e **la riga da incollare** nella configurazione del
  client;
* le ultime chiamate, lette dal diario, con l'ora e il file;
* un interruttore che spegne tutto — perché una funzione che si può
  spegnere si può anche accendere senza paura.

## 5. Come si prova

Il protocollo è JSON su stdio: si prova **senza rete e senza motore**.

* **Prove unitarie** sulle funzioni pure: il perimetro (dentro, fuori, `..`,
  link simbolico che esce, estensione non ammessa, file troppo grande), la
  costruzione delle risposte, il taglio di una lettura lunga.
* **Un banco**, come `selection_probe` e `quicklook_page`: gli si dà una
  cartella di prova e una sequenza di chiamate scritte in JSON, e stampa le
  risposte. Le prove della suite di controllo diventano allora confronti di
  testo, leggibili da chiunque.
* **Nella suite**: il server parte, dichiara i suoi strumenti, legge un file
  della cartella di prova, **rifiuta** un percorso fuori radice, e **rifiuta
  una scrittura** quando è partito in sola lettura. Sono i quattro casi in
  cui un errore costerebbe caro.

## 6. In che ordine

| Fase | Cosa | Perché prima |
|---|---|---|
| 1 | `search`, `read`, `list`, `outline` in sola lettura, più il perimetro e il diario | è già utile da sola, e non può rompere niente |
| 2 | `backlinks`, `frontmatter`, `find_by_field` | riusa codice provato; è la parte che rende una cartella navigabile |
| 3 | `append`, `create`, `replace` e i tre livelli | la scrittura si apre solo dopo che la lettura è in uso da un po' |
| 4 | il pannello nelle impostazioni | quando c'è qualcosa da mostrare |

La fase 1 è quella che decide: se il perimetro è giusto lì, le altre sono
lavoro; se è sbagliato, le altre sono un problema.

## 7. Le domande ancora aperte

1. **Una radice o più d'una?** Più d'una è comoda e raddoppia i modi di
   sbagliare un percorso. Propendo per più d'una, con il controllo fatto in
   un posto solo.
2. **`.textbundle`: un file o una cartella?** Per il server dovrebbe essere
   un documento solo — si legge il testo che ha dentro — ma `list` dovrebbe
   mostrarlo come un oggetto, non come tre.
3. **La ricerca su cartelle grandi**: un `grep` in Objective-C su diecimila
   file è lento. Prima misurare su una cartella vera, poi decidere se serve
   un indice — e un indice è uno stato da tenere giusto, che è esattamente
   quello che questa roadmap evita quando può.
4. **Chi apre i file quando l'applicazione non c'è**: `open_in_macdown`
   dovrebbe avviarla o rispondere di no? Rispondere di no, credo: un server
   che apre finestre da solo sorprende.

---

*Quando la fase 1 sarà scritta, questo file diventa un diario come gli
altri, con dentro i numeri veri invece delle intenzioni.*
