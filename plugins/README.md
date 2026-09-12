# Plug-in

Un plug-in è un bundle `.plugin` in
`~/Library/Application Support/MacDown/PlugIns/`. MacDown Next lo carica
all'avvio, istanzia la sua classe principale e aggiunge una voce al menu
**Plug-ins**.

Da **Plug-ins › Gestisci plug-in…** puoi vedere quelli installati,
disattivarne uno senza cancellarlo, aggiungerne e rimuoverne.

## Cosa deve fare la classe principale

Tre metodi, tutti opzionali:

| Metodo | Quando | A cosa serve |
|---|---|---|
| `-name` | all'avvio | il testo della voce di menu |
| `-plugInDidInitialize` | all'avvio | preparazione, se serve |
| `-run:` | alla scelta della voce | il lavoro; restituisce `BOOL` |

Il bundle deve dichiarare `NSPrincipalClass` nel suo `Info.plist`.

## Come raggiungere il documento

Un plug-in non viene compilato insieme a MacDown Next e non conosce le sue
classi. Il modo pulito è la catena dei responder: mentre scrivi, l'editor è
il first responder.

```objectivec
NSResponder *r = [NSApp keyWindow].firstResponder;
if ([r isKindOfClass:[NSTextView class]]) {
    NSTextView *editor = (NSTextView *)r;
    [editor insertText:@"ciao" replacementRange:editor.selectedRange];
}
```

Passando da `insertText:replacementRange:` l'inserimento rispetta la
selezione e finisce nella pila di annullamento, quindi ⌘Z lo toglie.

## Mettere una voce in un altro menu

Il menu **Plug-ins** è dove un plug-in va quando non ha un posto migliore.
Uno che importa un documento ce l'ha: sta accanto a quello che lo esporta,
cioè in Archivio. Un plug-in può mettersi una voce dove vuole — il menu
principale è fatto di oggetti come tutti gli altri — e poi dire
all'applicazione di **non** aggiungerne una sua:

```objc
- (BOOL)placesItsOwnMenuItem { return YES; }
```

Resta in **Gestisci plug-in…**, dove si spegne come gli altri; sparisce
solo dal menu Plug-ins, perché la stessa cosa in due menu è anche il doppio
dei posti in cui cercarla quando non funziona.

Il menu in cui infilarsi va trovato per **quello che fa**, non per come si
chiama: il titolo è nella lingua di chi legge, l'azione no.

```objc
for (NSMenuItem *item in [NSApp mainMenu].itemArray)
    if ([item.submenu indexOfItemWithTarget:nil
                                  andAction:@selector(saveDocument:)] >= 0)
        return item.submenu;            // questo è Archivio
```

Due avvertenze pagate sul campo:

* il menu principale **non è ancora montato** mentre i plug-in vengono
  caricati: la voce si aggiunge da `-plugInDidInitialize` con un
  `dispatch_async` sulla coda principale;
* `NSMenuItem.target` è un riferimento **debole**. Se l'oggetto che ha
  aggiunto la voce muore, la voce resta lì **grigia**, senza un errore e
  senza un motivo visibile. Chi si mette in un menu si tiene vivo.

## L'esempio

`LoremIpsum/` è un plug-in completo in un solo file: chiede tipo e numero di
paragrafi e li inserisce nel punto del cursore. Per costruirlo e
installarlo:

    ./LoremIpsum/build.sh --install

Poi riavvia MacDown Next, perché i plug-in vengono letti una volta sola.

Non serve un target Xcode: un `.plugin` è un Info.plist più un binario
compilato con `-bundle`, ed è quello che fa lo script.

## Le lingue del plug-in

`NSLocalizedString` chiede al bundle **principale**, che è l'applicazione: un
plug-in che la usasse avrebbe bisogno che MacDown Next portasse le *sue*
traduzioni, cioè il contrario di come stanno le cose. Un plug-in porta le
proprie, e chiede al bundle da cui è stato caricato:

```objc
#define LILocalizedString(key, comment) \
    [[NSBundle bundleForClass:[LoremIpsum class]] \
        localizedStringForKey:(key) value:@"" table:nil]
```

Le chiavi si scrivono **in inglese** — la chiave è quello che si legge quando
una lingua non risponde — e le traduzioni stanno in
`Localization/<lingua>.lproj/Localizable.strings`, che finisce in
`Contents/Resources/` del bundle: `build.sh` lo copia, e per Drawio lo copia
il target Xcode. Serve anche `en.lproj`, altrimenti un bundle con una sola
lingua la usa per tutti.

`Tools/check_translations.py` conta le stringhe di ogni bundle a parte,
quindi un plug-in senza traduzioni si vede, e `Tools/verify_features.sh`
chiede al bundle costruito la stessa cosa che gli chiederebbe l'interfaccia.
Il testo che il plug-in *inserisce* non è interfaccia: se sta nella lingua
che dimostra, si scrive `translation-check: content` in un commento sopra e
il conto lo salta.

## Quello che c'è nel progetto

`DocumentImport/` — importa un `.docx` o un `.odt` e ne fa Markdown
([come funziona](DocumentImport/README.md)). **Viaggia dentro
l'applicazione** e le sue voci stanno in **Archivio ▸ Importa**, non nel
menu dei plug-in: è l'esempio di `-placesItsOwnMenuItem` qui sopra. La
conversione è un file a parte, senza finestre, provato da
`DocumentImport/tests/run.sh`.

`Drawio/` — importa un diagramma draw.io e ne fa dei PNG collegati nel
documento ([come funziona](Drawio/README.md)). Questo **ha** un target
Xcode, e non perché serva: porta dentro il visualizzatore di draw.io e le
sue 97 librerie di forme, quindi viene costruito insieme all'applicazione e
**ci viaggia dentro**, in `Contents/PlugIns/`. Non si installa.

I plug-in vengono quindi letti da due posti: la cartella qui sopra, e quella
dentro l'app. Di due copie con lo stesso nome vince **la più recente**: una
copia messa lì per provarla è più nuova dell'app contro cui la provi, e una
build nuova dell'app è più recente della copia rimasta lì da prima. Quelle
dentro l'app non si cestinano — si spengono.
