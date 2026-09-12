# Progetto: parlare ai servizi, senza le loro applicazioni

Il [progetto della sincronizzazione](progetto-sync.md) aveva scartato questa
strada — «le API dei provider» — con una frase sola: *serve a una sola
persona, quella che non ha il client desktop installato, e costa più di
tutto il resto messo insieme*.

**È stata chiesta lo stesso, e questo documento la prende sul serio.** La
richiesta è chiara e ha un senso preciso: non dipendere da quello che
qualcun altro ha installato sul Mac. Quello che segue è cosa comporta
davvero, verificato sulle documentazioni ufficiali e non a memoria, e come
la farei.

Il mio dubbio resta scritto in fondo, una volta, e poi si va avanti.

---

## 1. Cosa cambia, in una riga

| | La cartella (strada A) | Le API (questa) |
|---|---|---|
| Chi copia i byte | il client del provider | **noi** |
| Se un file si perde | è un problema loro | **è un problema nostro** |
| Serve il client installato | sì | **no** |
| Funziona con iCloud | sì | **no, e non c'è modo** |
| Codice per provider | zero | uno per servizio, con la sua scadenza |

La riga che conta è la seconda. Finché il provider copia, noi ci comportiamo
bene dentro una cartella; da qui in poi la responsabilità di non perdere il
lavoro di qualcuno è nostra.

## 2. Servizio per servizio, verificato

### Dropbox — praticabile

* **PKCE** è supportato esplicitamente per «applicazioni desktop e mobili
  senza un server, che dovrebbero mettere il segreto dentro il binario».
  Niente segreto da nascondere in un'app che chiunque può aprire.
* I token di accesso sono **brevi**; per restare collegati serve un
  **refresh token**, che si chiede aggiungendo `token_access_type=offline`
  all'indirizzo di autorizzazione.
* Due livelli di permesso: **cartella dell'app** — una cartella dentro
  `Apps/` che è solo nostra — oppure **Dropbox intero**. La regola scritta
  nella loro guida è di chiedere «il permesso meno potente possibile».
* Fino a **50 utenti collegati** si resta in sviluppo; superati, ci sono
  **due settimane** per ottenere l'approvazione di produzione o il
  collegamento di nuovi utenti si ferma. Dopo l'approvazione il **nome
  dell'app non si può più cambiare**.

### Google Drive — il muro, e va conosciuto prima di cominciare

Gli ambiti di Drive sono classificati, e la classificazione decide tutto:

| Ambito | Classe | Cosa dà |
|---|---|---|
| `drive.file` | **non sensibile** | solo i file che l'app **crea**, o che l'utente le apre/condivide espressamente |
| `drive.appdata` | non sensibile | una cartella nascosta di configurazione dell'app |
| `drive.readonly` | **restricted** | vedere e scaricare **tutti** i file |
| `drive.metadata.readonly` | **restricted** | perfino i soli metadati di tutti i file |
| `drive` | **restricted** | tutto |

«Leggere la cartella dei miei appunti» è, in questa tabella, **restricted**.
Anche solo elencarla lo è.

Cosa vuol dire *restricted*, dalla documentazione di Google:

* verifica dell'app prima della pubblicazione: schermata di consenso col
  nome giusto, **video dimostrativo**, informativa sulla privacy che dica
  come si usano i dati, e il «tipo di applicazione permesso» — le
  applicazioni di **backup e sincronizzazione** sono uno dei tipi ammessi,
  quindi questa lo sarebbe;
* **ricertificazione ogni dodici mesi**;
* la **valutazione di sicurezza CASA** serve a ogni app che «ha la
  possibilità di accedere ai dati da o attraverso un server di terze
  parti». Un'applicazione che parla da dentro il Mac dell'utente e non ha
  nessun server **non ci rientra**, ed è l'unica ragione per cui questa
  strada non costa da sola fra i 500 e i 4.500 dollari l'anno, che è la
  forbice che gli assessor chiedono.

E una riga che chiude il discorso sull'alternativa comoda: il **Picker** di
Google — la finestra in cui l'utente sceglie i file da dare all'app — per le
applicazioni **desktop** è rigido: *«solo `drive.file` è permesso, e non si
può combinare con altri ambiti»*.

**Conseguenza di progetto**: su Drive ci sono due mondi e nessuna via di
mezzo.

1. **Dentro `drive.file`**: l'app lavora in una cartella **che ha creato
   lei** (per esempio `MacDown Next/`), e lì dentro vede tutto. Nessuna
   verifica, nessun video, nessuna scadenza annuale. Ma non può leggere gli
   appunti che stanno già altrove nel Drive di qualcuno: quelli vanno
   spostati là dentro una volta.
2. **Con `drive.readonly` o `drive`**: si legge dove si vuole, e si entra
   nella verifica restricted con la sua ricertificazione annuale.

### OneDrive / Microsoft Graph — plausibile, non verificato qui

La forma è la stessa (registrazione dell'app, consenso delegato, token che
si rinnovano), e non ho controllato i dettagli con la stessa cura degli
altri due: va fatto prima di scriverne una riga, non dopo.

### iCloud Drive — non si può, e non è una questione di volontà

Non esiste un'API pubblica con cui un'applicazione di terze parti legge i
file di iCloud Drive di una persona. CloudKit è un'altra cosa — il database
di un'app, non i documenti dell'utente — e vorrebbe un'applicazione
**firmata** con i suoi entitlement, mentre questa non è firmata da nessuno.

Quindi: **per iCloud la strada A resta l'unica**, e questo da solo dice che
le due strade convivono invece di sostituirsi.

## 3. La parte che non è HTTP, ed è quella vera

Le chiamate sono la settimana facile. Quello che c'è sotto:

* **Un motore di sincronizzazione.** Uno stato locale che ricorda cosa
  c'era, cosa è cambiato di qua, cosa di là, e cosa fare quando è cambiato
  da tutte e due le parti. È il pezzo che i provider hanno scritto in anni.
* **Il delta, non il giro completo.** Drive dà `changes.list` con un gettone
  di partenza; Dropbox dà `list_folder/continue` e un `longpoll` che aspetta
  senza consumare. Rifare l'elenco della cartella ogni volta è il modo per
  farsi limitare dal servizio dopo due giorni.
* **Drive non ha percorsi, ha identificatori**, e nella stessa cartella due
  file possono chiamarsi uguale. Il nostro mondo è fatto di percorsi: la
  traduzione fra i due è una tabella, e va tenuta.
* **I conflitti li facciamo noi.** Nessuno lascerà più accanto al file una
  «copia in conflitto»: se due Mac scrivono, decidiamo noi, e la decisione
  sbagliata perde il lavoro di qualcuno.
* **I token stanno nel portachiavi**, non in un file di preferenze, non nel
  diario, non nei log. E si revocano da un pulsante.
* **Le riprese**: rete che cade a metà, token scaduto durante un caricamento,
  file cambiato mentre saliva. Ogni operazione va pensata come ripetibile.

## 4. Scrivere, e non poter perdere niente

La prima stesura di questo documento metteva tre fasi in **sola lettura**, e
la domanda giusta è arrivata subito: perché?

**Non per i permessi.** Scrivere non costa un ambito in più: `drive.file` è
letteralmente *«crea nuovi file, o modifica quelli che apri con l'app»*, e
la cartella dell'app di Dropbox è lettura **e** scrittura. Sul piano
dell'autorizzazione, leggere e scrivere sono la stessa richiesta.

Era per il rischio: l'unico modo di perdere il lavoro di qualcuno è
scriverci sopra. Ma «prima leggiamo, poi vedremo» rimanda il problema invece
di risolverlo — e il problema ha una soluzione che si può scrivere subito,
perché **entrambi i servizi tengono le versioni**.

Quattro regole, e la scrittura entra dalla prima fase.

**1. Non si sovrascrive mai alla cieca.** Ogni caricamento porta con sé la
versione da cui si è partiti.

* **Dropbox** lo fa da solo (e questo, nell'ordine scelto, arriva dopo): `WriteMode` con `update:<rev>` — la
  documentazione dice che la modalità di scrittura *«determina cosa
  costituisce un conflitto e quale sia la strategia di rinomina»*. Con
  `autorename`, una scrittura partita da una versione vecchia **non
  sovrascrive**: atterra accanto, rinominata.
* **Google Drive non ha la stessa cosa**: `files.update` non ha una
  precondizione documentata. C'è però `headRevisionId`, *«la versione più
  recente del file»*. Quindi la si legge subito prima di caricare e, se si è
  mossa, **la copia in conflitto la creiamo noi** invece di scrivere sopra.
  L'asimmetria va scritta nel codice, non scoperta dopo.

**2. Niente si cancella.** In nessuna fase, per nessun motivo, nemmeno
quando il file «non serve più». Un file di troppo si butta a mano; uno
cancellato per conto nostro non torna.

**3. Quello che si sta per sovrascrivere si può guardare prima.** Il
pannello di confronto c'è già dalla 0.34: quando i due lati non partono
dalla stessa versione, si aprono affiancati e si decide, invece di
scegliere noi.

**4. Si può sempre tornare indietro.** Dropbox tiene le revisioni
(`rev:015a…`, che servono *«per il controllo di versione, per ripristinare
file cancellati e per gestire le copie in conflitto»*), Drive tiene
`revisions`. Se sbagliamo, la versione di prima è ancora là — e il pannello
la sa mostrare.

Con queste quattro, scrivere non è più il pezzo pericoloso: è il pezzo che
chiede di essere fatto per bene.

## 5. L'ordine: prima Google Drive

È stato chiesto di cominciare da Drive, e va detto cosa comporta, perché
Drive è **il più difficile dei due** e diventa la prima fase.

| | Dropbox | Google Drive |
|---|---|---|
| Come si nomina un file | per **percorso**, come da noi | per **identificatore**: due file possono chiamarsi uguale nella stessa cartella |
| Scrittura partita da una versione vecchia | **la rifiuta il servizio** (`update:<rev>`) | nessuna precondizione: **la fermiamo noi**, leggendo `headRevisionId` |
| Cosa si può vedere col permesso stretto | tutta la cartella dell'app | i file che l'app crea, **e quelli che l'utente le dà** |

Cominciare da Drive vuol dire prendere i due problemi di progetto più duri
per primi — gli identificatori e il conflitto fatto in casa — e trovarseli
già risolti quando arriva Dropbox, che a quel punto è la metà del lavoro.
È un ordine difendibile, purché si sappia che la prima fase è la più cara
delle due, non la più economica.

### La domanda che decide la forma di B1, e non è documentata

Sul desktop il **Picker** — la finestra in cui si scelgono i file da dare
all'app — funziona così, per documentazione: si apre **in una scheda del
browser predefinito**, l'utente sceglie, e torna all'applicazione con un
indirizzo di richiamo. Esiste il parametro `allow_folder_selection=true` che
«permette all'utente di selezionare anche cartelle».

Quello che la documentazione **non dice** è se scegliere una cartella, con
il solo `drive.file`, dia accesso anche ai file che ci sono dentro, o solo
alla cartella. Da questo dipende tutto:

* **se dà accesso al contenuto**: «collega Google Drive» diventa *scegli la
  cartella dei tuoi appunti*, e funziona con gli appunti che esistono già.
  È la versione che la gente si aspetta;
* **se non lo dà**: l'app può lavorare solo in una cartella **creata da
  lei** — `MacDown Next/` — e chi ha già gli appunti nel Drive li sposta
  là dentro una volta sola. Funziona, ma va detto in chiaro al primo
  collegamento.

**Va misurato prima di scrivere B1**, come è stato fatto per M0: un client
OAuth, il Picker, una cartella scelta, e una chiamata `files.list` per
vedere cosa risponde. È mezza giornata, e decide il resto.

## 5-bis. Le fasi

| Fase | Cosa | Perché qui |
|---|---|---|
| **B0** | **La misura**: client OAuth, Picker sul desktop, e la risposta alla domanda qui sopra. Nessun codice dell'applicazione | decide se B1 è «scegli la tua cartella» o «una cartella nostra» |
| **B1** | **Google Drive, `drive.file`, lettura e scrittura.** PKCE con richiamo su `127.0.0.1`, token nel portachiavi, elenco, scarico, e salvataggio con `headRevisionId` letto subito prima: se si è mosso, la copia in conflitto la facciamo noi | è il servizio chiesto per primo, ed è quello che insegna il modello più difficile |
| **B2** | **Il delta e lo stato**: `changes.list` con il gettone di partenza, la tabella identificatore ↔ percorso, e cosa fare quando un file cambia nome di là | è la parte che rende la cosa una sincronizzazione invece di un carica-e-scarica |
| **B3** | **Dropbox, cartella dell'app, lettura e scrittura**: PKCE, `update:<rev>` con `autorename`, `longpoll` + `continue` | con il motore già scritto, qui si aggiunge un servizio, non un sistema |
| **B4** | **Il conflitto nell'editor**: due colonne, tieni questo / tieni quello / tieni entrambi, sul pannello che già confronta | quando ci sono conflitti veri da mostrare, e non prima |
| **B5** | *Eventuale*: la **verifica restricted** di Google, se leggere e scrivere in una cartella qualunque del Drive è ciò che si vuole davvero | un video, un'informativa, e una scadenza ogni dodici mesi |
| **A** | La strada della cartella **resta**, per iCloud e per chi il client ce l'ha | non è un ripiego: è l'unica cosa che funziona con iCloud |

## 6. Il perimetro

Come per il server MCP, la parte che conta è quella che diciamo di no.

* **Una cartella dichiarata per servizio**, non «tutto il Drive», nemmeno
  quando l'ambito lo permetterebbe.
* **Si scrive solo dove si è stati messi**: la cartella dichiarata, e solo
  quella. Un salvataggio non inventa mai una cartella nuova da qualche altra
  parte.
* **Nessuna scrittura parte da una versione che non è più quella**: o la
  rifiuta il servizio (Dropbox), o la fermiamo noi (Drive).
* **Niente cancellazioni** per conto nostro, in nessuna fase.
* **Niente server nostri.** Non è solo una scelta di stile: è la ragione per
  cui la verifica di Google non chiede la valutazione di sicurezza.
* **Niente token fuori dal portachiavi**, e un pulsante che scollega.
* **Nessun dato di nessuno esce dal Mac**, se non verso il servizio che
  l'utente ha collegato lui.

## 7. Il dubbio, una volta

Questa strada mette sulle nostre spalle il pezzo che oggi fa qualcun altro
meglio di noi, e lo mette lì per sempre: tre servizi, tre modelli di file,
tre autenticazioni che scadono, e una verifica annuale se si vuole leggere
fuori dalla cartella dell'app. Il giorno in cui un token smette di
rinnovarsi o un formato cambia, la sincronizzazione si rompe per tutti, e
non c'è un client di Dropbox a cui dare la colpa.

Detto questo: la richiesta ha una ragione, e le quattro regole del capitolo
4 fanno sì che il caso peggiore sia **un file in più con un nome strano**,
non un file perduto — su Drive come su Dropbox, con la differenza che su
Drive quel nome strano lo scriviamo noi.

Si comincia da **B0**, che è mezza giornata e non è codice: senza sapere
cosa risponde il Picker quando gli si dà una cartella, B1 si scriverebbe due
volte.

---

*Le classificazioni degli ambiti di Drive, i requisiti della verifica
restricted, il PKCE e i token brevi di Dropbox, la soglia dei cinquanta
utenti, il `WriteMode` di Dropbox e `headRevisionId` di Drive sono stati
letti sulle documentazioni ufficiali il 12 settembre 2026. Microsoft Graph
no: quello è ancora da verificare.*
