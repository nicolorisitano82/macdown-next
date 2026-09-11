# Dove finisce il lavoro: salvataggi, versioni, interruzioni

Diario breve, nella serie delle [due anteprime](anteprime.md) e della
[selezione fra i due pannelli](selezione.md). La domanda era pratica: **se
qualcosa si interrompe, il lavoro c'è ancora?** E la richiesta era di
salvare in un file nascosto, come fa Word, «se no sfrutta quello che c'è in
macOS».

La risposta è la seconda, e non per pigrizia: quello che c'è in macOS fa già
tutto, e in tre posti diversi. La parte che mancava non era il salvataggio —
era **il momento giusto per tenere una versione**.

---

## Cosa fa macOS, misurato e non supposto

L'applicazione dichiara `autosavesInPlace = YES`, e da lì discendono tre
comportamenti distinti. Li ho misurati uno per uno con la build di sviluppo,
scrivendo nell'editor e **uccidendo il processo** (`kill -9`), che è
l'interruzione più brutale che ci sia.

### Un documento che ha un file si salva dentro il file

Scritto del testo, aspettati venti secondi, ucciso il processo. Il file su
disco **conteneva già** il testo digitato: l'impronta era cambiata prima
dell'interruzione.

Non c'è nessun file nascosto perché non serve: **il file è il salvataggio**.
È il modello di macOS dal 2011, ed è il motivo per cui in queste
applicazioni il comando «Salva» non è quasi mai necessario.

### Un documento mai salvato si salva in una cartella di sistema

Scritto in un documento nuovo, mai salvato, ucciso il processo, riaperta
l'applicazione: **il documento è tornato**, con dentro il testo. Lo tiene
`~/Library/Autosave Information/`, che è esattamente il «file nascosto tipo
Word» — solo che lo gestisce il sistema.

Una nota su come è stato misurato, perché serve a chi rifà la prova: quella
cartella **non si legge da un terminale** senza i permessi di accesso ai
dati (TCC), e `ls` risponde *Operation not permitted*. La prima volta ho
letto «cartella vuota» e ho creduto che non ci fosse niente: era la mia
finestra a essere cieca, non la cartella a essere vuota. La prova che vale è
quella per effetto — uccidere e riaprire — non quella per ispezione.

### Le versioni sono il Time Machine del singolo file

**Archivio ▸ Ripristina a ▸ Sfoglia tutte le versioni…** apre la stessa
interfaccia di Time Machine sul documento. Ogni salvataggio esplicito è una
versione; il sistema ne tiene anche di periodiche.

Si possono contare da fuori, con l'API pubblica, e questo è il modo di
verificare che ci siano davvero:

```objc
NSArray<NSFileVersion *> *v = [NSFileVersion otherVersionsOfItemAtURL:url];
for (NSFileVersion *one in v)
    NSLog(@"%@ — %@", one.modificationDate, one.URL);
```

## Quello che mancava: una versione *prima* che sia la macchina a scrivere

Il registro delle versioni è fitto di salvataggi fatti da chi scrive. Non
aveva un punto fermo **subito prima di un cambiamento automatico**: l'aiuto
alla scrittura che riscrive un paragrafo, la correzione della prosa, le
attività fatte spostate in fondo. Sono proprio le modifiche che domani si
vorrebbe rivedere — e ⌘Z non sopravvive alla chiusura della finestra.

Adesso il documento **si salva prima**, e la versione resta lì:

```objc
- (void)keepAVersionBefore:(NSString *)what
{
    if (!self.fileURL.isFileURL || MPFileIsMissing(self.fileURL))
        return;
    [self saveToURL:self.fileURL ofType:self.fileType
   forSaveOperation:NSSaveOperation completionHandler:…];
}
```

I byte vengono presi in quel momento, sul thread principale; solo la
scrittura è lasciata a sé. La riscrittura che segue **non può finire dentro
la versione**.

Misurato su un file di attività, chiedendo a macOS cosa tiene:

```
2 versioni precedenti
  18:49:22 — # Attività / - [x] fatta / - [ ] da fare / - [x] anche questa
  18:49:29 — # Attività / - [ ] da fare / - [x] fatta / - [x] anche questa
```

La prima è quella tenuta prima del comando. Dal menù **Sfoglia tutte le
versioni…** ci si torna con due clic, anche fra una settimana.

Niente di tutto questo inventa un formato o una cartella: le versioni sono
quelle del sistema, nel suo archivio, viste dal suo menù. Un archivio
parallelo scritto da noi sarebbe una cosa in più da tenere giusta, e una in
meno che Time Machine sa leggere.

## E se il file cambia sotto il documento

È il caso che ha fatto nascere tutto questo: `git` cambia ramo, uno script
riscrive una tabella, un agente salva sopra il file che hai aperto. Prima
l'editor **non diceva niente** e al salvataggio successivo riscriveva sopra
la sua copia vecchia.

Adesso guarda, e la risposta dipende da una cosa sola — se chi legge ha del
proprio in mano:

| Sul disco | Nel documento | Cosa succede |
|---|---|---|
| uguale | uguale | niente: è il nostro salvataggio che torna |
| diverso | niente di non salvato | **ricarica**, tenendo il cursore dov'era |
| diverso | modifiche non salvate | **chiede una volta**: ricarica o tieni |
| non c'è più | — | lo dice, col percorso, e offre *Salva con nome…* |

Un file che si legge come vuoto **non è un file cambiato**: uno in corso di
scrittura si legge vuoto per un istante, e rispondere «ricarica» a quello
svuoterebbe il documento. È una riga di codice e una prova, ed è la
differenza fra un aiuto e un danno.

## Se qualcosa è andato storto lo stesso

1. **Archivio ▸ Ripristina a ▸ Sfoglia tutte le versioni…** — il documento
   com'era prima, scelto da una pila.
2. Un documento mai salvato torna da solo alla riapertura; se non torna,
   `~/Library/Autosave Information/` è il posto dove guardare (dal Finder:
   Vai ▸ Vai alla cartella…).
3. Se il file non c'è più, l'applicazione lo dice e offre di salvare altrove
   quello che ha in mano, che è tutto quello che resta.
