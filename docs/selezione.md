# Una selezione sola, divisa in due pannelli

Diario breve, nella serie del [WYSIWYG](wysiwyg-testo.md) e delle
[due anteprime](anteprime.md). La domanda di partenza era piccola:
**selezionare «test» nell'anteprima, premere canc, e vederlo sparire dal
documento.** La risposta ha richiesto di guardare in faccia una cosa che
sembra ovvia e non lo è: il testo reso non è il sorgente.

---

## Perché non è un problema di eventi ma di mappa

Nell'anteprima si vede `grassetto`; nel sorgente c'è `**grassetto**`. Si vede
una riga di testo dove il sorgente ne ha due, perché la sorgente andava a
capo. Si vede `“così”` dove è stato battuto `"così"`, perché Smartypants ha
fatto il suo mestiere. E «test» in un documento può comparire dieci volte.

Quindi la domanda non è *quando* riportare una selezione, ma **dove finisce
nel sorgente** quella che è stata fatta sulla pagina.

Quello che rende la cosa trattabile è una cosa che c'era già: ogni blocco
reso porta con sé `data-src`, l'offset da cui è stato reso. La ricerca non
avviene nel documento, ma **dentro il blocco**.

## I tre tentativi

1. **Il testo come selezionato**, con qualunque sequenza di spazi che ne
   combacia un'altra: il browser restituisce uno spazio dove il sorgente
   andava a capo, e una `\s+` copre entrambi.
2. **Lo stesso, ovunque**, per un blocco il cui offset si è mosso da quando
   la pagina è stata disegnata.
3. **Dalla prima all'ultima parola, dentro il blocco**: è quello che resta
   quando la selezione ha attraversato marcatura che il lettore non vede.
   «questo è grassetto qui» nel sorgente è `questo è **grassetto** qui`. Uno
   span che si mangerebbe un paragrafo viene rifiutato: tre volte la
   lunghezza della selezione più quaranta caratteri è il limite.

Se nessuno dei tre convince, **non succede niente**. Una selezione messa
quasi giusta farebbe cancellare al tasto dopo le parole sbagliate, e fra
sbagliare e non fare non c'è partita.

## Quale «test»

Il primo tentativo, da solo, prende la prima corrispondenza del blocco: chi
seleziona il secondo «test» del paragrafo si vede selezionare il primo.

La pagina adesso dice anche **quanto del proprio testo viene prima della
selezione** — misurato lì, perché solo la pagina sa cosa mostra — e la
ricerca prende la corrispondenza **più vicina** a quel punto. È un
*pavimento*, non una risposta: il sorgente ha più caratteri di quanti la
pagina ne mostri, mai meno.

## Quello che il renderer ha cambiato all'uscita

| Nella pagina | Nel sorgente |
|---|---|
| `“ ” ‘ ’` | `" '` |
| `–` `—` | `--` `---` |
| `…` | `...` |
| `& < >` | `&amp; &lt; &gt;` |

Ognuno di questi è **un carattere nella pagina e un altro nel sorgente**. Il
caso che si sente di più, in italiano, è l'apostrofo: `l’editor` contro
`l'editor`. Prima una selezione di una parola sola con l'apostrofo curvo non
trovava niente.

## Comunque tu la faccia

| Gesto | L'editor segue | Il fuoco |
|---|---|---|
| Mouse rilasciato nella pagina | sì | **sì** |
| ⇧+frecce, ⌘A | sì | no |
| Trascinamento finito **fuori** dalla pagina | sì | no |
| Canc su una selezione | sì, **e cancella** | sì |

Il mouse non è l'unico gesto, e le altre due strade hanno la stessa forma
una volta che si smette di ragionare sul gesto: **una selezione che ha
smesso di cambiare è una selezione fatta**. La pagina aspetta 400 ms
dall'ultimo cambiamento e riporta allora, il che copre la tastiera e il
trascinamento rilasciato dove nessun `mouseup` della pagina arriva mai.

Quello che in quel caso non fa è **prendere il fuoco**: chi tiene ⇧ e una
freccia non ha finito. Il fuoco si sposta per il gesto palesemente concluso
— il mouse rilasciato dentro la pagina — e per canc, perché dopo aver
cancellato si scrive.

## Il segno che resta

Portare il fuoco all'editor spegne la selezione nativa della web view:
smorta, o sparita. Le parole scelte restano quindi segnate con la
**CSS Custom Highlight API** — un range clonato, nel colore di selezione di
sistema a poco più di metà forza. Con l'API e non avvolgendo le parole in
uno `<span>`: uno span sposterebbe ogni offset dopo di sé, e quegli offset
sono il modo in cui i due pannelli si trovano.

Quando l'editor cerca e **non trova**, il segno cambia: punteggiato e più
tenue. Non succedere niente e non dirlo sono la stessa cosa, da dove guarda
chi legge.

## Il verso opposto

Selezionare nell'editor segna le stesse parole nella pagina. Attraversa il
testo **come lo mostrerebbe la pagina** — marcatori tolti, indirizzo di un
collegamento tolto, pallino di elenco tolto — e la pagina lo cerca con la
stessa tolleranza. Un asterisco protetto (`\*`) resta, perché sulla pagina
c'è.

I due versi non si rincorrono: mentre l'editor riceve la selezione *dalla*
pagina, non si rimanda niente indietro.

## Gli elenchi, che non rispondevano

Selezionare dentro un elenco non faceva niente, e il motivo stava **a monte
di tutto**: né `<ul>` né `<li>` portavano `data-src`. La pagina risaliva
fino al `<body>` e si fermava.

Il parser adesso dichiara l'offset di ogni voce prima di analizzarla —
esattamente come già faceva per ogni riga di tabella, e con la stessa
motivazione scritta lì: *una lista è un blocco per il parser e dodici righe
per chi legge*. Ne hanno guadagnato anche la barra che segna dove stai (ora
segna la singola voce) e la sincronizzazione dello scorrimento.

Da lì è venuta anche una regola che non si vedeva: una lista e la sua prima
voce **cominciano allo stesso carattere**, e un blocco che finisce dove
comincia non è una finestra in cui cercare.

## Come si prova una cosa così

Le funzioni pure — trovare, sostituire, spogliare — hanno le loro prove.
Lo script della pagina ne ha **tredici vive**, che lo iniettano in una web
view vera e controllano cosa riporta: alla fine del gesto e non prima,
senza rubare il fuoco quando la selezione si è solo fermata, con l'offset
che distingue la seconda «test» dalla prima.

Ma le prove unitarie lavorano su HTML scritto a mano, e **gli ultimi due
difetti stavano proprio lì**: in un documento vero, reso dal renderer vero.
Quindi c'è un banco, `Tools/selection_probe.m`, che fa tutta la strada in un
comando:

```
selection_probe verbale.md pick "test" 2
pagina: «test»
blocco: 20…87, dentro il blocco: 24
sorgente: «test» a 44
```

Sette controlli della suite ci girano sopra, su un documento con le forme
che si erano rotte davvero.
