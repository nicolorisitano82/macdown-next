//
//  MPMailer.m
//  MacDown
//

#import "MPMailer.h"


@implementation MPMailClient
@end


/// Il tipo MIME di un'immagine dal suo nome, per il `data:`.
static NSString *MPMailImageType(NSURL *url)
{
    static NSDictionary *types = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        types = @{@"png": @"image/png", @"jpg": @"image/jpeg",
                  @"jpeg": @"image/jpeg", @"gif": @"image/gif",
                  @"svg": @"image/svg+xml", @"webp": @"image/webp",
                  @"heic": @"image/heic", @"tif": @"image/tiff",
                  @"tiff": @"image/tiff", @"bmp": @"image/bmp"};
    });
    return types[url.pathExtension.lowercaseString] ?: @"application/octet-stream";
}


NSString *MPHTMLWithLocalImagesInlined(NSString *html, NSURL *base)
{
    if (!html.length)
        return html ?: @"";

    static NSRegularExpression *images = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        images = [NSRegularExpression regularExpressionWithPattern:
            @"<img\\b[^>]*?\\bsrc\\s*=\\s*[\"']([^\"']+)[\"']"
            options:NSRegularExpressionCaseInsensitive error:NULL];
    });

    NSMutableString *made = [html mutableCopy];
    NSArray<NSTextCheckingResult *> *found = [images
        matchesInString:html options:0 range:NSMakeRange(0, html.length)];
    // All'indietro: sostituire dal fondo lascia validi gli indici di prima.
    for (NSTextCheckingResult *one in found.reverseObjectEnumerator)
    {
        NSRange where = [one rangeAtIndex:1];
        NSString *source = [html substringWithRange:where];
        NSString *low = source.lowercaseString;
        if ([low hasPrefix:@"data:"] || [low hasPrefix:@"http:"]
                || [low hasPrefix:@"https:"] || [low hasPrefix:@"cid:"])
            continue;

        NSURL *url = [low hasPrefix:@"file:"]
            ? [NSURL URLWithString:source]
            : [NSURL URLWithString:
                [source stringByRemovingPercentEncoding] ?: source
                relativeToURL:base];
        if (!url.isFileURL)
            continue;
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (!data.length)
            continue;   // un file che non c'è resta scritto com'era

        [made replaceCharactersInRange:where withString:
            [NSString stringWithFormat:@"data:%@;base64,%@",
                MPMailImageType(url),
                [data base64EncodedStringWithOptions:0]]];
    }
    return made;
}


/// Una stringa dentro uno script: le virgolette e le barre vanno dette.
static NSString *MPAppleScriptString(NSString *text)
{
    NSString *safe = [text ?: @"" stringByReplacingOccurrencesOfString:@"\\"
                                                           withString:@"\\\\"];
    safe = [safe stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    safe = [safe stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    return [safe stringByReplacingOccurrencesOfString:@"\r" withString:@""];
}


@implementation MPMailer

+ (NSArray<MPMailClient *> *)clients
{
    NSMutableArray<MPMailClient *> *found = [NSMutableArray array];
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSURL *mailto = [NSURL URLWithString:@"mailto:"];

    NSURL *preferred = [workspace URLForApplicationToOpenURL:mailto];
    NSMutableArray<NSURL *> *applications = [[workspace
        URLsForApplicationsToOpenURL:mailto] mutableCopy] ?: [NSMutableArray array];
    // Quello che il sistema userebbe da sé viene per primo, e una volta
    // sola: è la scelta che quasi tutti vogliono.
    if (preferred)
    {
        [applications removeObject:preferred];
        [applications insertObject:preferred atIndex:0];
    }

    for (NSURL *url in applications)
    {
        MPMailClient *client = [[MPMailClient alloc] init];
        client.applicationURL = url;
        client.name = [[NSFileManager defaultManager]
            displayNameAtPath:url.path].stringByDeletingPathExtension;
        client.icon = [workspace iconForFile:url.path];
        NSBundle *bundle = [NSBundle bundleWithURL:url];
        client.way = [bundle.bundleIdentifier isEqualToString:@"com.apple.mail"]
            ? MPMailWayAppleMail : MPMailWayApplication;
        [found addObject:client];
    }

    // La posta che non si installa. L'oggetto ci sta nell'indirizzo; il
    // corpo no, e per quello ci sono gli appunti.
    MPMailClient *gmail = [[MPMailClient alloc] init];
    gmail.name = @"Gmail";
    gmail.way = MPMailWayWeb;
    gmail.composeFormat = @"https://mail.google.com/mail/?view=cm&fs=1&tf=1&su=%@";
    [found addObject:gmail];

    MPMailClient *outlook = [[MPMailClient alloc] init];
    outlook.name = @"Outlook Web";
    outlook.way = MPMailWayWeb;
    outlook.composeFormat =
        @"https://outlook.office.com/mail/deeplink/compose?subject=%@";
    [found addObject:outlook];

    return found;
}


+ (NSString *)plainTextFrom:(NSString *)html
{
    NSData *data = [html ?: @"" dataUsingEncoding:NSUTF8StringEncoding];
    NSAttributedString *read = [[NSAttributedString alloc] initWithHTML:data
        options:@{NSCharacterEncodingDocumentOption: @(NSUTF8StringEncoding)}
        documentAttributes:NULL];
    return read.string ?: @"";
}


+ (NSString *)appleMailScriptForSubject:(NSString *)subject
                                htmlAt:(NSString *)path
{
    // L'HTML sta in un file e lo script lo legge: infilarlo nello script
    // vorrebbe dire una riga di codice lunga quanto il documento, con ogni
    // virgoletta da proteggere, e un'immagine dentro la fa megabyte.
    return [NSString stringWithFormat:
        @"set theFile to POSIX file \"%@\"\n"
        @"set theHTML to read theFile as «class utf8»\n"
        @"tell application \"Mail\"\n"
        @"  set theMessage to make new outgoing message with properties "
        @"{subject:\"%@\", visible:true}\n"
        @"  tell theMessage to set html content to theHTML\n"
        @"  activate\n"
        @"end tell\n",
        MPAppleScriptString(path), MPAppleScriptString(subject)];
}


+ (BOOL)open:(MPMailClient *)client
     subject:(NSString *)subject
        html:(NSString *)html
       plain:(NSString *)plain
wantsPasting:(BOOL *)wantsPasting
     problem:(NSString **)problem
{
    if (wantsPasting)
        *wantsPasting = NO;
    if (!client)
    {
        if (problem)
            *problem = NSLocalizedString(@"No mail program was chosen.",
                @"Opening a document as mail without a program");
        return NO;
    }

    if (client.way == MPMailWayAppleMail)
        return [self openMail:subject html:html problem:problem];

    // Le altre due strade sono la stessa: l'email negli appunti, e una
    // finestra di composizione aperta dove si è chiesto.
    [self putOnThePasteboard:html plain:plain];
    if (wantsPasting)
        *wantsPasting = YES;

    NSString *escaped = [subject ?: @"" stringByAddingPercentEncodingWithAllowedCharacters:
        [NSCharacterSet URLQueryAllowedCharacterSet]] ?: @"";
    if (client.way == MPMailWayWeb)
    {
        NSURL *compose = [NSURL URLWithString:
            [NSString stringWithFormat:client.composeFormat, escaped]];
        if (!compose)
        {
            if (problem)
                *problem = NSLocalizedString(@"That address could not be built.",
                    @"Failure building a webmail compose address");
            return NO;
        }
        return [[NSWorkspace sharedWorkspace] openURL:compose];
    }

    NSURL *mailto = [NSURL URLWithString:
        [NSString stringWithFormat:@"mailto:?subject=%@", escaped]];
    NSWorkspaceOpenConfiguration *how =
        [NSWorkspaceOpenConfiguration configuration];
    how.activates = YES;
    [[NSWorkspace sharedWorkspace] openURLs:@[mailto]
                       withApplicationAtURL:client.applicationURL
                              configuration:how completionHandler:nil];
    return YES;
}


/// Il messaggio in Mail, formattato, con uno script.
+ (BOOL)openMail:(NSString *)subject html:(NSString *)html
         problem:(NSString **)problem
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"macdown-email-%@.html",
            [NSUUID UUID].UUIDString]];
    NSError *writing = nil;
    if (![html ?: @"" writeToFile:path atomically:YES
                        encoding:NSUTF8StringEncoding error:&writing])
    {
        if (problem)
            *problem = writing.localizedDescription;
        return NO;
    }

    NSDictionary *bad = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:
        [self appleMailScriptForSubject:subject htmlAt:path]];
    [script executeAndReturnError:&bad];
    if (bad)
    {
        if (problem)
            *problem = bad[NSAppleScriptErrorBriefMessage]
                    ?: bad[NSAppleScriptErrorMessage]
                    ?: NSLocalizedString(@"Mail did not answer.",
                        @"Failure talking to Mail");
        return NO;
    }
    return YES;
}


/// L'email negli appunti: testo ricco per chi lo sa leggere, testo
/// semplice per chi no.
+ (void)putOnThePasteboard:(NSString *)html plain:(NSString *)plain
{
    NSPasteboard *board = [NSPasteboard generalPasteboard];
    [board clearContents];
    [board declareTypes:@[NSPasteboardTypeHTML, NSPasteboardTypeString]
                  owner:nil];
    [board setString:html ?: @"" forType:NSPasteboardTypeHTML];
    [board setString:plain ?: @"" forType:NSPasteboardTypeString];
}

@end
