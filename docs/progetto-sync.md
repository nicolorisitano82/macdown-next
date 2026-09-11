# Progetto: la sincronizzazione

Progetto, non diario: qui non c'è ancora codice. Serve a decidere **prima di
scrivere** quale delle tre strade — un provider (iCloud, Dropbox, Google
Drive, OneDrive), le loro API, oppure git — è la cosa da fare, e quale parte
del lavoro è davvero nostra.

> La domanda non è «come copiamo i file su un altro Mac»: quello lo fa già
> qualcun altro, meglio di noi. La domanda è **cosa deve fare l'editor
> quando i file sotto di lui si muovono da soli.**

---

## 1. Quello che c'è già

Tre cose, fatte, che cambiano la risposta:

* **Un file che cambia sotto il documento è già gestito** (v0.32.0): se sul
  disco cambia e in mano non hai niente di non salvato, l'editor ricarica
  tenendo il cursore dov'era; se hai modifiche, chiede una volta sola; se il
  file sparisce, lo dice col percorso. Un file che si legge vuoto non conta
  come cambiato. È scritto in [dove finisce il lavoro](salvataggi.md).
* **Le versioni di macOS** sono già in uso: prima di riscrivere un file
  cambiato sotto, l'editor ne tiene una versione, e Archivio ▸ Torna a ▸
  Sfoglia tutte le versioni le mostra.
* **Il formato è già un file**, non un database: Markdown, con le immagini
  accanto o dentro un `.textbundle`. Non c'è niente da esportare per
  sincronizzare.

Quindi non partiamo da zero: partiamo da un editor che **già sa accorgersi**
che il mondo sotto di lui si è mosso. Sincronizzare, qui, vuol dire due cose
diverse a seconda della strada: *far arrivare i byte* (provider) oppure
*tenere una storia* (git).

## 2. Le tre strade, e cosa sono davvero

### A. La cartella dentro un provider — *far arrivare i byte*

Metti gli appunti in `~/Library/CloudStorage/Dropbox`, in iCloud Drive o in
Google Drive, e la copia la fa il sistema. Non scriviamo una riga per
copiare niente. Ma il provider introduce quattro situazioni che oggi
l'editor **non conosce**.

**Un fatto misurato che semplifica tutto**: su macOS moderno Dropbox, Google
Drive e OneDrive non sono più cartelle magiche, sono **File Provider**, e
rispondono alle stesse chiavi di iCloud. Su questo Mac, un file dentro
`~/Library/CloudStorage/OneDrive-…`:

```
NSURLIsUbiquitousItemKey                  1
NSURLUbiquitousItemDownloadingStatusKey   …StatusCurrent
NSURLUbiquitousItemIsUploadedKey          0
```

e uno dentro iCloud Drive risponde le stesse cose. **Una sola API per tutti
e quattro**: niente SDK, niente codice per provider.

Le quattro situazioni:

| Situazione | Cosa succede oggi | Cosa dovrebbe succedere |
|---|---|---|
| File **non ancora scaricato** (segnaposto) | misurato: `NotDownloaded`, e `NSURLFileSizeKey` è **nullo** — si apre un documento vuoto o un errore secco | dire «lo sto scaricando», chiederlo con `startDownloadingUbiquitousItemAtURL:`, aprirlo quando arriva |
| File **in salita** dopo un salvataggio | niente | un segno piccolo nella barra: «non ancora caricato» |
| **Copia in conflitto** creata dal provider (`nota (copia in conflitto di Mac di Tizio).md`) | compare un file nella cartella e nessuno lo dice | accorgersene, dirlo, e offrire il confronto con l'originale |
| Cartella intera **non locale** | la ricerca e i backlink non vedono i documenti che non sono scesi | dirlo, invece di rispondere «zero» come se fosse un dato |

Costo: piccolo. Guadagno: alto. E non è «un sistema di sincronizzazione»: è
**comportarsi bene dentro quello che l'utente ha già installato**, che è la
cosa che manca adesso.

### B. Le API dei provider — *far arrivare i byte da soli*

Parlare noi con Dropbox e con Google Drive: OAuth, token da custodire e
rinnovare, quote, limiti di frequenza, e due modelli di file diversi dal
nostro (Drive non ha percorsi ma identificatori, e due file nella stessa
cartella possono chiamarsi uguale). Ogni provider è un pezzo di codice
diverso, con una sua manutenzione e una sua scadenza.

Serve a una sola persona: quella che **non** ha il client desktop
installato. E costa più di tutto il resto di questo progetto messo insieme.

**Proposta: no.** Se un giorno servirà, servirà per un motivo che oggi non
esiste.

### C. Git — *tenere una storia*

Git non è la stessa cosa messa in un altro modo: è un'altra cosa. Dà quello
che nessun provider dà — **cosa è cambiato, quando, e perché**, la
possibilità di tornare indietro a un giorno preciso, e un posto in cui i due
lati si incontrano invece di sovrascriversi. Funziona con GitHub, con
GitLab, con un Mac in ufficio, con una chiavetta.

Misurato, con due cloni locali e nessuna rete:

```
$ git pull
CONFLITTO (contenuto): conflitto di merge in note.md

# Appunti
- primo
<<<<<<< HEAD
- dal portatile
=======
- dal fisso
>>>>>>> 080d8d9
```

Questo, in un editor di appunti, è **inaccettabile**: nessuno vuole vedere
`<<<<<<<` dentro una nota. Ma git ha già la risposta, e l'ho misurata: una
riga in `.gitattributes`,

```
*.md merge=union
```

e lo stesso conflitto diventa

```
# Appunti
- primo
- dal portatile
- dal fisso
```

Le due versioni si uniscono, in ordine, senza marcatori. È **giusto per
appunti che crescono** (elenchi, verbali, diari) e **sbagliato per una
riscrittura** (lo stesso paragrafo riscritto due volte compare due volte).
Va proposto, non imposto, e detto con parole chiare.

Tre cose misurate che riguardano il come:

* **L'applicazione non è in sandbox** (il bundle non porta entitlement: solo
  l'estensione dell'anteprima ne ha). Può quindi eseguire `/usr/bin/git`
  senza acrobazie. Con `xcode-select -p` che punta ai Command Line Tools,
  `git` è la versione di sistema (qui 2.54.0).
* **Le credenziali le sa già git**: `git-credential-osxkeychain` è dentro i
  Command Line Tools, e le chiavi SSH stanno nell'agente. **Non dobbiamo
  custodire niente**, ed è la parte migliore della strada C.
* **Ma la configurazione dell'utente non è neutra.** Su questo Mac il
  `credential.helper` globale è un helper di AWS CodeCommit. Eseguire `git`
  ereditando l'ambiente dell'utente significa ereditare helper, alias, hook
  e firme dei commit. Va eseguito con un ambiente dichiarato, e va detto in
  chiaro nel pannello **quale** git stiamo usando.

Il rischio vero della strada C non è tecnico, è di ritmo: **l'autosave**. Un
commit a ogni salvataggio automatico produce una storia illeggibile («2 026
commit “aggiornamento”»); nessun commit produce un lavoro che non è da
nessuna parte. La scelta di quando si committa *è* il progetto, non un
dettaglio.

## 3. Cosa propongo

**A e C, in quest'ordine. B no.**

Non sono alternative: A è il pavimento — vale anche per chi non userà mai
git — e C è la funzione vera, per chi vuole una storia. Una cartella può
essere entrambe le cose (un repository dentro Dropbox funziona, con
l'avvertenza di sotto).

| Fase | Cosa | Perché in questo ordine |
|---|---|---|
| 1 | **Vivere bene in una cartella sincronizzata**: stato del file, scarico su richiesta, attesa dichiarata, copie in conflitto viste | vale per tutti e quattro i provider, non può rompere niente, e serve anche a chi poi userà git |
| 2 | **Git a comando**: pannello con stato, «porta giù», «porta su», storia del documento | è la funzione; a comando prima che automatica, perché un automatismo che sbaglia lo scopri dopo |
| 3 | **Git da solo**: porta giù all'apertura, porta su dopo N minuti di quiete, messaggi di commit scritti da noi | solo quando il comportamento a comando è in uso da un po' |
| 4 | **Il conflitto nell'editor**: due colonne, tieni questo / tieni quello / tieni entrambi | quando ci sarà qualcosa da mostrare, e non prima |

### Fase 1, in dettaglio

* Una **striscia nella barra del documento** quando il file è dentro un
  provider: scaricato / in arrivo / non locale / in salita. Quattro stati,
  una riga, nessuna finestra.
* Aprire un documento non locale **chiede il download** e lo aspetta
  dicendolo, invece di aprire un documento vuoto.
* Le funzioni che leggono l'intera cartella — ricerca, backlink, l'indice
  del server MCP — **contano quello che non hanno potuto leggere** e lo
  dicono: «12 documenti non sono ancora scesi» è un'informazione, «0
  risultati» è una bugia.
* Una **copia in conflitto** che compare accanto a un documento aperto viene
  notata (siamo già `NSFilePresenter` sulla cartella) e proposta: apri,
  confronta, unisci a mano, butta.

### Fase 2, in dettaglio

* **Nessuna libreria**: si esegue `git`, con un ambiente dichiarato. Una
  libreria (libgit2) vorrebbe dire reimplementare credenziali, hook e
  configurazione che git già fa bene.
* Il pannello mostra: il ramo, quante modifiche non portate su, quante non
  portate giù, e **l'ultimo errore per esteso** — un `git push` che fallisce
  per un token scaduto deve dirlo con le parole di git.
* Tre azioni, e basta: **Porta giù** (`pull --no-rebase`), **Porta su**
  (`add -A`, `commit`, `push`), **Mostra la storia di questo documento**
  (`log --follow`, con le date e i messaggi).
* Al primo uso, propone di scrivere `.gitattributes` con `*.md merge=union`
  e `.gitignore` con `.DS_Store`, spiegando in due righe cosa cambia.
* Un conflitto che resta conflitto **non si tocca**: il pannello lo dice e
  offre di aprire il file com'è. Meglio i marcatori visti che un merge
  inventato da noi.

## 4. Il perimetro — cosa non faremo

Come per il server MCP, la parte che conta è quella che diciamo di no.

* **Niente `push --force`**, niente `reset --hard`, niente `rebase`
  automatico. Sono i tre comandi con cui si perde lavoro.
* **Niente cancellazioni fatte da noi.** Se un file sparisce da una parte,
  la sparizione la porta git; noi non cancelliamo niente per conto nostro.
* **Niente credenziali nostre**: le chiede git, le tiene il portachiavi. Non
  memorizziamo token, non mostriamo password, non le scriviamo nel diario.
* **Niente merge di testo inventato da noi** oltre a quello che git sa già
  fare: union se l'utente lo vuole, marcatori altrimenti.
* **Una cartella dichiarata**, come per il server MCP: non «tutta la home».
* **Un repository dentro un provider si può fare, ma si avvisa**: due
  sincronizzazioni sullo stesso `.git` (Dropbox che copia mentre git scrive)
  è il modo classico di rovinare un repository. La regola sana è *o l'una o
  l'altro*, e il pannello lo dirà quando si accorge di essere in entrambi.

## 5. Come si prova

Tutto **senza rete**, che è il motivo per cui questo progetto è provabile.

* **Git**: un `git init --bare` in una cartella temporanea fa da server, due
  cloni fanno da due Mac. È esattamente il banco con cui ho misurato il
  conflitto e l'unione qui sopra: conflitto vero, unione vera, in mezzo
  secondo. Prove unitarie sulle funzioni pure (leggere `git status --porcelain`,
  costruire un messaggio di commit), controlli nella suite sul comportamento
  (porta su, porta giù, conflitto, errore).
* **Provider**: le funzioni pure prendono *uno stato* e rispondono *cosa
  mostrare* — nessuna rete, nessun provider installato. Per il resto,
  `NSURLUbiquitousItemDownloadingStatusKey` è leggibile su questo Mac e
  restituisce già oggi sia `Current` sia `NotDownloaded`, che sono i due
  casi che contano.
* **La cosa che non si prova da sola**: due Mac veri che si scambiano lo
  stesso documento. Quella resta una prova a mano, scritta nel diario con
  cosa si è visto.

## 6. Le domande da decidere prima

1. **Git dentro l'app o accanto?** Propendo per *accanto*: eseguiamo `git`,
   non lo reimplementiamo, e il pannello dice quale git sta usando.
2. **Commit a comando o a tempo?** Propendo per *a comando* in fase 2, e a
   tempo (dopo N minuti di quiete, mai durante la scrittura) in fase 3, con
   l'interruttore.
3. **`merge=union` di serie per i `.md`?** Propendo per *proposto al primo
   uso*, non imposto: è giusto per gli elenchi e sbagliato per la prosa
   riscritta.
4. **Una cartella o più?** Propendo per *una*, come per il server MCP: una
   radice sola è una frase sola da capire.
5. **Cosa fa un agente MCP con `--write` dentro una cartella git?** Le sue
   scritture diventano commit come le altre; ma vale la pena che il
   messaggio dica che le ha fatte un agente. Da decidere insieme alla
   fase 2.

---

*Quando la fase 1 sarà scritta, questo file diventa un diario come gli
altri, con dentro i numeri veri invece delle intenzioni.*
