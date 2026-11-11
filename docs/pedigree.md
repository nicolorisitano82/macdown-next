# Pedigree (alberi genealogici clinici)

Un blocco ` ```pedigree ` contiene un albero genealogico scritto nel DSL di
**pedigree-dsl** e l'anteprima lo disegna con i simboli NSGC (2008 e 2022).

````markdown
```pedigree
pedigree
  title Famiglia Bianchi
  condition BC "Tumore della mammella"
  nonna : F affected=BC:58 died=1999
  nonno : M died=2001
  madre : F affected=BC:47 test=BRCA1:"c.68_69del":P
  padre : M
  io    : F proband affected=BC:38 age=41
  nonno -- nonna => madre
  padre -- madre => io
```
````

Anche un blocco ` ```mermaid ` che inizia con `pedigree` viene disegnato: la
libreria si registra come tipo di diagramma Mermaid (`registerExternalDiagrams`).

La sintassi completa è nel progetto pedigree-dsl (`STUDIO.md`, `README.md`).

## Modalità edit

Passando sul disegno compare **✎ Modifica**: l'editor visuale di pedigree-dsl si
apre al posto del disegno (persone, coppie, figli, gemelli, malattie con età
d'esordio, test genetici, donatori…). Con **Fine** il nuovo testo viene scritto
nel blocco ` ```pedigree ` del documento, come un'unica modifica annullabile con ⌘Z.

- **Come trova il blocco:** l'anteprima manda il messaggio `macdownPedigreeEdit`
  con la posizione del blocco nel sorgente (`data-src`, offset UTF-8), il testo di
  partenza e quello nuovo. `MPFencedBlockContentRange` (`MPDiagramPrompt.m`) trova
  l'interno del blocco; `-replacePedigreeEditedInPreview:` (`MPDocument.m`) lo
  sostituisce.
- **Sicurezza:** il blocco viene sostituito solo se contiene ancora esattamente il
  testo da cui l'edit è partito. Se nel frattempo è cambiato (hai scritto
  nell'editor di testo), MacDown emette un bip e non scrive nulla. Nei documenti in
  sola lettura, lo stesso.
- **Formattazione:** l'editor riscrive il blocco in forma ordinata, quindi i
  commenti `%%` e l'allineamento manuale di quel blocco si perdono.
- **Limiti:** solo i blocchi ` ```pedigree `, non quelli ` ```mermaid `. Se mentre
  l'editor è aperto l'anteprima si aggiorna (perché scrivi nel testo), l'editor si
  chiude senza salvare.

## Dove si vede

| Dove | Come |
|---|---|
| Anteprima | `pedigree.init.js` disegna i blocchi; `MacDownRenderPedigree()` è richiamato a ogni aggiornamento (`MPDocument.m`, accanto a Mermaid e Graphviz). Zoom e pan come gli altri diagrammi. In modalità scura il disegno prende i colori della pagina |
| Export HTML, email, Word, EPUB | l'SVG già disegnato viene raccolto da `.macdown-diagram` (regex dei blocchi in `htmlByInliningDiagramsIn:` con `pedigree`) |
| PDF | stampa dell'anteprima |
| Quick Look | `MDDrawingPedigree` in `QuickLook/MDDiagramRenderer.m`; `pedigree.js` è tra le risorse dell'estensione e viene caricato solo se il documento ha un pedigree (o un blocco Mermaid che inizia con `pedigree`) |

Preferenza: **Impostazioni → HTML → Diagrammi → Pedigree (genetica)**
(`htmlPedigree`, attiva di default). Gli script si caricano solo per i documenti
che contengono un pedigree.

Lingua di legenda ed etichette: la riga `lang it|en` del blocco, altrimenti la
lingua del sistema.

## File

| File | Cosa |
|---|---|
| `MacDown/Resources/Extensions/pedigree.js` | bundle di pedigree-dsl (`dist/pedigree.js`, nessuna dipendenza, `window.Pedigree`) |
| `MacDown/Resources/Extensions/pedigree.init.js` | disegna i blocchi ` ```pedigree ` e apre l'editor |
| `MacDown/Resources/Extensions/mermaid.init.js` | registra pedigree come tipo Mermaid prima di disegnare |
| `MPRenderer.m` | `pedigreeScripts`, caricati per i blocchi pedigree e, se la preferenza è attiva, prima di Mermaid |

## Aggiornare la libreria

```bash
cd /percorso/pedigree-dsl && npm run build
cp dist/pedigree.js /percorso/macdown/MacDown/Resources/Extensions/pedigree.js
```

Il file è anche nelle risorse del target MacDownQuickLook (referenza singola nel
`project.pbxproj`, come `viz.js`).
