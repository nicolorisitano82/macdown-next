# Roadmap: la sincronizzazione

Il *perché* sta nel [progetto](progetto-sync.md), che aveva deciso le tre
strade: vivere bene dentro un provider (**sì**), le API dei provider
(**no**), git (**sì, dopo**). Questo file è il *come* e soprattutto
**in che ordine**, scritto per essere eseguito.

> **Cambiato in corsa.** È stato chiesto di **non dipendere dalle
> applicazioni dei provider** e di parlare direttamente ai servizi. Quella
> era la strada scartata, e adesso ha un progetto suo:
> [parlare ai servizi](progetto-sync-servizi.md), con quello che comporta
> davvero — gli ambiti di Google che sono *restricted* anche solo per
> elencare una cartella, il PKCE di Dropbox, e iCloud che **non ha
> un'API** e resta raggiungibile solo dalla cartella.
>
> Le tappe qui sotto **restano**, e non per affezione: sono l'unica strada
> che funziona con iCloud, e valgono per chiunque il client ce l'abbia già.
> Cambia il loro peso — non sono più tutta la sincronizzazione, sono la
> metà che non chiede a nessuno di collegare un account. La metà nuova è
> nelle fasi **B** dell'altro documento: leggere **e scrivere** fin dalla
> prima, con quattro regole che fanno sì che il caso peggiore sia un file
> in più, non un file perduto — e si comincia da **Google Drive**, che è il
> più difficile dei due, preceduto da una misura che decide la forma della
> prima fase.

Ogni tappa dice quattro cose: **cosa si vede**, **cosa si scrive**, **come
si prova**, e **quando è finita**. Una tappa che non ha tutte e quattro non
è una tappa, è un desiderio.

---

## Prima di cominciare: quattro fatti, tre misurati

**1. Una sola API per tutti.** Dropbox, Google Drive, OneDrive e iCloud su
macOS moderno non sono cartelle magiche: sono **File Provider**, e i loro
file rispondono alle stesse chiavi di `NSURL`. Misurato su questo Mac, un
file dentro `~/Library/CloudStorage/OneDrive-…`:

```
NSURLIsUbiquitousItemKey                  1
NSURLUbiquitousItemDownloadingStatusKey   …StatusCurrent
NSURLUbiquitousItemIsUploadedKey          0
```

Niente SDK, niente OAuth, niente codice per provider.

**2. Le chiavi possono non esserci, e il nome della cartella non prova
niente.** Sempre su questo Mac ci sono **tre** cartelle chiamate
`~/Library/CloudStorage/iCloudDrive-iCloudDrive (…)` — residui di migrazioni
— e i file dentro rispondono `(niente)` a tutte e cinque le chiavi: sono
cartelle locali con un nome che sembra cloud. Regola che ne esce:
*chiave assente = non è in un provider*, non è un errore, e il percorso non
è una prova.

**3. Non possiamo chiedere al sistema l'elenco dei provider.**
`NSFileProviderManager getDomainsWithCompletionHandler:` risponde, a chi non
possiede un dominio suo: *«In questo momento non è possibile utilizzare
l'applicazione»*, e zero domini. Misurato. Quindi si va per chiavi, file per
file, e non c'è una lista da mostrare.

**4. Da verificare, non misurato qui**: su questo Mac Dropbox e Google Drive
**non sono installati**. Che rispondano le stesse chiavi è vero per
costruzione — sono File Provider come OneDrive — ma non l'ho visto con i
miei occhi. È la prima cosa da fare quando uno dei due c'è: la tappa **M0**.

### La regola che tiene insieme tutta la parte «lettura»

> **I metadati non costano, il contenuto sì.** Leggere le chiavi di un file
> non lo scarica. **Aprirlo lo scarica.** Una ricerca a tutto testo su una
> cartella di Google Drive, fatta ingenuamente, si porta giù la cartella
> intera — gigabyte, sul contatore di qualcun altro, senza che nessuno
> l'abbia chiesto.

Da qui in poi ogni funzione che legge la cartella — ricerca, backlink,
indice del server MCP, importazione — deve dire **quale delle due cose sta
facendo**. È il filo rosso di M1, M4 e M5.

---

## M0 — Verificare, provider per provider · *fatta a metà*

**Cosa si vede**: niente. È una misura.

**Cosa si scrive**: l'arnese per misurare, che adesso c'è —
[`Tools/provider_probe.m`](../Tools/provider_probe.m), un file solo, si
compila da sé:

```bash
clang -fobjc-arc -framework Foundation -o probe Tools/provider_probe.m
./probe --file ~/Percorso/documento.md            # le cinque chiavi, e in quanti ms
./probe --cartella ~/Percorso --secondi 10        # cammina e conta, senza aprire niente
```

La seconda forma **è** il banco della tappa M4: cammina chiedendo le chiavi
all'enumeratore e non apre un file.

### Quello che risponde questo Mac

| Provider | Stato | Le cinque chiavi | La camminata |
|---|---|---|---|
| **iCloud Drive** (`~/Library/Mobile Documents/com~apple~CloudDocs`) | attivo | tutte, in **16 ms** | **949 file, 22 cartelle in 1,1 s**, zero scaricati |
| **OneDrive** | installato, **non in esecuzione** | — | le sottocartelle **non si aprono**: «The file "Documenti" couldn't be opened», 0,2 s |
| `CloudStorage/iCloudDrive-… (data)` ×3 | residui di migrazione | **nessuna** | cartelle locali normali |
| **Dropbox** | **non installato** | da fare | da fare |
| **Google Drive** | **non installato** | da fare | da fare |

Un file vero di iCloud Drive, per esteso:

```
NSURLIsUbiquitousItemKey                  1
NSURLUbiquitousItemDownloadingStatusKey   …StatusCurrent
NSURLUbiquitousItemIsDownloadingKey       0
NSURLUbiquitousItemIsUploadedKey          1
NSURLUbiquitousItemIsUploadingKey         0
```

### Tre cose che non sapevamo, e che cambiano le tappe dopo

**1. Un provider che non gira non risponde «vuoto»: rifiuta, una cartella
alla volta.** OneDrive non è in esecuzione su questo Mac, e le sue
sottocartelle danno un errore *per directory* — con `ls`, prima, la
chiamata è rimasta appesa **circa venticinque secondi** e poi ha detto
«Operation timed out». Quindi una camminata ha bisogno di **tre** cose: un
gestore d'errore per cartella (che tira avanti invece di fermarsi), una
**scadenza**, e un terzo conto oltre a «scesi» e «non scesi»: **non
leggibili**. Una cartella che non si è potuta aprire non è una cartella
vuota, ed è l'errore che «0 risultati» nasconderebbe due volte.

**2. Camminare 949 file costa 1,1 secondi e non scarica niente**, se le
chiavi si chiedono all'enumeratore. La regola di M4 regge, misurata — e
«non apre niente» è controllato, non sperato: l'ora di ultimo accesso dei
file camminati non cambia.

**3. `IsUploaded` non vuol dire la stessa cosa dappertutto**: 1 sul file
iCloud misurato oggi, **0** sul file OneDrive misurato per il progetto —
e quel file era a posto. «Da caricare» non si deduce da una chiave sola:
serve anche `IsUploading`, e nel dubbio non si mostra niente.

### Quello che manca ancora

* **Dropbox e Google Drive**: nessuno dei due è installato qui. Che
  rispondano le stesse chiavi è vero per costruzione — sono File Provider
  come OneDrive — ma **non l'ho visto**, e finché non lo vedo resta scritto
  così.
* **Un file non sceso**: su questo Mac non ce n'è nemmeno uno (949 file di
  iCloud, tutti con i byte). Lo stato `NotDownloaded` è quello su cui poggia
  M3, e va guardato per davvero prima di scrivere M3 — basta un file messo
  «disponibile solo online» dal Finder.

**Quando è finita**: quando la tabella qui sopra ha cinque righe piene e una
riga in più per un file non sceso.

## M1 — Sapere dove si è (una funzione pura)

**Cosa si vede**: ancora niente.

**Cosa si scrive**: `MPCloudStatus.{h,m}` — una funzione e un tipo:

```objc
typedef NS_ENUM(NSUInteger, MPCloudState) {
    MPCloudStateLocal,        // non è in un provider, o non lo sappiamo
    MPCloudStateDownloaded,   // c'è, ed è qui
    MPCloudStateDownloading,  // sta arrivando
    MPCloudStateNotLocal,     // esiste, ma i byte non ci sono
    MPCloudStateUploading,    // salvato, non ancora partito
    MPCloudStateUnreadable,   // il provider non risponde: da M0, e succede
};
MPCloudState MPCloudStateOfURL(NSURL *url);
```

Sei stati, non cinque: l'ultimo è quello che M0 ha trovato per terra — un
client non in esecuzione rifiuta di aprire le sue cartelle. E
`IsUploaded == 0` **da solo** non basta a dire «da caricare», sempre da M0.

Dentro: `resourceValuesForKeys:` con le cinque chiavi, e la regola del
fatto 2 — assente vuol dire `Local`. Nessuna finestra, nessuna rete,
nessun download: **non tocca il contenuto**.

**Come si prova**: le chiavi sono un dizionario, quindi la parte che decide
si separa da quella che legge — `MPCloudStateFromValues(NSDictionary *)` — e
si prova con una tabella di dizionari, compresi quelli vuoti e quelli
contraddittori. Più un controllo nella suite su un file vero, che su questo
Mac risponde `Local`.

**Quando è finita**: quando i sei stati hanno una prova ciascuno e
`MPCloudStateOfURL` non apre mai un file.

## M2 — Dirlo, in una riga

**Cosa si vede**: sotto il titolo del documento, dove oggi c'è «nessuna
segnalazione», una parola in più quando il file è dentro un provider: *in
arrivo*, *non scaricato*, *da caricare*, *non leggibile*. Quando è tutto a
posto, **niente** — è la decisione 1, e vale anche per lo stato
`Downloaded`: quello non si mostra mai.

**Cosa si scrive**: la riga nel controller del documento, e un
`NSFilePresenter` che già c'è per i cambi sotto il documento — lo stato si
aggiorna lì, non con un timer.

**Come si prova**: la funzione che trasforma uno stato in una parola è pura
e si prova da sola; il resto è un controllo nella suite che apre una
finestra e legge l'etichetta, come si fa per il pannello del confronto.

**Quando è finita**: quando aprire un documento locale non mostra niente di
nuovo.

## M3 — Aprire un documento che non è sceso

Oggi: si apre **vuoto**, o con un errore secco. Misurato nel progetto:
`NSURLFileSizeKey` è nullo per un segnaposto.

**Cosa si vede**: invece del documento vuoto, un foglio che dice «questo
documento non è ancora sceso da OneDrive», una barra che si muove, e
**Annulla**. Quando arriva, si apre da solo.

**Cosa si scrive**: `startDownloadingUbiquitousItemAtURL:error:`, e
l'attesa: un `NSMetadataQuery` sul singolo file — è il modo documentato di
sapere quando è arrivato — con un tetto di tempo e un annulla che funziona
davvero.

**Come si prova**: la logica dell'attesa (cosa fare a ogni cambio di stato,
quando arrendersi) è una macchina a stati pura. Il download vero è una prova
a mano, scritta nel diario, con un file messo «solo online» apposta.

**Quando è finita**: quando aprire un file non locale non produce mai un
documento vuoto. Quello è il difetto che stiamo togliendo.

## M4 — Le funzioni che leggono tutta la cartella

È la tappa che riguarda davvero **la lettura da Google Drive e Dropbox**, ed
è la più delicata: ricerca, backlink, indice del server MCP e importazione
oggi camminano una cartella e **aprono ogni file**.

**Cosa si vede**: in fondo ai risultati, una riga onesta — *«12 documenti
non sono ancora scesi e non sono stati cercati»*, o *«3 cartelle non si sono
potute aprire: OneDrive non è in esecuzione»*, con un pulsante **Scaricali**
per il primo caso. Non «0 risultati», che è una bugia due volte.

**Cosa si scrive**:

* una passata sola che, mentre cammina, chiede a ogni file **le chiavi** e
  non il contenuto: i non-locali finiscono in un elenco a parte invece di
  essere letti. Misurato a M0: 949 file in 1,1 secondi, zero scaricati;
* `MPFolderScan`, un risultato che porta con sé **due** conti — quanti non
  sono scesi e quante cartelle **non si sono potute aprire** — e una
  scadenza, perché una cartella di un provider fermo può restare appesa
  venticinque secondi (misurato a M0). Tutte e quattro le funzioni lo usano
  invece di camminare per conto loro;
* nel **server MCP** la stessa cosa, e la sua risposta lo deve dire nel
  testo: un assistente che riceve «nessun risultato» non ha modo di sapere
  che mezza cartella era in cielo. Questo tocca `MDMCPIndex` e le sue prove
  — e per la decisione 3 il server **non scarica niente in nessun caso**,
  il che è un controllo da scrivere: `MDMCPTools` non nomina mai
  `startDownloadingUbiquitousItemAtURL:`.

**Come si prova**: una cartella finta in cui alcuni file sono dichiarati
non-locali da una funzione iniettata (non serve un provider per provare la
*regola*); più una misura vera: quanti file apre una ricerca su N documenti,
contata, prima e dopo. Deve passare da N a zero.

**Quando è finita**: quando una ricerca su una cartella sincronizzata **non
scarica niente**, e dice cosa non ha guardato.

## M5 — Le copie in conflitto

Ogni provider, quando due Mac scrivono lo stesso file, ne lascia due:
`nota (copia in conflitto di Mac di Tizio).md`, `nota-conflicted copy.md`,
`nota (1).md`. I nomi sono diversi per ognuno — è l'unica cosa per cui
serve sapere **quale** provider è.

**Cosa si vede**: quando accanto al documento aperto compare una copia in
conflitto, una riga: *«è comparsa una copia in conflitto»* con **Confronta**
— e il pannello del confronto, che c'è già dalla 0.34, si apre con i due.

**Cosa si scrive**: il riconoscimento del nome (una funzione pura, un elenco
di forme per provider, da riempire a M0), e l'aggancio al presenter che
osserva la cartella.

**Come si prova**: nomi veri in una tabella, e un controllo nella suite che
mette un file dal nome giusto accanto a un documento aperto.

**Quando è finita**: quando una copia in conflitto non passa più inosservata.

---

A questo punto **la parte provider è finita** e non abbiamo scritto una riga
di sincronizzazione: abbiamo smesso di comportarci male dentro quella che
c'è già. Le tappe che seguono sono la funzione vera, e sono un'altra cosa.

---

## M6 — Git, a comando

**Cosa si vede**: un pannello con il ramo, quante modifiche non sono andate
su, quante non sono scese, l'ultimo errore **con le parole di git**, e tre
pulsanti: **Porta giù**, **Porta su**, **Storia di questo documento**.

**Cosa si scrive**: nessuna libreria — si esegue `git`, con un ambiente
dichiarato. Un lettore di `git status --porcelain=v2`, che è un formato
pensato per essere letto da un programma; la costruzione del messaggio di
commit; e il pannello.

**Come si prova**: `git init --bare` in una cartella temporanea fa da
server, due cloni fanno da due Mac. Senza rete, mezzo secondo a prova. È già
stato fatto una volta per misurare il conflitto nel progetto.

**Quando è finita**: quando i tre pulsanti funzionano su un repository vero
e un errore di rete si legge per esteso invece di sparire.

## M7 — Git, da solo

**Cosa si vede**: la stessa cosa, senza premere niente: porta giù
all'apertura, porta su dopo N minuti di quiete — **mai mentre si scrive**.

**Cosa si scrive**: un temporizzatore che guarda l'ultima battitura, non
l'orologio, e l'interruttore per spegnerlo.

**Quando è finita**: dopo che M6 è in uso da un po'. Un automatismo che
sbaglia lo si scopre dopo, e questa è la ragione per cui non è la prima
tappa.

## M8 — Il conflitto nell'editor

**Cosa si vede**: due colonne, *tieni questo / tieni quello / tieni
entrambi*, sul pannello che già confronta due documenti.

**Quando è finita**: quando c'è qualcosa da mostrare, e non prima.

---

## Cosa non faremo (dal progetto, e vale qui)

* Niente `push --force`, `reset --hard`, `rebase` automatico.
* Niente cancellazioni fatte da noi.
* Niente credenziali nostre: le chiede git, le tiene il portachiavi.
* Niente merge inventato da noi.
* Una cartella dichiarata, non tutta la home.
* Un repository dentro un provider si può fare, ma **si avvisa**: Dropbox
  che copia mentre git scrive dentro `.git` è il modo classico di rovinare
  un repository.
* **Niente download che non abbia un gesto dietro** (decisione 2), e
  **niente download dal server MCP, mai** (decisione 3).

## L'ordine, in una riga

**M0 → M1 → M2 → M3 → M4 → M5** è la parte che riguarda le cartelle dei
provider, si può fermare in qualsiasi punto e ogni tappa da sola migliora
qualcosa. **M6 → M7 → M8** è git. **B1 → B5**, nell'[altro
documento](progetto-sync-servizi.md), è parlare ai servizi senza le loro
applicazioni.

M1 e B1 non si ostacolano: la prima è una funzione che guarda un file, la
seconda è un collegamento a Dropbox in sola lettura. Si possono fare in
qualunque ordine, e M4 — contare quello che non si è potuto leggere — serve
a tutte e due.

Se si dovesse fare **una cosa sola**, è **M4**: è l'unica dove oggi
l'applicazione può fare un danno vero — scaricare gigabyte che nessuno ha
chiesto — e l'unica dove oggi dice una cosa falsa, «nessun risultato», di
una cartella che semplicemente non ha guardato.

## Cosa è stato deciso

Tre risposte, e valgono da qui in avanti. Non sono preferenze da mettere in
un pannello: sono il modo in cui questa parte si comporta.

**1. Lo stato si mostra solo quando è interessante.** Quando il documento è
qui ed è caricato, la barra non dice niente. Un'applicazione che ripete
«sincronizzato» sta occupando spazio per dire che non è successo niente.

**2. Non si scarica mai da soli.** Una ricerca che incontra documenti non
scesi li **conta e lo dice**; scaricarli è un pulsante che preme chi legge.

> La riga di confine, perché le due cose sembrano contraddirsi: **aprire un
> documento lo si è chiesto** — M3 scarica *quel* file perché è esattamente
> quello che l'utente ha appena domandato. **Camminare una cartella non lo
> si è chiesto**: lì non parte niente. Il discrimine è se c'è un gesto
> dietro, non se il codice è nostro.

**3. Il server MCP non scarica, mai.** «Per ora», ed è la formula giusta:
è un processo senza finestre che parla con un assistente, e nessuno sarebbe
lì a vedere partire dieci giga. Dice quanti documenti non ha potuto
guardare e perché — non scesi, oppure cartella che non si apre — e si ferma
lì. Niente interruttore per accenderlo: un'opzione che permette a un
programma esterno di far scaricare una cartella intera è un'opzione che
prima o poi qualcuno lascia accesa.

Conseguenze immediate, da portarsi dentro M4: la risposta del server dice i
due conti **nel testo**, perché un assistente che riceve «nessun risultato»
non ha modo di sapere che mezza cartella era in cielo; e `MDMCPTools` non
chiama mai `startDownloadingUbiquitousItemAtURL:`, il che è una riga di
prova nella sua suite, non un'intenzione.

## Cosa resta da decidere

1. **M0 quando si chiude?** Fatta a metà: iCloud misurato, OneDrive
   caratterizzato mentre **non** gira — che si è rivelato il caso più
   istruttivo — Dropbox e Drive ancora da guardare, e un file non sceso
   pure. M1 si può scrivere comunque; M3 e M5 aspettano il resto della
   tabella.

---

*Questa è una roadmap, non un diario: ogni tappa che si scrive porta qui i
suoi numeri veri, e quando ci saranno tutti questo file diventerà il diario
della sincronizzazione.*
