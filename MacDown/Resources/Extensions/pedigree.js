/*! pedigree-dsl 1.2.0 | MIT | browser bundle: window.Pedigree (render, editor, formats, genetics) */
(() => {
const __m = {};
__m.i18n = (() => {
// Strings for the renderer (legend, auto labels) and the editor UI. English + Italian.
// Language resolution everywhere: DSL `lang` > explicit option > page <html lang> > 'en'.

const MESSAGES = {
  en: {
    // renderer
    'legend.title': 'Key',
    'legend.affected': 'Affected',
    'legend.affectedWith': 'Affected: {c}',
    'legend.carrier': 'Carrier, not expected to manifest',
    'legend.presymptomatic': 'Presymptomatic carrier',
    'legend.evaluated': 'Documented evaluation',
    'legend.deceased': 'Deceased',
    'legend.stillbirth': 'Stillbirth (SB)',
    'legend.pregnancy': 'Pregnancy',
    'legend.miscarriage': 'Miscarriage',
    'legend.termination': 'Termination of pregnancy',
    'legend.ectopic': 'Ectopic pregnancy (ECT)',
    'legend.multiple': 'Multiple individuals',
    'legend.adoptedIn': 'Adopted in (dashed line of descent)',
    'legend.adoptedOut': 'Adopted out',
    'legend.donor': 'Gamete donor (D)',
    'legend.surrogate': 'Surrogate (S)',
    'legend.proband': 'Proband (P)',
    'legend.consultand': 'Person providing pedigree information',
    'legend.noChildren': 'No children (by choice or reason unknown)',
    'legend.infertility': 'Infertility',
    'sex.male': 'male',
    'sex.female': 'female',
    'legend.testPos': 'Pathogenic variant (LP = likely pathogenic)',
    'legend.testVus': 'Variant of uncertain significance',
    'legend.testNeg': 'Negative test (B / LB = benign / likely benign variant)',
    'gen.unrelated': 'not related by blood',
    'gen.degree': '{n}{th}-degree relative',
    'gen.adNoAffectedParent': '{ids}: affected with unaffected parents (de novo, reduced penetrance or non-paternity?)',
    'gen.arAffectedParent': '{ids}: affected with an affected parent (pseudo-dominance?)',
    'gen.maleToMale': 'Male-to-male transmission {ids}: excludes X-linked inheritance',
    'gen.xlAffectedFemale': '{ids}: affected female without affected father (skewed X-inactivation?)',
    'gen.xldUnaffectedDaughter': '{ids}: unaffected daughter of an affected father (unexpected for X-linked dominant)',
    'gen.mtPaternal': '{ids}: only the father is affected (mitochondrial inheritance is maternal)',
    'gen.mtUnaffectedMother': '{ids}: unaffected mother of an affected child (heteroplasmy?)',
    'gen.obligateCarriers': 'Obligate carriers: {ids}',
    'gen.noAffected': 'No affected individual for this condition',
    'fmt.years': '{n}y',
    'fmt.born': 'b. {v}',
    'fmt.died': 'd. {v}',
    'fmt.diedNoDate': 'd.',
    'fmt.dx': '{c} dx {a}',
    'fmt.dxNoName': 'dx {a}',
    'header.recordedBy': 'Recorded by',
    'header.historian': 'Historian',
    'header.date': 'Date',
    'header.indication': 'Indication',
    'legend.nonBinary': 'Non-binary (sex assigned at birth below)',
    'legend.art': 'Gamete donor / gestational carrier line',
    'legend.AMAB': 'AMAB: assigned male at birth',
    'legend.AFAB': 'AFAB: assigned female at birth',
    'legend.UAAB': 'UAAB: unassigned at birth',
    'legend.vsc': 'VSC: variations in sex characteristics',
    'acc.description': 'Pedigree with {n} individuals',
    'acc.condition': ', condition: {c}',

    // editor
    'ed.toggle': '✎ Edit',
    'ed.toggleTitle': 'Edit this pedigree',
    'ed.cannotEdit': 'Cannot edit: the source contains errors.',
    'ed.mode': 'Editing',
    'ed.addPerson': '+ person:',
    'ed.addPersonTitle': 'Add an unconnected person',
    'ed.undo': 'Undo (Ctrl+Z)',
    'ed.redo': 'Redo (Ctrl+Shift+Z)',
    'ed.source': '</> Source',
    'ed.done': 'Done',
    'ed.sourceTitle': 'DSL source',
    'ed.copy': 'Copy',
    'ed.copied': 'Copied',
    'ed.close': 'Close',
    'ed.document': 'Document',
    'ed.docHint': 'Click a symbol or a partnership line to edit it.',
    'ed.title': 'Title',
    'ed.defaultCondition': 'Condition (plain "affected")',
    'ed.conditionPlaceholder': 'e.g. Hereditary breast cancer',
    'ed.namedConditions': 'Named conditions (NSGC quadrants)',
    'ed.newCondition': 'New: KEY + Enter',
    'ed.badKey': 'Invalid key',
    'ed.options': 'Options',
    'ed.numbering': 'Numbering I, II…',
    'ed.legend': 'Key',
    'ed.strictOrder': 'Strict birth order',
    'ed.drawingLang': 'Drawing language',
    'ed.langAuto': 'Automatic',
    'ed.person': 'Person',
    'ed.identifier': 'Identifier',
    'ed.affectedBy': 'Affected by',
    'ed.affected': 'Affected',
    'ed.status': 'Status',
    'ed.count': 'Multiple individuals (n):',
    'ed.labels': 'Labels (one per line)',
    'ed.add': 'Add',
    'ed.addPartner': '+ Partner',
    'ed.addParents': '+ Parents',
    'ed.child': 'Child',
    'ed.sibling': 'Sibling',
    'ed.link': 'Link (then click a symbol)',
    'ed.partnerOf': 'Partner of…',
    'ed.pickPartner': 'Click the partner…',
    'ed.childOf': 'Child of…',
    'ed.pickParent': 'Click a parent or a partnership line…',
    'ed.twinMZ': 'MZ twin…',
    'ed.twinDZ': 'DZ twin…',
    'ed.twinUnknown': 'Twin ?…',
    'ed.pickTwin': 'Click the twin sibling…',
    'ed.untwin': 'Split twin',
    'ed.older': 'Older',
    'ed.earlier': '◀ Earlier',
    'ed.younger': 'Younger',
    'ed.later': 'Later ▶',
    'ed.detach': 'Detach from parents',
    'ed.deletePerson': 'Delete person',
    'ed.couple': 'Couple {a} – {b}',
    'ed.parent': 'Parent {a}',
    'ed.relType': 'Relationship',
    'ed.rel.partner': 'Partnership',
    'ed.rel.divorce': 'Separation / divorce',
    'ed.rel.consanguineous': 'Consanguineous',
    'ed.lineNote': 'Note on the line',
    'ed.lineNotePlaceholder': 'e.g. first cousins',
    'ed.noChildrenTitle': 'No children',
    'ed.nc.unspecified': 'Not specified',
    'ed.nc.none': 'No children (by choice)',
    'ed.nc.infertile': 'Infertility',
    'ed.reason': 'reason (optional)',
    'ed.addChild': 'Add child',
    'ed.childrenList': 'Children (oldest first): {list}',
    'ed.deleteUnion': 'Delete relationship',
    'ed.escToCancel': '(Esc to cancel)',
    'ed.pickOther': 'Pick another person',
    'ed.pickPerson': 'Click a person',
    'ed.alreadyPartners': 'Already partners',
    'ed.pickTwinErr': 'Click the twin',
    'ed.twinsSameParents': 'Twins must have the same parents',
    'ed.hasParents': 'Already has parents',
    'ed.badId': "'{id}' is not a valid identifier (letters, digits, _)",
    'ed.idExists': "'{id}' already exists",
    'flag.deceased': 'Deceased',
    'flag.proband': 'Proband (P)',
    'flag.consultand': 'Consultand (→)',
    'flag.carrier': 'Carrier (•)',
    'flag.presymptomatic': 'Presymptomatic',
    'flag.evaluated': 'Evaluated (*)',
    'flag.pregnancy': 'Pregnancy (P)',
    'flag.miscarriage': 'Miscarriage',
    'flag.stillbirth': 'Stillbirth (SB)',
    'flag.termination': 'Termination (TOP)',
    'flag.ectopic': 'Ectopic (ECT)',
    'flag.adoptedIn': 'Adopted in',
    'flag.adoptedOut': 'Adopted out',
    'flag.donor': 'Donor (D)',
    'flag.surrogate': 'Surrogate (S)',
    'ed.tests': 'Genetic tests',
    'ed.gene': 'Gene',
    'ed.variant': 'Variant (HGVS)',
    'ed.result': 'Result',
    'ed.addTest': '+ Test',
    'ed.relToProband': 'Relationship to proband',
    'ed.analysis': 'Genetic analysis',
    'ed.inheritance': 'Mode of inheritance to check',
    'ed.inheritanceNone': '— none',
    'ed.anyCondition': 'any condition',
    'ed.consistent': 'No inconsistency found.',
    'ed.inbreedingShow': 'Show F on consanguineous couples',
    'ed.inbreedingList': 'Inbreeding coefficient F',
    'ed.segregation': 'Segregation {gene}: carriers {ca} affected / {cu} unaffected · non-carriers {na} affected / {nu} unaffected',
    'ed.notDiagnosis': 'Consistency aid, not a diagnosis.',
    'res.P': 'Pathogenic', 'res.LP': 'Likely pathogenic', 'res.VUS': 'VUS', 'res.LB': 'Likely benign', 'res.B': 'Benign', 'res.N': 'Negative',
    'inh.AD': 'Autosomal dominant', 'inh.AR': 'Autosomal recessive', 'inh.XL': 'X-linked recessive', 'inh.XLD': 'X-linked dominant', 'inh.MT': 'Mitochondrial',
    'flag.vsc': 'VSC (variations in sex characteristics)',
    'ed.sexGender': 'Sex and gender (NSGC 2022)',
    'ed.genderHint': 'Shape = gender identity',
    'ed.assigned': 'Sex assigned at birth',
    'ed.assignedNone': '— not stated',
    'ed.karyotype': 'Karyotype',
    'ed.lifeData': 'Dates and age',
    'ed.born': 'Born',
    'ed.age': 'Age',
    'ed.died': 'Died',
    'ed.cause': 'Cause of death',
    'ed.disease': 'Disease',
    'ed.onset': 'Onset',
    'ed.addDisease': '+ Add',
    'ed.diseasePlaceholder': 'e.g. Breast cancer',
    'ed.inSymbol': 'Shade in symbol',
    'ed.remove': 'Remove',
    'ed.tooManySectors': 'At most 4 shaded conditions: added as text only',
    'ed.hpo': 'HPO terms (comma separated)',
    'ed.codes': 'codes, e.g. MONDO:0007254',
    'ed.header': 'Header',
    'ed.art': 'Assisted reproduction',
    'ed.donorOf': 'Donor / carrier of…',
    'ed.pickArtChild': 'Click the child conceived with this donation.',
    'ed.artFor': 'Donor for: {list}',
    'ed.partnersWritten': 'Partners as written (NSGC 2022)',
  },
  it: {
    'legend.title': 'Legenda',
    'legend.affected': 'Affetto',
    'legend.affectedWith': 'Affetto: {c}',
    'legend.carrier': 'Portatore, non manifesterà',
    'legend.presymptomatic': 'Portatore presintomatico',
    'legend.evaluated': 'Valutazione documentata',
    'legend.deceased': 'Deceduto',
    'legend.stillbirth': 'Nato morto (SB)',
    'legend.pregnancy': 'Gravidanza',
    'legend.miscarriage': 'Aborto spontaneo',
    'legend.termination': 'Interruzione di gravidanza',
    'legend.ectopic': 'Gravidanza ectopica (ECT)',
    'legend.multiple': 'Più individui',
    'legend.adoptedIn': 'Adottato (linea di discendenza tratteggiata)',
    'legend.adoptedOut': 'Dato in adozione',
    'legend.donor': 'Donatore di gameti (D)',
    'legend.surrogate': 'Gestante surrogata (S)',
    'legend.proband': 'Probando (P)',
    'legend.consultand': 'Persona che fornisce le informazioni',
    'legend.noChildren': 'Nessun figlio (per scelta o motivo ignoto)',
    'legend.infertility': 'Sterilità',
    'sex.male': 'maschio',
    'sex.female': 'femmina',
    'legend.testPos': 'Variante patogenetica (LP = probabilmente patogenetica)',
    'legend.testVus': 'Variante di significato incerto',
    'legend.testNeg': 'Test negativo (B / LB = variante benigna / probabilmente benigna)',
    'gen.unrelated': 'non consanguineo',
    'gen.degree': 'parente di {n}° grado',
    'gen.adNoAffectedParent': '{ids}: affetto/a con genitori non affetti (de novo, penetranza ridotta o non-paternità?)',
    'gen.arAffectedParent': '{ids}: affetto/a con un genitore affetto (pseudo-dominanza?)',
    'gen.maleToMale': 'Trasmissione maschio-maschio {ids}: esclude l\'ereditarietà X-linked',
    'gen.xlAffectedFemale': '{ids}: femmina affetta senza padre affetto (inattivazione X sbilanciata?)',
    'gen.xldUnaffectedDaughter': '{ids}: figlia non affetta di padre affetto (inattesa per X-linked dominante)',
    'gen.mtPaternal': '{ids}: è affetto solo il padre (l\'ereditarietà mitocondriale è materna)',
    'gen.mtUnaffectedMother': '{ids}: madre non affetta di figlio affetto (eteroplasmia?)',
    'gen.obligateCarriers': 'Portatori obbligati: {ids}',
    'gen.noAffected': 'Nessun individuo affetto per questa condizione',
    'fmt.years': '{n} a',
    'fmt.born': 'n. {v}',
    'fmt.died': 'm. {v}',
    'fmt.diedNoDate': 'm.',
    'fmt.dx': '{c} dx {a}',
    'fmt.dxNoName': 'dx {a}',
    'header.recordedBy': 'Compilato da',
    'header.historian': 'Fonte',
    'header.date': 'Data',
    'header.indication': 'Indicazione',
    'legend.nonBinary': 'Persona non binaria (sotto: sesso assegnato alla nascita)',
    'legend.art': 'Linea donatore di gameti / gestante',
    'legend.AMAB': 'AMAB: maschio alla nascita',
    'legend.AFAB': 'AFAB: femmina alla nascita',
    'legend.UAAB': 'UAAB: non assegnato alla nascita',
    'legend.vsc': 'VSC: variazioni delle caratteristiche sessuali',
    'acc.description': 'Albero genealogico con {n} individui',
    'acc.condition': ', condizione: {c}',

    'ed.toggle': '✎ Modifica',
    'ed.toggleTitle': 'Modifica questo pedigree',
    'ed.cannotEdit': 'Impossibile modificare: il sorgente contiene errori.',
    'ed.mode': 'Modifica',
    'ed.addPerson': '+ persona:',
    'ed.addPersonTitle': 'Aggiungi una persona non collegata',
    'ed.undo': 'Annulla (Ctrl+Z)',
    'ed.redo': 'Ripeti (Ctrl+Shift+Z)',
    'ed.source': '</> Sorgente',
    'ed.done': 'Fine',
    'ed.sourceTitle': 'Sorgente DSL',
    'ed.copy': 'Copia',
    'ed.copied': 'Copiato',
    'ed.close': 'Chiudi',
    'ed.document': 'Documento',
    'ed.docHint': 'Clicca un simbolo o una linea di coppia per modificarli.',
    'ed.title': 'Titolo',
    'ed.defaultCondition': 'Condizione ("affetto" generico)',
    'ed.conditionPlaceholder': 'es. Tumore al seno ereditario',
    'ed.namedConditions': 'Condizioni con nome (quadranti NSGC)',
    'ed.newCondition': 'Nuova: CHIAVE + Invio',
    'ed.badKey': 'Chiave non valida',
    'ed.options': 'Opzioni',
    'ed.numbering': 'Numerazione I, II…',
    'ed.legend': 'Legenda',
    'ed.strictOrder': 'Ordine di nascita rigido',
    'ed.drawingLang': 'Lingua del disegno',
    'ed.langAuto': 'Automatica',
    'ed.person': 'Persona',
    'ed.identifier': 'Identificatore',
    'ed.affectedBy': 'Affetto da',
    'ed.affected': 'Affetto',
    'ed.status': 'Stato',
    'ed.count': 'Più individui (n):',
    'ed.labels': 'Etichette (una per riga)',
    'ed.add': 'Aggiungi',
    'ed.addPartner': '+ Partner',
    'ed.addParents': '+ Genitori',
    'ed.child': 'Figlio',
    'ed.sibling': 'Fratello',
    'ed.link': 'Collega (poi clicca un simbolo)',
    'ed.partnerOf': 'Partner di…',
    'ed.pickPartner': 'Clicca il partner…',
    'ed.childOf': 'Figlio di…',
    'ed.pickParent': 'Clicca un genitore o una linea di coppia…',
    'ed.twinMZ': 'Gemello MZ…',
    'ed.twinDZ': 'Gemello DZ…',
    'ed.twinUnknown': 'Gemello ?…',
    'ed.pickTwin': 'Clicca il fratello gemello…',
    'ed.untwin': 'Separa gemello',
    'ed.older': 'Più grande',
    'ed.earlier': '◀ Prima',
    'ed.younger': 'Più piccolo',
    'ed.later': 'Dopo ▶',
    'ed.detach': 'Stacca dai genitori',
    'ed.deletePerson': 'Elimina persona',
    'ed.couple': 'Coppia {a} – {b}',
    'ed.parent': 'Genitore {a}',
    'ed.relType': 'Tipo di relazione',
    'ed.rel.partner': 'Unione',
    'ed.rel.divorce': 'Separazione / divorzio',
    'ed.rel.consanguineous': 'Consanguinei',
    'ed.lineNote': 'Nota sulla linea',
    'ed.lineNotePlaceholder': 'es. cugini primi',
    'ed.noChildrenTitle': 'Senza figli',
    'ed.nc.unspecified': 'Non specificato',
    'ed.nc.none': 'Nessun figlio (scelta)',
    'ed.nc.infertile': 'Sterilità',
    'ed.reason': 'motivo (opzionale)',
    'ed.addChild': 'Aggiungi figlio',
    'ed.childrenList': 'Figli (dal maggiore): {list}',
    'ed.deleteUnion': 'Elimina relazione',
    'ed.escToCancel': '(Esc per annullare)',
    'ed.pickOther': "Scegli un'altra persona",
    'ed.pickPerson': 'Clicca una persona',
    'ed.alreadyPartners': 'Sono già partner',
    'ed.pickTwinErr': 'Clicca il gemello',
    'ed.twinsSameParents': 'I gemelli devono avere gli stessi genitori',
    'ed.hasParents': 'Ha già dei genitori',
    'ed.badId': "'{id}' non è un identificatore valido (lettere, cifre, _)",
    'ed.idExists': "'{id}' esiste già",
    'flag.deceased': 'Deceduto',
    'flag.proband': 'Probando (P)',
    'flag.consultand': 'Consultando (→)',
    'flag.carrier': 'Portatore (•)',
    'flag.presymptomatic': 'Presintomatico',
    'flag.evaluated': 'Valutato (*)',
    'flag.pregnancy': 'Gravidanza (P)',
    'flag.miscarriage': 'Aborto spontaneo',
    'flag.stillbirth': 'Nato morto (SB)',
    'flag.termination': 'IVG (TOP)',
    'flag.ectopic': 'Ectopica (ECT)',
    'flag.adoptedIn': 'Adottato',
    'flag.adoptedOut': 'Dato in adozione',
    'flag.donor': 'Donatore (D)',
    'flag.surrogate': 'Surrogata (S)',
    'ed.tests': 'Test genetici',
    'ed.gene': 'Gene',
    'ed.variant': 'Variante (HGVS)',
    'ed.result': 'Esito',
    'ed.addTest': '+ Test',
    'ed.relToProband': 'Parentela con il probando',
    'ed.analysis': 'Analisi genetica',
    'ed.inheritance': 'Modello di ereditarietà da verificare',
    'ed.inheritanceNone': '— nessuno',
    'ed.anyCondition': 'qualsiasi condizione',
    'ed.consistent': 'Nessuna incoerenza trovata.',
    'ed.inbreedingShow': 'Mostra F sulle coppie consanguinee',
    'ed.inbreedingList': 'Coefficiente di inbreeding F',
    'ed.segregation': 'Segregazione {gene}: portatori {ca} affetti / {cu} non affetti · non portatori {na} affetti / {nu} non affetti',
    'ed.notDiagnosis': 'Supporto di coerenza, non una diagnosi.',
    'res.P': 'Patogenetica', 'res.LP': 'Prob. patogenetica', 'res.VUS': 'VUS', 'res.LB': 'Prob. benigna', 'res.B': 'Benigna', 'res.N': 'Negativo',
    'inh.AD': 'Autosomica dominante', 'inh.AR': 'Autosomica recessiva', 'inh.XL': 'X-linked recessiva', 'inh.XLD': 'X-linked dominante', 'inh.MT': 'Mitocondriale',
    'flag.vsc': 'VSC (variazioni caratteristiche sessuali)',
    'ed.sexGender': 'Sesso e genere (NSGC 2022)',
    'ed.genderHint': 'Forma = identità di genere',
    'ed.assigned': 'Sesso assegnato alla nascita',
    'ed.assignedNone': '— non indicato',
    'ed.karyotype': 'Cariotipo',
    'ed.lifeData': 'Date ed età',
    'ed.born': 'Nascita',
    'ed.age': 'Età',
    'ed.died': 'Decesso',
    'ed.cause': 'Causa di morte',
    'ed.disease': 'Malattia',
    'ed.onset': 'Esordio',
    'ed.addDisease': '+ Aggiungi',
    'ed.diseasePlaceholder': 'es. Tumore al seno',
    'ed.inSymbol': 'Colora nel simbolo',
    'ed.remove': 'Rimuovi',
    'ed.tooManySectors': 'Massimo 4 condizioni colorate: aggiunta solo come testo',
    'ed.hpo': 'Termini HPO (separati da virgola)',
    'ed.codes': 'codici, es. MONDO:0007254',
    'ed.header': 'Intestazione',
    'ed.art': 'Procreazione assistita',
    'ed.donorOf': 'Donatore / gestante di…',
    'ed.pickArtChild': 'Clicca il figlio nato da questa donazione.',
    'ed.artFor': 'Donatore per: {list}',
    'ed.partnersWritten': "Partner nell'ordine scritto (NSGC 2022)",
  },
};

const LANGUAGES = Object.keys(MESSAGES);

/** Normalise 'it-IT', 'IT', 'en_GB'… to a supported language, or null. */
function normalizeLang(lang) {
  const base = String(lang ?? '').toLowerCase().split(/[-_]/)[0];
  return LANGUAGES.includes(base) ? base : null;
}

/** First supported language among the candidates, else 'en'. */
function resolveLang(...candidates) {
  for (const c of candidates) {
    const l = normalizeLang(c);
    if (l) return l;
  }
  return 'en';
}

/** Language of the page around `el` (closest [lang], then <html lang>), or null outside a browser. */
function pageLang(el) {
  if (typeof document === 'undefined') return null;
  // the page's language; a page that declares none (e.g. an editor preview) follows the system
  return el?.closest?.('[lang]')?.getAttribute('lang') || document.documentElement.lang
    || (typeof navigator !== 'undefined' ? navigator.language : null) || null;
}

function t(lang, key, vars = {}) {
  const s = MESSAGES[lang]?.[key] ?? MESSAGES.en[key] ?? key;
  return s.replace(/\{(\w+)\}/g, (_, k) => (vars[k] ?? `{${k}}`));
}

return { MESSAGES, LANGUAGES, normalizeLang, resolveLang, pageLang, t };
})();

__m.parser = (() => {
// Pedigree DSL parser (mermaid-style).
// Produces a plain model: { title, condition, options, individuals: Map, unions: [] }

class PedigreeSyntaxError extends Error {
  constructor(message, line, col) {
    super(line ? `Line ${line}${col ? `:${col}` : ''}: ${message}` : message);
    this.name = 'PedigreeSyntaxError';
    this.line = line;
    this.col = col;
  }
}

const SEX = {
  m: 'M', male: 'M', maschio: 'M',
  f: 'F', female: 'F', femmina: 'F',
  u: 'U', unknown: 'U', ignoto: 'U',
  // NSGC 2022: shape = gender identity; diamond for non-binary people
  nb: 'NB', nonbinary: 'NB', non_binary: 'NB', non_binario: 'NB', non_binaria: 'NB',
};
// NSGC 2022: sex assigned at birth, written below the symbol
const ASSIGNED = ['AMAB', 'AFAB', 'UAAB'];

const FLAGS = {
  // HEE key
  affected: 'affected', aff: 'affected', affetto: 'affected', affetta: 'affected',
  deceased: 'deceased', dec: 'deceased', dead: 'deceased', morto: 'deceased', morta: 'deceased',
  pregnancy: 'pregnancy', preg: 'pregnancy', gravidanza: 'pregnancy',
  miscarriage: 'miscarriage', sab: 'miscarriage', aborto: 'miscarriage',
  consultand: 'consultand', informant: 'consultand', consultante: 'consultand',
  // NSGC (Bennett et al. 2008 / 2022)
  proband: 'proband', probando: 'proband',
  carrier: 'carrier', portatore: 'carrier', portatrice: 'carrier',
  presymptomatic: 'presymptomatic', presintomatico: 'presymptomatic', presintomatica: 'presymptomatic',
  evaluated: 'evaluated', documented: 'evaluated',
  stillbirth: 'stillbirth', sb: 'stillbirth', natomorto: 'stillbirth',
  termination: 'termination', top: 'termination', ivg: 'termination',
  ectopic: 'ectopic', ect: 'ectopic',
  adopted_in: 'adoptedIn', adopted: 'adoptedIn', adottato: 'adoptedIn', adottata: 'adoptedIn',
  adopted_out: 'adoptedOut', dato_in_adozione: 'adoptedOut',
  donor: 'donor', donatore: 'donor', donatrice: 'donor',
  surrogate: 'surrogate', surrogata: 'surrogate', gestational_carrier: 'surrogate',
  vsc: 'vsc', // variations in sex characteristics (NSGC 2022)
};
const AFFECTED_WORDS = new Set(['affected', 'aff', 'affetto', 'affetta']);
const NO_CHILDREN = { none: 'none', infertile: 'infertile', infertility: 'infertile', sterile: 'infertile' };
const TWINS = { mz: 'mz', dz: 'dz', twins: 'unknown' };
const MAX_CONDITIONS = 4;
const LANGS = ['en', 'it'];
const LAYOUT_KEYS = ['symbol', 'hgap', 'vgap', 'fontSize', 'lineHeight'];
// pedigree header (NSGC: who recorded it, historian, date, indication)
const HEADER_KEYS = { recorded_by: 'recordedBy', recorder: 'recordedBy', compilato_da: 'recordedBy',
  historian: 'historian', fonte: 'historian', date: 'date', data: 'date',
  indication: 'indication', indicazione: 'indication', motivo: 'indication' };
const PARTNER_MODES = ['sex', 'written'];
// genetic test results (ACMG classes + negative test)
const TEST_RESULTS = ['P', 'LP', 'VUS', 'LB', 'B', 'N'];
const RESULT_ALIASES = { POS: 'P', POSITIVE: 'P', POSITIVO: 'P', NEG: 'N', NEGATIVE: 'N', NEGATIVO: 'N', US: 'VUS' };
const INHERITANCE = ['AD', 'AR', 'XL', 'XLD', 'MT'];

const REL_OPS = { '--': 'partner', '-/-': 'divorce', '==': 'consanguineous' };
const OPS = ['-/-', '->', '--', '==', '=>', '=', ',', '(', ')', ':'];
// ontology CURIE (HP:0001250, MONDO:0007254, OMIM:114480) — also "BC:47" in dx=
const CURIE = /[A-Za-z][A-Za-z0-9_]*:\d[\w.-]*/y;
const IDENT = /[\p{L}_][\p{L}\p{N}_]*/uy;
const NUMBER = /\d+/y;

function tokenize(text, line) {
  const toks = [];
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    if (c === ' ' || c === '\t' || c === '\r') { i++; continue; }
    if (text.startsWith('%%', i)) break;
    if (c === '"') {
      let j = i + 1, s = '';
      while (j < text.length && text[j] !== '"') {
        if (text[j] === '\\' && j + 1 < text.length) { s += text[j + 1]; j += 2; continue; }
        s += text[j++];
      }
      if (j >= text.length) throw new PedigreeSyntaxError('unterminated string', line, i + 1);
      toks.push({ t: 'str', v: s, col: i + 1 });
      i = j + 1;
      continue;
    }
    CURIE.lastIndex = i;
    const cu = CURIE.exec(text);
    if (cu) { toks.push({ t: 'curie', v: cu[0], col: i + 1 }); i += cu[0].length; continue; }
    const op = OPS.find((o) => text.startsWith(o, i));
    if (op) { toks.push({ t: 'op', v: op, col: i + 1 }); i += op.length; continue; }
    NUMBER.lastIndex = i;
    let m = NUMBER.exec(text);
    if (m) { toks.push({ t: 'num', v: Number(m[0]), col: i + 1 }); i += m[0].length; continue; }
    IDENT.lastIndex = i;
    m = IDENT.exec(text);
    if (m) { toks.push({ t: 'id', v: m[0], col: i + 1 }); i += m[0].length; continue; }
    throw new PedigreeSyntaxError(`unexpected character '${c}'`, line, i + 1);
  }
  return toks;
}

class Cursor {
  constructor(toks, line) { this.toks = toks; this.i = 0; this.line = line; }
  peek(k = 0) { return this.toks[this.i + k]; }
  next() { return this.toks[this.i++]; }
  done() { return this.i >= this.toks.length; }
  is(t, v) { const k = this.peek(); return !!k && k.t === t && (v === undefined || k.v === v); }
  expect(t, v, what) {
    const k = this.next();
    if (!k || k.t !== t || (v !== undefined && k.v !== v)) {
      const got = k ? `'${k.v}'` : 'end of line';
      throw new PedigreeSyntaxError(`expected ${what || v || t}, got ${got}`, this.line, k?.col);
    }
    return k;
  }
  fail(msg) { throw new PedigreeSyntaxError(msg, this.line, this.peek()?.col); }
}

function rawRest(text, keyword) {
  let s = text.trim().slice(keyword.length).trim();
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) s = s.slice(1, -1);
  return s;
}

/** Blank individual record (also used by the editor). */
function createIndividual(id, extra = {}) {
  return {
    id, sex: 'U', affected: false, conditions: [], deceased: false, proband: false, consultand: false,
    carrier: false, presymptomatic: false, evaluated: false, pregnancy: false, miscarriage: false,
    stillbirth: false, termination: false, ectopic: false, adoptedIn: false, adoptedOut: false,
    donor: false, surrogate: false, vsc: false, count: null, labels: [],
    assigned: null, karyotype: null, born: null, age: null, died: null, cause: null,
    onset: {}, // condition key -> age at onset
    dx: [], // further diagnoses not drawn as sectors: [{ name, age }]
    hpo: [],
    tests: [], // genetic tests: [{ gene, variant, result: P|LP|VUS|LB|B|N }]
    declared: false, order: 0, line: 0, ...extra,
  };
}

/** Individual flags that map 1:1 to a DSL keyword (model property -> keyword). */
const FLAG_KEYWORDS = {
  deceased: 'deceased', proband: 'proband', consultand: 'consultand', carrier: 'carrier',
  presymptomatic: 'presymptomatic', evaluated: 'evaluated', pregnancy: 'pregnancy',
  miscarriage: 'miscarriage', stillbirth: 'stillbirth', termination: 'termination', ectopic: 'ectopic',
  adoptedIn: 'adopted_in', adoptedOut: 'adopted_out', donor: 'donor', surrogate: 'surrogate', vsc: 'vsc',
};

const VALUE_ATTRS = { born: 'born', nato: 'born', nata: 'born', age: 'age', eta: 'age', died: 'died', morto_nel: 'died',
  cause: 'cause', causa: 'cause', karyotype: 'karyotype', cariotipo: 'karyotype' };

function addCondition(ind, key, age) {
  if (!ind.conditions.includes(key)) ind.conditions.push(key);
  if (age != null && age !== '') ind.onset[key] = age;
  ind.affected = true;
}

function parseCondition(text, lineNo) {
  let toks;
  try { toks = tokenize(text, lineNo).slice(1); } catch { return null; }
  let i = 0, key = '';
  if (toks[i]?.t === 'id') key = toks[i++].v;
  if (toks[i]?.t !== 'str') return null;
  const out = { key, text: toks[i++].v, codes: [] };
  while (i < toks.length) {
    if (toks[i].t === 'curie') out.codes.push(toks[i++].v);
    else if (toks[i].v === ',') i++;
    else return null;
  }
  return out;
}

function parse(source) {
  const model = {
    title: null,
    condition: null,
    conditions: new Map(), // key -> description ('' = default condition)
    conditionCodes: new Map(), // key -> ['MONDO:…', 'OMIM:…']
    header: {}, // recordedBy, historian, date, indication
    options: { numbering: true, legend: true, order: 'auto', lang: null, layout: {}, partners: 'sex', inheritance: null, inbreeding: false },
    individuals: new Map(),
    unions: [],
    links: [], // ART: { from, to } gamete donor / gestational carrier -> child
    warnings: [],
  };
  const unionByKey = new Map();
  let order = 0;

  const getInd = (id, line) => {
    let ind = model.individuals.get(id);
    if (!ind) {
      ind = createIndividual(id, { order: order++, line });
      model.individuals.set(id, ind);
    }
    return ind;
  };

  const getUnion = (a, b, type, line) => {
    const key = b ? [a, b].sort().join('\u0000') : `${a}\u0000`;
    let u = unionByKey.get(key);
    if (!u) {
      u = { a, b, type: type || 'partner', children: [], noChildren: null, label: null, line };
      unionByKey.set(key, u);
      model.unions.push(u);
    } else if (type && type !== 'partner') {
      u.type = type;
    }
    return u;
  };

  const lines = source.split('\n');
  let sawHeader = false;

  for (let ln = 0; ln < lines.length; ln++) {
    const lineNo = ln + 1;
    const text = lines[ln];
    const trimmed = text.trim();
    if (!trimmed || trimmed.startsWith('%%')) continue;

    let kw = trimmed.split(/\s+/)[0].toLowerCase();
    if (!sawHeader && kw === 'pedigree') { sawHeader = true; continue; }
    sawHeader = true;
    // an individual may be called like a directive (`date : F`): statements win
    if (/^\S+\s*(:|--|-\/-|==|=>|->)/.test(trimmed)) kw = '';

    if (HEADER_KEYS[kw]) { model.header[HEADER_KEYS[kw]] = rawRest(trimmed, kw) || null; continue; }
    if (kw === 'inheritance' || kw === 'ereditarieta') {
      // inheritance AD|AR|XL|XLD|MT [CONDITION_KEY]   (used by the consistency check, not drawn)
      const [pat, key] = rawRest(trimmed, kw).split(/\s+/);
      const p = (pat ?? '').toUpperCase();
      if (!INHERITANCE.includes(p)) throw new PedigreeSyntaxError(`inheritance expects one of: ${INHERITANCE.join(', ')}`, lineNo);
      model.options.inheritance = { pattern: p, condition: key ?? null };
      continue;
    }
    if (kw === 'inbreeding') {
      const v = rawRest(trimmed, kw).toLowerCase();
      if (v !== 'on' && v !== 'off') throw new PedigreeSyntaxError("inbreeding expects 'on' or 'off'", lineNo);
      model.options.inbreeding = v === 'on';
      continue;
    }
    if (kw === 'partners') {
      const v = rawRest(trimmed, kw).toLowerCase();
      if (!PARTNER_MODES.includes(v)) throw new PedigreeSyntaxError(`partners expects one of: ${PARTNER_MODES.join(', ')}`, lineNo);
      model.options.partners = v;
      continue;
    }

    if (kw === 'title') { model.title = rawRest(trimmed, 'title'); continue; }
    if (kw === 'condition') {
      // condition "text"            -> default condition (plain `affected`)
      // condition KEY "text"        -> named condition (`affected=KEY`)
      // either form may end with ontology codes: condition BC "Breast cancer" MONDO:0007254, OMIM:114480
      const c = parseCondition(text, lineNo);
      if (c) {
        if (c.key) model.conditions.set(c.key, c.text);
        else { model.condition = c.text; model.conditions.set('', c.text); }
        if (c.codes.length) model.conditionCodes.set(c.key, c.codes);
      } else { model.condition = rawRest(trimmed, 'condition'); model.conditions.set('', model.condition); }
      continue;
    }
    if (kw === 'legend' || kw === 'numbering') {
      const v = rawRest(trimmed, kw).toLowerCase();
      if (v !== 'on' && v !== 'off') throw new PedigreeSyntaxError(`${kw} expects 'on' or 'off'`, lineNo);
      model.options[kw] = v === 'on';
      continue;
    }

    if (kw === 'lang') {
      const v = rawRest(trimmed, kw).toLowerCase();
      if (!LANGS.includes(v)) throw new PedigreeSyntaxError(`lang expects one of: ${LANGS.join(', ')}`, lineNo);
      model.options.lang = v;
      continue;
    }
    if (kw === 'layout') {
      // layout symbol=30 vgap=44   (per-diagram layout options; work everywhere, Mermaid included)
      const toks = tokenize(text, lineNo).slice(1);
      for (let i = 0; i < toks.length; i += 3) {
        const [k, eq, v] = [toks[i], toks[i + 1], toks[i + 2]];
        if (k?.t !== 'id' || !LAYOUT_KEYS.includes(k.v) || eq?.v !== '=' || v?.t !== 'num') {
          throw new PedigreeSyntaxError(`layout expects key=number pairs (${LAYOUT_KEYS.join(', ')})`, lineNo, k?.col);
        }
        model.options.layout[k.v] = v.v;
      }
      continue;
    }
    if (kw === 'order') {
      const v = rawRest(trimmed, kw).toLowerCase();
      if (v !== 'strict' && v !== 'auto') throw new PedigreeSyntaxError("order expects 'strict' or 'auto'", lineNo);
      model.options.order = v;
      continue;
    }

    const cur = new Cursor(tokenize(text, lineNo), lineNo);
    if (cur.done()) continue;
    const first = cur.expect('id', undefined, 'identifier');

    // ---- individual declaration:  id : attrs...
    if (cur.is('op', ':')) {
      cur.next();
      const ind = getInd(first.v, lineNo);
      if (ind.declared) throw new PedigreeSyntaxError(`'${first.v}' already declared on line ${ind.line}`, lineNo, first.col);
      ind.declared = true;
      ind.line = lineNo;
      while (!cur.done()) {
        const t = cur.next();
        if (t.t === 'str') { ind.labels.push(t.v); continue; }
        if (t.t === 'curie' && AFFECTED_WORDS.has(t.v.split(':')[0].toLowerCase())) {
          addCondition(ind, '', Number(t.v.split(':')[1])); // affected:47 (default condition, onset 47)
          continue;
        }
        if (t.t === 'id') {
          const k = t.v.toLowerCase();
          if (SEX[k]) { ind.sex = SEX[k]; continue; }
          if ((AFFECTED_WORDS.has(k) || k === 'dx') && cur.is('op', '=')) {
            // affected=BC:47,OC,"Type 2 diabetes":50
            //   KEY[:age]        -> condition drawn as a sector (NSGC), with age at onset
            //   "free text"[:age] -> further diagnosis, written below the symbol only
            cur.next();
            do {
              const c = cur.next();
              let age = null;
              const readAge = () => {
                if (!cur.is('op', ':')) return;
                cur.next();
                const a = cur.next();
                if (!a || (a.t !== 'num' && a.t !== 'str')) cur.fail("expected age after ':'");
                age = a.v;
              };
              if (c?.t === 'curie') {
                const at = c.v.indexOf(':');
                addCondition(ind, c.v.slice(0, at), Number(c.v.slice(at + 1)));
              } else if (c?.t === 'str') {
                readAge();
                if (!ind.dx.some((d) => d.name === c.v)) ind.dx.push({ name: c.v, age });
              } else if (c && (c.t === 'id' || c.t === 'num')) {
                readAge();
                addCondition(ind, String(c.v), age);
              } else cur.fail("expected condition after 'affected=' (e.g. affected=BC:47)");
            } while (cur.is('op', ',') && cur.next());
            continue;
          }
          if (AFFECTED_WORDS.has(k)) { addCondition(ind, '', null); continue; }
          if (ASSIGNED.includes(t.v.toUpperCase())) { ind.assigned = t.v.toUpperCase(); continue; }
          if (VALUE_ATTRS[k] && cur.is('op', '=')) {
            cur.next();
            const v = cur.next();
            if (!v || !['num', 'str', 'id'].includes(v.t)) cur.fail(`expected a value after '${k}='`);
            ind[VALUE_ATTRS[k]] = v.t === 'num' ? v.v : String(v.v);
            if (VALUE_ATTRS[k] === 'died') ind.deceased = true;
            continue;
          }
          if ((k === 'test' || k === 'tests') && cur.is('op', '=')) {
            // test=BRCA1:P,MLH1:"c.1A>G":VUS,"HLA-B":N    gene[:variant]:result
            cur.next();
            do {
              const g = cur.next();
              if (!g || (g.t !== 'id' && g.t !== 'str')) cur.fail("expected gene after 'test=' (e.g. test=BRCA1:P)");
              cur.expect('op', ':', "':' after gene");
              let variant = null;
              if (cur.is('str')) { variant = cur.next().v; cur.expect('op', ':', "':' after variant"); }
              const r = cur.next();
              const res = r && String(r.v).toUpperCase();
              const result = RESULT_ALIASES[res] ?? res;
              if (!r || !TEST_RESULTS.includes(result)) cur.fail(`expected test result (${TEST_RESULTS.join(', ')})`);
              ind.tests.push({ gene: String(g.v), variant, result });
            } while (cur.is('op', ',') && cur.next());
            continue;
          }
          if (k === 'hpo' && cur.is('op', '=')) {
            cur.next();
            do {
              const c = cur.next();
              if (c?.t !== 'curie') cur.fail("expected ontology code after 'hpo=' (e.g. HP:0001250)");
              if (!ind.hpo.includes(c.v)) ind.hpo.push(c.v);
            } while (cur.is('op', ',') && cur.next());
            continue;
          }
          if (FLAGS[k]) { ind[FLAGS[k]] = true; continue; }
          if (k === 'n') {
            if (cur.is('op', '=')) {
              cur.next();
              const v = cur.next();
              if (!v || (v.t !== 'num' && v.t !== 'id')) cur.fail("expected number after 'n='");
              ind.count = String(v.v);
            } else ind.count = 'n';
            continue;
          }
        }
        throw new PedigreeSyntaxError(`unknown attribute '${t.v}'`, lineNo, t.col);
      }
      continue;
    }

    // ---- relationship:  a OP b [=> kids]   |   a => kids
    getInd(first.v, lineNo);
    if (cur.is('op', '->')) {
      // ART: donor -> child[, child]   (gamete donor, or gestational carrier if flagged `surrogate`)
      cur.next();
      do {
        const t = cur.expect('id', undefined, 'child identifier');
        if (t.v === first.v) throw new PedigreeSyntaxError('an individual cannot be its own donor', lineNo, t.col);
        getInd(t.v, lineNo);
        if (!model.links.some((l) => l.from === first.v && l.to === t.v)) model.links.push({ from: first.v, to: t.v, line: lineNo });
      } while (cur.is('op', ',') && cur.next());
      if (!cur.done()) cur.fail(`unexpected '${cur.peek().v}'`);
      continue;
    }
    let union;
    if (cur.is('op') && REL_OPS[cur.peek().v]) {
      const type = REL_OPS[cur.next().v];
      const second = cur.expect('id', undefined, 'partner identifier');
      if (second.v === first.v) throw new PedigreeSyntaxError('an individual cannot partner with itself', lineNo, second.col);
      getInd(second.v, lineNo);
      union = getUnion(first.v, second.v, type, lineNo);
      if (cur.is('str')) union.label = cur.next().v; // e.g. a == b "first cousins"
    } else if (cur.is('op', '=>')) {
      union = getUnion(first.v, null, null, lineNo);
    } else {
      cur.fail("expected ':', '--', '-/-', '==', '=>' or '->'");
    }

    if (cur.is('op', '=>')) {
      cur.next();
      do {
        const nc = cur.is('id') && NO_CHILDREN[cur.peek().v.toLowerCase()];
        if (nc && (!cur.peek(1) || cur.peek(1).t === 'str' || cur.peek(1).v === ',')) {
          cur.next();
          union.noChildren = { kind: nc, reason: cur.is('str') ? cur.next().v : null };
          continue;
        }
        if (cur.is('id') && TWINS[cur.peek().v.toLowerCase()] && cur.peek(1)?.v === '(') {
          const kind = TWINS[cur.next().v.toLowerCase()];
          cur.next();
          const ids = [];
          do {
            const t = cur.expect('id', undefined, 'twin identifier');
            getInd(t.v, lineNo);
            ids.push(t.v);
          } while (cur.is('op', ',') && cur.next());
          cur.expect('op', ')');
          if (ids.length < 2) cur.fail(`${kind}() needs at least two individuals`);
          union.children.push({ kind, ids });
        } else {
          const t = cur.expect('id', undefined, 'child identifier');
          getInd(t.v, lineNo);
          union.children.push({ kind: 'single', ids: [t.v] });
        }
      } while (cur.is('op', ',') && cur.next());
    }
    if (!cur.done()) cur.fail(`unexpected '${cur.peek().v}'`);
  }

  // ---- validation
  const parentOf = new Map();
  for (const u of model.unions) {
    for (const g of u.children) {
      for (const id of g.ids) {
        if (id === u.a || id === u.b) throw new PedigreeSyntaxError(`'${id}' cannot be its own child`, u.line);
        if (parentOf.has(id)) {
          throw new PedigreeSyntaxError(`'${id}' has two sets of parents (lines ${parentOf.get(id).line} and ${u.line})`, u.line);
        }
        parentOf.set(id, u);
      }
    }
  }
  for (const u of model.unions) {
    if (u.noChildren && u.children.length) {
      throw new PedigreeSyntaxError(`'${u.noChildren.kind}' cannot be combined with children`, u.line);
    }
  }
  // conditions: declaration order first, then order of first use
  const used = [];
  for (const ind of model.individuals.values()) for (const c of ind.conditions) if (!used.includes(c)) used.push(c);
  const ordered = [...model.conditions.keys()].filter((k) => used.includes(k));
  for (const c of used) if (!ordered.includes(c)) ordered.push(c);
  if (ordered.length > MAX_CONDITIONS) {
    throw new PedigreeSyntaxError(`at most ${MAX_CONDITIONS} conditions can be shown (one per quadrant), found ${ordered.length}`);
  }
  model.conditionOrder = ordered;
  for (const c of ordered) {
    if (!model.conditions.has(c)) {
      if (c) model.warnings.push(`condition '${c}' used but not described (add: condition ${c} "…")`);
      model.conditions.set(c, c || null);
    }
  }
  for (const ind of model.individuals.values()) {
    if (!ind.declared) model.warnings.push(`'${ind.id}' used but never declared (drawn as sex unknown)`);
  }
  return model;
}

return { PedigreeSyntaxError, ASSIGNED, MAX_CONDITIONS, LANGS, LAYOUT_KEYS, HEADER_KEYS, PARTNER_MODES, TEST_RESULTS, INHERITANCE, createIndividual, FLAG_KEYWORDS, parse };
})();

__m.formats = (() => {
// Interchange formats.
//
//   import:  PED / PLINK .fam            pedToDSL(text)          -> DSL source
//   export:  PED / PLINK .fam            toPED(model)            -> text
//            CanRisk v4 (BOADICEA)       toCanRisk(model)        -> { text, warnings }
//            Phenopackets v2 Family      toPhenopacketFamily()   -> object (JSON)
//            GA4GH Pedigree (logical)    toGA4GH(model)          -> object (JSON)
//
// Genetic parentage: with a gamete donor (`d -> child`) the donor, not the social
// parent of the same sex, is the biological parent; a gestational carrier (`surrogate`)
// is not. Adopted-in children have no known biological parents in PED / CanRisk.

const ID_OK = /^[\p{L}_][\p{L}\p{N}_]*$/u;

// ---------------------------------------------------------------- shared helpers
/** Sex assigned at birth when stated, otherwise the symbol's sex: 'M' | 'F' | 'U'. */
function birthSex(ind) {
  if (ind.assigned === 'AMAB') return 'M';
  if (ind.assigned === 'AFAB') return 'F';
  if (ind.assigned === 'UAAB') return 'U';
  return ind.sex === 'M' || ind.sex === 'F' ? ind.sex : 'U';
}

const isLoss = (i) => i.miscarriage || i.termination || i.ectopic;

/** Real people: no "n individuals" groups, no pregnancy losses (unless asked). */
function people(model, { includeLosses = false } = {}) {
  return [...model.individuals.values()]
    .filter((i) => i.count == null && (includeLosses || !isLoss(i)))
    .sort((a, b) => a.order - b.order);
}

const parentUnionOf = (model, id) => model.unions.find((u) => u.children.some((g) => g.ids.includes(id)));

/** Biological father / mother of a person (ids or null), honouring donors and adoption. */
function biologicalParents(model, id) {
  const ind = model.individuals.get(id);
  let father = null, mother = null;
  const u = parentUnionOf(model, id);
  if (u && !ind.adoptedIn) {
    const ps = [u.a, u.b].filter(Boolean);
    const unassigned = [];
    for (const p of ps) {
      const s = birthSex(model.individuals.get(p));
      if (s === 'M' && !father) father = p;
      else if (s === 'F' && !mother) mother = p;
      else unassigned.push(p);
    }
    for (const p of unassigned) { if (!father) father = p; else if (!mother) mother = p; }
  }
  for (const l of model.links ?? []) {
    if (l.to !== id) continue;
    const d = model.individuals.get(l.from);
    if (!d || d.surrogate) continue; // gestational carrier: not a genetic parent
    const s = birthSex(d);
    if (s === 'M') father = l.from;
    else if (s === 'F') mother = l.from;
  }
  return { father, mother };
}

const affectedBy = (ind, key) => (key == null ? (ind.conditions?.length ?? 0) > 0 : ind.conditions?.includes(key));
const num = (v) => (typeof v === 'number' ? v : /^\d+$/.test(String(v ?? '')) ? Number(v) : null);

// ---------------------------------------------------------------- PED / PLINK .fam
/**
 * 6 tab-separated columns: FID IID PAT MAT SEX PHENO
 * (sex 1 male / 2 female / 0 unknown; phenotype 2 affected / 1 unaffected).
 * `condition`: only that condition key counts as affected (default: any).
 */
function toPED(model, { familyId = 'FAM1', condition = null, includeLosses = false } = {}) {
  const ids = new Set(people(model, { includeLosses }).map((i) => i.id));
  const rows = [];
  for (const ind of people(model, { includeLosses })) {
    const { father, mother } = biologicalParents(model, ind.id);
    const s = birthSex(ind);
    rows.push([familyId, ind.id, ids.has(father) ? father : '0', ids.has(mother) ? mother : '0',
      s === 'M' ? 1 : s === 'F' ? 2 : 0, affectedBy(ind, condition) ? 2 : 1].join('\t'));
  }
  return rows.join('\n') + '\n';
}

/** PED / .fam text -> DSL source. Several families are kept apart with an id prefix. */
function pedToDSL(text, { title = null } = {}) {
  const rows = [];
  for (const [n, raw] of text.split(/\r?\n/).entries()) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const c = line.split(/\s+/);
    if (c.length < 6) throw new Error(`PED line ${n + 1}: expected 6 columns (FID IID PAT MAT SEX PHENO), got ${c.length}`);
    rows.push({ fid: c[0], iid: c[1], pat: c[2], mat: c[3], sex: c[4], pheno: c[5] });
  }
  const multi = new Set(rows.map((r) => r.fid)).size > 1;
  const used = new Map();
  const taken = new Set();
  const idOf = (fid, iid) => {
    const key = `${fid}\u0000${iid}`;
    if (used.has(key)) return used.get(key);
    let id = (multi ? `${fid}_${iid}` : iid).replace(/[^\p{L}\p{N}_]/gu, '_');
    if (!ID_OK.test(id)) id = `I${id}`;
    let k = id, n = 2;
    while (taken.has(k)) k = `${id}_${n++}`;
    taken.add(k);
    used.set(key, k);
    return k;
  };
  const q = (s) => `"${String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  const decl = new Map();
  for (const r of rows) {
    const id = idOf(r.fid, r.iid);
    const sex = r.sex === '1' ? 'M' : r.sex === '2' ? 'F' : 'U';
    const parts = [sex];
    if (r.pheno === '2') parts.push('affected');
    if (id !== (multi ? `${r.fid}_${r.iid}` : r.iid)) parts.push(q(r.iid)); // keep the original ID visible
    decl.set(id, `${id} : ${parts.join(' ')}`);
  }
  // parents referenced but missing from the file
  for (const r of rows) {
    for (const [p, sex] of [[r.pat, 'M'], [r.mat, 'F']]) {
      if (p === '0' || p === '-9') continue;
      const id = idOf(r.fid, p);
      if (!decl.has(id)) decl.set(id, `${id} : ${sex}`);
    }
  }
  const unions = new Map();
  for (const r of rows) {
    const pa = r.pat === '0' || r.pat === '-9' ? null : idOf(r.fid, r.pat);
    const ma = r.mat === '0' || r.mat === '-9' ? null : idOf(r.fid, r.mat);
    if (!pa && !ma) continue;
    const key = `${pa ?? ''}\u0000${ma ?? ''}`;
    if (!unions.has(key)) unions.set(key, { lhs: pa && ma ? `${pa} -- ${ma}` : pa ?? ma, kids: [] });
    unions.get(key).kids.push(idOf(r.fid, r.iid));
  }
  const out = ['pedigree'];
  if (title) out.push(`  title ${title}`);
  out.push('', ...[...decl.values()].map((l) => `  ${l}`), '');
  for (const u of unions.values()) out.push(`  ${u.lhs} => ${u.kids.join(', ')}`);
  return out.join('\n') + '\n';
}

/** Does this text look like PED rather than DSL? */
function looksLikePED(text) {
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter((l) => l && !l.startsWith('#') && !l.startsWith('%%'));
  if (!lines.length || /^pedigree\b/i.test(lines[0])) return false;
  return lines.every((l) => l.split(/\s+/).length >= 6 && !/[:=]|--/.test(l));
}

// ---------------------------------------------------------------- CanRisk v4
const CANRISK_COLUMNS = ['FamID', 'Name', 'Target', 'IndivID', 'FathID', 'MothID', 'Sex', 'MZtwin', 'Dead', 'Age', 'Yob',
  'BC1', 'BC2', 'OC', 'PRO', 'PAN', 'Ashkn', 'BRCA1', 'BRCA2', 'PALB2', 'ATM', 'CHEK2', 'BARD1', 'RAD51D', 'RAD51C', 'BRIP1',
  'HOXB13', 'ER:PR:HER2:CK14:CK56'];
const GENES = ['BRCA1', 'BRCA2', 'PALB2', 'ATM', 'CHEK2', 'BARD1', 'RAD51D', 'RAD51C', 'BRIP1'];

// automatic mapping of conditions to the CanRisk cancer columns
const CANCERS = {
  BC1: { re: /^(bc|bc1)$|breast|mammell|seno/i, codes: ['MONDO:0007254', 'MONDO:0016419', 'OMIM:114480'] },
  OC: { re: /^oc$|ovar/i, codes: ['MONDO:0008170', 'OMIM:167000'] },
  PRO: { re: /^(pro|pc|prca)$|prostat/i, codes: ['MONDO:0008315', 'OMIM:176807'] },
  PAN: { re: /^(pan|panc)$|pancrea/i, codes: ['MONDO:0009831', 'OMIM:260350'] },
};

/** condition key / diagnosis name -> CanRisk column (BC1, OC, PRO, PAN) or null */
function canriskColumn(model, keyOrName, map = {}) {
  for (const [col, key] of Object.entries(map)) if (key === keyOrName) return col;
  const desc = model.conditions?.get(keyOrName) ?? '';
  const codes = model.conditionCodes?.get(keyOrName) ?? [];
  for (const [col, c] of Object.entries(CANCERS)) {
    if (Object.keys(map).includes(col)) continue; // explicitly mapped elsewhere
    if (c.codes.some((x) => codes.includes(x)) || c.re.test(keyOrName) || (desc && c.re.test(desc))) return col;
  }
  return null;
}

/**
 * CanRisk gene column "type:result". P/LP -> P, N/B/LB -> N, VUS -> untested.
 * Type T (targeted test) when another relative already carries a pathogenic variant in
 * the same gene (cascade testing), otherwise S (mutation search).
 */
function canriskTest(ind, gene, inds) {
  const x = (ind.tests ?? []).find((t) => t.gene === gene);
  if (!x || x.result === 'VUS') return '0:0';
  const pos = (t) => t.gene === gene && (t.result === 'P' || t.result === 'LP');
  const cascade = inds.some((o) => o !== ind && (o.tests ?? []).some(pos) && (o.proband || o.order < ind.order));
  return `${cascade && !ind.proband ? 'T' : 'S'}:${pos(x) ? 'P' : 'N'}`;
}

/**
 * CanRisk v4 pedigree file. Options:
 *   familyId   (≤13 alphanumeric), target (id; default proband > consultand > first),
 *   map        { BC1: 'KEY', OC: 'KEY', PRO: 'KEY', PAN: 'KEY' } to override auto-detection,
 *   names      true to write the first label as Name (default: the id — no personal names),
 *   year       reference year for ages computed from birth year (default: current year).
 */
function toCanRisk(model, { familyId = 'FAM1', target = null, map = {}, names = false, year = new Date().getFullYear() } = {}) {
  const warnings = [];
  const fam = String(familyId).replace(/[^A-Za-z0-9]/g, '').slice(0, 13) || 'FAM1';
  const all = people(model);
  const include = new Set();
  for (const ind of all) {
    const s = birthSex(ind);
    if (s !== 'U') { include.add(ind.id); continue; }
    const isParent = all.some((o) => Object.values(biologicalParents(model, o.id)).includes(ind.id));
    if (isParent) throw new Error(`CanRisk needs sex M or F: set the sex (or AMAB/AFAB) of '${ind.id}', a parent`);
    warnings.push(`'${ind.id}' left out: CanRisk accepts only sex M or F`);
  }
  const inds = all.filter((i) => include.has(i.id));

  // IndivID: ≤7 characters
  const short = new Map();
  const usedShort = new Set();
  let seq = 1;
  for (const ind of inds) {
    let s = /^[A-Za-z0-9_]{1,7}$/.test(ind.id) && !usedShort.has(ind.id) ? ind.id : null;
    while (!s || usedShort.has(s)) s = String(seq++);
    usedShort.add(s);
    short.set(ind.id, s);
  }

  // MZ twins share a code 1..9, A
  const mz = new Map();
  const CODES = '123456789A';
  let mzi = 0;
  for (const u of model.unions) for (const g of u.children) {
    if (g.kind !== 'mz') continue;
    if (mzi >= CODES.length) { warnings.push('more than 10 MZ twin sets: extra sets written as non-twins'); break; }
    const code = CODES[mzi++];
    for (const id of g.ids) mz.set(id, code);
  }

  const tgt = target ?? (inds.find((i) => i.proband) ?? inds.find((i) => i.consultand) ?? inds[0])?.id;
  if (target && !include.has(target)) throw new Error(`target '${target}' is not in the exported pedigree`);

  const rows = [];
  const extra = [];
  let dummy = 1;
  for (const ind of inds) {
    let { father, mother } = biologicalParents(model, ind.id);
    if (father && !include.has(father)) father = null;
    if (mother && !include.has(mother)) mother = null;
    let F = father ? short.get(father) : '0', Mo = mother ? short.get(mother) : '0';
    if ((father == null) !== (mother == null)) {
      // CanRisk: both parents or neither -> add an unknown parent
      let s;
      do { s = `x${dummy++}`; } while (usedShort.has(s));
      usedShort.add(s);
      const sex = father ? 'F' : 'M';
      extra.push({ id: s, sex });
      if (father) Mo = s; else F = s;
      warnings.push(`'${ind.id}': unknown ${father ? 'mother' : 'father'} added as ${s} (CanRisk needs both parents)`);
    }
    const cancers = { BC1: '0', BC2: '0', OC: '0', PRO: '0', PAN: '0' };
    const mark = (col, age) => { if (col) cancers[col] = num(age) != null ? String(num(age)) : 'AU'; };
    for (const c of ind.conditions ?? []) mark(canriskColumn(model, c, map), ind.onset?.[c]);
    for (const d of ind.dx ?? []) mark(canriskColumn(model, d.name, map), d.age);
    if (birthSex(ind) === 'M' && cancers.OC !== '0') warnings.push(`'${ind.id}': ovarian cancer on a male`);

    const born = num(ind.born), died = num(ind.died);
    let age = num(ind.age);
    if (age == null && born != null) age = ind.deceased ? (died != null ? died - born : null) : year - born;
    const name = names ? (ind.labels?.[0] ?? ind.id) : ind.id;
    const genes = GENES.map((g) => canriskTest(ind, g, inds));
    const hox = (ind.tests ?? []).find((x) => x.gene === 'HOXB13');
    const hoxb13 = !hox || hox.result === 'VUS' ? '0:0' : hox.result === 'P' || hox.result === 'LP' ? 'T:HET' : 'T:N';
    for (const x of ind.tests ?? []) {
      if (x.result === 'VUS' && (GENES.includes(x.gene) || x.gene === 'HOXB13')) warnings.push(`'${ind.id}': ${x.gene} VUS written as untested (CanRisk has no VUS class)`);
    }
    rows.push([fam, name.replace(/\t/g, ' '), ind.id === tgt ? 1 : 0, short.get(ind.id), F, Mo, birthSex(ind),
      mz.get(ind.id) ?? 0, ind.deceased || ind.stillbirth ? 1 : 0, age ?? 0, born ?? 0,
      cancers.BC1, cancers.BC2, cancers.OC, cancers.PRO, cancers.PAN, 0,
      ...genes, hoxb13, '0:0:0:0:0'].join('\t'));
  }
  for (const x of extra) {
    rows.push([fam, x.id, 0, x.id, 0, 0, x.sex, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...GENES.map(() => '0:0'), '0:0', '0:0:0:0:0'].join('\t'));
  }
  const text = ['##CanRisk 4.0', `##${CANRISK_COLUMNS.join('\t')}`, ...rows].join('\n') + '\n';
  return { text, warnings, ids: short };
}

// ---------------------------------------------------------------- Phenopackets v2
const RESOURCES = {
  HP: { id: 'hp', name: 'human phenotype ontology', url: 'http://purl.obolibrary.org/obo/hp.owl', namespacePrefix: 'HP', iriPrefix: 'http://purl.obolibrary.org/obo/HP_' },
  MONDO: { id: 'mondo', name: 'Mondo Disease Ontology', url: 'http://purl.obolibrary.org/obo/mondo.obo', namespacePrefix: 'MONDO', iriPrefix: 'http://purl.obolibrary.org/obo/MONDO_' },
  OMIM: { id: 'omim', name: 'Online Mendelian Inheritance in Man', url: 'https://www.omim.org', namespacePrefix: 'OMIM', iriPrefix: 'https://www.omim.org/entry/' },
  ORPHA: { id: 'orphanet', name: 'Orphanet Rare Disease Ontology', url: 'http://www.orpha.net/ORDO', namespacePrefix: 'ORPHA', iriPrefix: 'http://www.orpha.net/ORDO/Orphanet_' },
};
const PP_SEX = { M: 'MALE', F: 'FEMALE', U: 'UNKNOWN_SEX' };
const KARYO = ['XX', 'XY', 'XO', 'XXY', 'XXX', 'XXYY', 'XXXY', 'XXXX', 'XYY'];
const slug = (s) => String(s).normalize('NFD').replace(/[^\w]+/g, '_').replace(/^_|_$/g, '');
const isoAge = (a) => (num(a) != null ? { age: { iso8601duration: `P${num(a)}Y` } } : null);

/**
 * Phenopackets v2 Family: proband + relatives (one Phenopacket each, with HPO features and
 * diseases with onset) + the PED-equivalent pedigree. Conditions without an ontology code
 * get a local id ("LOCAL:BC").
 */
function toPhenopacketFamily(model, { id = 'family-1', familyId = 'FAM1', createdBy = 'pedigree-dsl', created = new Date().toISOString(), condition = null } = {}) {
  const inds = people(model);
  const prefixes = new Set();
  const term = (key, label) => {
    const code = model.conditionCodes?.get(key)?.[0];
    if (code) prefixes.add(code.split(':')[0]);
    return { id: code ?? `LOCAL:${slug(key) || 'affected'}`, label: label || key || 'affected' };
  };
  const packet = (ind) => {
    const subject = { id: ind.id, sex: PP_SEX[birthSex(ind)] };
    const k = /\b(X{1,4}Y{0,2}|XO)\b/.exec(String(ind.karyotype ?? ''))?.[1];
    if (k) subject.karyotypicSex = KARYO.includes(k) ? k : 'OTHER_KARYOTYPE';
    if (ind.deceased || ind.stillbirth) {
      subject.vitalStatus = { status: 'DECEASED' };
    } else if (num(ind.age) != null || num(ind.born) != null) subject.vitalStatus = { status: 'ALIVE' };
    if (num(ind.age) != null) subject.timeAtLastEncounter = isoAge(ind.age);
    if (num(ind.born) != null) subject.dateOfBirth = `${num(ind.born)}-01-01T00:00:00Z`; // year only known
    const pp = { id: `phenopacket-${ind.id}`, subject };
    if (ind.hpo?.length) {
      ind.hpo.forEach((h) => prefixes.add(h.split(':')[0]));
      pp.phenotypicFeatures = ind.hpo.map((h) => ({ type: { id: h, label: h } }));
    }
    const diseases = [
      ...(ind.conditions ?? []).map((c) => ({ term: term(c, model.conditions?.get(c)), ...(isoAge(ind.onset?.[c]) ? { onset: isoAge(ind.onset[c]) } : {}) })),
      ...(ind.dx ?? []).map((d) => ({ term: { id: `LOCAL:${slug(d.name)}`, label: d.name }, ...(isoAge(d.age) ? { onset: isoAge(d.age) } : {}) })),
    ];
    if (diseases.length) pp.diseases = diseases;
    return pp;
  };
  const proband = inds.find((i) => i.proband) ?? inds.find((i) => i.consultand) ?? inds[0];
  const persons = inds.map((ind) => {
    const { father, mother } = biologicalParents(model, ind.id);
    const known = (p) => (p && inds.some((i) => i.id === p) ? p : '0');
    return { familyId, individualId: ind.id, paternalId: known(father), maternalId: known(mother), sex: PP_SEX[birthSex(ind)],
      affectedStatus: affectedBy(ind, condition) ? 'AFFECTED' : 'UNAFFECTED' };
  });
  const pu = proband && parentUnionOf(model, proband.id);
  const family = {
    id,
    proband: proband ? packet(proband) : undefined,
    relatives: inds.filter((i) => i !== proband).map(packet),
    consanguinousParents: pu?.type === 'consanguineous',
    pedigree: { persons },
  };
  family.metaData = {
    created, createdBy, phenopacketSchemaVersion: '2.0',
    resources: [...prefixes].filter((p) => RESOURCES[p]).map((p) => ({ ...RESOURCES[p], version: 'unspecified' })),
  };
  // every Phenopacket requires its own metaData
  for (const pp of [family.proband, ...family.relatives]) if (pp) pp.metaData = family.metaData;
  return family;
}

// ---------------------------------------------------------------- GA4GH Pedigree (logical model)
const KIN_SYSTEM = 'http://purl.org/ga4gh/kin.fhir';
const KIN = {
  mother: ['KIN:027', 'isBiologicalMother'], father: ['KIN:028', 'isBiologicalFather'],
  sperm: ['KIN:004', 'isSpermDonor'], ovum: ['KIN:038', 'isOvumDonor'], carrier: ['KIN:005', 'isGestationalCarrier'],
  twin: ['KIN:009', 'isTwin'], mz: ['KIN:010', 'isMonozygoticTwin'], dz: ['KIN:011', 'isPolyzygoticTwin'],
  adoptive: ['KIN:022', 'isAdoptiveParent'], partner: ['KIN:026', 'isPartner'], consanguineous: ['KIN:030', 'isConsanguineousPartner'],
};
const SEX_WORD = { M: 'male', F: 'female', U: 'unknown' };
const GENDER_WORD = { M: 'man', F: 'woman', NB: 'non-binary', U: 'unknown' };

/**
 * GA4GH Pedigree conceptual model as JSON: individuals + relationships as
 * (individual, KIN relation, relative) triples, the relation being what the relative
 * is to the individual (child → isBiologicalMother → mother), as the GA4GH FHIR IG reads it. The GA4GH model is still a draft and
 * fixes no value sets for sex/gender: plain words are used.
 */
function toGA4GH(model, { id = 'pedigree-1' } = {}) {
  const inds = people(model);
  const ids = new Set(inds.map((i) => i.id));
  const rel = (individual, kind, relative) => ({ individual, relation: { system: KIN_SYSTEM, code: KIN[kind][0], display: KIN[kind][1] }, relative });
  const relationships = [];
  for (const ind of inds) {
    const u = parentUnionOf(model, ind.id);
    const donorFor = (model.links ?? []).filter((l) => l.to === ind.id && ids.has(l.from));
    const { father, mother } = biologicalParents(model, ind.id);
    if (u) for (const p of [u.a, u.b].filter((x) => x && ids.has(x))) {
      if (ind.adoptedIn) relationships.push(rel(ind.id, 'adoptive', p));
      else if (p === father) relationships.push(rel(ind.id, 'father', p));
      else if (p === mother) relationships.push(rel(ind.id, 'mother', p));
    }
    for (const l of donorFor) {
      const d = model.individuals.get(l.from);
      relationships.push(rel(ind.id, d.surrogate ? 'carrier' : birthSex(d) === 'M' ? 'sperm' : 'ovum', l.from));
    }
  }
  for (const u of model.unions) {
    if (u.b && ids.has(u.a) && ids.has(u.b)) relationships.push(rel(u.a, u.type === 'consanguineous' ? 'consanguineous' : 'partner', u.b));
    for (const g of u.children) {
      if (g.kind === 'single') continue;
      const kind = g.kind === 'mz' ? 'mz' : g.kind === 'dz' ? 'dz' : 'twin';
      const t = g.ids.filter((x) => ids.has(x));
      for (let i = 0; i < t.length; i++) for (let j = i + 1; j < t.length; j++) relationships.push(rel(t[i], kind, t[j]));
    }
  }
  const individuals = inds.map((ind) => {
    const out = { id: ind.id, sex: SEX_WORD[birthSex(ind)] };
    if (ind.assigned || ind.sex === 'NB') out.gender = GENDER_WORD[ind.sex];
    if (ind.karyotype) out.karyotypicSex = String(ind.karyotype);
    if (ind.born != null) out.dateOfBirth = String(ind.born);
    if (ind.age != null) out.age = String(ind.age);
    out.deceased = !!(ind.deceased || ind.stillbirth);
    out.affected = (ind.conditions?.length ?? 0) > 0;
    return out;
  });
  const indexPatients = [
    ...inds.filter((i) => i.proband).map((i) => ({ individual: i.id, role: 'proband' })),
    ...inds.filter((i) => i.consultand).map((i) => ({ individual: i.id, role: 'consultand' })),
  ];
  const out = { id };
  if (model.header?.date) out.date = model.header.date;
  if (model.header?.indication) out.narrative = model.header.indication;
  return { ...out, indexPatients, individuals, relationships };
}

// ---------------------------------------------------------------- FHIR R4 (GA4GH Pedigree IG)
const IG = 'http://purl.org/ga4gh/pedigree-fhir-ig/StructureDefinition/';
const SNOMED = 'http://snomed.info/sct';
const ONTOLOGY_SYSTEMS = {
  MONDO: 'http://purl.obolibrary.org/obo/mondo.owl', HP: 'http://human-phenotype-ontology.org',
  OMIM: 'https://omim.org', ORPHA: 'http://www.orpha.net',
};
// deterministic urn:uuid from a string (FNV-1a), so the same pedigree gives the same Bundle
function uuidFor(text) {
  const parts = [];
  for (let k = 0; k < 4; k++) {
    let hsh = 0x811c9dc5 ^ k;
    for (let i = 0; i < text.length; i++) { hsh ^= text.charCodeAt(i); hsh = Math.imul(hsh, 0x01000193) >>> 0; }
    parts.push(hsh.toString(16).padStart(8, '0'));
  }
  const hex = parts.join('');
  return `urn:uuid:${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}
const fhirDate = (v) => (/^\d{4}(-\d{2}(-\d{2})?)?$/.test(String(v ?? '')) ? String(v) : null);

/**
 * FHIR R4 document Bundle following the GA4GH Pedigree FHIR Implementation Guide (0.1.0,
 * draft): Composition "Pedigree" first (sections proband, reason, individuals,
 * relationships, other), one Patient per person (PedigreeIndividual), one
 * FamilyMemberHistory per relationship (PedigreeRelationship, KIN codes), an
 * AffectedStatus Observation per person and a Condition per condition in the reason
 * section. Names are left out unless `names: true`.
 */
function toFHIR(model, { id = 'pedigree-1', condition = null, names = false, timestamp = new Date().toISOString() } = {}) {
  const inds = people(model);
  const ids = new Set(inds.map((i) => i.id));
  const ref = (kind, key) => uuidFor(`${id}/${kind}/${key}`);
  const entry = (fullUrl, resource) => ({ fullUrl, resource });
  const proband = inds.find((i) => i.proband) ?? inds.find((i) => i.consultand) ?? inds[0];

  const patients = inds.map((ind) => {
    const r = { resourceType: 'Patient', meta: { profile: [`${IG}PedigreeIndividual`] }, identifier: [{ value: ind.id }] };
    const ext = [];
    if (ind.assigned || ind.sex === 'NB') {
      const gi = { M: 'male', F: 'female', NB: 'non-binary', U: 'non-disclose' }[ind.sex];
      ext.push({ url: 'http://hl7.org/fhir/StructureDefinition/patient-genderIdentity',
        valueCodeableConcept: { coding: [{ system: 'http://hl7.org/fhir/gender-identity', code: gi }] } });
    }
    if (ind.pregnancy) ext.push({ url: `${IG}patient-unborn`, valueBoolean: true });
    if (ext.length) r.extension = ext;
    if (names && ind.labels?.[0]) r.name = [{ text: ind.labels[0] }];
    r.gender = { M: 'male', F: 'female', U: 'unknown' }[birthSex(ind)];
    if (fhirDate(ind.born)) r.birthDate = fhirDate(ind.born);
    if (fhirDate(ind.died)) r.deceasedDateTime = fhirDate(ind.died);
    else if (ind.deceased || ind.stillbirth) r.deceasedBoolean = true;
    return entry(ref('Patient', ind.id), r);
  });

  const triples = toGA4GH(model).relationships;
  const relations = triples.map((t, n) => entry(ref('FamilyMemberHistory', `${n}:${t.individual}:${t.relation.code}:${t.relative}`), {
    resourceType: 'FamilyMemberHistory',
    meta: { profile: [`${IG}PedigreeRelationship`] },
    extension: [{ url: 'http://hl7.org/fhir/StructureDefinition/familymemberhistory-patient-record', valueReference: { reference: ref('Patient', t.relative) } }],
    status: 'completed',
    patient: { reference: ref('Patient', t.individual) },
    relationship: { coding: [{ system: KIN_SYSTEM, code: t.relation.code, display: t.relation.display }] },
  }));

  const observations = inds.map((ind) => entry(ref('Observation', ind.id), {
    resourceType: 'Observation',
    meta: { profile: [`${IG}AffectedStatus`] },
    status: 'final',
    code: { coding: [{ system: SNOMED, code: '103309006', display: 'Patient affected' }] },
    subject: { reference: ref('Patient', ind.id) },
    valueBoolean: affectedBy(ind, condition),
  }));

  // the conditions the pedigree is about (reason section); codes when the DSL has them
  const conditions = [...(model.conditionOrder ?? [])].filter((k) => !condition || k === condition).map((k) => {
    const text = model.conditions.get(k) || k || model.header?.indication || 'affected';
    const coding = (model.conditionCodes?.get(k) ?? []).map((c) => {
      const [prefix, local] = c.split(':');
      return { system: ONTOLOGY_SYSTEMS[prefix] ?? `urn:curie:${prefix}`, code: prefix === 'HP' || prefix === 'MONDO' ? c : local };
    });
    return entry(ref('Condition', k || 'default'), {
      resourceType: 'Condition',
      code: { ...(coding.length ? { coding } : {}), text },
      subject: { reference: ref('Patient', proband?.id) },
    });
  });

  const section = (code, title, entries) => ({
    title, code: { coding: [{ system: 'http://purl.org/ga4gh/pedigree-fhir-ig/CodeSystem/SectionType', code }] },
    ...(entries.length ? { entry: entries.map((e) => ({ reference: e.fullUrl ?? e })) } : {}),
  });
  const composition = {
    resourceType: 'Composition',
    meta: { profile: [`${IG}Pedigree`] },
    status: 'final',
    type: { coding: [{ system: SNOMED, code: '422432008', display: 'Family history section' }] },
    ...(proband ? { subject: { reference: ref('Patient', proband.id) } } : {}),
    date: fhirDate(model.header?.date) ?? timestamp,
    author: [{ display: model.header?.recordedBy || 'pedigree-dsl' }],
    title: 'Pedigree',
    section: [
      section('proband', 'Proband', proband ? [ref('Patient', proband.id)] : []),
      section('reason', 'Reason', conditions),
      section('individuals', 'Individuals', patients),
      section('relationships', 'Relationships', relations),
      section('other', 'Other', observations),
    ],
  };
  if (!ids.size) throw new Error('FHIR: the pedigree has no individuals');
  return {
    resourceType: 'Bundle',
    identifier: { system: 'urn:ietf:rfc:3986', value: uuidFor(`${id}/bundle`) },
    type: 'document',
    timestamp,
    entry: [entry(uuidFor(`${id}/Composition`), composition), ...patients, ...relations, ...observations, ...conditions],
  };
}

/** One entry point for hosts (CLI, playground). Returns { text, mime, ext, warnings }. */
const FORMATS = {
  ped: { label: 'PED / PLINK .fam', ext: 'ped', mime: 'text/plain' },
  canrisk: { label: 'CanRisk v4 (BOADICEA)', ext: 'txt', mime: 'text/plain' },
  phenopacket: { label: 'Phenopackets v2 Family (JSON)', ext: 'json', mime: 'application/json' },
  ga4gh: { label: 'GA4GH Pedigree (JSON)', ext: 'json', mime: 'application/json' },
  fhir: { label: 'FHIR R4 · GA4GH Pedigree IG (JSON)', ext: 'fhir.json', mime: 'application/fhir+json' },
};
function exportAs(model, format, options = {}) {
  if (format === 'ped') return { text: toPED(model, options), warnings: [], ...FORMATS.ped };
  if (format === 'canrisk') { const r = toCanRisk(model, options); return { text: r.text, warnings: r.warnings, ...FORMATS.canrisk }; }
  if (format === 'phenopacket') return { text: JSON.stringify(toPhenopacketFamily(model, options), null, 2) + '\n', warnings: [], ...FORMATS.phenopacket };
  if (format === 'fhir') return { text: JSON.stringify(toFHIR(model, options), null, 2) + '\n', warnings: [], ...FORMATS.fhir };
  if (format === 'ga4gh') return { text: JSON.stringify(toGA4GH(model, options), null, 2) + '\n', warnings: [], ...FORMATS.ga4gh };
  throw new Error(`unknown format '${format}' (${Object.keys(FORMATS).join(', ')})`);
}

return { birthSex, people, biologicalParents, toPED, pedToDSL, looksLikePED, CANRISK_COLUMNS, canriskColumn, toCanRisk, toPhenopacketFamily, toGA4GH, toFHIR, FORMATS, exportAs };
})();

__m.genetics = (() => {
// Genetic analysis on a pedigree model (no drawing).
//
//   kinship(model)                 -> phi(a, b): kinship coefficient (biological parentage)
//   inbreeding(model, a, b)        -> F of a child of a and b (= phi(a, b))
//   fraction(x)                    -> "1/16"
//   relationship(model, a, b, lang)-> { text, degree, side, ... }  "b is a's maternal aunt"
//   checkInheritance(model, pattern, { condition, lang }) -> findings (warnings, never a diagnosis)
//   segregation(model, gene, { condition }) -> carrier × affected counts
//
// These are aids for the clinician: they check consistency and do bookkeeping, they do not
// compute disease risk (see RICERCA.md on the MDR boundary).

const { biologicalParents, birthSex } = __m.formats;
const { t } = __m.i18n;

// ---------------------------------------------------------------- kinship / inbreeding
function kinship(model) {
  const parents = new Map();
  const P = (id) => {
    if (!parents.has(id)) { const p = biologicalParents(model, id); parents.set(id, [p.father, p.mother].filter(Boolean)); }
    return parents.get(id);
  };
  const depthMemo = new Map();
  const depth = (id, seen = new Set()) => {
    if (depthMemo.has(id)) return depthMemo.get(id);
    if (seen.has(id)) throw new Error('Pedigree contains a cycle');
    seen.add(id);
    const d = Math.max(-1, ...P(id).map((p) => depth(p, seen))) + 1;
    depthMemo.set(id, d);
    return d;
  };
  const memo = new Map();
  const phi = (a, b) => {
    if (!a || !b) return 0;
    const key = a < b ? `${a}\u0000${b}` : `${b}\u0000${a}`;
    if (memo.has(key)) return memo.get(key);
    let v;
    if (a === b) {
      const [f, m] = P(a);
      v = (1 + (f && m ? phi(f, m) : 0)) / 2;
    } else {
      // recurse on the younger one: it cannot be an ancestor of the other
      const [x, y] = depth(a) >= depth(b) ? [a, b] : [b, a];
      const ps = P(x);
      v = ps.length ? ps.reduce((s, p) => s + phi(p, y), 0) / 2 : 0;
    }
    memo.set(key, v);
    return v;
  };
  return phi;
}

const inbreeding = (model, a, b) => kinship(model)(a, b);

/** Exact fraction for sums of powers of two (kinship values): 0.0625 -> "1/16". */
function fraction(x) {
  if (!x) return '0';
  for (let k = 1; k <= 40; k++) {
    const n = x * 2 ** k;
    if (Math.abs(n - Math.round(n)) < 1e-9) {
      let num = Math.round(n), den = 2 ** k;
      while (num % 2 === 0 && den > 1) { num /= 2; den /= 2; }
      return `${num}/${den}`;
    }
  }
  return x.toPrecision(3);
}

/** F for every consanguineous (or any, with all=true) partnership: [{ union, a, b, F }]. */
function unionInbreeding(model, { all = false } = {}) {
  const phi = kinship(model);
  return model.unions.filter((u) => u.b && (all || u.type === 'consanguineous')).map((u) => ({ union: u, a: u.a, b: u.b, F: phi(u.a, u.b) }));
}

// ---------------------------------------------------------------- relationship in words
// Family tree parents (social, incl. adoptive): what people call aunt, cousin…
function treeParents(model, id) {
  const u = model.unions.find((x) => x.children.some((g) => g.ids.includes(id)));
  return u ? [u.a, u.b].filter(Boolean) : [];
}

function ancestors(model, id) {
  const out = new Map([[id, 0]]);
  const q = [id];
  while (q.length) {
    const x = q.shift();
    for (const p of treeParents(model, x)) if (!out.has(p)) { out.set(p, out.get(x) + 1); q.push(p); }
  }
  return out;
}

const G = (sex, m, f, n) => (sex === 'M' ? m : sex === 'F' ? f : n);
const ORD_EN = ['', 'first', 'second', 'third', 'fourth', 'fifth', 'sixth'];
const ORD_IT = ['', 'primo', 'secondo', 'terzo', 'quarto', 'quinto', 'sesto'];
const TIMES_EN = ['', 'once', 'twice', 'three times', 'four times'];

function nameEN(kind, n, sex, removed) {
  const great = (k) => 'great-'.repeat(Math.max(0, k));
  switch (kind) {
    case 'self': return 'self';
    case 'partner': return 'partner';
    case 'parent': return n === 1 ? G(sex, 'father', 'mother', 'parent') : `${great(n - 2)}${G(sex, 'grandfather', 'grandmother', 'grandparent')}`;
    case 'child': return n === 1 ? G(sex, 'son', 'daughter', 'child') : `${great(n - 2)}${G(sex, 'grandson', 'granddaughter', 'grandchild')}`;
    case 'sibling': return G(sex, 'brother', 'sister', 'sibling');
    case 'halfSibling': return G(sex, 'half-brother', 'half-sister', 'half-sibling');
    case 'aunt': return `${great(n - 2)}${G(sex, 'uncle', 'aunt', 'parent’s sibling')}`;
    case 'niece': return `${n > 2 ? `${great(n - 3)}grand` : ''}${G(sex, 'nephew', 'niece', 'sibling’s child')}`;
    case 'cousin': return `${ORD_EN[n] ?? `${n}th`} cousin${removed ? ` ${TIMES_EN[removed] ?? `${removed} times`} removed` : ''}`;
    default: return 'relative';
  }
}

function nameIT(kind, n, sex, removed) {
  const avo = ['', '', 'nonno', 'bisnonno', 'trisnonno'];
  switch (kind) {
    case 'self': return 'sé';
    case 'partner': return 'partner';
    case 'parent':
      if (n === 1) return G(sex, 'padre', 'madre', 'genitore');
      if (n <= 4) return G(sex, avo[n], avo[n].replace(/o$/, 'a'), `${avo[n]}/a`);
      return `antenato di ${n}ª generazione`;
    case 'child':
      if (n === 1) return G(sex, 'figlio', 'figlia', 'figlio/a');
      if (n === 2) return 'nipote (figlio/a di figlio/a)';
      return n === 3 ? G(sex, 'pronipote', 'pronipote', 'pronipote') + ' (linea diretta)' : `discendente di ${n}ª generazione`;
    case 'sibling': return G(sex, 'fratello', 'sorella', 'fratello/sorella');
    case 'halfSibling': return G(sex, 'fratello unilaterale', 'sorella unilaterale', 'fratello/sorella unilaterale');
    case 'aunt': return n === 2 ? G(sex, 'zio', 'zia', 'zio/a') : `${G(sex, 'prozio', 'prozia', 'prozio/a')}${n > 3 ? ` (${n - 1}ª generazione)` : ''}`;
    case 'niece': return n === 2 ? 'nipote (figlio/a di fratello o sorella)' : 'pronipote (discendente di fratello o sorella)';
    case 'cousin': return `${G(sex, 'cugino', 'cugina', 'cugino/a')} di ${ORD_IT[n] ?? `${n}°`} grado${removed ? ` (${removed} generazion${removed > 1 ? 'i' : 'e'} di distanza)` : ''}`;
    default: return 'parente';
  }
}

/**
 * How `b` is related to `a` ("b is a's …"). Returns null when they are not related by blood
 * or partnership. degree = 1 (parents, children, full siblings), 2, 3…; side = 'maternal' |
 * 'paternal' | null (through which parent of `a`).
 */
function relationship(model, a, b, lang = 'en') {
  const sex = model.individuals.get(b)?.sex;
  const name = lang === 'it' ? nameIT : nameEN;
  const mk = (kind, n = 0, extra = {}) => ({ kind, n, ...extra, text: name(kind, n, sex, extra.removed ?? 0) });
  if (a === b) return mk('self');
  const partners = model.unions.some((u) => u.b && ((u.a === a && u.b === b) || (u.a === b && u.b === a)));
  // gamete donor: biological parent / child outside the family tree
  const donor = (x, y) => (model.links ?? []).some((l) => l.from === x && l.to === y && !model.individuals.get(x)?.surrogate);
  if (donor(b, a)) return { kind: 'donor', n: 1, degree: 1, side: null, text: lang === 'it' ? 'donatore/donatrice di gameti (genitore biologico)' : 'gamete donor (biological parent)' };
  if (donor(a, b)) return { kind: 'donorChild', n: 1, degree: 1, side: null, text: lang === 'it' ? 'figlio/a biologico/a (da donazione)' : 'biological child (from donation)' };

  const A = ancestors(model, a), B = ancestors(model, b);
  let best = null;
  for (const [x, d1] of A) if (B.has(x)) {
    const d2 = B.get(x);
    if (!best || d1 + d2 < best.d1 + best.d2) best = { x, d1, d2 };
  }
  if (!best) return partners ? mk('partner', 0, { degree: null, side: null }) : null;
  const { d1, d2 } = best;
  // full vs half: both members of a couple are common ancestors at the same distances
  const commons = [...A].filter(([x, d]) => d === d1 && B.get(x) === d2).map(([x]) => x);
  const full = d1 === 0 || d2 === 0 || commons.length >= 2;

  // side: which parent of `a` leads to the common ancestor
  let side = null;
  // side only where it adds information: beyond parents / full siblings
  if (d1 >= 2 || (d1 >= 1 && d2 >= 1 && !full)) {
    const u = model.unions.find((x) => x.children.some((g) => g.ids.includes(a)));
    const via = [u?.a, u?.b].filter(Boolean).filter((p) => commons.some((c) => p === c || (ancestors(model, p).get(c) ?? Infinity) === d1 - 1));
    if (via.length === 1) {
      const s = birthSex(model.individuals.get(via[0]));
      side = s === 'F' ? 'maternal' : s === 'M' ? 'paternal' : null;
    }
  }
  const degree = d1 === 0 || d2 === 0 ? d1 + d2 : full ? d1 + d2 - 1 : d1 + d2;
  let r;
  if (d1 === 0) r = mk('child', d2);
  else if (d2 === 0) r = mk('parent', d1);
  else if (d1 === 1 && d2 === 1) r = mk(full ? 'sibling' : 'halfSibling', 1);
  else if (d1 === 1) r = mk('niece', d2);
  else if (d2 === 1) r = mk('aunt', d1);
  else r = mk('cousin', Math.min(d1, d2) - 1, { removed: Math.abs(d1 - d2) });
  if (!full && r.kind !== 'halfSibling') r.text += lang === 'it' ? ' (un solo antenato in comune)' : ' (half)';
  if (partners) r.text += lang === 'it' ? ', partner' : ', partner';
  return { ...r, degree, side, full, via: best.x };
}

/** "zia (ramo materno) · 2° grado" / "maternal aunt · 2nd-degree relative" */
function describeRelationship(r, lang = 'en') {
  if (!r) return t(lang, 'gen.unrelated');
  let s = r.text;
  if (r.side) s = lang === 'it' ? `${s} (ramo ${r.side === 'maternal' ? 'materno' : 'paterno'})` : `${r.side} ${s}`;
  if (r.degree) s += ` · ${t(lang, 'gen.degree', { n: r.degree, th: ['th', 'st', 'nd', 'rd'][r.degree % 10 <= 3 && Math.floor(r.degree / 10) !== 1 ? r.degree % 10 : 0] })}`;
  return s;
}

// ---------------------------------------------------------------- inheritance consistency
const PATTERNS = ['AD', 'AR', 'XL', 'XLD', 'MT'];

/**
 * Check the drawn affection status against a mode of inheritance. Returns
 * [{ level: 'error'|'warn'|'info', code, ids, text }]. 'error' = classic exclusion
 * (e.g. male-to-male transmission for X-linked), 'warn' = unusual but possible,
 * 'info' = bookkeeping (obligate carriers). Not a diagnosis.
 */
function checkInheritance(model, pattern, { condition = null, lang = 'en' } = {}) {
  const out = [];
  const T = (code, ids, level, vars = {}) => out.push({ level, code, ids, text: t(lang, `gen.${code}`, { ...vars, ids: ids.join(', ') }) });
  const inds = [...model.individuals.values()].filter((i) => i.count == null);
  const aff = (id) => {
    const i = model.individuals.get(id);
    return !!i && (condition ? i.conditions.includes(condition) : i.conditions.length > 0);
  };
  const sex = (id) => birthSex(model.individuals.get(id));
  const par = (id) => biologicalParents(model, id);
  const kids = (id) => inds.filter((c) => { const p = par(c.id); return p.father === id || p.mother === id; }).map((c) => c.id);
  const carrierFlag = (id) => { const i = model.individuals.get(id); return i.carrier || i.presymptomatic; };
  const obligate = new Set();

  for (const c of inds) {
    const { father, mother } = par(c.id);
    const A = aff(c.id);
    if (pattern === 'AD') {
      if (A && father && mother && !aff(father) && !aff(mother)) T('adNoAffectedParent', [c.id], 'warn');
      if (!A && (father && aff(father) || mother && aff(mother)) && kids(c.id).some(aff)) obligate.add(c.id);
    }
    if (pattern === 'AR') {
      if (A) {
        for (const p of [father, mother]) if (p && !aff(p)) obligate.add(p);
        if ((father && aff(father)) || (mother && aff(mother))) T('arAffectedParent', [c.id], 'warn');
        for (const k of kids(c.id)) if (!aff(k)) obligate.add(k);
      }
    }
    if (pattern === 'XL') {
      if (A && sex(c.id) === 'M' && father && aff(father) && mother && !aff(mother) && !carrierFlag(mother)) T('maleToMale', [father, c.id], 'error');
      if (A && sex(c.id) === 'F' && !(father && aff(father))) T('xlAffectedFemale', [c.id], 'warn');
      if (A && sex(c.id) === 'M') for (const k of kids(c.id)) if (sex(k) === 'F' && !aff(k)) obligate.add(k);
      if (A && sex(c.id) === 'M' && mother && !aff(mother)) {
        const affectedSons = kids(mother).filter((k) => sex(k) === 'M' && aff(k)).length;
        const mf = par(mother).father;
        if (affectedSons >= 2 || (mf && aff(mf))) obligate.add(mother);
      }
    }
    if (pattern === 'XLD') {
      if (A && sex(c.id) === 'M' && father && aff(father) && mother && !aff(mother)) T('maleToMale', [father, c.id], 'error');
      if (!A && sex(c.id) === 'F' && father && aff(father)) T('xldUnaffectedDaughter', [c.id], 'warn');
    }
    if (pattern === 'MT') {
      if (A && father && aff(father) && mother && !aff(mother)) T('mtPaternal', [father, c.id], 'warn');
      if (A && mother && !aff(mother)) {
        const m = model.individuals.get(mother);
        if (!carrierFlag(mother) && !m.deceased) T('mtUnaffectedMother', [mother, c.id], 'info');
      }
    }
  }
  if (obligate.size) T('obligateCarriers', [...obligate], 'info');
  if (!inds.some((i) => aff(i.id))) T('noAffected', [], 'info');
  const rank = { error: 0, warn: 1, info: 2 };
  return out.sort((x, y) => rank[x.level] - rank[y.level]);
}

// ---------------------------------------------------------------- segregation
/** Gene test result vs affection: { carriers: { affected, unaffected }, nonCarriers: {…}, vus, ids } */
function segregation(model, gene, { condition = null } = {}) {
  const res = { carriers: { affected: [], unaffected: [] }, nonCarriers: { affected: [], unaffected: [] }, vus: [] };
  for (const i of model.individuals.values()) {
    const tst = (i.tests ?? []).find((x) => x.gene === gene);
    if (!tst) continue;
    const A = condition ? i.conditions.includes(condition) : i.conditions.length > 0;
    if (tst.result === 'P' || tst.result === 'LP') res.carriers[A ? 'affected' : 'unaffected'].push(i.id);
    else if (tst.result === 'VUS') res.vus.push(i.id);
    else res.nonCarriers[A ? 'affected' : 'unaffected'].push(i.id);
  }
  return res;
}

/** Genes tested in the pedigree, in order of first appearance. */
const testedGenes = (model) => [...new Set([...model.individuals.values()].flatMap((i) => (i.tests ?? []).map((x) => x.gene)))];

return { kinship, inbreeding, fraction, unionInbreeding, relationship, describeRelationship, PATTERNS, checkInheritance, segregation, testedGenes };
})();

__m.layout = (() => {
// Pedigree layout: generation assignment, ordering, x-placement.
//
// 1. Generations  — constraint propagation (child = parent + 1, partners equal,
//                   founder couples pulled down next to their children).
// 2. Ordering     — per generation: sibships in birth order, sorted by parents'
//                   position; married-in partners inserted beside their spouse
//                   (male on the left by convention).
// 3. X placement  — iterative relaxation: each node wants to sit under its
//                   parents / above its children / next to its partner; each
//                   row is solved exactly with weighted isotonic regression
//                   (PAVA) under minimum-separation constraints, so order is
//                   preserved and nothing overlaps.

const { t, resolveLang } = __m.i18n;
const { kinship, fraction } = __m.genetics;

const HEADER_ORDER = ['recordedBy', 'historian', 'date', 'indication'];

const DEFAULTS = {
  symbol: 40,        // symbol size (px)
  hgap: 30,          // min gap between neighbouring symbols
  vgap: 64,          // vertical gap between label bottom and next generation
  fontSize: 12,
  lineHeight: 14,
  margin: 30,
  marginLeft: 56,    // room for generation numerals
  iterations: 80,
  strictBirthOrder: false, // never move siblings out of declared order
};

function textWidth(s, fontSize) {
  return String(s).length * fontSize * 0.58;
}

// pregnancy outcomes drawn as a small triangle (NSGC)
const isTriangle = (ind) => ind.miscarriage || ind.termination || ind.ectopic;

// NSGC 2022: diamond = gender unknown or non-binary
const isDiamond = (ind) => ind.sex === 'U' || ind.sex === 'NB';

const NUMERIC = /^\d+(\.\d+)?$/;
// NSGC-style test notation below the symbol
const TEST_MARK = { P: '+', LP: '+ (LP)', VUS: 'VUS', LB: '\u2013 (LB)', B: '\u2013 (B)', N: '\u2013' };
const lineText = (l) => (typeof l === 'string' ? l : l.text);
function fmtAge(a, lang = 'en') {
  return NUMERIC.test(String(a)) ? t(lang, 'fmt.years', { n: a }) : String(a);
}

/**
 * Text written below a symbol, in NSGC order: pregnancy-loss notes, sex assigned at
 * birth / VSC / karyotype, birth / age / death, diagnoses with age at onset, free labels.
 */
function labelLines(ind, lang = 'en') {
  const T = (k, v) => t(lang, k, v);
  const lines = [];
  if (isTriangle(ind) && (ind.sex === 'M' || ind.sex === 'F')) lines.push(T(ind.sex === 'M' ? 'sex.male' : 'sex.female'));
  if (ind.ectopic) lines.push('ECT');
  if (ind.stillbirth) lines.push('SB');
  if (ind.assigned) lines.push(ind.assigned);
  if (ind.vsc) lines.push('VSC');
  if (ind.karyotype) lines.push(String(ind.karyotype));
  if (ind.born != null) lines.push(T('fmt.born', { v: ind.born }));
  if (ind.age != null) lines.push(fmtAge(ind.age, lang));
  if (ind.died != null || ind.cause) {
    const d = ind.died != null ? T('fmt.died', { v: ind.died }) : T('fmt.diedNoDate');
    lines.push(ind.cause ? `${d} (${ind.cause})` : d);
  }
  const onset = ind.onset ?? {};
  for (const c of ind.conditions ?? []) {
    if (onset[c] == null) continue;
    lines.push(c ? T('fmt.dx', { c, a: fmtAge(onset[c], lang) }) : T('fmt.dxNoName', { a: fmtAge(onset[c], lang) }));
  }
  for (const d of ind.dx ?? []) lines.push(d.age != null ? T('fmt.dx', { c: d.name, a: fmtAge(d.age, lang) }) : d.name);
  // genetic test results: "BRCA1 c.68_69del +", positive in bold
  for (const x of ind.tests ?? []) {
    lines.push({ text: `${x.gene}${x.variant ? ` ${x.variant}` : ''} ${TEST_MARK[x.result]}`, cls: x.result === 'P' || x.result === 'LP' ? 'gt pos' : 'gt' });
  }
  lines.push(...(ind.labels ?? []));
  return lines;
}

// extra room taken by adoption brackets
const bracketPad = (ind) => (ind.adoptedIn || ind.adoptedOut ? 7 : 0);

function symbolHalfWidth(ind, h) {
  if (isTriangle(ind)) return h * 0.8;
  return (isDiamond(ind) ? h * 1.2 : h) + bracketPad(ind);
}

function layout(model, options = {}) {
  const o = { ...DEFAULTS, ...options, ...(model.options?.layout ?? {}) }; // DSL `layout` wins
  const lang = resolveLang(model.options?.lang, options.lang); // DSL `lang` wins
  const h = o.symbol / 2;
  const ids = [...model.individuals.keys()];
  const ind = (id) => model.individuals.get(id);

  const kidsOf = (u) => u.children.flatMap((g) => g.ids);
  const parentsOf = (u) => [u.a, u.b].filter(Boolean);
  const parentUnion = new Map();
  const unionsOf = new Map(ids.map((id) => [id, []]));
  for (const u of model.unions) {
    for (const p of parentsOf(u)) unionsOf.get(p).push(u);
    for (const k of kidsOf(u)) parentUnion.set(k, u);
  }
  const partnerOf = (u, id) => (u.a === id ? u.b : u.a);
  // ART: gamete donors / gestational carriers linked to a child (not a partnership)
  const links = (model.links ?? []).filter((l) => model.individuals.has(l.from) && model.individuals.has(l.to));
  const donorsOf = new Map();
  for (const l of links) donorsOf.set(l.to, [...(donorsOf.get(l.to) ?? []), l.from]);

  // ---------------------------------------------------------------- generations
  const gen = new Map(ids.map((id) => [id, 0]));

  // partner components (couples, chains of remarriages)
  const comp = new Map(ids.map((id) => [id, id]));
  const find = (x) => (comp.get(x) === x ? x : (comp.set(x, find(comp.get(x))), comp.get(x)));
  for (const u of model.unions) if (u.b) comp.set(find(u.a), find(u.b));
  const groups = new Map();
  for (const id of ids) {
    const r = find(id);
    if (!groups.has(r)) groups.set(r, []);
    groups.get(r).push(id);
  }

  let changed = true;
  let guard = 0;
  while (changed) {
    if (++guard > 10 * ids.length + 50) throw new Error('Pedigree contains a cycle (someone is their own ancestor)');
    changed = false;
    for (const u of model.unions) {
      const pg = Math.max(...parentsOf(u).map((p) => gen.get(p)));
      for (const k of kidsOf(u)) if (gen.get(k) < pg + 1) { gen.set(k, pg + 1); changed = true; }
    }
    for (const l of links) if (gen.get(l.to) < gen.get(l.from) + 1) { gen.set(l.to, gen.get(l.from) + 1); changed = true; }
    for (const members of groups.values()) {
      const g = Math.max(...members.map((m) => gen.get(m)));
      for (const m of members) if (gen.get(m) !== g) { gen.set(m, g); changed = true; }
    }
    // founder groups float down to sit directly above their children
    for (const members of groups.values()) {
      if (members.some((m) => parentUnion.has(m))) continue;
      let hi = Infinity;
      for (const m of members) for (const u of unionsOf.get(m)) for (const k of kidsOf(u)) hi = Math.min(hi, gen.get(k) - 1);
      for (const l of links) if (members.includes(l.from)) hi = Math.min(hi, gen.get(l.to) - 1);
      if (hi !== Infinity && gen.get(members[0]) < hi) {
        for (const m of members) gen.set(m, hi);
        changed = true;
      }
    }
  }
  const minGen = Math.min(...gen.values());
  for (const id of ids) gen.set(id, gen.get(id) - minGen);
  const G = ids.length ? Math.max(...gen.values()) + 1 : 0;

  // ---------------------------------------------------------------- ordering
  const rows = Array.from({ length: G }, () => []);
  const placed = new Set();
  const indexIn = new Map();
  const declOrder = [...ids].sort((a, b) => ind(a).order - ind(b).order);

  const addCluster = (id, row, donorSink = row) => {
    if (placed.has(id)) return;
    const me = ind(id);
    const spouses = [];
    const spouseFirst = new Set(); // partner written first (`s -- id`)
    for (const u of unionsOf.get(id)) {
      const p = partnerOf(u, id);
      if (p && !placed.has(p) && !parentUnion.has(p) && gen.get(p) === gen.get(id) && !spouses.includes(p)) {
        spouses.push(p);
        if (u.a === p) spouseFirst.add(p);
      }
    }
    const left = [], right = [];
    spouses.forEach((s, i) => {
      // first partner on the conventional side (male left, or as written with
      // `partners written` — NSGC 2022 drops the male-left rule); others alternate
      const conventionalLeft = model.options?.partners === 'written' ? spouseFirst.has(s) : me.sex !== 'M' && ind(s).sex === 'M';
      const goLeft = i === 0 ? conventionalLeft : right.length > left.length;
      (goLeft ? left : right).push(s);
    });
    // donors / gestational carriers of this person's children sit beside the family
    const donors = [];
    for (const u of unionsOf.get(id)) for (const k of kidsOf(u)) for (const d of donorsOf.get(k) ?? []) {
      if (!placed.has(d) && !parentUnion.has(d) && gen.get(d) === gen.get(id) && !spouses.includes(d) && !donors.includes(d)) donors.push(d);
    }
    for (const x of [...left.reverse(), id, ...right]) { placed.add(x); row.push(x); }
    for (const x of donors) { placed.add(x); donorSink.push(x); }
  };

  for (let g = 0; g < G; g++) {
    const row = rows[g];
    const fams = model.unions
      .filter((u) => kidsOf(u).some((k) => gen.get(k) === g))
      .map((u) => {
        const ps = parentsOf(u);
        return { u, pos: ps.reduce((s, p) => s + (indexIn.get(p) ?? 0), 0) / ps.length };
      })
      .sort((a, b) => a.pos - b.pos);
    // sibships as lists of clusters (person + married-in partners)
    const famOf = new Map();
    fams.forEach(({ u }, i) => kidsOf(u).forEach((k) => famOf.set(k, i)));
    for (const [i, { u }] of fams.entries()) {
      const clusters = [];
      const donorsOfCluster = new Map();
      for (const k of kidsOf(u)) {
        if (gen.get(k) !== g || placed.has(k)) continue;
        const c = [], d = [];
        addCluster(k, c, d);
        clusters.push(c);
        donorsOfCluster.set(c, d);
      }
      // a sibling partnered with someone from another sibship moves to the
      // edge facing that sibship (stable: birth order kept otherwise)
      const score = (c) => {
        let s = 0, n = 0;
        for (const id of c) for (const un of unionsOf.get(id)) {
          const p = partnerOf(un, id);
          const j = p != null ? famOf.get(p) : undefined;
          if (j !== undefined && j !== i) { s += Math.sign(j - i); n++; }
        }
        return n ? s / n : 0;
      };
      if (!o.strictBirthOrder && model.options.order !== 'strict') clusters.sort((a, b) => score(a) - score(b));
      // donors of a sibling's children go to the nearest outer edge of the sibship,
      // so the sibship line never runs above them
      const before = [], after = [];
      clusters.forEach((c, j) => (j < clusters.length / 2 ? before : after).push(...donorsOfCluster.get(c)));
      row.push(...before.reverse());
      for (const c of clusters) row.push(...c);
      row.push(...after);
    }
    for (const id of declOrder) if (gen.get(id) === g) addCluster(id, row);
    row.forEach((id, i) => indexIn.set(id, i));
  }

  // ---------------------------------------------------------------- x placement
  const width = new Map(ids.map((id) => {
    const i = ind(id);
    const lw = Math.max(0, ...labelLines(i, lang).map((l) => textWidth(lineText(l), o.fontSize)));
    return [id, Math.max(2 * symbolHalfWidth(i, h), lw)];
  }));
  // a union label ("first cousins") must fit between the two partners
  const pairKey = (a, b) => (a < b ? `${a}\u0000${b}` : `${b}\u0000${a}`);
  const pairMin = new Map();
  // inbreeding coefficient on consanguineous unions (`inbreeding on`)
  const unionLabels = model.unions.map((u) => u.label);
  if (model.options?.inbreeding) {
    const phi = kinship(model);
    model.unions.forEach((u, i) => {
      if (!u.b || u.type !== 'consanguineous') return;
      const F = phi(u.a, u.b);
      if (F > 0) unionLabels[i] = [u.label, `F = ${fraction(F)}`].filter(Boolean).join(' · ');
    });
  }
  model.unions.forEach((u, i) => {
    if (u.b && unionLabels[i]) pairMin.set(pairKey(u.a, u.b), textWidth(unionLabels[i], o.fontSize - 1) + o.symbol + 16);
  });
  // the descent line drops halfway between partners: keep it clear of their labels
  for (const u of model.unions) {
    if (!u.b || !u.children.length) continue;
    const k = pairKey(u.a, u.b);
    pairMin.set(k, Math.max(pairMin.get(k) || 0, Math.max(width.get(u.a), width.get(u.b)) + 10));
  }
  const sep = (a, b) => Math.max(o.symbol + o.hgap, (width.get(a) + width.get(b)) / 2 + 14, pairMin.get(pairKey(a, b)) || 0);
  const stub = h + o.hgap / 2; // single-parent descent offset

  const x = new Map();
  for (const row of rows) {
    let cx = 0;
    row.forEach((id, i) => { if (i) cx += sep(row[i - 1], id); x.set(id, cx); });
  }

  // Partners with somebody between them (a third partner, a sibling…): the
  // partnership line goes over the symbols and the descent drops in the gap
  // beside the partner with fewer partnerships, not through whoever is between.
  const isRaised = (u) => !!u.b && gen.get(u.a) === gen.get(u.b)
    && Math.abs(indexIn.get(u.a) - indexIn.get(u.b)) > 1;
  const dropPair = (u) => {
    const p = unionsOf.get(u.a).length > unionsOf.get(u.b).length ? u.b : u.a;
    const other = p === u.a ? u.b : u.a;
    const row = rows[gen.get(p)];
    const n = row[indexIn.get(p) + (indexIn.get(other) > indexIn.get(p) ? 1 : -1)];
    return [p, n];
  };
  const unionMid = (u) => {
    if (!u.b) return x.get(u.a) + stub;
    if (isRaised(u)) { const [p, n] = dropPair(u); return (x.get(p) + x.get(n)) / 2; }
    return (x.get(u.a) + x.get(u.b)) / 2;
  };
  const kidsCenter = (u) => {
    const xs = kidsOf(u).map((k) => x.get(k));
    return (Math.min(...xs) + Math.max(...xs)) / 2;
  };

  const desire = (id) => {
    let sw = 0, s = 0;
    const add = (t, w) => { s += t * w; sw += w; };
    const pu = parentUnion.get(id);
    if (pu) add(unionMid(pu), 1);
    for (const u of unionsOf.get(id)) {
      const p = partnerOf(u, id);
      const side = p ? (x.get(id) < x.get(p) ? -1 : 1) : 0;
      if (p) add(x.get(p) + side * sep(id, p), 2);
      if (u.children.length) {
        const off = p && !isRaised(u) ? side * sep(id, p) / 2 : x.get(id) - unionMid(u);
        add(kidsCenter(u) + off, 1);
      }
    }
    for (const l of links) if (l.from === id) add(x.get(l.to), 0.5);
    if (!sw) add(x.get(id), 1);
    return { t: s / sw, w: sw };
  };

  const relax = (row) => {
    if (!row.length) return;
    const c = [0];
    for (let i = 1; i < row.length; i++) c.push(c[i - 1] + sep(row[i - 1], row[i]));
    const z = [], w = [];
    row.forEach((id, i) => { const d = desire(id); z.push(d.t - c[i]); w.push(d.w); });
    const y = isotonic(z, w);
    row.forEach((id, i) => x.set(id, y[i] + c[i]));
  };

  for (let it = 0; it < o.iterations; it++) {
    for (let g = 0; g < G; g++) relax(rows[g]);
    for (let g = G - 1; g >= 0; g--) relax(rows[g]);
  }
  // final top-down pass so children sit under parents
  for (let g = 0; g < G; g++) relax(rows[g]);

  // ---------------------------------------------------------------- y + bounds
  const labelH = rows.map((row) => Math.max(0, ...row.map((id) => labelLines(ind(id), lang).length * o.lineHeight + (ind(id).proband ? 12 : 0))));
  // header (NSGC): recorded by, historian, date, indication
  const header = HEADER_ORDER.filter((k) => model.header?.[k]).map((k) => [t(lang, `header.${k}`), model.header[k]]);
  const titleH = (model.title ? 34 : 0) + (header.length ? header.length * (o.lineHeight + 2) + 10 : 0);
  const rowY = [];
  // Raised partnership lines (somebody between the partners): spans that do not
  // overlap share a level; a row with raised lines gets room above it for them.
  const lanes = (spans) => {
    const ends = [];
    const out = new Map();
    for (const s of [...spans].sort((p, q) => p.lo - q.lo)) {
      let j = ends.findIndex((e) => e < s.lo - 6);
      if (j < 0) { j = ends.length; ends.push(0); }
      ends[j] = s.hi;
      out.set(s.i, j);
    }
    return { out, count: ends.length };
  };
  const raisedLevel = model.unions.map(() => 0);
  const extraTop = Array(G).fill(0);
  for (let g = 0; g < G; g++) {
    const spans = [];
    model.unions.forEach((u, i) => {
      if (isRaised(u) && gen.get(u.a) === g) {
        spans.push({ i, lo: Math.min(x.get(u.a), x.get(u.b)), hi: Math.max(x.get(u.a), x.get(u.b)) });
      }
    });
    if (!spans.length) continue;
    const { out, count } = lanes(spans);
    for (const [i, j] of out) raisedLevel[i] = j;
    extraTop[g] = 14 + 7 * count;
  }
  // Sibship lines of different unions over the same children's row: spans that
  // would overlap (one parent, several partners) go at different heights.
  const sibLane = model.unions.map(() => 0);
  const extraGap = Array(G).fill(0);
  for (let g = 0; g < G; g++) {
    const spans = [];
    model.unions.forEach((u, i) => {
      if (!u.children.length || gen.get(u.children[0].ids[0]) !== g) return;
      const xs = u.children.map((c) => c.ids.reduce((s, id) => s + x.get(id), 0) / c.ids.length);
      spans.push({ i, lo: Math.min(unionMid(u), ...xs), hi: Math.max(unionMid(u), ...xs) });
    });
    const { out, count } = lanes(spans);
    for (const [i, j] of out) sibLane[i] = j;
    extraGap[g] = Math.max(0, count - 3) * 9;
  }

  let y = o.margin + titleH + h + 10;
  for (let g = 0; g < G; g++) {
    y += extraTop[g];
    rowY.push(y);
    y += h + labelH[g] + o.vgap + h + 8 + (extraGap[g + 1] ?? 0);
  }

  let minX = Infinity, maxX = -Infinity;
  for (const id of ids) {
    const half = Math.max(width.get(id) / 2, h * 2.1); // proband arrow reach
    minX = Math.min(minX, x.get(id) - half);
    maxX = Math.max(maxX, x.get(id) + half);
  }
  for (const u of model.unions) if (!u.b) maxX = Math.max(maxX, x.get(u.a) + stub);
  if (!ids.length) { minX = 0; maxX = 0; }
  const dx = o.marginLeft - minX;

  const nodes = new Map();
  rows.forEach((row, g) => row.forEach((id, i) => {
    nodes.set(id, { id, ind: ind(id), x: x.get(id) + dx, y: rowY[g], gen: g, number: i + 1 });
  }));

  let contentBottom = G ? rowY[G - 1] + h + labelH[G - 1] + 6 : o.margin + titleH;
  // "no children" / "infertility" bars hang below their union
  for (const u of model.unions) {
    if (u.noChildren) contentBottom = Math.max(contentBottom, rowY[gen.get(u.a)] + h + (u.noChildren.reason ? 44 : 28));
  }
  return {
    lang,
    options: o,
    model,
    nodes,
    rows,
    rowY,
    unions: model.unions,
    unionLabels,
    raised: model.unions.map(isRaised),
    raisedLevel,
    sibLane,
    unionDrop: model.unions.map((u) => unionMid(u) + dx),
    links,
    header,
    width: Math.max(maxX + dx + o.margin, 200),
    contentBottom,
    stub,
  };
}

// Weighted isotonic regression (non-decreasing), pool-adjacent-violators.
function isotonic(z, w) {
  const blocks = [];
  for (let i = 0; i < z.length; i++) {
    blocks.push({ v: z[i], w: w[i], n: 1 });
    while (blocks.length > 1 && blocks[blocks.length - 2].v > blocks[blocks.length - 1].v) {
      const b = blocks.pop(), a = blocks.pop();
      blocks.push({ v: (a.v * a.w + b.v * b.w) / (a.w + b.w), w: a.w + b.w, n: a.n + b.n });
    }
  }
  const out = [];
  for (const b of blocks) for (let k = 0; k < b.n; k++) out.push(b.v);
  return out;
}

return { DEFAULTS, textWidth, isTriangle, isDiamond, TEST_MARK, lineText, fmtAge, labelLines, bracketPad, symbolHalfWidth, layout, isotonic };
})();

__m.describe = (() => {
// Plain-language description of a pedigree, for screen readers (SVG <desc>, Mermaid
// accDescr), report text and quick review. English + Italian.

const { relationship, describeRelationship, unionInbreeding, fraction } = __m.genetics;
const { fmtAge } = __m.layout;

const S = {
  en: {
    intro: (n, g, title) => `${title ? `${title}: p` : 'P'}edigree of ${n} ${n === 1 ? 'person' : 'people'} in ${g} generation${g === 1 ? '' : 's'}.`,
    proband: 'Proband', consultand: 'Consultand',
    sex: { M: 'male', F: 'female', NB: 'non-binary', U: 'sex unknown' },
    affectedWith: 'affected by', unaffected: 'unaffected', onset: 'onset', deceased: 'deceased',
    affectedRelatives: 'Affected relatives', noAffected: 'No affected relatives recorded.',
    tests: 'Genetic tests', consanguinity: 'Consanguineous couple', donor: 'conceived with a gamete donor',
    result: { P: 'pathogenic', LP: 'likely pathogenic', VUS: 'uncertain significance', LB: 'likely benign', B: 'benign', N: 'negative' },
    and: 'and',
  },
  it: {
    intro: (n, g, title) => `${title ? `${title}: a` : 'A'}lbero genealogico di ${n} ${n === 1 ? 'persona' : 'persone'} in ${g} generazion${g === 1 ? 'e' : 'i'}.`,
    proband: 'Probando', consultand: 'Consultante',
    sex: { M: 'maschio', F: 'femmina', NB: 'persona non binaria', U: 'sesso non noto' },
    affectedWith: 'affetto/a da', unaffected: 'non affetto/a', onset: 'esordio', deceased: 'deceduto/a',
    affectedRelatives: 'Parenti affetti', noAffected: 'Nessun parente affetto registrato.',
    tests: 'Test genetici', consanguinity: 'Coppia consanguinea', donor: 'concepito/a con donatore di gameti',
    result: { P: 'patogenetica', LP: 'probabilmente patogenetica', VUS: 'significato incerto', LB: 'probabilmente benigna', B: 'benigna', N: 'negativo' },
    and: 'e',
  },
};

const nameOf = (ind) => ind.labels?.[0] ?? ind.id;
// Italian agreement: "affetto/a" -> "affetta" for a woman, "affetto" for a man
const agree = (text, sex) => (sex === 'M' ? text.replace(/(\p{L}+)o\/a\b/gu, '$1o') : sex === 'F' ? text.replace(/(\p{L}+)o\/a\b/gu, '$1a') : text);

function conditionsText(model, ind, s, lang) {
  const parts = [
    ...(ind.conditions ?? []).map((c) => {
      const d = (c ? model.conditions.get(c) : model.conditions.get('')) || c || null;
      const o = ind.onset?.[c];
      return `${d ?? s.affectedWith.split(' ')[0]}${o != null ? ` (${s.onset} ${fmtAge(o, lang)})` : ''}`;
    }),
    ...(ind.dx ?? []).map((d) => `${d.name}${d.age != null ? ` (${s.onset} ${fmtAge(d.age, lang)})` : ''}`),
  ];
  return parts.join(', ');
}

/** Text paragraphs (array of sentences). `generations` defaults to a quick count. */
function describe(model, { lang = 'en', generations = null } = {}) {
  const s = S[lang] ?? S.en;
  const inds = [...model.individuals.values()].filter((i) => i.count == null);
  const out = [];
  const gens = generations ?? countGenerations(model);
  out.push(s.intro(inds.length, gens, model.title));

  const pb = inds.find((i) => i.proband) ?? inds.find((i) => i.consultand);
  if (pb) {
    const bits = [s.sex[pb.sex] ?? s.sex.U];
    if (pb.assigned) bits.push(pb.assigned);
    if (pb.age != null) bits.push(fmtAge(pb.age, lang));
    const conds = conditionsText(model, pb, s, lang);
    out.push(agree(`${pb.proband ? s.proband : s.consultand}: ${nameOf(pb)}, ${bits.join(', ')}, ${conds ? `${s.affectedWith} ${conds}` : s.unaffected}.`, pb.sex));
  }

  const affected = inds.filter((i) => i !== pb && ((i.conditions?.length ?? 0) > 0 || (i.dx?.length ?? 0) > 0));
  if (affected.length) {
    const items = affected.map((i) => {
      let rel = '';
      if (pb) { try { rel = describeRelationship(relationship(model, pb.id, i.id, lang), lang).split(' · ')[0]; } catch { rel = ''; } }
      return agree(`${rel ? `${rel}, ` : ''}${nameOf(i)}${i.deceased ? ` (${s.deceased})` : ''}: ${conditionsText(model, i, s, lang)}`, i.sex);
    });
    out.push(`${s.affectedRelatives}: ${items.join('; ')}.`);
  } else if (pb) out.push(s.noAffected);

  const tested = inds.filter((i) => i.tests?.length);
  if (tested.length) {
    const byTest = new Map();
    for (const i of tested) for (const x of i.tests) {
      const k = `${x.gene}${x.variant ? ` ${x.variant}` : ''} ${s.result[x.result]}`;
      byTest.set(k, [...(byTest.get(k) ?? []), nameOf(i)]);
    }
    out.push(`${s.tests}: ${[...byTest].map(([k, ids]) => `${k} (${ids.join(', ')})`).join('; ')}.`);
  }

  for (const x of unionInbreeding(model)) out.push(`${s.consanguinity} ${x.a} × ${x.b}${x.F ? ` (F = ${fraction(x.F)})` : ''}.`);
  const donorKids = [...new Set((model.links ?? []).map((l) => l.to))];
  for (const k of donorKids) out.push(agree(`${nameOf(model.individuals.get(k))}: ${s.donor}.`, model.individuals.get(k)?.sex));
  return out;
}

function countGenerations(model) {
  const memo = new Map();
  const parentsOf = (id) => {
    const u = model.unions.find((x) => x.children.some((g) => g.ids.includes(id)));
    return u ? [u.a, u.b].filter(Boolean) : [];
  };
  const depth = (id, guard = 0) => {
    if (memo.has(id)) return memo.get(id);
    if (guard > 500) return 0;
    const d = Math.max(-1, ...parentsOf(id).map((p) => depth(p, guard + 1))) + 1;
    memo.set(id, d);
    return d;
  };
  const ds = [...model.individuals.keys()].map((id) => depth(id));
  return ds.length ? Math.max(...ds) + 1 : 0;
}

const describeText = (model, opts) => describe(model, opts).join(' ');

return { describe, describeText };
})();

__m.render = (() => {
// SVG renderer for a laid-out pedigree. Output is a self-contained SVG string.
const { labelLines, lineText, symbolHalfWidth, isTriangle, isDiamond, bracketPad } = __m.layout;
const { t } = __m.i18n;
const { describeText } = __m.describe;

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const f = (n) => Math.round(n * 10) / 10;

const ROMAN = [[1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'], [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'], [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']];
function roman(n) {
  let s = '';
  for (const [v, r] of ROMAN) while (n >= v) { s += r; n -= v; }
  return s;
}

const line = (x1, y1, x2, y2, cls = 'ln') => `<line class="${cls}" x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}"/>`;

// ---------------------------------------------------------------- symbols
// NSGC: one quadrant (or half) per condition, consistent across the pedigree.
const SECTOR_LAYOUT = { 1: ['full'], 2: ['L', 'R'], 3: ['TL', 'TR', 'BR', 'BL'], 4: ['TL', 'TR', 'BR', 'BL'] };
function sectorMap(conditionOrder = []) {
  const pos = SECTOR_LAYOUT[Math.max(1, conditionOrder.length)];
  return new Map(conditionOrder.map((k, i) => [k, pos[i]]));
}

const shapeKind = (ind) => (isTriangle(ind) ? 'tri' : ind.sex === 'M' ? 'sq' : ind.sex === 'F' ? 'ci' : 'di');

function outline(kind, cx, cy, h, cls) {
  if (kind === 'tri') {
    const t = h * 0.8;
    return `<polygon class="${cls}" points="${f(cx)},${f(cy - t)} ${f(cx + t)},${f(cy + t * 0.75)} ${f(cx - t)},${f(cy + t * 0.75)}"/>`;
  }
  if (kind === 'sq') return `<rect class="${cls}" x="${f(cx - h)}" y="${f(cy - h)}" width="${f(2 * h)}" height="${f(2 * h)}"/>`;
  if (kind === 'ci') return `<circle class="${cls}" cx="${f(cx)}" cy="${f(cy)}" r="${f(h)}"/>`;
  const d = h * 1.2;
  return `<polygon class="${cls}" points="${f(cx)},${f(cy - d)} ${f(cx + d)},${f(cy)} ${f(cx)},${f(cy + d)} ${f(cx - d)},${f(cy)}"/>`;
}

function sector(kind, pos, cx, cy, h) {
  const poly = (pts) => `<polygon class="f-ink" points="${pts.map(([x, y]) => `${f(x)},${f(y)}`).join(' ')}"/>`;
  if (kind === 'sq') {
    const r = { L: [-h, -h, h, 2 * h], R: [0, -h, h, 2 * h], TL: [-h, -h, h, h], TR: [0, -h, h, h], BR: [0, 0, h, h], BL: [-h, 0, h, h] }[pos];
    return `<rect class="f-ink" x="${f(cx + r[0])}" y="${f(cy + r[1])}" width="${f(r[2])}" height="${f(r[3])}"/>`;
  }
  if (kind === 'ci') {
    const T = [cx, cy - h], B = [cx, cy + h], Lp = [cx - h, cy], Rp = [cx + h, cy];
    const arc = (from, to, sweep, large = 0) => `M${f(from[0])},${f(from[1])} A${f(h)},${f(h)} 0 ${large} ${sweep} ${f(to[0])},${f(to[1])}`;
    const d = {
      L: `${arc(T, B, 0)} Z`, R: `${arc(T, B, 1)} Z`,
      TL: `M${f(cx)},${f(cy)} L${f(Lp[0])},${f(Lp[1])} ${arc(Lp, T, 1).slice(arc(Lp, T, 1).indexOf('A'))} Z`,
      TR: `M${f(cx)},${f(cy)} L${f(T[0])},${f(T[1])} ${arc(T, Rp, 1).slice(arc(T, Rp, 1).indexOf('A'))} Z`,
      BR: `M${f(cx)},${f(cy)} L${f(Rp[0])},${f(Rp[1])} ${arc(Rp, B, 1).slice(arc(Rp, B, 1).indexOf('A'))} Z`,
      BL: `M${f(cx)},${f(cy)} L${f(B[0])},${f(B[1])} ${arc(B, Lp, 1).slice(arc(B, Lp, 1).indexOf('A'))} Z`,
    }[pos];
    return `<path class="f-ink" d="${d}"/>`;
  }
  // diamond
  const d = h * 1.2, C = [cx, cy], T = [cx, cy - d], B = [cx, cy + d], Lp = [cx - d, cy], Rp = [cx + d, cy];
  return poly({ L: [T, B, Lp], R: [T, B, Rp], TL: [C, T, Lp], TR: [C, T, Rp], BR: [C, Rp, B], BL: [C, B, Lp] }[pos]);
}

function symbol(ind, cx, cy, h, { fontSize = 12, idAttr = true, arrowId = 'ped-arrow', sectors = new Map() } = {}) {
  const kind = shapeKind(ind);
  const secs = (ind.conditions?.length ? ind.conditions : ind.affected ? [''] : []).map((c) => sectors.get(c) ?? 'full');
  const full = secs.length > 0 && (kind === 'tri' || secs.includes('full') || new Set(secs).size === 4);
  const partial = secs.length > 0 && !full;
  const out = [];

  if (partial) {
    out.push(outline(kind, cx, cy, h, 'f-paper'));
    for (const pos of new Set(secs)) out.push(sector(kind, pos, cx, cy, h));
    out.push(outline(kind, cx, cy, h, 'sym f-none'));
  } else {
    out.push(outline(kind, cx, cy, h, `sym f-${full ? 'ink' : 'paper'}`));
  }

  if (ind.carrier && !ind.affected) out.push(`<circle class="f-ink" cx="${f(cx)}" cy="${f(cy)}" r="${f(h * 0.2)}"/>`);
  if (ind.presymptomatic && kind !== 'tri') {
    const v = kind === 'di' ? h * 1.2 : h;
    out.push(line(cx, cy - v, cx, cy + v, full ? 'ln inv' : 'ln'));
  }

  const inside = ind.pregnancy ? 'P' : ind.count ?? (ind.donor ? 'D' : ind.surrogate ? 'S' : null);
  if (inside && kind !== 'tri') {
    const cls = full ? 'in f-paper' : partial ? 'in f-ink halo' : 'in f-ink';
    out.push(`<text class="${cls}" x="${f(cx)}" y="${f(cy)}" font-size="${fontSize}" text-anchor="middle" dominant-baseline="central">${esc(inside)}</text>`);
  }

  if (ind.deceased || ind.stillbirth || ind.termination) {
    const k = kind === 'tri' ? h * 1.05 : h * 1.35;
    out.push(line(cx - k, cy + k, cx + k, cy - k));
  }

  if (ind.adoptedIn || ind.adoptedOut) {
    const hw = (kind === 'di' ? h * 1.2 : h) + bracketPad(ind) - 2;
    const hh = (kind === 'di' ? h * 1.2 : h) + 4;
    for (const sgn of [-1, 1]) {
      const x = cx + sgn * hw;
      out.push(`<path class="ln" d="M${f(x - sgn * 5)},${f(cy - hh)} H${f(x)} V${f(cy + hh)} H${f(x - sgn * 5)}"/>`);
    }
  }

  if (ind.evaluated) {
    out.push(`<text class="mark" x="${f(cx + symbolHalfWidth(ind, h) + 1)}" y="${f(cy + h + 6)}">*</text>`);
  }

  if (ind.proband || ind.consultand) {
    const tip = (kind === 'ci' ? 0.74 : kind === 'di' ? 0.62 : kind === 'tri' ? 0.5 : 1.0) * h + 3 + bracketPad(ind);
    const x1 = cx - tip - 13, y1 = cy + tip + 11;
    out.push(`<line class="ln" marker-end="url(#${arrowId})" x1="${f(x1)}" y1="${f(y1)}" x2="${f(cx - tip)}" y2="${f(cy + tip)}"/>`);
    if (ind.proband) out.push(`<text class="pmark" x="${f(x1 - 1)}" y="${f(y1 + 3)}" text-anchor="end">P</text>`);
  }

  const attr = idAttr ? ` data-id="${esc(ind.id)}"` : '';
  // ontology codes travel with the symbol (tooltip + data attribute)
  const hpo = idAttr && ind.hpo?.length ? ` data-hpo="${esc(ind.hpo.join(' '))}"` : '';
  const tip = idAttr && ind.hpo?.length ? `<title>${esc(`${ind.id}: ${ind.hpo.join(', ')}`)}</title>` : '';
  return `<g class="ind"${attr}${hpo}>${tip}${out.join('')}</g>`;
}

// top attachment point of a symbol (where the individual line ends)
function topY(ind, cy, h) {
  if (isTriangle(ind)) return cy - h * 0.8;
  if (isDiamond(ind)) return cy - h * 1.2;
  return cy - h;
}

// ---------------------------------------------------------------- main
const DEFAULT_THEME = {
  ink: '#111', paper: '#fff', muted: '#666', border: '#888',
  fontFamily: 'Helvetica, Arial, sans-serif',
};

/** CSS for a pedigree. `scope` is prepended to every selector ('' when the host scopes it, e.g. Mermaid). */
function css({ scope = '.ped', fontSize = 12, theme = {} } = {}) {
  const t = { ...DEFAULT_THEME, ...theme };
  const s = scope ? `${scope} ` : '';
  return [
    scope ? `${scope}{font-family:${t.fontFamily}}` : `text{font-family:${t.fontFamily}}`,
    `${s}.bg,${s}.f-paper{fill:${t.paper}}`,
    `${s}.f-ink{fill:${t.ink}}`,
    `${s}.sym{stroke:${t.ink};stroke-width:1.6}`,
    `${s}.ln{stroke:${t.ink};stroke-width:1.4;fill:none}`,
    `${s}text{fill:${t.ink};font-size:${fontSize}px}`,
    `${s}text.f-paper{fill:${t.paper}}`,
    `${s}.lbl{paint-order:stroke;stroke:${t.paper};stroke-width:3px;stroke-linejoin:round}`,
    `${s}.num{fill:${t.muted};font-size:${fontSize - 2}px}`,
    `${s}.gen{font-weight:700;font-size:${fontSize + 2}px}`,
    `${s}.title{font-weight:700;font-size:${fontSize + 4}px}`,
    `${s}.lgbox{fill:none;stroke:${t.border};stroke-width:.8}`,
    `${s}.f-none{fill:none}`,
    `${s}.hit{stroke:transparent;stroke-width:12;fill:none}`,
    `${s}.ln.dash{stroke-dasharray:5 3}`,
    `${s}.ln.inv{stroke:${t.paper}}`,
    `${s}.halo{paint-order:stroke;stroke:${t.paper};stroke-width:3px}`,
    `${s}.mark{font-size:${fontSize + 4}px;font-weight:700}`,
    `${s}.pmark{font-weight:700}`,
    `${s}.rel{font-size:${fontSize - 1}px;font-style:italic}`,
    `${s}.hdr{font-size:${fontSize - 1}px}`,
    `${s}.gt{font-size:${fontSize - 1}px}`,
    `${s}.gt.pos{font-weight:700}`,
    `${s}.hdrk{fill:${t.muted}}`,
  ].join('\n');
}

/** Standalone SVG document string. */
function render(L, { idPrefix = 'ped', theme } = {}) {
  const p = renderParts(L, { idPrefix });
  // accessible name + plain-language description for screen readers
  let desc = '';
  try { desc = describeText(L.model, { lang: L.lang, generations: L.rows.length }); } catch { desc = ''; }
  return `<svg xmlns="http://www.w3.org/2000/svg" class="ped" width="${f(p.width)}" height="${f(p.height)}" viewBox="0 0 ${f(p.width)} ${f(p.height)}" role="img" aria-labelledby="${idPrefix}-title ${idPrefix}-desc">
<title id="${idPrefix}-title">${esc(L.model.title || 'Pedigree')}</title>
<desc id="${idPrefix}-desc">${esc(desc)}</desc>
<style>${css({ scope: '.ped', fontSize: L.options.fontSize, theme })}</style>
<defs>${p.defs}</defs>
<rect class="bg" width="100%" height="100%"/>
${p.body}
</svg>`;
}

/** Drawing split in pieces, for hosts (Mermaid) that own the <svg> element. */
function renderParts(L, { idPrefix = 'ped' } = {}) {
  const arrowId = `${idPrefix}-arrow`;
  const sectors = sectorMap(L.model.conditionOrder);
  const o = L.options;
  const h = o.symbol / 2;
  const { nodes, model } = L;
  const N = (id) => nodes.get(id);
  const parts = [];

  // ---- relationship + descent lines
  const allParts = parts;
  L.unions.forEach((u, ui) => {
    // each union is its own group (clickable in the editor) with a wide transparent hit line
    const parts = [];
    const hits = [];
    const flush = () => allParts.push(`<g class="union" data-union="${ui}">${hits.join('')}${parts.join('')}</g>`);
    const a = N(u.a);
    const kids = u.children;
    let mx, startY;
    if (u.b && L.raised?.[ui]) {
      // somebody stands between the partners: the line goes over them
      const b = N(u.b);
      const y = a.y - h - 14 - 7 * (L.raisedLevel?.[ui] ?? 0);
      const d = `M${f(a.x)},${f(topY(a.ind, a.y, h))} V${f(y)} H${f(b.x)} V${f(topY(b.ind, b.y, h))}`;
      parts.push(`<path class="ln" d="${d}"/>`);
      if (u.type === 'consanguineous') parts.push(line(Math.min(a.x, b.x), y - 4, Math.max(a.x, b.x), y - 4));
      hits.push(`<path class="hit" d="${d}"/>`);
      mx = L.unionDrop[ui];
      const ulabel = L.unionLabels?.[ui] ?? u.label;
      if (ulabel) parts.push(`<text class="rel lbl" x="${f((a.x + b.x) / 2)}" y="${f(y - (u.type === 'consanguineous' ? 8 : 4))}" text-anchor="middle">${esc(ulabel)}</text>`);
      if (u.type === 'divorce') {
        const sx = mx + (Math.abs(a.x - mx) < Math.abs(b.x - mx) ? 1 : -1) * 14;
        for (const s of [-3, 3]) parts.push(line(sx + s - 5, y + 8, sx + s + 5, y - 8));
      }
      startY = y;
    } else if (u.b) {
      const b = N(u.b);
      const [l, r] = a.x <= b.x ? [a, b] : [b, a];
      const y = l.y;
      const x1 = l.x + symbolHalfWidth(l.ind, h), x2 = r.x - symbolHalfWidth(r.ind, h);
      mx = (l.x + r.x) / 2;
      hits.push(line(x1, y, x2, y, 'hit'));
      if (u.type === 'consanguineous') {
        parts.push(line(x1, y - 3, x2, y - 3), line(x1, y + 3, x2, y + 3));
      } else {
        parts.push(line(x1, y, x2, y));
      }
      const ulabel = L.unionLabels?.[ui] ?? u.label;
      if (ulabel) {
        parts.push(`<text class="rel lbl" x="${f(mx)}" y="${f(y - (u.type === 'consanguineous' ? 9 : 6))}" text-anchor="middle">${esc(ulabel)}</text>`);
      }
      if (u.type === 'divorce') {
        const sx = kids.length || u.noChildren ? mx - Math.min(14, (x2 - x1) / 4) : mx;
        for (const k of [-3, 3]) parts.push(line(sx + k - 5, y + 8, sx + k + 5, y - 8));
      }
      startY = u.type === 'consanguineous' ? y + 3 : y;
    } else {
      // single known parent: short stub to the right, then down
      mx = a.x + L.stub;
      startY = a.y;
      hits.push(line(a.x + symbolHalfWidth(a.ind, h), a.y, mx, a.y, 'hit'));
      if (kids.length || u.noChildren) parts.push(line(a.x + symbolHalfWidth(a.ind, h), a.y, mx, a.y));
    }
    if (u.noChildren) {
      // NSGC: no children by choice = one bar; infertility = two bars
      const by = a.y + h + 12;
      parts.push(line(mx, startY, mx, by), line(mx - 11, by, mx + 11, by));
      if (u.noChildren.kind === 'infertile') parts.push(line(mx - 11, by + 4, mx + 11, by + 4));
      if (u.noChildren.reason) {
        parts.push(`<text class="lbl rel" x="${f(mx)}" y="${f(by + 17)}" text-anchor="middle">${esc(u.noChildren.reason)}</text>`);
      }
      hits.push(line(mx, startY, mx, by, 'hit'));
      return flush();
    }
    if (!kids.length) return flush();

    const childRowTop = Math.min(...kids.flatMap((g) => g.ids).map((id) => N(id).y)) - h;
    const sibY = childRowTop - Math.min(26, o.vgap * 0.42) - 9 * (L.sibLane?.[ui] ?? 0);
    parts.push(line(mx, startY, mx, sibY));
    hits.push(line(mx, startY, mx, sibY, 'hit'));

    const attach = kids.map((g) => g.ids.reduce((s, id) => s + N(id).x, 0) / g.ids.length);
    const lo = Math.min(mx, ...attach), hi = Math.max(mx, ...attach);
    if (hi - lo > 0.5) parts.push(line(lo, sibY, hi, sibY));

    kids.forEach((g, i) => {
      const ax = attach[i];
      if (g.kind === 'single') {
        const c = N(g.ids[0]);
        parts.push(line(ax, sibY, ax, topY(c.ind, c.y, h), c.ind.adoptedIn ? 'ln dash' : 'ln'));
        return;
      }
      const ends = g.ids.map((id) => { const c = N(id); return [c.x, topY(c.ind, c.y, h)]; });
      for (const [ex, ey] of ends) parts.push(line(ax, sibY, ex, ey));
      if (g.kind === 'unknown') {
        parts.push(`<text class="lbl" x="${f(ax)}" y="${f(sibY + 15)}" text-anchor="middle">?</text>`);
      }
      if (g.kind === 'mz') {
        const t = 0.42;
        const xs = ends.map(([ex]) => ax + (ex - ax) * t);
        const ys = ends.map(([, ey]) => sibY + (ey - sibY) * t);
        parts.push(line(Math.min(...xs), Math.max(...ys), Math.max(...xs), Math.max(...ys)));
      }
    });
    flush();
  });

  // ---- ART: donor / gestational carrier -> child (no partnership line, NSGC)
  for (const l of L.links ?? []) {
    const d = N(l.from), c = N(l.to);
    const dir = c.x >= d.x ? 1 : -1;
    const ty = topY(c.ind, c.y, h);
    const ly = ty - Math.min(12, o.vgap * 0.18);
    // straight down from the donor when nothing is written below it, else from its side
    const below = labelLines(d.ind, L.lang).length === 0 && !d.ind.proband && !d.ind.consultand;
    const start = below
      ? `M${f(d.x)},${f(d.y + (isDiamond(d.ind) ? h * 1.2 : h))}`
      : `M${f(d.x + dir * symbolHalfWidth(d.ind, h))},${f(d.y)} H${f(d.x + dir * L.stub)}`;
    parts.push(`<g class="art" data-from="${esc(l.from)}" data-to="${esc(l.to)}"><path class="ln" d="${start} V${f(ly)} H${f(c.x)} V${f(ty)}"/></g>`);
  }

  // ---- individuals, labels, numbers
  for (const n of nodes.values()) {
    parts.push(symbol(n.ind, n.x, n.y, h, { fontSize: o.fontSize, arrowId, sectors }));
    const lines = labelLines(n.ind, L.lang);
    const by = n.y + (isTriangle(n.ind) ? h * 0.6 : isDiamond(n.ind) ? h * 1.2 : h) + o.lineHeight + (n.ind.proband || n.ind.consultand ? 12 : 0) + (n.ind.adoptedIn || n.ind.adoptedOut ? 4 : 0);
    lines.forEach((t, i) => {
      const cls = typeof t === 'string' ? 'lbl' : `lbl ${t.cls}`;
      parts.push(`<text class="${cls}" x="${f(n.x)}" y="${f(by + i * o.lineHeight)}" text-anchor="middle">${esc(lineText(t))}</text>`);
    });
    if (model.options.numbering) {
      const hw = symbolHalfWidth(n.ind, h);
      parts.push(`<text class="num" x="${f(n.x - hw - 3)}" y="${f(n.y - h - 3)}" text-anchor="end">${n.number}</text>`);
    }
  }

  // ---- generation numerals
  if (model.options.numbering) {
    L.rowY.forEach((y, g) => {
      parts.push(`<text class="gen" x="14" y="${f(y)}" dominant-baseline="central">${roman(g + 1)}</text>`);
    });
  }

  // ---- title
  if (model.title) {
    parts.push(`<text class="title" x="${o.marginLeft}" y="${o.margin + 12}">${esc(model.title)}</text>`);
  }
  // ---- header (recorded by, historian, date, indication)
  (L.header ?? []).forEach(([k, v], i) => {
    const y = o.margin + (model.title ? 34 : 0) + 4 + i * (o.lineHeight + 2);
    parts.push(`<text class="hdr" x="${o.marginLeft}" y="${f(y)}"><tspan class="hdrk">${esc(k)}:</tspan> ${esc(v)}</text>`);
  });

  // ---- legend
  let height = L.contentBottom + o.margin;
  let width = L.width;
  if (model.options.legend) {
    const lg = legend(model, o, L.contentBottom + 26, arrowId, sectors, L.lang);
    if (lg) {
      parts.push(lg.svg);
      height = lg.bottom + o.margin;
      width = Math.max(width, lg.right + o.margin);
    }
  }

  const defs = `<marker id="${arrowId}" viewBox="0 0 10 10" refX="9" refY="5" markerUnits="userSpaceOnUse" markerWidth="9" markerHeight="9" orient="auto-start-reverse"><path class="f-ink" d="M0,0 L10,5 L0,10 z"/></marker>`;
  return { width, height, defs, body: parts.join('\n') };
}

// ---------------------------------------------------------------- legend
function legend(model, o, top, arrowId, sectors, lang = 'en') {
  const T = (k, v) => t(lang, `legend.${k}`, v);
  const inds = [...model.individuals.values()];
  const first = (k) => inds.find((i) => i[k]);
  const items = [];
  const base = { id: '', sex: 'U', labels: [], count: null, conditions: [] };
  const add = (k, label, extra = {}) => {
    const i = first(k);
    if (i) items.push([{ ...base, sex: i.sex, ...extra }, label]);
  };

  const order = model.conditionOrder || [];
  const sexOf = (c) => (inds.find((i) => i.conditions.includes(c)) || {}).sex || 'M';
  const codes = (c) => (model.conditionCodes?.get(c)?.length ? ` (${model.conditionCodes.get(c).join(', ')})` : '');
  // named conditions show their key, so "BC dx 47y" below a symbol can be decoded
  const named = (c) => (c && model.conditions.get(c) && model.conditions.get(c) !== c ? `${c}: ${model.conditions.get(c)}` : model.conditions.get(c) || c);
  if (order.length === 1) {
    const d = named(order[0]);
    items.push([{ ...base, sex: sexOf(order[0]), affected: true, conditions: [order[0]] }, (d ? T('affectedWith', { c: d }) : T('affected')) + codes(order[0])]);
  } else {
    for (const c of order) items.push([{ ...base, sex: 'M', affected: true, conditions: [c] }, (named(c) || T('affected')) + codes(c)]);
  }
  if (inds.some((i) => i.sex === 'NB')) items.push([{ ...base, sex: 'NB' }, T('nonBinary')]);
  add('carrier', T('carrier'), { carrier: true });
  add('presymptomatic', T('presymptomatic'), { presymptomatic: true });
  add('evaluated', T('evaluated'), { evaluated: true });
  add('deceased', T('deceased'), { deceased: true });
  add('stillbirth', T('stillbirth'), { stillbirth: true });
  if (first('pregnancy')) items.push([{ ...base, pregnancy: true }, T('pregnancy')]);
  if (first('miscarriage')) items.push([{ ...base, miscarriage: true }, T('miscarriage')]);
  if (first('termination')) items.push([{ ...base, termination: true }, T('termination')]);
  if (first('ectopic')) items.push([{ ...base, ectopic: true }, T('ectopic')]);
  if (inds.some((i) => i.count)) items.push([{ ...base, count: 'n' }, T('multiple')]);
  add('adoptedIn', T('adoptedIn'), { adoptedIn: true });
  add('adoptedOut', T('adoptedOut'), { adoptedOut: true });
  add('donor', T('donor'), { donor: true });
  add('surrogate', T('surrogate'), { surrogate: true });
  add('proband', T('proband'), { proband: true });
  add('consultand', T('consultand'), { consultand: true });
  if ((model.links ?? []).length) items.push([{ art: true }, T('art')]);
  for (const a of ['AMAB', 'AFAB', 'UAAB']) if (inds.some((i) => i.assigned === a)) items.push([{ text: a }, T(a)]);
  if (inds.some((i) => i.vsc)) items.push([{ text: 'VSC' }, T('vsc')]);
  const results = new Set(inds.flatMap((i) => (i.tests ?? []).map((x) => x.result)));
  if (results.has('P') || results.has('LP')) items.push([{ text: '+' }, T('testPos')]);
  if (results.has('VUS')) items.push([{ text: 'VUS' }, T('testVus')]);
  if (results.has('N') || results.has('B') || results.has('LB')) items.push([{ text: '\u2013' }, T('testNeg')]);
  const nc = model.unions.map((u) => u.noChildren?.kind).filter(Boolean);
  if (nc.includes('none')) items.push([{ bars: 1 }, T('noChildren')]);
  if (nc.includes('infertile')) items.push([{ bars: 2 }, T('infertility')]);
  if (!items.length) return null;

  const h = 9, rowH = 28, x0 = o.marginLeft;
  const parts = [`<text x="${x0}" y="${top + 4}" font-weight="700">${esc(T('title'))}</text>`];
  let right = x0 + 40;
  items.forEach(([ind, label], i) => {
    const cy = top + 26 + i * rowH;
    const cx = x0 + 22;
    if (ind.text) {
      parts.push(`<text x="${cx}" y="${cy}" text-anchor="middle" dominant-baseline="central" font-size="${o.fontSize - 2}">${esc(ind.text)}</text>`);
    } else if (ind.art) {
      parts.push(`<path class="ln" d="M${cx - 12},${cy - 8} H${cx - 4} V${cy + 4} H${cx + 12} V${cy + 10}"/>`);
    } else if (ind.bars) {
      parts.push(line(cx, cy - 10, cx, cy + 4), line(cx - 8, cy + 4, cx + 8, cy + 4));
      if (ind.bars === 2) parts.push(line(cx - 8, cy + 8, cx + 8, cy + 8));
    } else {
      parts.push(symbol(ind, cx, cy, h, { fontSize: 9, idAttr: false, arrowId, sectors }));
      if (ind.code) parts.push(`<text x="${cx}" y="${cy + h * 1.2 + 8}" text-anchor="middle" font-size="7">${esc(ind.code)}</text>`);
    }
    parts.push(`<text x="${cx + 26}" y="${cy}" dominant-baseline="central">${esc(label)}</text>`);
    right = Math.max(right, cx + 26 + label.length * o.fontSize * 0.58);
  });
  const bottom = top + 26 + (items.length - 1) * rowH + 26;
  parts.unshift(`<rect class="lgbox" x="${x0 - 10}" y="${top - 12}" width="${f(right - x0 + 20)}" height="${f(bottom - top + 12)}" rx="4"/>`);
  return { svg: `<g class="legend">${parts.join('')}</g>`, bottom, right: right + 10 };
}

return { roman, sectorMap, symbol, DEFAULT_THEME, css, render, renderParts };
})();

__m.serialize = (() => {
// Model -> DSL source. parse(serialize(m)) is equivalent to m.
// Comments and original formatting are not preserved (the editor regenerates the text).
const { FLAG_KEYWORDS } = __m.parser;

const ID = /^[\p{L}_][\p{L}\p{N}_]*$/u;
const q = (s) => `"${String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;

const val = (v) => (typeof v === 'number' || ID.test(String(v)) ? String(v) : q(v));
const NUM = /^\d+$/;

function serializeIndividual(ind) {
  const parts = [ind.sex];
  if (ind.assigned) parts.push(ind.assigned);
  const conds = ind.conditions?.length ? ind.conditions : ind.affected ? [''] : [];
  const onset = ind.onset ?? {};
  const age = (a) => (a == null || a === '' ? '' : `:${typeof a === 'number' || NUM.test(String(a)) ? a : q(a)}`);
  if (conds.includes('')) parts.push(onset[''] != null && NUM.test(String(onset[''])) ? `affected:${onset['']}` : 'affected');
  const list = [
    ...conds.filter((c) => c !== '').map((c) => `${c}${age(onset[c])}`),
    ...(ind.dx ?? []).map((d) => `${q(d.name)}${age(d.age)}`),
  ];
  if (list.length) parts.push(`affected=${list.join(',')}`);
  for (const [prop, kw] of Object.entries(FLAG_KEYWORDS)) {
    if (prop === 'deceased' && ind.died != null) continue; // implied by died=
    if (ind[prop]) parts.push(kw);
  }
  if (ind.count != null) parts.push(ind.count === 'n' ? 'n' : `n=${ind.count}`);
  for (const k of ['karyotype', 'born', 'age', 'died', 'cause']) if (ind[k] != null && ind[k] !== '') parts.push(`${k}=${val(ind[k])}`);
  if (ind.tests?.length) parts.push(`test=${ind.tests.map((t) => `${ID.test(t.gene) ? t.gene : q(t.gene)}:${t.variant ? `${q(t.variant)}:` : ''}${t.result}`).join(',')}`);
  if (ind.hpo?.length) parts.push(`hpo=${ind.hpo.join(',')}`);
  for (const l of ind.labels) parts.push(q(l));
  return `${ind.id} : ${parts.join(' ')}`;
}

function childGroup(g) {
  if (g.kind === 'single') return g.ids[0];
  const fn = g.kind === 'unknown' ? 'twins' : g.kind;
  return `${fn}(${g.ids.join(', ')})`;
}

const HEADER_OUT = { recordedBy: 'recorded_by', historian: 'historian', date: 'date', indication: 'indication' };
const OPS = { partner: '--', divorce: '-/-', consanguineous: '==' };

function serializeUnion(u) {
  let s = u.b ? `${u.a} ${OPS[u.type] || '--'} ${u.b}` : u.a;
  if (u.b && u.label) s += ` ${q(u.label)}`;
  if (u.children.length) s += ` => ${u.children.map(childGroup).join(', ')}`;
  else if (u.noChildren) s += ` => ${u.noChildren.kind}${u.noChildren.reason ? ` ${q(u.noChildren.reason)}` : ''}`;
  else if (!u.b) return null; // lone parent with nothing to say
  return s;
}

function serialize(model) {
  const out = ['pedigree'];
  if (model.title) out.push(`  title ${model.title}`);
  for (const [k, kw] of Object.entries(HEADER_OUT)) if (model.header?.[k]) out.push(`  ${kw} ${model.header[k]}`);
  const codes = (k) => (model.conditionCodes?.get(k)?.length ? ` ${model.conditionCodes.get(k).join(', ')}` : '');
  for (const [k, v] of model.conditions ?? []) {
    if (k === '') { if (v) out.push(`  condition ${q(v)}${codes('')}`); }
    else if (ID.test(k)) out.push(`  condition ${k} ${q(v ?? k)}${codes(k)}`);
  }
  if (model.condition && !model.conditions?.has('')) out.push(`  condition ${q(model.condition)}`);
  if (model.options?.numbering === false) out.push('  numbering off');
  if (model.options?.legend === false) out.push('  legend off');
  if (model.options?.order === 'strict') out.push('  order strict');
  if (model.options?.lang) out.push(`  lang ${model.options.lang}`);
  if (model.options?.partners && model.options.partners !== 'sex') out.push(`  partners ${model.options.partners}`);
  if (model.options?.inheritance) out.push(`  inheritance ${model.options.inheritance.pattern}${model.options.inheritance.condition ? ` ${model.options.inheritance.condition}` : ''}`);
  if (model.options?.inbreeding) out.push('  inbreeding on');
  const lay = Object.entries(model.options?.layout ?? {});
  if (lay.length) out.push(`  layout ${lay.map(([k, v]) => `${k}=${v}`).join(' ')}`);

  const inds = [...model.individuals.values()].sort((a, b) => a.order - b.order);
  if (inds.length) out.push('');
  for (const ind of inds) out.push(`  ${serializeIndividual(ind)}`);

  const rels = model.unions.map(serializeUnion).filter(Boolean);
  // ART links, grouped by donor
  const byDonor = new Map();
  for (const l of model.links ?? []) byDonor.set(l.from, [...(byDonor.get(l.from) ?? []), l.to]);
  for (const [from, to] of byDonor) rels.push(`${from} -> ${to.join(', ')}`);
  if (rels.length) out.push('');
  for (const r of rels) out.push(`  ${r}`);
  return out.join('\n') + '\n';
}

return { serializeIndividual, serializeUnion, serialize };
})();

__m.privacy = (() => {
// De-identification (GDPR art. 9: genetic data are a special category; a pedigree also
// holds data about relatives who did not consent). Non-destructive: returns a new model.
//
//   identifiable    unchanged
//   pseudonymised   ids -> generation numbering (II_3), free labels / title / historian removed;
//                   clinical data kept (years, ages, diagnoses, tests)
//   publication     as pseudonymised + birth / death years dropped, ages and ages at onset
//                   in 10-year bands, header reduced to the indication

const { parse } = __m.parser;
const { serialize } = __m.serialize;
const { layout } = __m.layout;
const { roman } = __m.render;

const PRIVACY_LEVELS = ['identifiable', 'pseudonymised', 'publication'];

const band = (a) => {
  const n = typeof a === 'number' ? a : /^\d+$/.test(String(a ?? '')) ? Number(a) : null;
  if (n == null) return a == null ? null : String(a).replace(/\d/g, '…');
  const lo = Math.floor(n / 10) * 10;
  return `${lo}-${lo + 9}`;
};

/** Rename every reference to individual ids (unions, children, ART links, onset keys stay). */
function renameAll(model, map) {
  model.individuals = new Map([...model.individuals].map(([k, v]) => [map.get(k) ?? k, Object.assign(v, { id: map.get(k) ?? k })]));
  for (const u of model.unions) {
    u.a = map.get(u.a) ?? u.a;
    if (u.b) u.b = map.get(u.b) ?? u.b;
    for (const g of u.children) g.ids = g.ids.map((x) => map.get(x) ?? x);
  }
  for (const l of model.links ?? []) { l.from = map.get(l.from) ?? l.from; l.to = map.get(l.to) ?? l.to; }
  return model;
}

/**
 * De-identified copy of a model. Returns { model, map } where map is original id -> new id
 * (keep it apart from the shared document if re-identification must stay possible).
 */
function anonymize(model, { level = 'pseudonymised' } = {}) {
  if (!PRIVACY_LEVELS.includes(level)) throw new Error(`privacy level must be one of: ${PRIVACY_LEVELS.join(', ')}`);
  const m = parse(serialize(model)); // deep copy
  const map = new Map();
  if (level === 'identifiable') return { model: m, map };

  const L = layout(m);
  for (const n of L.nodes.values()) map.set(n.id, `${roman(n.gen + 1)}_${n.number}`);
  renameAll(m, map);

  m.title = null;
  m.options.numbering = true;
  delete m.header.historian;
  for (const ind of m.individuals.values()) ind.labels = [];

  if (level === 'publication') {
    m.header = m.header.indication ? { indication: m.header.indication } : {};
    for (const ind of m.individuals.values()) {
      if (ind.died != null) ind.deceased = true;
      ind.born = null;
      ind.died = null;
      ind.age = band(ind.age);
      for (const k of Object.keys(ind.onset ?? {})) ind.onset[k] = band(ind.onset[k]);
      for (const d of ind.dx ?? []) d.age = band(d.age);
    }
  }
  return { model: m, map };
}

return { PRIVACY_LEVELS, renameAll, anonymize };
})();

__m.json = (() => {
// JSON form of a pedigree (schema/pedigree.schema.json), meant for LLM structured output
// and APIs. fromJSON validates through the DSL parser, so anything it accepts renders.

const { parse, createIndividual, FLAG_KEYWORDS } = __m.parser;
const { serialize } = __m.serialize;

const KW_TO_PROP = Object.fromEntries(Object.entries(FLAG_KEYWORDS).map(([p, k]) => [k, p]));
const STATUS = Object.keys(KW_TO_PROP).filter((k) => !['proband', 'consultand'].includes(k));

/** Model -> plain JSON object. */
function toJSON(model) {
  const out = {};
  if (model.title) out.title = model.title;
  if (model.options?.lang) out.lang = model.options.lang;
  if (Object.keys(model.header ?? {}).some((k) => model.header[k])) out.header = { ...model.header };
  const conditions = [...(model.conditions ?? [])].filter(([k, v]) => k || v).map(([key, name]) => ({
    key, name: name ?? key, ...(model.conditionCodes?.get(key)?.length ? { codes: model.conditionCodes.get(key) } : {}),
  }));
  if (conditions.length) out.conditions = conditions;
  out.individuals = [...model.individuals.values()].sort((a, b) => a.order - b.order).map((i) => {
    const o = { id: i.id, sex: i.sex };
    if (i.assigned) o.assignedAtBirth = i.assigned;
    if (i.proband) o.proband = true;
    if (i.consultand) o.consultand = true;
    const status = STATUS.filter((k) => i[KW_TO_PROP[k]] && !(k === 'deceased' && i.died != null));
    if (status.length) o.status = status;
    if (i.labels.length) o.labels = [...i.labels];
    for (const [k, j] of [['born', 'born'], ['age', 'age'], ['died', 'died'], ['cause', 'causeOfDeath'], ['karyotype', 'karyotype']]) if (i[k] != null) o[j] = i[k];
    if (i.count != null) o.count = i.count === 'n' ? 'n' : Number(i.count) || i.count;
    if (i.conditions.length) o.conditions = i.conditions.map((key) => ({ key, ...(i.onset?.[key] != null ? { onset: i.onset[key] } : {}) }));
    if (i.dx?.length) o.diagnoses = i.dx.map((d) => ({ name: d.name, ...(d.age != null ? { onset: d.age } : {}) }));
    if (i.tests?.length) o.tests = i.tests.map((x) => ({ gene: x.gene, ...(x.variant ? { variant: x.variant } : {}), result: x.result }));
    if (i.hpo?.length) o.hpo = [...i.hpo];
    return o;
  });
  out.unions = model.unions.map((u) => {
    const o = { partners: [u.a, u.b].filter(Boolean) };
    if (u.b && u.type !== 'partner') o.type = u.type;
    if (u.label) o.note = u.label;
    if (u.children.length) o.children = u.children.map((g) => (g.kind === 'single' ? g.ids[0] : { twins: g.kind === 'unknown' ? 'unknown' : g.kind, ids: [...g.ids] }));
    if (u.noChildren) o.noChildren = { kind: u.noChildren.kind, ...(u.noChildren.reason ? { reason: u.noChildren.reason } : {}) };
    return o;
  });
  if (model.links?.length) out.donations = model.links.map((l) => ({ donor: l.from, child: l.to }));
  const opts = {};
  if (model.options?.inheritance) opts.inheritance = { ...model.options.inheritance };
  if (model.options?.partners === 'written') opts.partners = 'written';
  if (model.options?.inbreeding) opts.inbreeding = true;
  if (model.options?.numbering === false) opts.numbering = false;
  if (model.options?.legend === false) opts.legend = false;
  if (Object.keys(opts).length) out.options = opts;
  return out;
}

const fail = (path, msg) => { throw new Error(`${path}: ${msg}`); };

/** JSON -> model (validated: the result is re-parsed from DSL). Returns { model, source }. */
function fromJSON(json) {
  const j = typeof json === 'string' ? JSON.parse(json) : json;
  if (!j || typeof j !== 'object') fail('$', 'expected an object');
  if (!Array.isArray(j.individuals)) fail('$.individuals', 'required array');
  const m = parse('pedigree');
  if (j.title) m.title = String(j.title);
  if (j.lang) m.options.lang = j.lang;
  m.header = { ...(j.header ?? {}) };
  for (const [n, c] of (j.conditions ?? []).entries()) {
    const key = c.key ?? '';
    if (key && !/^[\p{L}_][\p{L}\p{N}_]*$/u.test(key)) fail(`$.conditions[${n}].key`, `'${key}' is not a valid key (letters, digits, _)`);
    m.conditions.set(key, c.name ?? key);
    if (!key) m.condition = c.name;
    if (c.codes?.length) m.conditionCodes.set(key, [...c.codes]);
  }
  j.individuals.forEach((p, n) => {
    const at = `$.individuals[${n}]`;
    if (!p.id) fail(at, 'id is required');
    if (m.individuals.has(p.id)) fail(at, `duplicate id '${p.id}'`);
    const ind = createIndividual(p.id, { sex: p.sex ?? 'U', declared: true, order: n });
    if (p.assignedAtBirth) ind.assigned = p.assignedAtBirth;
    ind.proband = !!p.proband;
    ind.consultand = !!p.consultand;
    for (const s of p.status ?? []) {
      if (!KW_TO_PROP[s]) fail(`${at}.status`, `unknown status '${s}' (${STATUS.join(', ')})`);
      ind[KW_TO_PROP[s]] = true;
    }
    ind.labels = [...(p.labels ?? [])];
    for (const [k, jk] of [['born', 'born'], ['age', 'age'], ['died', 'died'], ['cause', 'causeOfDeath'], ['karyotype', 'karyotype']]) if (p[jk] != null) ind[k] = p[jk];
    if (ind.died != null) ind.deceased = true;
    if (p.count != null) ind.count = String(p.count);
    for (const c of p.conditions ?? []) {
      const key = typeof c === 'string' ? c : c.key ?? '';
      if (!ind.conditions.includes(key)) ind.conditions.push(key);
      if (c.onset != null) ind.onset[key] = c.onset;
    }
    ind.affected = ind.conditions.length > 0;
    ind.dx = (p.diagnoses ?? []).map((d) => ({ name: d.name, age: d.onset ?? null }));
    ind.tests = (p.tests ?? []).map((x) => ({ gene: x.gene, variant: x.variant ?? null, result: x.result }));
    ind.hpo = [...(p.hpo ?? [])];
    m.individuals.set(p.id, ind);
  });
  const known = (id, at) => { if (!m.individuals.has(id)) fail(at, `unknown individual '${id}'`); return id; };
  (j.unions ?? []).forEach((u, n) => {
    const at = `$.unions[${n}]`;
    const ps = u.partners ?? [];
    if (ps.length < 1 || ps.length > 2) fail(`${at}.partners`, 'one or two individuals');
    ps.forEach((p) => known(p, `${at}.partners`));
    m.unions.push({
      a: ps[0], b: ps[1] ?? null, type: ps[1] ? u.type ?? 'partner' : 'partner', label: u.note ?? null, line: 0,
      children: (u.children ?? []).map((c) => (typeof c === 'string'
        ? { kind: 'single', ids: [known(c, `${at}.children`)] }
        : { kind: c.twins === 'unknown' ? 'unknown' : c.twins, ids: c.ids.map((x) => known(x, `${at}.children`)) })),
      noChildren: u.noChildren ? { kind: u.noChildren.kind, reason: u.noChildren.reason ?? null } : null,
    });
  });
  m.links = (j.donations ?? []).map((d, n) => ({ from: known(d.donor, `$.donations[${n}]`), to: known(d.child, `$.donations[${n}]`), line: 0 }));
  const o = j.options ?? {};
  if (o.inheritance) m.options.inheritance = { pattern: o.inheritance.pattern, condition: o.inheritance.condition ?? null };
  if (o.partners) m.options.partners = o.partners;
  if (o.inbreeding) m.options.inbreeding = true;
  if (o.numbering === false) m.options.numbering = false;
  if (o.legend === false) m.options.legend = false;
  const source = serialize(m);
  return { model: parse(source), source }; // parse() re-validates everything
}

return { toJSON, fromJSON };
})();

__m.index = (() => {
const { parse, PedigreeSyntaxError, createIndividual } = __m.parser;
const { layout, DEFAULTS } = __m.layout;
const { render, renderParts, css } = __m.render;
const { serialize } = __m.serialize;
const { pageLang, resolveLang, t, MESSAGES, LANGUAGES } = __m.i18n;
const { anonymize, PRIVACY_LEVELS } = __m.privacy;
const { describe, describeText } = __m.describe;
const { toJSON, fromJSON } = __m.json;
const { kinship, inbreeding, fraction, unionInbreeding, relationship, describeRelationship, checkInheritance, segregation, testedGenes, PATTERNS } = __m.genetics;
const { toPED, pedToDSL, looksLikePED, toCanRisk, toPhenopacketFamily, toGA4GH, toFHIR, exportAs, FORMATS } = __m.formats;



/** Source text -> SVG string. */
function renderPedigree(source, options = {}, { idPrefix = 'ped' } = {}) {
  return render(layout(parse(source), options), { idPrefix });
}

let seq = 0;

/**
 * Render `source` into `el` (replacing its content) and remember the source on the
 * element, so add-ons such as the editor can pick it up (`el.pedigreeSource`).
 * Fires a bubbling `pedigree:rendered` event.
 */
function renderInto(el, source, options = {}) {
  el.pedigreeSource = source;
  el.pedigreeOptions = options;
  el.pedigreeId ??= `ped${++seq}`;
  let error = null;
  try {
    // drawing language: DSL `lang` > options.lang > page <html lang> > en
    el.innerHTML = renderPedigree(source, { ...options, lang: options.lang ?? pageLang(el) }, { idPrefix: el.pedigreeId });
  } catch (e) {
    error = e;
    el.innerHTML = `<pre style="color:#b00;white-space:pre-wrap">${String(e.message).replace(/</g, '&lt;')}</pre>`;
  }
  el.dataset.processed = 'true';
  el.dispatchEvent(new CustomEvent('pedigree:rendered', { bubbles: true, detail: { source, error } }));
  return error;
}

/**
 * Viewer, mermaid.run()-style: renders every matching element from its text content.
 * Render-only: editing is enabled only if `editor.js` is also loaded on the page.
 */
function run({ querySelector = '.pedigree', options = {} } = {}) {
  for (const el of document.querySelectorAll(querySelector)) {
    if (el.dataset.processed) continue;
    renderInto(el, el.textContent, options);
  }
}

return { parse, layout, render, renderParts, css, serialize, createIndividual, PedigreeSyntaxError, DEFAULTS, pageLang, resolveLang, t, MESSAGES, LANGUAGES, toPED, pedToDSL, looksLikePED, toCanRisk, toPhenopacketFamily, toGA4GH, toFHIR, exportAs, FORMATS, kinship, inbreeding, fraction, unionInbreeding, relationship, describeRelationship, checkInheritance, segregation, testedGenes, PATTERNS, anonymize, PRIVACY_LEVELS, describe, describeText, toJSON, fromJSON, renderPedigree, renderInto, run };
})();

__m.editor = (() => {
// WYSIWYG editor for pedigree diagrams. Optional add-on to the viewer (index.js).
//
// Without this script a page only renders pedigrees. With it, every element marked
// `data-editable` gets an "Edit" button:
//
//   <div class="pedigree" data-editable>pedigree ...</div>
//   <script type="module">
//     import { run } from './src/index.js';
//     import './src/editor.js';             // ← enables edit mode
//     run();
//   </script>
//
// The editor edits the model, regenerates the DSL (serialize) and re-parses it, so
// whatever you build by clicking is always valid source. Every change fires a
// bubbling `pedigree:change` event with `detail.source`.

const { parse, layout, render, serialize, createIndividual, renderInto } = __m.index;
const { t, resolveLang, pageLang, LANGUAGES } = __m.i18n;
const { checkInheritance, unionInbreeding, fraction, relationship, describeRelationship, segregation, testedGenes, PATTERNS } = __m.genetics;
const { TEST_RESULTS } = __m.parser;

// ---------------------------------------------------------------- model helpers
const ID_RE = /^[\p{L}_][\p{L}\p{N}_]*$/u;
const MERMAID_SVG = 'svg[data-pedigree-source]';
const OPPOSITE = { M: 'F', F: 'M', U: 'U', NB: 'U' };

const parentUnion = (m, id) => m.unions.find((u) => u.children.some((g) => g.ids.includes(id)));
const unionsOf = (m, id) => m.unions.filter((u) => u.a === id || u.b === id);
const groupOf = (u, id) => u.children.find((g) => g.ids.includes(id));

function newId(m, base = 'p') {
  let n = m.individuals.size + 1;
  while (m.individuals.has(`${base}${n}`)) n++;
  return `${base}${n}`;
}

function addInd(m, sex = 'U') {
  const order = Math.max(-1, ...[...m.individuals.values()].map((i) => i.order)) + 1;
  const ind = createIndividual(newId(m), { sex, declared: true, order });
  m.individuals.set(ind.id, ind);
  return ind;
}

function newUnion(m, a, b = null) {
  const u = { a, b, type: 'partner', children: [], noChildren: null, label: null, line: 0 };
  m.unions.push(u);
  return u;
}

function normalizeGroups(u) {
  u.children = u.children.filter((g) => g.ids.length);
  for (const g of u.children) if (g.ids.length === 1) g.kind = 'single';
}

function detachChild(m, id) {
  const pu = parentUnion(m, id);
  if (!pu) return;
  for (const g of pu.children) g.ids = g.ids.filter((x) => x !== id);
  normalizeGroups(pu);
  if (!pu.b && !pu.children.length && !pu.noChildren) m.unions.splice(m.unions.indexOf(pu), 1);
}

function deletePerson(m, id) {
  detachChild(m, id);
  m.links = (m.links ?? []).filter((l) => l.from !== id && l.to !== id);
  m.individuals.delete(id);
  for (const u of [...m.unions]) {
    if (u.a !== id && u.b !== id) continue;
    const other = u.a === id ? u.b : u.a;
    if (other && u.children.length) Object.assign(u, { a: other, b: null, type: 'partner', label: null });
    else m.unions.splice(m.unions.indexOf(u), 1);
  }
}

function renamePerson(m, from, to, lang = 'en') {
  if (!ID_RE.test(to)) throw new Error(t(lang, 'ed.badId', { id: to }));
  if (m.individuals.has(to)) throw new Error(t(lang, 'ed.idExists', { id: to }));
  const entries = [...m.individuals.entries()].map(([k, v]) => (k === from ? [to, Object.assign(v, { id: to })] : [k, v]));
  m.individuals = new Map(entries);
  for (const u of m.unions) {
    if (u.a === from) u.a = to;
    if (u.b === from) u.b = to;
    for (const g of u.children) g.ids = g.ids.map((x) => (x === from ? to : x));
  }
  for (const l of m.links ?? []) {
    if (l.from === from) l.from = to;
    if (l.to === from) l.to = to;
  }
}

// value typed in an age / year field: number when numeric, text otherwise, null when empty
const fieldValue = (v) => { v = v.trim(); return v === '' ? null : /^\d+$/.test(v) ? Number(v) : v; };

// short key for a new shaded condition: initials ("Breast cancer" -> BC), made unique
function conditionKey(m, name) {
  let base = name.normalize('NFD').replace(/[^\p{L}\p{N}\s]/gu, ' ').split(/\s+/).filter(Boolean)
    .map((w) => w[0]).join('').toUpperCase().slice(0, 4);
  if (!ID_RE.test(base)) base = `C${base}`;
  let k = base, n = 2;
  while (m.conditions.has(k)) k = `${base}${n++}`;
  return k;
}

/** Add a disease (with optional age at onset) to a person: shaded sector or text-only diagnosis. */
function addDisease(m, id, name, age, shade) {
  const ind = m.individuals.get(id);
  name = name.trim();
  if (!name) return 'empty';
  const lc = name.toLowerCase();
  let key = [...m.conditions.keys()].find((k) => k === name || (m.conditions.get(k) ?? '').toLowerCase() === lc);
  let result = 'ok';
  if (key === undefined && shade) {
    const used = new Set([...m.individuals.values()].flatMap((i) => i.conditions));
    if (used.size >= 4) result = 'full';
    else { key = conditionKey(m, name); m.conditions.set(key, name); }
  }
  if (key !== undefined) {
    if (!ind.conditions.includes(key)) ind.conditions.push(key);
    ind.onset ??= {};
    if (age != null) ind.onset[key] = age;
    ind.affected = true;
  } else {
    ind.dx ??= [];
    ind.dx = ind.dx.filter((d) => d.name !== name);
    ind.dx.push({ name, age });
  }
  return result;
}

function childUnionFor(m, id, partnerSex) {
  const us = unionsOf(m, id);
  const couple = [...us].reverse().find((u) => u.b);
  if (couple) return couple;
  if (us.length) return us[us.length - 1];
  const p = addInd(m, partnerSex);
  return newUnion(m, id, p.id);
}

// ---------------------------------------------------------------- UI helpers
function h(tag, attrs = {}, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null || v === false) continue;
    if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else if (k === 'class') el.className = v;
    else if (k === 'value') el.value = v;
    else if (k === 'checked') el.checked = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of kids.flat()) if (c != null && c !== false) el.append(c instanceof Node ? c : String(c));
  return el;
}

// append children, flattening arrays and skipping null/false (Element.append would stringify them)
const fill = (parent, ...kids) => parent.append(...kids.flat(Infinity).filter((k) => k != null && k !== false));

const FLAGS = ['deceased', 'proband', 'consultand', 'carrier', 'presymptomatic', 'evaluated', 'pregnancy',
  'miscarriage', 'stillbirth', 'termination', 'ectopic', 'adoptedIn', 'adoptedOut', 'donor', 'surrogate', 'vsc'];
const SEX_LABEL = { M: '♂ M', F: '♀ F', U: '◇ ?', NB: '◇ NB' };
const UNION_TYPES = ['partner', 'divorce', 'consanguineous'];

const EDITOR_CSS = `
.ped-ed-host{position:relative}
.ped-ed-toggle{position:absolute;top:6px;right:6px;z-index:2;font:12px system-ui,sans-serif;padding:4px 9px;border:1px solid #c9ced6;border-radius:6px;background:#fff;color:#1b1f24;cursor:pointer;opacity:.55;transition:opacity .15s}
.ped-ed-host:hover .ped-ed-toggle,.ped-ed-toggle:focus{opacity:1}
.ped-ed{font:13px/1.4 system-ui,-apple-system,sans-serif;color:#1b1f24;border:1px solid #c9ced6;border-radius:8px;background:#fff;overflow:hidden}
.ped-ed-bar{display:flex;flex-wrap:wrap;gap:6px;align-items:center;padding:7px 10px;border-bottom:1px solid #e3e6ea;background:#f7f8fa}
.ped-ed-bar .sp{flex:1}
.ped-ed button{font:inherit;padding:3px 9px;border:1px solid #c9ced6;border-radius:5px;background:#fff;color:inherit;cursor:pointer}
.ped-ed button:hover:not(:disabled){border-color:#2563eb;color:#2563eb}
.ped-ed button:disabled{opacity:.4;cursor:default}
.ped-ed button.primary{background:#2563eb;border-color:#2563eb;color:#fff}
.ped-ed button.danger:hover{border-color:#b91c1c;color:#b91c1c}
.ped-ed .hint{font-size:12px;color:#2563eb;font-weight:600}
.ped-ed .hint.err{color:#b91c1c}
.ped-ed-main{display:grid;grid-template-columns:minmax(0,1fr) 270px}
@media (max-width:720px){.ped-ed-main{grid-template-columns:1fr}}
.ped-ed-stage{overflow:auto;padding:8px;min-height:260px}
.ped-ed-stage.picking{cursor:crosshair}
.ped-ed-panel{border-left:1px solid #e3e6ea;padding:10px 12px;background:#fbfbfc;overflow:auto;max-height:80vh}
.ped-ed-panel h4{margin:2px 0 8px;font-size:13px}
.ped-ed-panel h5{margin:12px 0 5px;font-size:11px;text-transform:uppercase;letter-spacing:.04em;color:#6b7280}
.ped-ed-panel label{display:flex;gap:6px;align-items:center;margin:2px 0;cursor:pointer}
.ped-ed-panel input[type=text],.ped-ed-panel input[type=number],.ped-ed-panel select,.ped-ed-panel textarea{width:100%;font:inherit;padding:4px 6px;border:1px solid #c9ced6;border-radius:5px;box-sizing:border-box;background:#fff}
.ped-ed-panel textarea{min-height:58px;resize:vertical}
.ped-ed-panel .grid{display:grid;grid-template-columns:1fr 1fr;gap:0 8px}
.ped-ed-panel .row{display:flex;flex-wrap:wrap;gap:4px;margin:3px 0}
.ped-ed-panel .seg button.on{background:#2563eb;border-color:#2563eb;color:#fff}
.ped-ed-panel .muted{color:#6b7280;font-size:12px}
.ped-ed-panel .dis{align-items:center;flex-wrap:nowrap}
.ped-ed-panel .dname{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ped-ed-panel .dis button{padding:2px 7px}
.ped-ed-panel .findings{margin:4px 0;padding-left:18px;font-size:12px}
.ped-ed-src{width:100%;min-height:180px;font:12px/1.5 ui-monospace,Menlo,monospace;box-sizing:border-box}
.ped-ed .ind[data-id]{cursor:pointer}
.ped-ed .ind[data-id]:hover .sym{stroke:#2563eb}
.ped-ed g.union{cursor:pointer}
.ped-ed g.union:hover .ln{stroke:#2563eb}
.ped-ed .ind.ped-sel .sym,.ped-ed .ind.ped-sel .ln{stroke:#2563eb;stroke-width:3}
.ped-ed g.union.ped-sel .ln{stroke:#2563eb;stroke-width:2.6}
.ped-ed .ind.ped-src .sym{stroke:#f59e0b;stroke-width:3;stroke-dasharray:4 2}
`;

function injectCss() {
  if (document.getElementById('ped-ed-css')) return;
  document.head.append(h('style', { id: 'ped-ed-css' }, EDITOR_CSS));
}

// ---------------------------------------------------------------- editor
class PedigreeEditor {
  constructor(el, { onChange, lang } = {}) {
    this.el = el;
    this.onChange = onChange;
    this.uiLang = lang; // UI language: option > page <html lang> > en
    this.T = (k, v) => t(resolveLang(this.uiLang, pageLang(this.el)), `ed.${k}`, v);
    this.history = [];
    this.future = [];
    this.sel = null;        // { type: 'ind', id } | { type: 'union', index } | null
    this.pending = null;    // { kind, from, twinKind? }
    this.editing = false;
    this.showSource = false;
    this.onKey = this.onKey.bind(this);
    injectCss();
    el.classList.add('ped-ed-host');
    el.pedigreeEditor = this;
    // Host kind: our viewer (renderInto) or Mermaid (plugin stamps the DSL on its <svg>).
    this.isMermaid = el.classList.contains('mermaid') || !!el.querySelector(MERMAID_SVG);
    if (this.isMermaid) {
      if (el.querySelector(MERMAID_SVG)) this.addToggle(); // otherwise wait: the observer calls addToggle after Mermaid renders
    } else {
      el.addEventListener('pedigree:rendered', () => { if (!this.editing) this.addToggle(); });
      if (el.dataset.processed) this.addToggle();
      else renderInto(el, el.textContent, el.pedigreeOptions);
    }
  }

  get source() {
    if (this.isMermaid) {
      const svg = this.el.querySelector(MERMAID_SVG);
      if (svg) return svg.getAttribute('data-pedigree-source');
    }
    return this.el.pedigreeSource ?? this.el.textContent;
  }

  /** Layout options: the viewer's, or the Mermaid `config.pedigree` the diagram was drawn with. */
  readHostOptions() {
    if (!this.isMermaid) return { layout: this.el.pedigreeOptions, mermaid: null };
    let cfg = {};
    try { cfg = JSON.parse(this.el.querySelector(MERMAID_SVG)?.getAttribute('data-pedigree-config') || '{}'); } catch { /* keep defaults */ }
    const { useMaxWidth, ...layoutOpts } = cfg;
    return { layout: layoutOpts, mermaid: cfg };
  }

  addToggle() {
    if (this.el.querySelector(':scope > .ped-ed-toggle')) return;
    this.el.append(h('button', { class: 'ped-ed-toggle', type: 'button', title: this.T('toggleTitle'), onclick: () => this.open() }, this.T('toggle')));
  }

  // ---- lifecycle
  open() {
    try {
      this.model = parse(this.source);
    } catch (e) {
      alert(`${this.T('cannotEdit')}\n\n${e.message}`);
      return;
    }
    const host = this.readHostOptions();
    this.layoutOptions = host.layout;
    this.mermaidConfig = host.mermaid;
    this.editing = true;
    this.sel = null;
    this.pending = null;
    this.idPrefix = `${this.el.pedigreeId || 'ped'}e`;
    this.hint = h('span', { class: 'hint' });
    const T = this.T;
    this.undoBtn = h('button', { type: 'button', title: T('undo'), onclick: () => this.undo() }, '↶');
    this.redoBtn = h('button', { type: 'button', title: T('redo'), onclick: () => this.redo() }, '↷');
    const bar = h('div', { class: 'ped-ed-bar' },
      h('strong', {}, T('mode')),
      h('span', { class: 'muted' }, ` ${T('addPerson')}`),
      ['M', 'F', 'U'].map((s) => h('button', { type: 'button', title: T('addPersonTitle'), onclick: () => this.addPerson(s) }, SEX_LABEL[s])),
      this.undoBtn, this.redoBtn,
      h('button', { type: 'button', onclick: () => { this.showSource = !this.showSource; this.drawPanel(); } }, T('source')),
      this.hint,
      h('span', { class: 'sp' }),
      h('button', { type: 'button', class: 'primary', onclick: () => this.close() }, T('done')));
    this.stage = h('div', { class: 'ped-ed-stage', onclick: (e) => this.onStageClick(e) });
    this.panel = h('aside', { class: 'ped-ed-panel' });
    this.root = h('div', { class: 'ped-ed' }, bar, h('div', { class: 'ped-ed-main' }, this.stage, this.panel));
    this.el.replaceChildren(this.root);
    document.addEventListener('keydown', this.onKey);
    this.draw();
  }

  close() {
    this.editing = false;
    document.removeEventListener('keydown', this.onKey);
    const src = serialize(this.model);
    const mermaid = mermaidInstance ?? globalThis.mermaid;
    if (this.isMermaid && mermaid?.run) {
      // hand the diagram back to Mermaid (per-diagram options live in the DSL: `layout`, `lang`)
      this.el.pedigreeSource = src;
      this.el.removeAttribute('data-processed');
      this.el.textContent = src;
      mermaid.run({ nodes: [this.el] }).then(() => this.addToggle(), (e) => { this.el.textContent = String(e?.message ?? e); });
      return;
    }
    if (this.isMermaid) {
      console.warn('pedigree editor: Mermaid instance not found (pass enableEditing({ mermaid })); falling back to the built-in renderer');
      this.isMermaid = false;
      this.el.addEventListener('pedigree:rendered', () => { if (!this.editing) this.addToggle(); });
    }
    renderInto(this.el, src, this.layoutOptions);
  }

  // ---- state changes
  commit(fn, { select } = {}) {
    const before = serialize(this.model);
    let result;
    try {
      result = fn(this.model);
      const src = serialize(this.model);
      const m = parse(src);
      layout(m); // throws on cycles
      this.model = m;
      this.history.push(before);
      this.future = [];
      this.emit(src);
      if (select !== undefined) this.sel = typeof select === 'function' ? select(result) : select;
      this.flash('');
    } catch (e) {
      this.model = parse(before);
      this.flash(e.message, true);
    }
    this.pending = null;
    this.draw();
    return result;
  }

  emit(src) {
    this.el.pedigreeSource = src;
    this.onChange?.(src);
    this.el.dispatchEvent(new CustomEvent('pedigree:change', { bubbles: true, detail: { source: src } }));
  }

  undo() { this.travel(this.history, this.future); }
  redo() { this.travel(this.future, this.history); }
  travel(from, to) {
    if (!from.length) return;
    to.push(serialize(this.model));
    this.model = parse(from.pop());
    if (this.sel?.type === 'ind' && !this.model.individuals.has(this.sel.id)) this.sel = null;
    if (this.sel?.type === 'union' && !this.model.unions[this.sel.index]) this.sel = null;
    this.emit(serialize(this.model));
    this.flash('');
    this.draw();
  }

  flash(msg, err = false) {
    if (!this.hint) return;
    this.hint.textContent = msg;
    this.hint.className = err ? 'hint err' : 'hint';
  }

  // ---- drawing
  draw() {
    this.stage.innerHTML = render(layout(this.model, { lang: pageLang(this.el), ...this.layoutOptions }), { idPrefix: this.idPrefix });
    this.stage.classList.toggle('picking', !!this.pending);
    if (this.sel?.type === 'ind') this.stage.querySelector(`.ind[data-id="${CSS.escape(this.sel.id)}"]`)?.classList.add('ped-sel');
    if (this.sel?.type === 'union') this.stage.querySelector(`g.union[data-union="${this.sel.index}"]`)?.classList.add('ped-sel');
    if (this.pending) this.stage.querySelector(`.ind[data-id="${CSS.escape(this.pending.from)}"]`)?.classList.add('ped-src');
    this.undoBtn.disabled = !this.history.length;
    this.redoBtn.disabled = !this.future.length;
    this.drawPanel();
  }

  drawPanel() {
    const p = this.panel;
    p.replaceChildren();
    if (this.showSource) {
      const ta = h('textarea', { class: 'ped-ed-src', readonly: true }, serialize(this.model));
      fill(p, h('h4', {}, this.T('sourceTitle')), ta,
        h('div', { class: 'row' },
          h('button', { type: 'button', onclick: () => navigator.clipboard?.writeText(ta.value).then(() => this.flash(this.T('copied'))) }, this.T('copy')),
          h('button', { type: 'button', onclick: () => { this.showSource = false; this.drawPanel(); } }, this.T('close'))));
      return;
    }
    if (this.sel?.type === 'ind' && this.model.individuals.has(this.sel.id)) return this.personPanel(p, this.model.individuals.get(this.sel.id));
    if (this.sel?.type === 'union' && this.model.unions[this.sel.index]) return this.unionPanel(p, this.sel.index);
    this.docPanel(p);
  }

  docPanel(p) {
    const m = this.model;
    const T = this.T;
    fill(p,
      h('h4', {}, T('document')),
      h('p', { class: 'muted' }, T('docHint')),
      h('h5', {}, T('title')),
      h('input', { type: 'text', value: m.title ?? '', onchange: (e) => this.commit((mm) => { mm.title = e.target.value.trim() || null; }) }),
      h('h5', {}, T('header')),
      ['recordedBy', 'historian', 'date', 'indication'].map((k) => h('input', {
        type: 'text', value: m.header?.[k] ?? '', placeholder: t(resolveLang(this.uiLang, pageLang(this.el)), `header.${k}`), style: 'margin:2px 0',
        onchange: (e) => this.commit((mm) => { mm.header ??= {}; mm.header[k] = e.target.value.trim() || null; }) })),
      h('h5', {}, T('defaultCondition')),
      h('input', { type: 'text', value: m.conditions.get('') ?? m.condition ?? '', placeholder: T('conditionPlaceholder'),
        onchange: (e) => this.commit((mm) => { const v = e.target.value.trim(); mm.condition = v || null; if (v) mm.conditions.set('', v); else mm.conditions.delete(''); }) }),
      h('h5', {}, T('namedConditions')),
      [...m.conditions].filter(([k]) => k).map(([k, v]) => h('div', { class: 'row' },
        h('strong', { style: 'min-width:36px' }, k),
        h('input', { type: 'text', value: v ?? '', style: 'flex:1;width:auto', onchange: (e) => this.commit((mm) => { mm.conditions.set(k, e.target.value || k); }) }),
        h('input', { type: 'text', value: (m.conditionCodes?.get(k) ?? []).join(', '), placeholder: T('codes'), style: 'flex:1 1 100%;width:auto',
          onchange: (e) => this.commit((mm) => { const c = e.target.value.split(/[\s,;]+/).filter((x) => /^[A-Za-z][A-Za-z0-9_]*:\d/.test(x)); mm.conditionCodes ??= new Map(); if (c.length) mm.conditionCodes.set(k, c); else mm.conditionCodes.delete(k); }) }))),
      h('div', { class: 'row' },
        h('input', { type: 'text', placeholder: T('newCondition'), style: 'flex:1;width:auto', onkeydown: (e) => {
          if (e.key !== 'Enter') return;
          const k = e.target.value.trim();
          if (!ID_RE.test(k)) return this.flash(T('badKey'), true);
          this.commit((mm) => { mm.conditions.set(k, k); });
        } })),
      h('h5', {}, T('options')),
      h('label', {}, h('input', { type: 'checkbox', checked: m.options.numbering, onchange: (e) => this.commit((mm) => { mm.options.numbering = e.target.checked; }) }), T('numbering')),
      h('label', {}, h('input', { type: 'checkbox', checked: m.options.legend, onchange: (e) => this.commit((mm) => { mm.options.legend = e.target.checked; }) }), T('legend')),
      h('label', {}, h('input', { type: 'checkbox', checked: m.options.partners === 'written', onchange: (e) => this.commit((mm) => { mm.options.partners = e.target.checked ? 'written' : 'sex'; }) }), T('partnersWritten')),
      h('label', {}, h('input', { type: 'checkbox', checked: m.options.order === 'strict', onchange: (e) => this.commit((mm) => { mm.options.order = e.target.checked ? 'strict' : 'auto'; }) }), T('strictOrder')),
      h('h5', {}, T('drawingLang')),
      h('select', { onchange: (e) => this.commit((mm) => { mm.options.lang = e.target.value || null; }) },
        h('option', { value: '', selected: !m.options.lang }, T('langAuto')),
        LANGUAGES.map((l) => h('option', { value: l, selected: m.options.lang === l }, { en: 'English', it: 'Italiano' }[l] ?? l))),
      this.analysisSection(),
    );
  }

  /** Inheritance consistency, inbreeding coefficients, segregation of tested genes. */
  analysisSection() {
    const m = this.model;
    const T = this.T;
    const lang = resolveLang(this.uiLang, pageLang(this.el));
    const inh = m.options.inheritance;
    const setInh = (pattern, condition) => this.commit((mm) => { mm.options.inheritance = pattern ? { pattern, condition: condition || null } : null; });
    const conds = [...m.conditions.keys()].filter(Boolean);
    let findings = [];
    try { findings = inh ? checkInheritance(m, inh.pattern, { condition: inh.condition, lang }) : []; } catch { findings = []; }
    const colors = { error: '#b91c1c', warn: '#b45309', info: '#2563eb' };
    const F = unionInbreeding(m);
    const genes = testedGenes(m);
    return h('div', {},
      h('h5', {}, T('analysis')),
      h('div', { class: 'muted' }, T('inheritance')),
      h('div', { class: 'grid' },
        h('select', { onchange: (e) => setInh(e.target.value, inh?.condition) },
          h('option', { value: '', selected: !inh }, T('inheritanceNone')),
          PATTERNS.map((p) => h('option', { value: p, selected: inh?.pattern === p }, `${p} · ${t(lang, `inh.${p}`)}`))),
        h('select', { disabled: !inh, onchange: (e) => setInh(inh.pattern, e.target.value) },
          h('option', { value: '', selected: !inh?.condition }, T('anyCondition')),
          conds.map((c) => h('option', { value: c, selected: inh?.condition === c }, c)))),
      inh && (findings.length
        ? h('ul', { class: 'findings' }, findings.map((f) => h('li', { style: `color:${colors[f.level]}` }, f.text)))
        : h('p', { class: 'muted' }, T('consistent'))),
      genes.map((g) => {
        const sg = segregation(m, g, { condition: inh?.condition });
        return h('p', { class: 'muted' }, T('segregation', { gene: g, ca: sg.carriers.affected.length, cu: sg.carriers.unaffected.length, na: sg.nonCarriers.affected.length, nu: sg.nonCarriers.unaffected.length }));
      }),
      F.length > 0 && h('div', {},
        h('div', { class: 'muted' }, T('inbreedingList')),
        F.map((x) => h('div', {}, `${x.a} × ${x.b}: F = ${fraction(x.F)}`))),
      h('label', {}, h('input', { type: 'checkbox', checked: !!m.options.inbreeding, onchange: (e) => this.commit((mm) => { mm.options.inbreeding = e.target.checked; }) }), T('inbreedingShow')),
      (inh || genes.length) && h('p', { class: 'muted' }, T('notDiagnosis')),
    );
  }

  /** Genetic test results: gene, variant, ACMG class / negative. */
  testList(ind, set) {
    const T = this.T;
    const resSelect = (value, onchange) => h('select', { style: 'width:auto', onchange },
      TEST_RESULTS.map((r) => h('option', { value: r, selected: value === r }, `${r} · ${t(resolveLang(this.uiLang, pageLang(this.el)), `res.${r}`)}`)));
    const rows = (ind.tests ?? []).map((x, j) => h('div', { class: 'row dis' },
      h('span', { class: 'dname', title: x.variant ?? '' }, `${x.gene}${x.variant ? ` ${x.variant}` : ''}`),
      resSelect(x.result, (e) => set((i) => { i.tests[j].result = e.target.value; })),
      h('button', { type: 'button', title: T('remove'), onclick: () => set((i) => { i.tests.splice(j, 1); }) }, '×')));
    const gene = h('input', { type: 'text', placeholder: T('gene'), style: 'width:80px' });
    const variant = h('input', { type: 'text', placeholder: T('variant'), style: 'flex:1;width:auto' });
    const result = resSelect('P', null);
    const add = () => {
      const g = gene.value.trim();
      if (!g) return;
      set((i) => { i.tests ??= []; i.tests.push({ gene: g, variant: variant.value.trim() || null, result: result.value }); });
    };
    return [rows, h('div', { class: 'row' }, gene, variant), h('div', { class: 'row', style: 'align-items:center' }, result, h('span', { class: 'sp', style: 'flex:1' }), h('button', { type: 'button', onclick: add }, T('addTest')))];
  }

  personPanel(p, ind) {
    const m = this.model;
    const T = this.T;
    const id = ind.id;
    const set = (fn) => this.commit((mm) => fn(mm.individuals.get(id), mm), { select: { type: 'ind', id } });
    const pu = parentUnion(m, id);
    const grp = pu && groupOf(pu, id);
    const gi = pu ? pu.children.indexOf(grp) : -1;
    const conds = [...new Set(['', ...m.conditions.keys()])];
    const sexBtns = ['M', 'F', 'U'];
    const addBtns = (fn) => sexBtns.map((s) => h('button', { type: 'button', onclick: () => fn(s) }, SEX_LABEL[s]));

    fill(p,
      h('h4', {}, T('person')),
      h('div', { class: 'row' },
        h('input', { type: 'text', value: id, title: T('identifier'), onchange: (e) => {
          const to = e.target.value.trim();
          if (to !== id) this.commit((mm) => renamePerson(mm, id, to, resolveLang(this.uiLang, pageLang(this.el))), { select: { type: 'ind', id: to } });
        } })),
      (() => {
        // relationship to the proband (or consultand), e.g. "zia (ramo materno) · parente di 2° grado"
        const pb = [...m.individuals.values()].find((i) => i.proband) ?? [...m.individuals.values()].find((i) => i.consultand);
        if (!pb || pb.id === id) return null;
        const lang = resolveLang(this.uiLang, pageLang(this.el));
        let txt;
        try { txt = describeRelationship(relationship(m, pb.id, id, lang), lang); } catch { return null; }
        return h('p', { class: 'muted', title: T('relToProband') }, `${T('relToProband')} (${pb.id}): `, h('b', {}, txt));
      })(),
      h('h5', {}, T('sexGender')),
      h('div', { class: 'row seg', title: T('genderHint') }, ['M', 'F', 'NB', 'U'].map((s) => h('button', { type: 'button', class: ind.sex === s ? 'on' : null, onclick: () => set((i) => { i.sex = s; }) }, SEX_LABEL[s]))),
      h('div', {},
        h('select', { title: T('assigned'), style: 'margin:2px 0', onchange: (e) => set((i) => { i.assigned = e.target.value || null; }) },
          h('option', { value: '', selected: !ind.assigned }, `${T('assigned')} ${T('assignedNone')}`),
          ['AMAB', 'AFAB', 'UAAB'].map((a) => h('option', { value: a, selected: ind.assigned === a }, a))),
        h('input', { type: 'text', value: ind.karyotype ?? '', placeholder: T('karyotype'), title: T('karyotype'), onchange: (e) => set((i) => { i.karyotype = e.target.value.trim() || null; }) })),

      h('h5', {}, T('affectedBy')),
      this.diseaseList(ind, set, conds),
      h('input', { type: 'text', value: (ind.hpo ?? []).join(', '), placeholder: T('hpo'), title: T('hpo'), onchange: (e) => set((i) => {
        i.hpo = e.target.value.split(/[\s,;]+/).filter(Boolean);
      }) }),

      h('h5', {}, T('tests')),
      this.testList(ind, set),

      h('h5', {}, T('lifeData')),
      h('div', { class: 'grid' }, [['born', 'born'], ['age', 'age'], ['died', 'died'], ['cause', 'cause']].map(([k, l]) => h('input', {
        type: 'text', value: ind[k] ?? '', placeholder: T(l), title: T(l),
        onchange: (e) => set((i) => {
          i[k] = k === 'cause' ? e.target.value.trim() || null : fieldValue(e.target.value);
          if (k === 'died' && i.died != null) i.deceased = true;
        }) }))),

      h('h5', {}, T('status')),
      h('div', { class: 'grid' }, FLAGS.map((k) => h('label', {},
        h('input', { type: 'checkbox', checked: !!ind[k], onchange: (e) => set((i) => { i[k] = e.target.checked; }) }),
        t(resolveLang(this.uiLang, pageLang(this.el)), `flag.${k}`)))),
      h('div', { class: 'row', style: 'align-items:center' }, h('span', { class: 'muted' }, T('count')),
        h('input', { type: 'text', value: ind.count ?? '', style: 'width:60px', placeholder: '–', onchange: (e) => set((i) => { const v = e.target.value.trim(); i.count = v || null; }) })),

      h('h5', {}, T('labels')),
      h('textarea', { onchange: (e) => set((i) => { i.labels = e.target.value.split('\n').map((s) => s.trim()).filter(Boolean); }) }, ind.labels.join('\n')),

      h('h5', {}, T('add')),
      h('div', { class: 'row' }, h('button', { type: 'button', onclick: () => this.addPartner(id) }, T('addPartner')),
        h('button', { type: 'button', disabled: !!pu, onclick: () => this.addParents(id) }, T('addParents'))),
      h('div', { class: 'row' }, h('span', { class: 'muted', style: 'min-width:52px' }, T('child')), addBtns((s) => this.addChild(id, s))),
      h('div', { class: 'row' }, h('span', { class: 'muted', style: 'min-width:52px' }, T('sibling')), addBtns((s) => this.addSibling(id, s))),

      h('h5', {}, T('link')),
      h('div', { class: 'row' },
        h('button', { type: 'button', onclick: () => this.pick({ kind: 'partner', from: id }, T('pickPartner')) }, T('partnerOf')),
        h('button', { type: 'button', onclick: () => this.pick({ kind: 'childOf', from: id }, T('pickParent')) }, T('childOf'))),
      pu && h('div', { class: 'row' },
        ['mz', 'dz', 'unknown'].map((k) => h('button', { type: 'button', onclick: () => this.pick({ kind: 'twin', twinKind: k, from: id }, T('pickTwin')) },
          T({ mz: 'twinMZ', dz: 'twinDZ', unknown: 'twinUnknown' }[k]))),
        grp?.ids.length > 1 && h('button', { type: 'button', onclick: () => this.untwin(id) }, T('untwin'))),
      pu && h('div', { class: 'row' },
        h('button', { type: 'button', disabled: gi <= 0, title: T('older'), onclick: () => this.move(id, -1) }, T('earlier')),
        h('button', { type: 'button', disabled: gi >= pu.children.length - 1, title: T('younger'), onclick: () => this.move(id, 1) }, T('later')),
        h('button', { type: 'button', onclick: () => this.commit((mm) => detachChild(mm, id), { select: { type: 'ind', id } }) }, T('detach'))),

      h('h5', {}, T('art')),
      h('div', { class: 'row' },
        h('button', { type: 'button', onclick: () => this.pick({ kind: 'art', from: id }, T('pickArtChild')) }, T('donorOf'))),
      (m.links ?? []).filter((l) => l.from === id || l.to === id).map((l) => h('div', { class: 'row', style: 'align-items:center' },
        h('span', { class: 'muted', style: 'flex:1' }, `${l.from} → ${l.to}`),
        h('button', { type: 'button', title: T('remove'), onclick: () => set((i, mm) => { mm.links = mm.links.filter((x) => x !== mm.links.find((y) => y.from === l.from && y.to === l.to)); }) }, '×'))),

      h('h5', {}, ''),
      h('button', { type: 'button', class: 'danger', onclick: () => this.deleteSelected() }, T('deletePerson')),
    );
  }

  /** "Affected by": extensible list of diseases, each with age at onset. */
  diseaseList(ind, set, conds) {
    const m = this.model;
    const T = this.T;
    const ageInput = (value, onchange) => h('input', { type: 'text', value: value ?? '', placeholder: T('onset'), title: T('onset'), style: 'width:64px', onchange });
    const rows = [
      ...ind.conditions.map((c) => h('div', { class: 'row dis' },
        h('span', { class: 'dname', title: T('inSymbol') }, '◐ ', c ? `${c} — ${m.conditions.get(c) ?? ''}` : (m.conditions.get('') || T('affected'))),
        ageInput(ind.onset?.[c], (e) => set((i) => { const v = fieldValue(e.target.value); i.onset ??= {}; if (v == null) delete i.onset[c]; else i.onset[c] = v; })),
        h('button', { type: 'button', title: T('remove'), onclick: () => set((i) => {
          i.conditions = i.conditions.filter((x) => x !== c);
          if (i.onset) delete i.onset[c];
          i.affected = i.conditions.length > 0;
        }) }, '×'))),
      ...(ind.dx ?? []).map((d, j) => h('div', { class: 'row dis' },
        h('span', { class: 'dname' }, d.name),
        ageInput(d.age, (e) => set((i) => { i.dx[j].age = fieldValue(e.target.value); })),
        h('button', { type: 'button', title: T('remove'), onclick: () => set((i) => { i.dx.splice(j, 1); }) }, '×'))),
    ];
    const listId = `${this.idPrefix}-dis`;
    const name = h('input', { type: 'text', placeholder: T('diseasePlaceholder'), list: listId, style: 'flex:1 1 100%;width:auto' });
    const age = ageInput('', null);
    const used = new Set([...m.individuals.values()].flatMap((i) => i.conditions));
    const shade = h('input', { type: 'checkbox', checked: used.size < 4 });
    const add = () => {
      const v = name.value;
      const a = fieldValue(age.value);
      let res;
      set((i, mm) => { res = addDisease(mm, ind.id, v, a, shade.checked); });
      if (res === 'full') this.flash(T('tooManySectors'));
    };
    name.addEventListener('keydown', (e) => { if (e.key === 'Enter') add(); });
    return [
      rows,
      h('datalist', { id: listId }, conds.filter((c) => c).flatMap((c) => [h('option', { value: m.conditions.get(c) ?? c }), h('option', { value: c })])),
      h('div', { class: 'row' }, name),
      h('div', { class: 'row', style: 'align-items:center' }, age,
        h('label', { class: 'muted', style: 'flex:1' }, shade, T('inSymbol')),
        h('button', { type: 'button', onclick: add }, T('addDisease'))),
    ];
  }

  unionPanel(p, index) {
    const u = this.model.unions[index];
    const set = (fn) => this.commit((mm) => fn(mm.unions[index]), { select: { type: 'union', index } });
    const T = this.T;
    fill(p,
      h('h4', {}, u.b ? T('couple', { a: u.a, b: u.b }) : T('parent', { a: u.a })),
      u.b && h('div', {},
        h('h5', {}, T('relType')),
        h('select', { onchange: (e) => set((x) => { x.type = e.target.value; }) },
          UNION_TYPES.map((v) => h('option', { value: v, selected: u.type === v }, T(`rel.${v}`)))),
        h('h5', {}, T('lineNote')),
        h('input', { type: 'text', value: u.label ?? '', placeholder: T('lineNotePlaceholder'), onchange: (e) => set((x) => { x.label = e.target.value.trim() || null; }) })),
      !u.children.length && h('div', {},
        h('h5', {}, T('noChildrenTitle')),
        [[null, T('nc.unspecified')], ['none', T('nc.none')], ['infertile', T('nc.infertile')]].map(([v, l]) => h('label', {},
          h('input', { type: 'radio', name: `nc${index}`, checked: (u.noChildren?.kind ?? null) === v,
            onchange: () => set((x) => { x.noChildren = v ? { kind: v, reason: x.noChildren?.reason ?? null } : null; }) }), l)),
        u.noChildren && h('input', { type: 'text', value: u.noChildren.reason ?? '', placeholder: T('reason'),
          onchange: (e) => set((x) => { x.noChildren.reason = e.target.value.trim() || null; }) })),
      h('h5', {}, T('addChild')),
      h('div', { class: 'row' }, ['M', 'F', 'U'].map((s) => h('button', { type: 'button', onclick: () => this.addChildTo(index, s) }, SEX_LABEL[s]))),
      u.children.length > 0 && h('p', { class: 'muted' }, T('childrenList', { list: u.children.map((g) => g.ids.join(g.kind === 'single' ? '' : ' + ')).join(', ') })),
      h('h5', {}, ''),
      h('button', { type: 'button', class: 'danger', onclick: () => this.deleteSelected() }, T('deleteUnion')),
    );
  }

  // ---- interaction
  pick(pending, msg) {
    this.pending = pending;
    this.flash(`${msg} ${this.T('escToCancel')}`);
    this.draw();
  }

  onStageClick(e) {
    const indEl = e.target.closest('.ind[data-id]');
    const unEl = e.target.closest('g.union[data-union]');
    if (this.pending) {
      if (!indEl && !unEl) { this.pending = null; this.flash(''); this.draw(); return; }
      this.completePick(indEl?.dataset.id, unEl ? Number(unEl.dataset.union) : null);
      return;
    }
    if (indEl) this.sel = { type: 'ind', id: indEl.dataset.id };
    else if (unEl) this.sel = { type: 'union', index: Number(unEl.dataset.union) };
    else this.sel = null;
    this.draw();
  }

  completePick(targetId, unionIndex) {
    const { kind, from } = this.pending;
    if (targetId === from) { this.flash(this.T('pickOther'), true); return; }
    if (kind === 'partner') {
      if (!targetId) return this.flash(this.T('pickPerson'), true);
      return this.commit((m) => {
        if (unionsOf(m, from).some((u) => u.a === targetId || u.b === targetId)) throw new Error(this.T('alreadyPartners'));
        const u = newUnion(m, from, targetId);
        return m.unions.indexOf(u);
      }, { select: (i) => ({ type: 'union', index: i }) });
    }
    if (kind === 'childOf') {
      return this.commit((m) => {
        detachChild(m, from);
        let u;
        if (unionIndex != null && !targetId) u = m.unions[unionIndex];
        else {
          const us = unionsOf(m, targetId);
          u = us.find((x) => x.b) ?? us[0] ?? newUnion(m, targetId);
        }
        u.noChildren = null;
        u.children.push({ kind: 'single', ids: [from] });
      }, { select: { type: 'ind', id: from } });
    }
    if (kind === 'art') {
      if (!targetId) return this.flash(this.T('pickPerson'), true);
      return this.commit((m) => {
        m.links ??= [];
        if (!m.links.some((l) => l.from === from && l.to === targetId)) m.links.push({ from, to: targetId, line: 0 });
        const d = m.individuals.get(from);
        if (!d.surrogate) d.donor = true;
      }, { select: { type: 'ind', id: from } });
    }
    if (kind === 'twin') {
      if (!targetId) return this.flash(this.T('pickTwinErr'), true);
      const twinKind = this.pending.twinKind;
      return this.commit((m) => {
        const pu = parentUnion(m, from);
        if (!pu || parentUnion(m, targetId) !== pu) throw new Error(this.T('twinsSameParents'));
        const g1 = groupOf(pu, from), g2 = groupOf(pu, targetId);
        if (g1 === g2) { g1.kind = twinKind; return; }
        const at = Math.min(pu.children.indexOf(g1), pu.children.indexOf(g2));
        const [first, second] = pu.children.indexOf(g1) < pu.children.indexOf(g2) ? [g1, g2] : [g2, g1];
        const merged = { kind: twinKind, ids: [...first.ids, ...second.ids] }; // keep birth order
        pu.children = pu.children.filter((g) => g !== g1 && g !== g2);
        pu.children.splice(at, 0, merged);
      }, { select: { type: 'ind', id: from } });
    }
  }

  onKey(e) {
    if (!this.editing) return;
    const t = e.target;
    const typing = t instanceof HTMLElement && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName));
    if (e.key === 'Escape') {
      if (this.pending) { this.pending = null; this.flash(''); } else this.sel = null;
      this.draw();
      return;
    }
    if (typing) return;
    const mod = e.metaKey || e.ctrlKey;
    if (mod && e.key.toLowerCase() === 'z') { e.preventDefault(); e.shiftKey ? this.redo() : this.undo(); return; }
    if (mod && e.key.toLowerCase() === 'y') { e.preventDefault(); this.redo(); return; }
    if ((e.key === 'Delete' || e.key === 'Backspace') && this.sel) { e.preventDefault(); this.deleteSelected(); }
  }

  // ---- actions
  addPerson(sex) {
    this.commit((m) => addInd(m, sex).id, { select: (id) => ({ type: 'ind', id }) });
  }

  addPartner(id) {
    this.commit((m) => {
      const p = addInd(m, OPPOSITE[m.individuals.get(id).sex]);
      newUnion(m, id, p.id);
      return p.id;
    }, { select: (pid) => ({ type: 'ind', id: pid }) });
  }

  addParents(id) {
    this.commit((m) => {
      if (parentUnion(m, id)) throw new Error(this.T('hasParents'));
      const f = addInd(m, 'M'), mo = addInd(m, 'F');
      newUnion(m, f.id, mo.id).children.push({ kind: 'single', ids: [id] });
    }, { select: { type: 'ind', id } });
  }

  addChild(id, sex) {
    this.commit((m) => {
      const u = childUnionFor(m, id, OPPOSITE[m.individuals.get(id).sex]);
      const c = addInd(m, sex);
      u.noChildren = null;
      u.children.push({ kind: 'single', ids: [c.id] });
      return c.id;
    }, { select: (cid) => ({ type: 'ind', id: cid }) });
  }

  addChildTo(index, sex) {
    this.commit((m) => {
      const u = m.unions[index];
      const c = addInd(m, sex);
      u.noChildren = null;
      u.children.push({ kind: 'single', ids: [c.id] });
      return c.id;
    }, { select: (cid) => ({ type: 'ind', id: cid }) });
  }

  addSibling(id, sex) {
    this.commit((m) => {
      let pu = parentUnion(m, id);
      if (!pu) {
        const f = addInd(m, 'M'), mo = addInd(m, 'F');
        pu = newUnion(m, f.id, mo.id);
        pu.children.push({ kind: 'single', ids: [id] });
      }
      const s = addInd(m, sex);
      pu.children.splice(pu.children.indexOf(groupOf(pu, id)) + 1, 0, { kind: 'single', ids: [s.id] });
      return s.id;
    }, { select: (sid) => ({ type: 'ind', id: sid }) });
  }

  untwin(id) {
    this.commit((m) => {
      const pu = parentUnion(m, id);
      const g = groupOf(pu, id);
      g.ids = g.ids.filter((x) => x !== id);
      pu.children.splice(pu.children.indexOf(g) + 1, 0, { kind: 'single', ids: [id] });
      normalizeGroups(pu);
    }, { select: { type: 'ind', id } });
  }

  move(id, dir) {
    this.commit((m) => {
      const pu = parentUnion(m, id);
      const i = pu.children.indexOf(groupOf(pu, id));
      const j = i + dir;
      if (j < 0 || j >= pu.children.length) return;
      [pu.children[i], pu.children[j]] = [pu.children[j], pu.children[i]];
    }, { select: { type: 'ind', id } });
  }

  deleteSelected() {
    const s = this.sel;
    if (!s) return;
    if (s.type === 'ind') this.commit((m) => deletePerson(m, s.id), { select: null });
    else this.commit((m) => { m.unions.splice(s.index, 1); }, { select: null });
  }
}

// ---------------------------------------------------------------- bootstrap
let mermaidInstance = null;
const settings = { querySelector: '.pedigree[data-editable]', mermaidSelector: '.mermaid[data-editable]', options: {} };
let wired = false;

/** Tell the editor which Mermaid instance re-renders diagrams when editing ends. */
function setMermaid(instance) { mermaidInstance = instance; }

/** Attach the editor to one element (rendered by the viewer, by Mermaid, or not yet rendered). */
function attachEditor(el, options = {}) {
  return el.pedigreeEditor ?? new PedigreeEditor(el, options);
}

function scan() {
  document.querySelectorAll(settings.querySelector).forEach((el) => attachEditor(el, settings.options));
  // Mermaid hosts: only pedigree diagrams (the plugin stamps data-pedigree-source), not flowcharts etc.
  document.querySelectorAll(settings.mermaidSelector).forEach((el) => {
    if (!el.querySelector(MERMAID_SVG)) return;
    const ed = attachEditor(el, settings.options);
    if (!ed.editing) ed.addToggle();
  });
}

/**
 * Enable edit mode on every matching element, now and whenever the viewer or Mermaid
 * (re)renders one. Runs automatically with defaults when this module is loaded; call it
 * again to pass options, e.g. `enableEditing({ mermaid })`.
 */
function enableEditing({ querySelector, mermaidSelector, mermaid, ...options } = {}) {
  if (querySelector) settings.querySelector = querySelector;
  if (mermaidSelector) settings.mermaidSelector = mermaidSelector;
  if (mermaid) mermaidInstance = mermaid;
  Object.assign(settings.options, options);
  scan();
  if (wired) return;
  wired = true;
  document.addEventListener('pedigree:rendered', scan);
  // Mermaid renders asynchronously and fires no event: watch the DOM instead
  let queued = false;
  new MutationObserver(() => {
    if (queued) return;
    queued = true;
    queueMicrotask(() => { queued = false; scan(); });
  }).observe(document.documentElement, { childList: true, subtree: true });
}

if (typeof document !== 'undefined') {
  const go = () => enableEditing();
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', go, { once: true });
  else go();
}

// model operations, exported for tests and for custom UIs
const ops = { addDisease, conditionKey, parentUnion, unionsOf, addInd, newUnion, detachChild, deletePerson, renamePerson };

return { PedigreeEditor, setMermaid, attachEditor, enableEditing, ops };
})();

__m.mermaid = (() => {
// Mermaid external diagram plugin.
//
//   import mermaid from 'mermaid';
//   import pedigree from 'pedigree-dsl/mermaid';
//   await mermaid.registerExternalDiagrams([pedigree]);
//   mermaid.initialize({ startOnLoad: true });
//
// Then any ```mermaid block starting with `pedigree` renders as a pedigree.
// Per-diagram layout options go in the DSL (Mermaid drops unknown frontmatter config keys):
//
//   pedigree
//     layout symbol=36 vgap=50
//     ...

const { parse } = __m.parser;
const { layout } = __m.layout;
const { renderParts, css } = __m.render;
const { t, resolveLang, pageLang } = __m.i18n;
const { describeText } = __m.describe;

const id = 'pedigree';

const detector = (text) => /^\s*pedigree\b/i.test(text);

let getMermaidConfig = () => ({});

function createDb() {
  let model = null;
  let title = ''; // frontmatter title, set by Mermaid before parse()
  let accTitle = '';
  let accDescription = '';
  return {
    clear() { model = null; title = ''; accTitle = ''; accDescription = ''; },
    setModel(m) { model = m; },
    getModel() { return model; },
    getConfig() { return getMermaidConfig()?.pedigree ?? {}; },
    setDiagramTitle(t) { title = t; },
    getDiagramTitle() { return model?.title || title; },
    setAccTitle(t) { accTitle = t; },
    getAccTitle() { return accTitle || model?.title || ''; },
    setAccDescription(d) { accDescription = d; },
    getAccDescription() {
      if (accDescription) return accDescription;
      if (!model) return '';
      const lang = resolveLang(model.options?.lang, getMermaidConfig()?.pedigree?.lang, pageLang());
      try { return describeText(model, { lang }); } catch {
        const n = model.individuals.size;
        return t(lang, 'acc.description', { n }) + (model.condition ? t(lang, 'acc.condition', { c: model.condition }) : '');
      }
    },
  };
}

const db = createDb();

const parser = {
  parse(text) {
    // Mermaid calls db.clear() and setDiagramTitle(frontmatter title) *before* parse,
    // so parse must not clear. A DSL `title` line wins over the frontmatter one.
    db.setModel(parse(text));
  },
};

const renderer = {
  draw(text, svgId, _version, diagram) {
    const ddb = diagram?.db ?? db;
    const model = ddb.getModel?.() ?? parse(text);
    const cfg = { ...ddb.getConfig?.() };
    const useMaxWidth = cfg.useMaxWidth ?? true;
    delete cfg.useMaxWidth;

    // frontmatter `title:` is stored by Mermaid in its common db; honour it if the DSL has none
    let source = text;
    if (!model.title) {
      model.title = ddb.getDiagramTitle?.() || null;
      // Mermaid strips frontmatter before draw(); keep the title in the source we hand to the editor
      if (model.title) source = `${text.replace(/\s*$/, '')}\n  title ${model.title}\n`;
    }
    const fullCfg = { ...cfg, useMaxWidth };

    const svgEl = document.getElementById(svgId);
    const L = layout(model, { lang: pageLang(svgEl), ...cfg });
    const p = renderParts(L, { idPrefix: svgId });

    const svg = document.getElementById(svgId);
    if (!svg) throw new Error(`pedigree: target <svg id="${svgId}"> not found`);
    svg.setAttribute('viewBox', `0 0 ${p.width} ${p.height}`);
    // the DSL travels with the SVG so editor.js can edit Mermaid-rendered diagrams
    svg.setAttribute('data-pedigree-source', source);
    svg.setAttribute('data-pedigree-config', JSON.stringify(fullCfg));
    if (useMaxWidth) {
      svg.setAttribute('width', '100%');
      svg.style.maxWidth = `${p.width}px`;
    } else {
      svg.setAttribute('width', String(p.width));
      svg.setAttribute('height', String(p.height));
    }
    svg.insertAdjacentHTML('beforeend', `<defs>${p.defs}</defs><rect class="bg" width="100%" height="100%"/>${p.body}`);
  },
};

// Mermaid passes the flattened theme variables; map them onto the pedigree palette.
const styles = (o = {}) =>
  css({
    scope: '',
    fontSize: 12,
    theme: {
      ink: o.lineColor || o.primaryTextColor || '#111',
      paper: o.background || o.mainBkg || '#fff',
      muted: o.tertiaryTextColor || o.textColor || '#666',
      border: o.lineColor || '#888',
      fontFamily: o.fontFamily || 'Helvetica, Arial, sans-serif',
    },
  });

const diagram = {
  db,
  parser,
  renderer,
  styles,
  injectUtils(_log, _setLogLevel, _getConfig) {
    if (typeof _getConfig === 'function') getMermaidConfig = _getConfig;
  },
};

const plugin = {
  id,
  detector,
  loader: async () => ({ id, diagram }),
};



return { id, detector, diagram, default: plugin };
})();
window.Pedigree = { ...__m.index, ...__m.editor, mermaidPlugin: __m.mermaid.default };
})();
