//
//  MPPreferences.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <PAPreferences/PAPreferences.h>


extern NSString * const MPDidDetectFreshInstallationNotification;


@interface MPPreferences : PAPreferences

@property (assign) NSString *firstVersionInstalled;
@property (assign) NSString *latestVersionInstalled;
@property (assign) BOOL supressesUntitledDocumentOnLaunch;
@property (assign) BOOL createFileForLinkTarget;

// Extension flags.
@property (assign) BOOL extensionIntraEmphasis;
@property (assign) BOOL extensionTables;
@property (assign) BOOL extensionFencedCode;
@property (assign) BOOL extensionAutolink;
@property (assign) BOOL extensionStrikethough;
@property (assign) BOOL extensionUnderline;
@property (assign) BOOL extensionSuperscript;
@property (assign) BOOL extensionHighlight;
@property (assign) BOOL extensionFootnotes;
@property (assign) BOOL extensionQuote;
@property (assign) BOOL extensionSmartyPants;

@property (assign) BOOL markdownManualRender;

@property (assign) NSDictionary *editorBaseFontInfo;
@property (assign) BOOL editorAutoIncrementNumberedLists;
@property (assign) BOOL editorConvertTabs;
@property (assign) BOOL editorInsertPrefixInBlock;
@property (assign) BOOL editorCompleteMatchingCharacters;
@property (assign) BOOL editorSyncScrolling;
@property (assign) BOOL editorSmartHome;
@property (assign) NSString *editorStyleName;
@property (assign) CGFloat editorHorizontalInset;
@property (assign) CGFloat editorVerticalInset;
@property (assign) CGFloat editorLineSpacing;
@property (assign) BOOL editorWidthLimited;
@property (assign) CGFloat editorMaximumWidth;
@property (assign) BOOL editorOnRight;
@property (assign) BOOL editorShowWordCount;
@property (assign) NSInteger editorWordCountType;
@property (assign) BOOL editorScrollsPastEnd;
@property (assign) BOOL editorEnsuresNewlineAtEndOfFile;
@property (assign) NSInteger editorUnorderedListMarkerType;

@property (assign) BOOL previewZoomRelativeToBaseFontSize;

@property (assign) NSString *htmlTemplateName;
@property (assign) NSString *htmlStyleName;
@property (assign) BOOL htmlDetectFrontMatter;
@property (assign) BOOL htmlTaskList;
@property (assign) BOOL htmlHardWrap;
@property (assign) BOOL htmlMathJax;
@property (assign) BOOL htmlMathJaxInlineDollar;
@property (assign) BOOL htmlSyntaxHighlighting;
@property (assign) NSString *htmlHighlightingThemeName;
@property (assign) BOOL htmlLineNumbers;
@property (assign) BOOL htmlGraphviz;
@property (assign) BOOL htmlMermaid;
/// Whether [[…]] becomes a link to a neighbouring document.
@property (assign) BOOL htmlWikiLinks;
/// Whether a new document starts with the prose checker on.
@property (assign) BOOL editorProseHighlights;
/// Whether the editor sets headings larger, emphasis italic and so on,
/// instead of showing the source in one uniform face.
@property (assign) BOOL editorSemanticStyling;
/// Whether the editor hides the Markdown markers until the caret arrives.
@property (assign) BOOL editorHideMarkers;

/// Whether what is asked of the editor is written down. Off.
@property (assign) BOOL diagnosticsRecording;

/// Dims all but the paragraph being written. Off: it is a mode, not a look.
@property (assign) BOOL editorFocusMode;
/// Keeps the line being written at the same height. Off, for the same reason.
@property (assign) BOOL editorTypewriter;
/// Whether lists are indented, quotations get a bar and headings get room.
@property (assign) BOOL editorBlockLayout;

/** Whether an export goes and gets the pictures kept on the web.
 *
 * A .docx and an EPUB are packages, so a picture they do not carry is a
 * picture nobody sees. Fetching it means an export makes network requests,
 * which is a thing some people will want to forbid — hence the switch,
 * though it is on, because an export that quietly drops half the figures
 * is the worse surprise.
 */
@property (assign) BOOL exportFetchesRemoteImages;

/** Whether the writing commands are offered at all.
 *
 * On, because they are the reason someone would install a model; and a
 * switch, because someone who never wants them should not have a submenu
 * of things that do nothing. With it off the commands go away and the
 * Models panel stays — a model already downloaded is still theirs to
 * manage or delete.
 */
@property (assign) BOOL editorWritingHelp;
/// Whether pasting formatted text writes the Markdown that means the same.
@property (assign) BOOL editorPasteAsMarkdown;
/// Whether a pipe table's columns are drawn lined up, source untouched.
/// Identifiers of plug-ins the user has switched off. Absent means enabled,
/// so a newly dropped-in plug-in works without being turned on first.
@property (copy) NSArray<NSString *> *disabledPlugIns;
/// Whether the card on a web link asks the page what it is. Off: the card
/// takes the address apart instead, and nothing is fetched.
@property (assign) BOOL previewFetchesLinkPages;
/// Whether selecting text in the preview selects it in the editor too.
@property (assign) BOOL previewSelectionSelectsSource;

/// Whether an assistant may use the folder server at all. On, because the
/// server only runs when a client starts it — the switch is here so that a
/// thing that can be turned off can also be turned on without worrying.
@property (assign) BOOL agentsAllowed;
/// The folder the panel writes into the line you paste in a client's
/// configuration. Nothing reads it but that line.
@property (copy) NSString *agentsFolderPath;
/// What that line asks for: 0 reading, 1 appending, 2 writing.
@property (assign) NSInteger agentsWritingLevel;

/// Whether the application looks for a newer release by itself, once a day.
@property (assign) BOOL updatesCheckAutomatically;
/// When it last looked, whatever the answer was.
@property (assign) NSDate *updatesLastCheck;

@property (assign) NSInteger htmlCodeBlockAccessory;
@property (assign) NSURL *htmlDefaultDirectoryUrl;
@property (assign) BOOL htmlRendersTOC;

// Calculated values.
@property (readonly) NSString *editorBaseFontName;
@property (readonly) CGFloat editorBaseFontSize;
@property (nonatomic, assign) NSFont *editorBaseFont;
@property (readonly) NSString *editorUnorderedListMarker;

- (instancetype)init;

// Convinience methods.
@property (nonatomic, assign) NSArray *filesToOpen;
@property (nonatomic, assign) NSString *pipedContentFileToOpen;

@end
