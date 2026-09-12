# DocumentImport.plugin — un .docx o un .odt dentro il documento

**Archivio ▸ Importa ▸ Documento Word (.docx)…** o **Testo OpenDocument
(.odt)…**: il testo arriva in Markdown dove sta il cursore, le immagini
finiscono in una cartella accanto al documento, e un solo ⌘Z toglie tutto.

Qualcuno manda un file Word. Le alternative erano ribatterlo a mano o
tenersi un formato che non si legge senza il programma che l'ha scritto.
Questa è la terza.

## Installarlo

Non serve: **viaggia dentro l'applicazione**, come il plug-in di draw.io.
Da **Plug-ins ▸ Gestisci plug-in…** si vede, e si può spegnere.

Nel menu **Plug-ins** non c'è, di proposito: le sue voci stanno in Archivio,
accanto a Esporta, e la stessa cosa in due menu è anche il doppio dei posti
dove cercarla quando non funziona. Un plug-in lo dichiara rispondendo
`YES` a `-placesItsOwnMenuItem`.

Per lavorare sul plug-in senza ricostruire l'applicazione:

    ./plugins/DocumentImport/build.sh --install

e riavvia. Fra due copie con lo stesso nome vince **la più recente**: la
copia installata a mano prende il sopravvento fino alla prossima build
dell'applicazione, che torna a vincere da sola.

## Cosa arriva

Un `.docx` e un `.odt` sono uno zip di XML — `word/document.xml` per il
primo, `content.xml` per il secondo — quindi non serve nessuna libreria:
l'archivio lo apre `unzip`, l'XML lo legge `NSXMLDocument`, che è dentro
Foundation.

| | da Word | da OpenDocument |
|---|---|---|
| Titoli | `Heading 1…6`, `Title` | `text:h` col suo livello |
| Grassetto, corsivo | `w:b`, `w:i` | dagli stili automatici |
| Barrato, codice | `w:strike`, carattere a spaziatura fissa | idem |
| Elenchi, anche annidati | `w:numPr` + `numbering.xml` | `text:list` annidate |
| Puntato o numerato | dal formato in `numbering.xml` | dallo stile di elenco |
| Tabelle | `w:tbl` | `table:table` |
| Citazioni | stile `Quote` | stile di citazione |
| Collegamenti | `w:hyperlink` + `document.xml.rels` | `text:a` |
| Immagini | `w:drawing` + i rels | `draw:image` |

Il testo alternativo di un'immagine viene da `wp:docPr@descr` e da
`draw:name`: se il documento ne aveva uno, il Markdown ce l'ha.

Due elenchi attaccati restano **due elenchi**: ognuno porta il suo
identificativo di numerazione, e quando cambia si chiude il primo. Un
elenco che continua dopo un paragrafo è un altro elenco, che è quello che
il documento diceva.

Quello che nel testo sarebbe markup viene **protetto**: un asterisco resta
un asterisco, `\*`, e non diventa corsivo alla riapertura.

## Le immagini

Vanno in una cartella **accanto al documento**, chiamata come il file
importato: `verbale.docx` → `verbale-immagini/`. La stessa immagine usata
due volte è **un file e due collegamenti**.

Se il documento in cui stai importando **non è mai stato salvato** non c'è
un accanto dove metterle: i collegamenti vengono tolti — al loro posto un
commento HTML — e l'avviso finale lo dice. Salvare prima e reimportare è la
cosa da fare.

## Quando qualcosa resta fuori

Alla fine, se manca qualcosa, un avviso lo elenca invece di lasciartelo
scoprire dopo:

* un'immagine il cui file non si è trovato dentro l'archivio;
* le immagini, quando il documento non è ancora salvato;
* il documento che non si è potuto leggere come XML.

Restano fuori **note a piè di pagina, commenti, revisioni** e tutto ciò che
è disegnato dentro il documento: un `.docx` sa fare cose che il Markdown non
ha, e inventarle sarebbe peggio che dirlo.

## Com'è fatto

Due file, e la divisione conta:

| | |
|---|---|
| `MDOfficeImport.m` | XML dentro, Markdown fuori. Nessuna finestra, nessun file, nessuno zip |
| `DocumentImport.m` | il pannello, l'archivio, le immagini, il menu |

È per questo che le parti difficili — un elenco dentro un elenco, una
tabella con dei paragrafi nelle celle, un grassetto che comincia a metà
parola — si chiedono in una prova invece di trovarle nel documento di
qualcun altro:

    ./plugins/DocumentImport/tests/run.sh          # le prove
    ./plugins/DocumentImport/tests/run.sh --show   # e cosa è uscito

Tredici controlli su due documenti finti, più quello che succede quando il
file non è XML, non è un documento, o non è nemmeno uno zip.
`Tools/verify_features.sh` li rifà sull'applicazione costruita.
