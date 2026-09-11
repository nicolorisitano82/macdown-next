# Studio: un'icona nella barra dei menu

Studio, non progetto: qui non si scrive niente. Serve a rispondere a due
domande nell'ordine giusto — **cosa potrebbe fare** e **se vale la pena** —
prima di occupare per sempre un pezzo di schermo che non è nostro.

Nota di vocabolario, perché cambia il ragionamento: su macOS non esiste una
*tray*. Esiste la **barra dei menu**, e quello che ci si mette è un
`NSStatusItem`. La differenza non è il nome: la tray di Windows è un posto
dove le applicazioni si nascondono, la barra dei menu di macOS è una riga
sola, sempre visibile, condivisa da tutti, e ogni icona in più la accorcia
per tutti gli altri. Un'icona lì dentro va **guadagnata**.

---

## 1. La domanda giusta

Non «cosa possiamo metterci» — la risposta sarebbe «tutto» — ma:

> Cosa c'è, in questa applicazione, che **vale la pena sapere o fare quando
> la finestra non è davanti**?

Tutto il resto — nuovo documento, esporta, impostazioni, documenti recenti —
è già a un `⌘` di distanza quando l'applicazione è davanti, e quando non lo
è c'è il Dock. Duplicarlo nella barra non aggiunge niente e toglie spazio.

## 2. L'inventario, e dove si vede oggi

| Cosa | Dove si vede oggi | Vale la barra? |
|---|---|---|
| **Un agente sta leggendo la tua cartella** | **da nessuna parte**: solo il diario, e solo dopo | **sì — è il caso più forte** |
| L'interruttore che spegne gli agenti | Impostazioni ▸ Agenti (tre clic) | sì, se c'è già la spia |
| Il modello locale è caricato (≈ 2 GB) | da nessuna parte | forse |
| Aprire una nota nuova al volo | ⌘N, se l'app è davanti | sì, con una scorciatoia globale |
| Appunti → nuovo documento Markdown | niente di simile | sì, è la stessa gesture |
| Anteprima del Finder, aggiornamenti, stile | Impostazioni | no: si guardano una volta l'anno |
| Documenti recenti | Archivio ▸ Apri Recente, Dock | no: c'è già due volte |
| Sincronizzazione | non esiste ancora | da rivedere quando esisterà |

Due righe di quella tabella sono la risposta di questo studio. Le altre sono
il motivo per cui la maggior parte delle icone nella barra dei menu sono di
troppo.

## 3. Le tre cose che potrebbe fare davvero

### A. La spia degli agenti — *il motivo per farla*

Oggi il server MCP è **invisibile mentre lavora**. Lo avvia un client, legge
la cartella dichiarata, scrive nel diario, e l'unico modo di accorgersene è
aprire Impostazioni ▸ Agenti e leggere le ultime righe *dopo*. Per una
funzione che dà a un programma esterno una cartella di documenti, «lo scopri
dopo» è la parte debole.

Nella barra sarebbe:

* **spenta** quando nessuno sta leggendo niente (icona in grigio, o assente);
* **accesa** mentre un server è vivo, col nome della cartella;
* il menu: le ultime chiamate — *ha letto `verbale.md`*, *ha rifiutato
  `/etc/hosts`* — e in fondo **Spegni gli agenti**, che è la stessa
  preferenza del pannello.

**Il problema tecnico, detto subito**: oggi l'applicazione non ha modo di
sapere se un server è in esecuzione. Il server è un processo che avvia
qualcun altro, e l'unica traccia è il diario. Servirebbe una delle due:

1. il server **tiene un file di lock** mentre vive (`flock` su un pidfile in
   `~/Library/Application Support/…`), e l'applicazione guarda quello: dice
   la verità anche se il diario è spento, costa dieci righe;
2. l'applicazione **osserva il diario** e considera «vivo» un server che ha
   scritto negli ultimi N secondi: costa zero righe nel server, ma sbaglia
   in due modi — un server appena avviato che non ha ancora fatto niente
   risulta spento, e `--no-log` lo rende invisibile.

La prima è quella giusta, ed è lavoro da fare **nel server**, non nella
barra.

### B. La cattura veloce — *il motivo per cui la gente le chiede*

Una scorciatoia globale e una nota nuova, senza cercare la finestra:

* **Nuova nota** in una cartella scelta una volta, con un nome dalla data;
* **Dagli appunti**: quello che è negli appunti diventa un documento nuovo —
  e se sono HTML, diventa Markdown, che è il mestiere che il web clipper già
  sa fare;
* **Apri l'ultima**.

Questo è ciò che un'icona nella barra dà davvero: un posto dove mettere un
pensiero senza cambiare contesto. È anche la parte che richiede una
**scorciatoia globale**, e una scorciatoia globale è un conflitto in più con
tutto il resto del sistema: va scelta dall'utente, non decisa da noi.

### C. Lo stato del modello — *piccolo, ma onesto*

Misurato: il modello sul disco è **1,96 GB**, e l'applicazione lo tiene in
memoria finché non passano **dieci minuti** senza richieste, poi lo scarica
da sola. Una riga nel menu — *modello caricato · scarica adesso* — dice a
chi guarda la memoria del Mac perché quei due giga sono lì, e glieli fa
togliere senza chiudere l'applicazione.

Da solo non giustifica un'icona. Insieme ad A, è una riga in più nello
stesso menu.

## 4. Quello che non ci metterei

* **Il duplicato dei menu** (nuovo, apri, esporta, preferenze): c'è già, e
  due volte.
* **Un contatore di parole o lo stato del documento**: riguarda la finestra
  davanti, e la barra dei menu non è il posto di quello che è già sullo
  schermo.
* **Notifiche di sistema** per ogni chiamata di un agente: sarebbero
  centinaia. Il diario è il posto giusto; la spia accesa è il riassunto.
* **Un'icona che appare da sola** la prima volta che succede qualcosa: una
  cosa che compare nella barra dei menu senza che nessuno l'abbia chiesta è
  esattamente il comportamento che rende antipatiche le altre applicazioni.

## 5. I costi veri

* **Lo spazio.** È una riga condivisa. La nostra icona va **spenta di
  serie** e accesa da chi la vuole, in Impostazioni ▸ Generale.
* **L'applicazione deve restare viva senza finestre.** Misurato: già lo fa —
  chiusa l'ultima finestra il processo resta. Quindi **niente `LSUIElement`**
  e niente icona sparita dal Dock: sarebbe un cambio di natura
  dell'applicazione per una funzione accessoria.
* **L'icona.** Una sagoma *template*, monocromatica, che macOS colora da sé
  in chiaro e in scuro; e uno stato visibile **anche senza colore** (piena
  contro vuota), come per i segni nel margine del confronto.
* **La scorciatoia globale** (solo per B): un conflitto potenziale con
  qualunque altra cosa, quindi scelta dall'utente e vuota di serie.
* **L'accessibilità**: il menu va letto da VoiceOver, e la spia deve avere
  un titolo che dica lo stato a parole («agenti: nessuno in lettura»).
* **Le prove.** Un `NSStatusItem` non si preme da uno script con facilità,
  ma il menu si costruisce da una funzione pura — *dato questo stato, queste
  voci* — e quella si prova senza barra, come il pannello del confronto.

## 6. È utile?

**Sì, a una condizione: che faccia A e B.** La spia degli agenti è l'unica
cosa in questa applicazione che oggi *non si vede da nessuna parte mentre
succede*, e riguarda la fiducia — chi legge i miei documenti, adesso. La
cattura veloce è il motivo per cui una persona vuole un'icona lì, ed è
l'unico posto dove una nota nuova costa meno di cambiare finestra.

**No, se fa il resto.** Un menu che ripete Archivio è spazio tolto a
tutti in cambio di niente.

E prima di A va fatto il pezzo che manca nel server: **un modo di sapere che
è vivo**. Senza quello la spia mentirebbe, e una spia che mente è peggio di
nessuna spia.

## 7. In che ordine, se si fa

| Fase | Cosa | Perché prima |
|---|---|---|
| 0 | Il server tiene un file di lock mentre vive | senza questo, la spia è un'impressione |
| 1 | L'icona, spenta di serie, con la spia degli agenti, le ultime chiamate e lo spegnimento | è il pezzo che non esiste altrove |
| 2 | Nuova nota · dagli appunti, con la scorciatoia globale scelta dall'utente | è quello che la gente usa tutti i giorni |
| 3 | La riga del modello: caricato, scaricalo adesso | una riga, nello stesso menu |
| — | Sincronizzazione | quando esisterà, e nello stesso menu |

## 8. Le domande da decidere

1. **Spenta di serie o accesa?** Propendo per *spenta*, con una riga in
   Impostazioni ▸ Generale. Chi vuole l'icona la accende una volta; agli
   altri non abbiamo tolto niente.
2. **La cattura veloce dove scrive?** Una cartella scelta una volta (la
   stessa che si offre agli agenti, se ce n'è una) o l'ultima usata.
   Propendo per *una cartella scelta*, perché «dove è finita la nota» è la
   domanda che rovina questa funzione.
3. **La scorciatoia globale la proponiamo o la lasciamo vuota?** Propendo
   per *vuota*, con un campo in cui sceglierla: qualunque combinazione
   scegliessimo, sarebbe già di qualcun altro.
4. **La spia mostra anche le scritture di un agente in modo diverso dalle
   letture?** Propendo di sì: leggere è normale, scrivere è la cosa che si
   vuole vedere subito.

---

*Questo è uno studio: nessuna di queste è promessa. Se si farà, la fase 0
appartiene al [progetto del server MCP](progetto-mcp.md) più che a questa
icona.*
