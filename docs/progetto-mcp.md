# Progetto: un server MCP sulla cartella

Progetto e, da oggi, diario: le **fasi 1 e 2 sono scritte** — il perimetro,
l'indice, i quattro strumenti di lettura e i tre che leggono la cartella
come un insieme di note — e il binario viaggia dentro l'applicazione. Le
sezioni da 1 a 6 restano il progetto com'era; la 7 dice cosa è stato deciso,
la 8 com'è andata la fase 1 e la 9 la fase 2, con i numeri.

Viene da due studi già scritti — la [strada C dello studio su Claude e
GPT](studio-claude-gpt.md) e la [fase 3 della roadmap](roadmap-bear.md) — e
serviva a decidere **prima di scrivere** la sola cosa che conta davvero:

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
duecento righe. (In fase 1 il server sta per conto suo: i pezzi condivisi
arrivano con la fase 2, che è quella che ne ha bisogno.)

## 2. Il perimetro

Questa è la parte del progetto che va letta due volte.

### La radice si dichiara, non si indovina

```
macdownext-mcp --root ~/Verbali
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

## 7. Le domande, e come sono state decise

1. **Una radice o più d'una?** → **una sola.** Il progetto propendeva per
   più d'una; la decisione è stata la più stretta. Una seconda `--root` non
   viene ignorata: è un errore, e il server non parte. Una cartella sola è
   una frase sola da leggere nella configurazione del client, ed è l'unica
   cosa che chi la scrive deve capire per sapere cosa sta dando in mano.
2. **`.textbundle`: un file o una cartella?** → **un file.** Il perimetro lo
   conta come un documento solo, non ci cammina dentro, e `read` gli chiede
   il suo `text.markdown`. `list` lo mostra come un oggetto, come fa il
   Finder.
3. **Serve un indice?** → **sì.** In memoria, mai su disco: nome, data e
   dimensione di ogni documento, e il testo di quelli che servono. A ogni
   chiamata l'indice guarda le date e **rilegge solo quello che è cambiato**;
   di quello che è sparito si dimentica. Niente stato da tenere giusto fra
   un avvio e l'altro, perché all'avvio non c'è niente da leggere.
4. **`open_in_macdown` avvia l'applicazione?** → **no**, e in fase 1 quello
   strumento non c'è proprio. Un server che apre finestre da solo sorprende,
   e la sorpresa è la cosa che un perimetro serve a evitare.

## 8. La fase 1, com'è andata

Cinque file, in `macdown-mcp/`, e nient'altro: nessuna libreria nuova, il
protocollo è JSON su due tubi.

| File | Righe | Cosa tiene |
|---|---|---|
| `MDMCPPerimeter.m` | 300 | dentro o fuori, testo o no, quanto pesa, cosa si salta |
| `MDMCPIndex.m` | 163 | l'indice in memoria, e cosa rileggere |
| `MDMCPTools.m` | 304 | `search`, `read`, `list`, `outline` e i loro schemi |
| `MDMCPServer.m` | 192 | `initialize`, `tools/list`, `tools/call`, `ping` |
| `main.m` | 89 | gli argomenti, e il rifiuto della seconda radice |

Il verdetto di uno strumento sta **dentro la risposta** (`isError`), non nel
codice d'errore del protocollo: «quel percorso è fuori dalla cartella» è una
cosa che il motore deve poter leggere e raccontare, non un guasto della
connessione. I codici JSON-RPC restano per i guasti veri, un metodo che non
esiste o un messaggio che non si legge.

### I numeri, misurati

Sulla cartella di questo repository — 258 documenti fra `.md` e `.txt` —
con il binario che esce dalla build:

| Chiamata | Tempo | Cosa ha letto |
|---|---|---|
| `initialize` | 15 ms | niente |
| prima `search` | 234 ms | 258 documenti |
| seconda `search` | 206 ms | **0**: l'indice era già caldo |
| `outline` di un documento | 2 ms | uno |

I 206 ms della seconda ricerca non sono lettura: sono la passeggiata nella
cartella per sapere se qualcosa è cambiato. È il prezzo di non avere stato
su disco, e a questa scala si paga volentieri.

### Come si dichiara a un client

Il binario sta dentro l'applicazione, e si passa la cartella per intero:

```bash
claude mcp add appunti -- \
    "/Applications/MacDown Next.app/Contents/SharedSupport/bin/macdownext-mcp" \
    --root ~/Verbali
```

o, per un client che legge un file di configurazione:

```json
{"mcpServers": {"appunti": {
    "command": "/Applications/MacDown Next.app/Contents/SharedSupport/bin/macdownext-mcp",
    "args": ["--root", "/Users/tizio/Verbali"]}}}
```

### Com'è provata

* **23 prove unitarie** in `MacDownTests/MDMCPTests.m`: il perimetro (dentro,
  fuori, `..`, un link simbolico che esce, estensione non ammessa, file
  troppo grande), il Textbundle contato una volta sola, i quattro strumenti,
  l'indice caldo, cambiato e con un file sparito, e il protocollo dalla
  stretta di mano al metodo che non esiste.
* **Otto prove nella suite di controllo**, che non parlano alle classi ma
  **al binario**, da un tubo, come farebbe un motore: che viaggi dentro
  l'app, che risponda alla stretta di mano, che si presenti col suo nome,
  che dichiari i quattro strumenti, che trovi una parola, che **rifiuti un
  percorso fuori radice**, che dica che *non esiste* uno strumento che
  scrive, e che il documento sul disco sia rimasto quello di prima.

### Cosa il progetto diceva e la fase 1 non fa

* **il diario `mcp.log` non c'è ancora**: in sola lettura non c'è niente da
  raccontare il giorno dopo che il file stesso non dica già; arriva con la
  scrittura, in fase 3;
* **niente `.macdownignore`**: c'è `--exclude <glob>`, e le esclusioni di
  serie (`.git`, `node_modules`, `.build`, i file che cominciano con un
  punto);
* **niente espressioni regolari** in `search`: si cerca testo;
* `backlinks`, `frontmatter`, `find_by_field` restano alla fase 2, la
  scrittura alla 3, il pannello nelle impostazioni alla 4.

## 9. La fase 2, com'è andata

Tre strumenti in più, e **nessuna riga nuova che decida cosa è una
citazione**: quella la decidono i pezzi che l'applicazione usa già.

| Strumento | Argomenti | Risposta |
|---|---|---|
| `backlinks` | `path` | chi cita quel documento: file, titolo, riga, la frase |
| `frontmatter` | `path` | i campi del front matter, come mappa |
| `find_by_field` | `field`, `value?` | i documenti che lo dichiarano, col valore |

### Il codice è lo stesso, non è un secondo

`backlinks` chiama `MPBacklinksInText`, la funzione che riempie il pannello
dei backlink nell'editor; `frontmatter` e `find_by_field` chiamano
`-[NSString frontMatter:]`, quella che l'anteprima usa per la tabella in
cima al documento. Un documento non può quindi risultare citato
nell'applicazione e non citato sul tubo: è una risposta sola, data due
volte.

Per prendere quel codice senza prendersi dietro l'applicazione intera sono
nati `MacDown/Code/Utility/MPMarkdownText.{h,m}`: le cinque funzioni di
testo senza opinioni — che riga è questa, quali pezzi sono codice, cos'è uno
spazio — che stavano in `MPUtilities` insieme alle preferenze, alle finestre
e ai bundle. `MPUtilities.h` le include, e chi le usava non se ne è accorto.

Il front matter torna da YAML come **dizionario ordinato** (l'anteprima
vuole i campi nell'ordine in cui sono scritti), che non è un `NSDictionary`:
per una risposta l'ordine non conta e i due sono la stessa cosa, quindi il
server chiede a entrambi le due domande a cui entrambi rispondono.

### I numeri, misurati

Stessa cartella di prima — 259 documenti:

| Chiamata | Tempo | Cosa ha letto |
|---|---|---|
| `backlinks` a indice freddo | 292 ms | 259 documenti |
| `backlinks` a indice caldo | 254 ms | 0 |
| `frontmatter` di un documento | 3 ms | uno |
| `find_by_field` | 220 ms | 0 |

Le tre domande sull'intera cartella costano quanto una ricerca, perché sono
la stessa passeggiata: l'indice tiene il testo, e leggere il front matter di
259 documenti già in memoria sono i quindici millisecondi che separano una
ricerca da un `find_by_field`.

### Il difetto che le prove hanno tirato fuori

La cartella di prova sta in una cartella temporanea, cioè sotto `/private`,
e **standardizzare un percorso toglie quel `/private`**: la radice diventava
`/tmp/…` mentre i file arrivavano come `/private/tmp/…`, il confronto
falliva e ogni documento in una sottocartella tornava col nome nudo,
`nota.md` invece di `sotto/nota.md`. Sotto `/Users` non si vedeva. Adesso il
percorso relativo lo calcola il perimetro — che è l'unico a sapere come ha
standardizzato la radice — e una prova lo tiene fermo.

### Com'è provata

* **30 prove unitarie** (sette nuove): chi cita e chi no — il documento non
  cita sé stesso, quello che sta fra i backtick non è una citazione, un
  collegamento scritto da una sottocartella è lo stesso file — il front
  matter come mappa e quando non c'è, `find_by_field` sul campo, sul valore
  e dentro una lista, e la sottocartella che resta nel percorso.
* **Undici prove nella suite di controllo** (tre nuove), tutte al binario:
  che dica chi cita un documento e da quale sottocartella, che legga il
  front matter come mappa, che trovi i documenti che dichiarano un campo.

### Cosa la fase 2 non fa

* **`search` non guarda il front matter come campi**: cerca testo, e il
  front matter è testo come il resto;
* `find_by_field` confronta valori **uguali**, non «contiene» e non
  intervalli: una data «dopo il primo marzo» è una domanda che non sa fare;
* niente `open_in_macdown`, niente scrittura, niente diario: fasi 3 e 4.

---

*Fase 1 e fase 2 fatte l'11 settembre 2026, versione 0.33.0. Restano la
scrittura (fase 3) e il pannello nelle impostazioni (fase 4): quando
toccherà a loro, questo file cresce di una sezione per volta, con i numeri
veri invece delle intenzioni.*
