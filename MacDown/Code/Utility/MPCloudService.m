//
//  MPCloudService.m
//  MacDown
//

#import "MPCloudService.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "MPCloudLedger.h"

#import <AppKit/AppKit.h>
#import <Security/Security.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#include <CommonCrypto/CommonDigest.h>


static NSString *const kMPKeychainService = @"MacDown Next — spazi in rete";


#pragma mark - Il portachiavi

/// Una password generica per servizio e conto. Il portachiavi è l'unico
/// posto in cui queste cose hanno il diritto di stare.
static NSString *MPKeychainRead(NSString *account)
{
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kMPKeychainService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef found = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &found) != errSecSuccess)
        return nil;
    NSData *data = CFBridgingRelease(found);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}


static void MPKeychainWrite(NSString *account, NSString *value)
{
    NSDictionary *what = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kMPKeychainService,
        (__bridge id)kSecAttrAccount: account,
    };
    SecItemDelete((__bridge CFDictionaryRef)what);
    if (!value.length)
        return;

    NSMutableDictionary *item = [what mutableCopy];
    item[(__bridge id)kSecValueData] =
        [value dataUsingEncoding:NSUTF8StringEncoding];
    // Solo quando questo Mac è sbloccato, e senza sincronizzarsi altrove:
    // un gettone che gira fra i dispositivi di qualcuno non è affare
    // nostro.
    item[(__bridge id)kSecAttrAccessible] =
        (__bridge id)kSecAttrAccessibleWhenUnlocked;
    SecItemAdd((__bridge CFDictionaryRef)item, NULL);
}


#pragma mark - PKCE

static NSString *MPBase64URL(NSData *data)
{
    NSString *text = [data base64EncodedStringWithOptions:0];
    text = [text stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    text = [text stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [text stringByReplacingOccurrencesOfString:@"=" withString:@""];
}


NSString *MPCloudPKCEChallenge(NSString *verifier)
{
    NSData *data = [verifier dataUsingEncoding:NSASCIIStringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    return MPBase64URL([NSData dataWithBytes:digest length:sizeof(digest)]);
}


static NSString *MPRandomVerifier(void)
{
    uint8_t bytes[48];
    arc4random_buf(bytes, sizeof(bytes));
    return MPBase64URL([NSData dataWithBytes:bytes length:sizeof(bytes)]);
}


#pragma mark - L'ascolto del richiamo

/// Una porta sola su 127.0.0.1, scelta dal sistema: un client desktop è
/// ammesso sul loopback da qualunque porta, quindi non c'è niente da
/// registrare a ogni giro.
static int MPListenOnLoopback(uint16_t *outPort)
{
    int handle = socket(AF_INET, SOCK_STREAM, 0);
    if (handle < 0)
        return -1;
    int yes = 1;
    setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(handle, (struct sockaddr *)&address, sizeof(address)) < 0
            || listen(handle, 1) < 0)
    {
        close(handle);
        return -1;
    }
    socklen_t size = sizeof(address);
    getsockname(handle, (struct sockaddr *)&address, &size);
    *outPort = ntohs(address.sin_port);
    return handle;
}


/// Aspetta il richiamo, ma non per sempre.
///
/// Chi apre il consenso e poi chiude la finestra non torna mai, e senza una
/// scadenza il pannello resterebbe su «aspetto il browser» finché non si
/// chiude l'applicazione — con il pulsante spento. Cinque minuti sono più
/// di quanto serva a dare un permesso, e meno di quanto serva a dimenticare
/// di averlo chiesto.
static const time_t kMPConsentPatience = 300;

static NSDictionary *MPAcceptCallback(int listener)
{
    fd_set waiting;
    FD_ZERO(&waiting);
    FD_SET(listener, &waiting);
    struct timeval limit = {.tv_sec = kMPConsentPatience, .tv_usec = 0};
    if (select(listener + 1, &waiting, NULL, NULL, &limit) <= 0)
        return nil;             // nessuno è tornato: si smette di aspettare

    int client = accept(listener, NULL, NULL);
    if (client < 0)
        return nil;

    char buffer[8192];
    ssize_t got = read(client, buffer, sizeof(buffer) - 1);
    if (got <= 0)
    {
        close(client);
        return nil;
    }
    buffer[got] = '\0';

    NSString *line = [@(buffer) componentsSeparatedByString:@"\r\n"].firstObject;
    NSArray *parts = [line componentsSeparatedByString:@" "];
    NSString *path = parts.count > 1 ? parts[1] : @"/";

    NSString *body = NSLocalizedString(
        @"<!doctype html><meta charset=utf-8><title>Done</title>"
        @"<body style=\"font:16px -apple-system;padding:3em\">"
        @"<p>Done — you can close this tab and go back to MacDown Next.",
        @"The page the browser shows after the permission is handed back");
    NSString *response = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n"
        @"Content-Length: %lu\r\nConnection: close\r\n\r\n%@",
        (unsigned long)[body lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
        body];
    NSData *out = [response dataUsingEncoding:NSUTF8StringEncoding];
    write(client, out.bytes, out.length);
    close(client);

    NSURLComponents *url = [NSURLComponents componentsWithString:
        [@"http://127.0.0.1" stringByAppendingString:path]];
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in url.queryItems)
        values[item.name] = item.value ?: @"";
    return values;
}


#pragma mark - Quello che ogni servizio deve saper dire

@interface MPCloudService ()
- (NSString *)freshToken:(NSString **)outProblem;
@property (copy, nonatomic) NSString *problem;
@property (assign, nonatomic) BOOL linking;
/// Cosa si sta andando a scegliere in questo giro.
@property (assign, nonatomic) MPCloudPick picking;
@end


/// La data come la scrive Drive — RFC 3339, con i millesimi — letta una
/// volta sola: un formattatore costruito per ogni riga di un elenco è il
/// modo classico di rendere lento qualcosa che non lo è.
NSDate *MPDateFromDrive(NSString *written)
{
    if (!written.length)
        return nil;
    static NSISO8601DateFormatter *reader = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        reader = [[NSISO8601DateFormatter alloc] init];
        reader.formatOptions = NSISO8601DateFormatWithInternetDateTime
                             | NSISO8601DateFormatWithFractionalSeconds;
    });
    return [reader dateFromString:written]
        ?: [[[NSISO8601DateFormatter alloc] init] dateFromString:written];
}


@implementation MPCloudDocument
@end


@implementation MPCloudService

+ (NSArray<MPCloudService *> *)services
{
    static NSArray *services = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        services = @[[[NSClassFromString(@"MPGoogleDriveService") alloc] init],
                     [[NSClassFromString(@"MPICloudService") alloc] init],
                     [[NSClassFromString(@"MPDropboxService") alloc] init]];
    });
    return services;
}


#pragma mark Da riempire nelle sottoclassi

- (NSString *)name { return @""; }
- (NSString *)identifier { return @""; }
- (NSString *)symbolName { return @"externaldrive.connected.to.line.below"; }
/// Se il pannello lo lascia toccare. Un servizio che non c'è ancora si
/// mostra lo stesso: nasconderlo vorrebbe dire far cercare alla gente una
/// cosa che è in programma.
- (BOOL)available { return YES; }
/// Se si porta un client OAuth proprio. iCloud Drive no: è una cartella.
- (BOOL)needsAClient { return YES; }
/// Se i documenti che esistono già si passano uno per uno. Dove la
/// cartella li porta tutti, questa domanda non si fa.
- (BOOL)picksDocuments { return YES; }
/// Se «scollega» vuol dire qualcosa: dove il permesso è un gettone, sì.
- (BOOL)canDisconnect { return YES; }
- (NSString *)consoleButtonTitle { return @""; }
- (NSURL *)consoleURL { return nil; }
- (NSString *)explanation { return @""; }
- (NSString *)howToGetAClient { return @""; }
- (NSString *)clientPlaceholder { return @""; }
- (NSString *)scopeExplanation { return @""; }

/// L'indirizzo del consenso, senza le parti comuni.
- (NSURLComponents *)consentComponentsWithRedirect:(NSString *)redirect
                                         challenge:(NSString *)challenge
{
    return nil;
}

- (NSURL *)tokenURL { return nil; }

/// Cosa fare col richiamo, oltre allo scambio del codice: Drive ci mette
/// dentro quello che la persona ha scelto, Dropbox no.
- (void)rememberFromCallback:(NSDictionary *)callback
                       token:(NSString *)token { }


#pragma mark Quello che vale per tutti

- (NSString *)defaultsKey:(NSString *)what
{
    return [NSString stringWithFormat:@"cloud.%@.%@", self.identifier, what];
}

- (NSString *)keychainAccount:(NSString *)what
{
    return [NSString stringWithFormat:@"%@/%@", self.identifier, what];
}

- (NSString *)clientIdentifier
{
    return [[NSUserDefaults standardUserDefaults]
        stringForKey:[self defaultsKey:@"client"]] ?: @"";
}

- (void)setClientIdentifier:(NSString *)identifier
{
    NSString *clean = [identifier stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    [[NSUserDefaults standardUserDefaults] setObject:clean
        forKey:[self defaultsKey:@"client"]];
}

- (NSString *)clientSecret
{
    return MPKeychainRead([self keychainAccount:@"secret"]) ?: @"";
}

- (void)setClientSecret:(NSString *)secret
{
    MPKeychainWrite([self keychainAccount:@"secret"],
                    [secret stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]]);
}

- (BOOL)isConfigured
{
    return self.clientIdentifier.length >= 8;
}

- (BOOL)isLinked
{
    return MPKeychainRead([self keychainAccount:@"refresh"]).length > 0;
}

- (NSString *)placeIdentifier
{
    return [[NSUserDefaults standardUserDefaults]
        stringForKey:[self defaultsKey:@"place"]];
}

- (NSString *)placeName
{
    return [[NSUserDefaults standardUserDefaults]
        stringForKey:[self defaultsKey:@"placeName"]];
}

- (void)rememberPlace:(NSString *)identifier named:(NSString *)name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:identifier ?: @"" forKey:[self defaultsKey:@"place"]];
    [defaults setObject:name ?: @"" forKey:[self defaultsKey:@"placeName"]];
}

- (NSInteger)visibleInPlace
{
    NSNumber *count = [[NSUserDefaults standardUserDefaults]
        objectForKey:[self defaultsKey:@"visible"]];
    return count ? count.integerValue : -1;
}

- (void)rememberVisible:(NSInteger)count
{
    [[NSUserDefaults standardUserDefaults] setObject:@(count)
        forKey:[self defaultsKey:@"visible"]];
}

- (void)unlink
{
    MPKeychainWrite([self keychainAccount:@"refresh"], nil);
    self.problem = nil;
    // Il registro è quello che sapevamo di un collegamento che non c'è
    // più: tenerlo vorrebbe dire ricominciare con delle idee sbagliate.
    [[MPCloudLedger ledgerFor:self.identifier] forget];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:[self defaultsKey:@"place"]];
    [defaults removeObjectForKey:[self defaultsKey:@"placeName"]];
    [defaults removeObjectForKey:[self defaultsKey:@"visible"]];
}


#pragma mark La verifica, e il rinnovo che le serve

/// Un gettone valido adesso, chiesto con quello di rinnovo. Sincrona: chi
/// la chiama è già su una coda di fondo.
- (NSString *)freshToken:(NSString **)outProblem
{
    NSString *refresh = MPKeychainRead([self keychainAccount:@"refresh"]);
    if (!refresh.length)
    {
        if (outProblem)
            *outProblem = NSLocalizedString(@"Not connected.",
                                            @"State: no permission yet");
        return nil;
    }

    NSMutableArray *fields = [NSMutableArray arrayWithArray:@[
        [NSString stringWithFormat:@"client_id=%@", self.clientIdentifier],
        [NSString stringWithFormat:@"refresh_token=%@", refresh],
        @"grant_type=refresh_token",
    ]];
    NSString *secret = self.clientSecret;
    if (secret.length)
        [fields addObject:[NSString stringWithFormat:@"client_secret=%@",
                           secret]];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:self.tokenURL];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded"
   forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [[fields componentsJoinedByString:@"&"]
        dataUsingEncoding:NSUTF8StringEncoding];

    __block NSData *got = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *body, NSURLResponse *r, NSError *e) {
        got = body;
        dispatch_semaphore_signal(done);
    }] resume];
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW,
                                                30 * NSEC_PER_SEC));
    NSDictionary *tokens = got
        ? [NSJSONSerialization JSONObjectWithData:got options:0 error:NULL] : nil;
    if (![tokens isKindOfClass:[NSDictionary class]]
            || !tokens[@"access_token"])
    {
        if (outProblem)
            *outProblem = tokens[@"error_description"] ?: tokens[@"error"]
                ?: NSLocalizedString(@"The service did not answer.",
                        @"The token endpoint gave nothing back");
        return nil;
    }
    return tokens[@"access_token"];
}


/// Una richiesta qualunque, aspettata, con il gettone addosso.
static NSDictionary *MPSend(NSMutableURLRequest *request, NSString *token,
                            NSString **outText)
{
    [request setValue:[@"Bearer " stringByAppendingString:token ?: @""]
   forHTTPHeaderField:@"Authorization"];

    __block NSData *got = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *body, NSURLResponse *r, NSError *e) {
        got = body;
        dispatch_semaphore_signal(done);
    }] resume];
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW,
                                                60 * NSEC_PER_SEC));
    if (!got)
        return nil;
    if (outText)
        *outText = [[NSString alloc] initWithData:got
                                         encoding:NSUTF8StringEncoding];
    id parsed = [NSJSONSerialization JSONObjectWithData:got options:0
                                                  error:NULL];
    return [parsed isKindOfClass:[NSDictionary class]] ? parsed : nil;
}


/// Quello che il servizio risponde a «cosa vedi». Nelle sottoclassi.
- (NSString *)lookAroundWithToken:(NSString *)token { return nil; }


- (void)checkWithCompletion:(void (^)(NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *problem = nil;
        NSString *token = [self freshToken:&problem];
        if (token)
            problem = [self lookAroundWithToken:token];
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(problem);
        });
    });
}


#pragma mark Il collegamento, uguale per tutti

- (void)linkWithCompletion:(void (^)(MPCloudLinkOutcome, NSString *))done
{
    [self link:MPCloudPickFolder completion:done];
}


- (void)link:(MPCloudPick)what
  completion:(void (^)(MPCloudLinkOutcome, NSString *))done
{
    self.picking = what;
    void (^answer)(MPCloudLinkOutcome, NSString *) =
        ^(MPCloudLinkOutcome outcome, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.linking = NO;
            if (done)
                done(outcome, message);
        });
    };

    if (!self.isConfigured)
    {
        answer(MPCloudLinkBroken, NSLocalizedString(
            @"There is no client ID yet.",
            @"Refusing to link a service without a client ID"));
        return;
    }
    if (self.linking)
        return;
    self.linking = YES;

    NSString *verifier = MPRandomVerifier();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        uint16_t port = 0;
        int listener = MPListenOnLoopback(&port);
        if (listener < 0)
        {
            answer(MPCloudLinkBroken, NSLocalizedString(
                @"No port on this Mac would answer.",
                @"The loopback listener could not be opened"));
            return;
        }
        NSString *redirect = [NSString stringWithFormat:
            @"http://127.0.0.1:%u/macdown-%@", port, self.identifier];

        NSURL *consent = MPCloudConsentURL(self, redirect,
                                           MPCloudPKCEChallenge(verifier));
        if (!consent)
        {
            close(listener);
            answer(MPCloudLinkBroken, nil);
            return;
        }
        [[NSWorkspace sharedWorkspace] openURL:consent];

        NSDictionary *callback = MPAcceptCallback(listener);
        close(listener);
        if (!callback)
        {
            answer(MPCloudLinkCancelled, nil);
            return;
        }
        if (callback[@"error"])
        {
            answer(MPCloudLinkRefused,
                   callback[@"error_description"] ?: callback[@"error"]);
            return;
        }
        [self exchange:callback verifier:verifier redirect:redirect
                answer:answer];
    });
}


- (void)exchange:(NSDictionary *)callback
        verifier:(NSString *)verifier
        redirect:(NSString *)redirect
          answer:(void (^)(MPCloudLinkOutcome, NSString *))answer
{
    NSMutableArray *fields = [NSMutableArray arrayWithArray:@[
        [NSString stringWithFormat:@"client_id=%@", self.clientIdentifier],
        [NSString stringWithFormat:@"code=%@", callback[@"code"] ?: @""],
        [NSString stringWithFormat:@"code_verifier=%@", verifier],
        @"grant_type=authorization_code",
        [NSString stringWithFormat:@"redirect_uri=%@",
         [redirect stringByAddingPercentEncodingWithAllowedCharacters:
          [NSCharacterSet alphanumericCharacterSet]]],
    ]];
    NSString *secret = self.clientSecret;
    if (secret.length)
        [fields addObject:[NSString stringWithFormat:@"client_secret=%@",
                           secret]];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:self.tokenURL];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded"
   forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [[fields componentsJoinedByString:@"&"]
        dataUsingEncoding:NSUTF8StringEncoding];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *e) {
        NSDictionary *tokens = data
            ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]
            : nil;
        if (![tokens isKindOfClass:[NSDictionary class]]
                || !tokens[@"access_token"])
        {
            // Le parole del servizio, non le nostre: un client sbagliato e
            // un permesso negato si distinguono solo così.
            NSString *said = tokens[@"error_description"] ?: tokens[@"error"]
                          ?: tokens[@"error_summary"] ?: e.localizedDescription;
            answer(MPCloudLinkRefused, said);
            return;
        }
        if (tokens[@"refresh_token"])
            MPKeychainWrite([self keychainAccount:@"refresh"],
                            tokens[@"refresh_token"]);

        [self rememberFromCallback:callback token:tokens[@"access_token"]];
        answer(MPCloudLinkDone, nil);
    }] resume];
}

@end


#pragma mark - L'indirizzo del consenso

NSURL *MPCloudConsentURL(MPCloudService *service, NSString *redirect,
                         NSString *challenge)
{
    NSURLComponents *url = [service consentComponentsWithRedirect:redirect
                                                        challenge:challenge];
    if (!url)
        return nil;
    NSMutableArray *items = [url.queryItems mutableCopy] ?: [NSMutableArray array];
    // Le tre che valgono per tutti e due, aggiunte qui così nessuno se le
    // dimentica in una sottoclasse.
    [items addObject:[NSURLQueryItem queryItemWithName:@"client_id"
                                                 value:service.clientIdentifier]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"redirect_uri"
                                                 value:redirect]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"response_type"
                                                 value:@"code"]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"code_challenge"
                                                 value:challenge]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"code_challenge_method"
                                                 value:@"S256"]];
    url.queryItems = items;
    return url.URL;
}


#pragma mark - Google Drive

@interface MPGoogleDriveService : MPCloudService
@end

@implementation MPGoogleDriveService

- (NSString *)name { return @"Google Drive"; }
- (NSString *)identifier { return @"google"; }
- (NSString *)consoleButtonTitle
{
    return NSLocalizedString(@"Open the Google Cloud console…",
                             @"Opens the page where a Google client is made");
}
- (NSURL *)consoleURL
{
    return [NSURL URLWithString:
        @"https://console.cloud.google.com/apis/credentials"];
}

- (NSString *)explanation
{
    return NSLocalizedString(
        @"Google asks for an application of its own, and this one does not "
        @"carry one: a client inside a program is a client anybody can take "
        @"out, and one for everybody would mean a single verification, a "
        @"single quota and a consent screen with somebody else's name on "
        @"it. Standard use of the Drive API costs nothing.",
        @"Why you bring your own Google client");
}

- (NSString *)howToGetAClient
{
    return NSLocalizedString(
        @"Make a project, enable the Google Drive API, then Credentials ▸ "
        @"Create credentials ▸ OAuth client ID, of type Desktop app. Copy "
        @"the ID. There is no redirect address to register: a desktop "
        @"client may come back to this Mac on any port.\n\n"
        @"Then press Publish app on the consent screen. It is the step "
        @"everybody misses, and without it Google answers «this app has "
        @"not completed verification and is only open to approved "
        @"testers». Publishing asks for no verification here, because "
        @"drive.file is not one of the scopes Google calls sensitive — and "
        @"it matters for a second reason: while the project stays in "
        @"testing, Google hands out permissions that expire after seven "
        @"days, so a connection made today would quietly stop working next "
        @"week. Adding yourself under Test users works too, with that same "
        @"seven-day clock.",
        @"How to make a Google OAuth client");
}

- (NSString *)clientPlaceholder { return @"…apps.googleusercontent.com"; }

- (NSString *)scopeExplanation
{
    return NSLocalizedString(
        @"What is asked for is the narrowest thing Drive has — the files "
        @"this application creates and whatever you hand it in the picker "
        @"— and not anything resembling «see everything in my Drive», "
        @"which Google classes as restricted and which would need a yearly "
        @"verification.",
        @"What the drive.file scope means");
}

- (BOOL)isConfigured
{
    return [self.clientIdentifier containsString:@"apps.googleusercontent.com"];
}

- (NSURL *)tokenURL
{
    return [NSURL URLWithString:@"https://oauth2.googleapis.com/token"];
}

- (NSURLComponents *)consentComponentsWithRedirect:(NSString *)redirect
                                         challenge:(NSString *)challenge
{
    NSURLComponents *url = [NSURLComponents componentsWithString:
        @"https://accounts.google.com/o/oauth2/v2/auth"];
    // Una cartella o dei documenti, mai tutti e due: sono due gesti con due
    // significati, e B0 ha misurato che una cartella **non** porta con sé
    // quello che contiene.
    BOOL folder = (self.picking == MPCloudPickFolder);
    url.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"scope"
            value:@"https://www.googleapis.com/auth/drive.file"],
        [NSURLQueryItem queryItemWithName:@"access_type" value:@"offline"],
        [NSURLQueryItem queryItemWithName:@"prompt" value:@"consent"],
        // Le due che, su desktop, *sono* il Picker: la scelta avviene
        // dentro la schermata di consenso, nel browser.
        [NSURLQueryItem queryItemWithName:@"trigger_onepick" value:@"true"],
        [NSURLQueryItem queryItemWithName:@"allow_folder_selection"
                                    value:folder ? @"true" : @"false"],
        [NSURLQueryItem queryItemWithName:@"allow_multiple"
                                    value:folder ? @"false" : @"true"],
        [NSURLQueryItem queryItemWithName:@"mimetypes"
                                    value:folder
            ? @"application/vnd.google-apps.folder"
            : @"text/markdown,text/plain,application/octet-stream"],
    ];
    return url;
}


/// Una GET aspettata: siamo su una coda di fondo, e questo pezzo di
/// collegamento è fatto di tre domande in fila.
/// La risposta del servizio, o nil. L'errore non si inghiotte: sta dentro
/// il dizionario, con le sue parole, ed è il chiamante a decidere.
static NSDictionary *MPGet(NSString *address, NSString *token)
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:address]];
    [request setValue:[@"Bearer " stringByAppendingString:token ?: @""]
   forHTTPHeaderField:@"Authorization"];

    __block NSData *got = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *body, NSURLResponse *r, NSError *e) {
        got = body;
        dispatch_semaphore_signal(done);
    }] resume];
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW,
                                                20 * NSEC_PER_SEC));
    id parsed = got ? [NSJSONSerialization JSONObjectWithData:got options:0
                                                        error:NULL] : nil;
    return [parsed isKindOfClass:[NSDictionary class]] ? parsed : nil;
}


/** Cosa vede l'applicazione, adesso, con il permesso che ha.
 *
 * Con `drive.file` l'universo visibile è piccolo per costruzione — quello
 * che l'app ha creato e quello che le è stato passato — quindi chiederlo
 * tutto è una domanda sola e onesta. Se fra quelle cose c'è una cartella,
 * si guarda dentro: è la domanda di B0.
 */
- (NSString *)lookAroundWithToken:(NSString *)token
{
    NSDictionary *all = MPGet(
        @"https://www.googleapis.com/drive/v3/files"
        @"?q=trashed%20%3D%20false&fields=files(id,name,mimeType)&pageSize=100",
        token);
    if (all[@"error"])
        return all[@"error"][@"message"];
    if (!all)
        return NSLocalizedString(@"Drive did not answer.",
                                 @"The Drive API gave nothing back");

    NSDictionary *folder = nil;
    for (NSDictionary *file in all[@"files"])
    {
        if ([file[@"mimeType"]
                isEqualToString:@"application/vnd.google-apps.folder"])
        {
            folder = file;
            break;
        }
    }
    if (!folder)
    {
        // Nessuna cartella fra le cose passate: il posto sono i file
        // stessi, ed è già una risposta.
        NSArray *files = all[@"files"];
        [self rememberPlace:@"" named:@""];
        [self rememberVisible:(NSInteger)files.count];
        return nil;
    }

    [self rememberPlace:folder[@"id"] named:folder[@"name"]];
    NSString *query = [[NSString stringWithFormat:
        @"'%@' in parents and trashed = false", folder[@"id"]]
        stringByAddingPercentEncodingWithAllowedCharacters:
            [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSDictionary *children = MPGet([NSString stringWithFormat:
        @"https://www.googleapis.com/drive/v3/files?q=%@"
        @"&fields=files(id)&pageSize=100", query], token);
    if (children[@"error"])
        return children[@"error"][@"message"];
    [self rememberVisible:(NSInteger)[children[@"files"] count]];
    return nil;
}


/// Drive rimanda indietro quello che è stato scelto: si chiede come si
/// chiama, così il pannello dice «Appunti» invece di un identificatore — e
/// se è una cartella si chiede anche **cosa ci si vede dentro**, che è la
/// domanda a cui la documentazione non risponde.
- (void)rememberFromCallback:(NSDictionary *)callback token:(NSString *)token
{
    NSString *first = [callback[@"picked_file_ids"]
        componentsSeparatedByString:@","].firstObject;
    if (!first.length)
        return;

    NSDictionary *file = MPGet([NSString stringWithFormat:
        @"https://www.googleapis.com/drive/v3/files/%@?fields=id,name,mimeType",
        first], token);
    if (!file[@"id"])
        return;
    [self rememberPlace:file[@"id"] named:file[@"name"]];

    if (![file[@"mimeType"]
            isEqualToString:@"application/vnd.google-apps.folder"])
    {
        [self rememberVisible:-1];      // un file solo: non c'è un dentro
        return;
    }

    // La domanda: con il solo `drive.file`, una cartella passata dal Picker
    // porta con sé quello che contiene? Si chiede una volta, al
    // collegamento, e la risposta resta scritta.
    NSString *query = [[NSString stringWithFormat:
        @"'%@' in parents and trashed = false", file[@"id"]]
        stringByAddingPercentEncodingWithAllowedCharacters:
            [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSDictionary *children = MPGet([NSString stringWithFormat:
        @"https://www.googleapis.com/drive/v3/files?q=%@"
        @"&fields=files(id)&pageSize=100", query], token);
    NSArray *files = children[@"files"];
    [self rememberVisible:files ? (NSInteger)files.count : 0];
}

@end


#pragma mark - Dropbox

/** Un segnaposto, e lo dice.
 *
 * Dropbox è la fase dopo — nella roadmap è B3 — e questo è quanto se ne sa
 * oggi: come si chiama, dove si registra un'applicazione, e che il permesso
 * stretto è «cartella dell'app». Scrivere adesso il resto vorrebbe dire
 * scrivere un giro OAuth che nessuno ha ancora provato contro il servizio
 * vero, e sarebbe codice che sembra finito senza esserlo.
 *
 * Finché `available` dice di no, il pannello lo mostra e non lo lascia
 * toccare.
 */
@interface MPDropboxService : MPCloudService
@end

@implementation MPDropboxService

- (NSString *)name { return @"Dropbox"; }
- (NSString *)identifier { return @"dropbox"; }
- (NSString *)symbolName { return @"shippingbox"; }
- (BOOL)available { return NO; }

- (NSString *)consoleButtonTitle
{
    return NSLocalizedString(@"Open the Dropbox App Console…",
                             @"Opens the page where a Dropbox app is made");
}
- (NSURL *)consoleURL
{
    return [NSURL URLWithString:@"https://www.dropbox.com/developers/apps"];
}

- (NSString *)explanation
{
    return NSLocalizedString(
        @"Dropbox comes after Drive, and for one reason: Drive is the "
        @"harder of the two — files named by identifier rather than by "
        @"path, and no way to make it refuse a write that started from an "
        @"old version — so what is learned there makes this one half the "
        @"work.",
        @"Why the Dropbox section is a placeholder");
}

- (NSString *)howToGetAClient { return @""; }
- (NSString *)clientPlaceholder { return @""; }
- (NSString *)scopeExplanation { return @""; }

@end


#pragma mark - I documenti

@implementation MPCloudService (Documents)

/// Le quattro operazioni sono le stesse per tutti i servizi a parte come
/// si scrivono le richieste; finché il servizio è uno, stanno qui e
/// parlano Drive. Quando Dropbox arriverà, questo diventa un altro metodo
/// da riempire, come lo sono già il consenso e i gettoni.
- (BOOL)isGoogle
{
    return [self.identifier isEqualToString:@"google"];
}


- (void)documentsWithCompletion:(void (^)(NSArray<MPCloudDocument *> *,
                                          NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *problem = nil;
        NSString *token = [self freshToken:&problem];
        NSMutableArray *found = [NSMutableArray array];
        if (token && [self isGoogle])
        {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                [NSURL URLWithString:
                    @"https://www.googleapis.com/drive/v3/files"
                    @"?q=trashed%20%3D%20false"
                    @"&fields=files(id,name,mimeType,headRevisionId,"
                    @"modifiedTime,size)"
                    @"&pageSize=200"]];
            NSDictionary *answer = MPSend(request, token, NULL);
            if (answer[@"error"])
                problem = answer[@"error"][@"message"];
            for (NSDictionary *file in answer[@"files"])
            {
                if ([file[@"mimeType"] isEqualToString:
                        @"application/vnd.google-apps.folder"])
                    continue;   // le cartelle non sono documenti
                MPCloudDocument *document = [[MPCloudDocument alloc] init];
                document.identifier = file[@"id"];
                document.name = file[@"name"];
                document.revision = file[@"headRevisionId"];
                document.modified = MPDateFromDrive(file[@"modifiedTime"]);
                document.size = [file[@"size"] longLongValue];
                [found addObject:document];
            }
        }
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(problem ? nil : found, problem);
        });
    });
}


- (void)readDocument:(NSString *)identifier
          completion:(void (^)(NSString *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *problem = nil;
        NSString *token = [self freshToken:&problem];
        NSString *text = nil;
        if (token)
        {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                [NSURL URLWithString:[NSString stringWithFormat:
                    @"https://www.googleapis.com/drive/v3/files/%@?alt=media",
                    identifier]]];
            NSString *body = nil;
            NSDictionary *answer = MPSend(request, token, &body);
            // Con alt=media quello che torna è il file, non JSON: un
            // dizionario vuol dire che è andata storta.
            if (answer[@"error"])
                problem = answer[@"error"][@"message"];
            else
                text = body;
        }
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(text, problem);
        });
    });
}


/// Il corpo di un caricamento in due pezzi: prima cosa è, poi cos'è
/// dentro. Fuori da ogni rete, così si può guardare in una prova.
NSData *MPGoogleUploadBody(NSString *boundary, NSDictionary *metadata,
                           NSString *text)
{
    NSMutableData *body = [NSMutableData data];
    void (^put)(NSString *) = ^(NSString *piece) {
        [body appendData:[piece dataUsingEncoding:NSUTF8StringEncoding]];
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:metadata
                                                   options:0 error:NULL];
    put([NSString stringWithFormat:@"--%@\r\n", boundary]);
    put(@"Content-Type: application/json; charset=UTF-8\r\n\r\n");
    [body appendData:json];
    put([NSString stringWithFormat:@"\r\n--%@\r\n", boundary]);
    put(@"Content-Type: text/markdown; charset=UTF-8\r\n\r\n");
    put(text ?: @"");
    put([NSString stringWithFormat:@"\r\n--%@--\r\n", boundary]);
    return body;
}


/// Lo stesso corpo, per un file che non è testo: un allegato è byte, e
/// il suo tipo lo dichiara chi lo manda.
NSData *MPGoogleUploadBodyOfData(NSString *boundary, NSDictionary *metadata,
                                 NSData *data, NSString *mime)
{
    NSMutableData *body = [NSMutableData data];
    void (^put)(NSString *) = ^(NSString *piece) {
        [body appendData:[piece dataUsingEncoding:NSUTF8StringEncoding]];
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:metadata
                                                   options:0 error:NULL];
    put([NSString stringWithFormat:@"--%@\r\n", boundary]);
    put(@"Content-Type: application/json; charset=UTF-8\r\n\r\n");
    [body appendData:json];
    put([NSString stringWithFormat:@"\r\n--%@\r\n", boundary]);
    put([NSString stringWithFormat:@"Content-Type: %@\r\n\r\n",
         mime.length ? mime : @"application/octet-stream"]);
    [body appendData:data ?: [NSData data]];
    put([NSString stringWithFormat:@"\r\n--%@--\r\n", boundary]);
    return body;
}


/** Un file qualunque nella cartella collegata, e come ci si arriva.
 *
 * È la strada degli **allegati**: un documento che sta in un servizio
 * tiene i suoi file lì, dove sta lui, e non in una cartella di questo Mac
 * che chi apre il documento da un altro computer non vedrà mai.
 *
 * `link` è quello che va scritto nel Markdown: su Drive l'indirizzo che
 * apre il file, dove una cartella è una cartella il nome e basta.
 */
- (void)uploadFile:(NSURL *)file named:(NSString *)name
        completion:(void (^)(NSString *name, NSString *link,
                             NSString *problem))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *problem = nil;
        NSString *token = [self freshToken:&problem];
        NSString *made = nil;
        NSString *link = nil;
        NSData *data = [NSData dataWithContentsOfURL:file
                                             options:NSDataReadingMappedIfSafe
                                               error:NULL];
        if (!data)
            problem = NSLocalizedString(@"That file could not be read.",
                @"Failure reading a file to upload");
        else if (token && [self isGoogle])
        {
            NSMutableDictionary *metadata =
                [@{@"name": name ?: file.lastPathComponent} mutableCopy];
            if (self.placeIdentifier.length)
                metadata[@"parents"] = @[self.placeIdentifier];

            UTType *type = [UTType typeWithFilenameExtension:
                file.pathExtension ?: @""];
            NSString *boundary = [NSUUID UUID].UUIDString;
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                [NSURL URLWithString:
                    @"https://www.googleapis.com/upload/drive/v3/files"
                    @"?uploadType=multipart&fields=id,name,webViewLink"]];
            request.HTTPMethod = @"POST";
            [request setValue:[NSString stringWithFormat:
                @"multipart/related; boundary=%@", boundary]
           forHTTPHeaderField:@"Content-Type"];
            request.HTTPBody = MPGoogleUploadBodyOfData(boundary, metadata,
                data, type.preferredMIMEType);

            NSDictionary *answer = MPSend(request, token, NULL);
            if (answer[@"error"])
                problem = answer[@"error"][@"message"];
            else if (answer[@"id"])
            {
                made = answer[@"name"];
                link = answer[@"webViewLink"] ?: answer[@"name"];
            }
        }
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(made, link, problem);
        });
    });
}


- (void)createDocumentNamed:(NSString *)name
                       text:(NSString *)text
                 completion:(void (^)(MPCloudDocument *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *problem = nil;
        NSString *token = [self freshToken:&problem];
        MPCloudDocument *made = nil;
        if (token)
        {
            NSString *folder = self.placeIdentifier;
            NSMutableDictionary *metadata =
                [@{@"name": name ?: NSLocalizedString(@"untitled.md",
                    @"File name when a document has none")} mutableCopy];
            if (folder.length)
                metadata[@"parents"] = @[folder];

            NSString *boundary = [NSUUID UUID].UUIDString;
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                [NSURL URLWithString:
                    @"https://www.googleapis.com/upload/drive/v3/files"
                    @"?uploadType=multipart&fields=id,name,headRevisionId"]];
            request.HTTPMethod = @"POST";
            [request setValue:[NSString stringWithFormat:
                @"multipart/related; boundary=%@", boundary]
           forHTTPHeaderField:@"Content-Type"];
            request.HTTPBody = MPGoogleUploadBody(boundary, metadata, text);

            NSDictionary *answer = MPSend(request, token, NULL);
            if (answer[@"error"])
                problem = answer[@"error"][@"message"];
            else if (answer[@"id"])
            {
                made = [[MPCloudDocument alloc] init];
                made.identifier = answer[@"id"];
                made.name = answer[@"name"];
                made.revision = answer[@"headRevisionId"];
            }
        }
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(made, problem);
        });
    });
}


/// Come si chiama la copia che si scrive quando non si può sovrascrivere.
NSString *MPConflictNameFor(NSString *name, NSDate *when)
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH.mm";
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    NSString *stamp = [formatter stringFromDate:when ?: [NSDate date]];
    NSString *stem = name.stringByDeletingPathExtension;
    NSString *extension = name.pathExtension;
    NSString *made = [NSString stringWithFormat:@"%@ (copia in conflitto %@)",
                      stem.length ? stem : @"documento", stamp];
    return extension.length ? [made stringByAppendingPathExtension:extension]
                            : made;
}


- (void)writeDocument:(NSString *)identifier
                 text:(NSString *)text
         fromRevision:(NSString *)fromRevision
              ifMoved:(MPCloudOnMoved)ifMoved
           completion:(void (^)(NSString *, BOOL, NSString *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *problem = nil, *conflict = nil, *revision = nil;
        BOOL moved = NO;
        NSString *token = [self freshToken:&problem];
        if (token)
        {
            // Drive non ha una precondizione da offrire su files.update:
            // si guarda la versione **subito prima**. Non è atomico e non
            // finge di esserlo: è la finestra più stretta che l'API lasci.
            NSMutableURLRequest *look = [NSMutableURLRequest requestWithURL:
                [NSURL URLWithString:[NSString stringWithFormat:
                    @"https://www.googleapis.com/drive/v3/files/%@"
                    @"?fields=id,name,headRevisionId", identifier]]];
            NSDictionary *now = MPSend(look, token, NULL);
            if (now[@"error"])
                problem = now[@"error"][@"message"];

            NSString *head = now[@"headRevisionId"];
            moved = fromRevision.length && head.length
                 && ![head isEqualToString:fromRevision];

            if (!problem && moved && ifMoved == MPCloudOnMovedAsk)
            {
                // Ci si ferma qui, e non si scrive niente da nessuna
                // parte: sovrascrivere e fare una copia sono due
                // decisioni, e non sono nostre.
            }
            else if (!problem && moved && ifMoved == MPCloudOnMovedCopy)
            {
                // Accanto, non sopra.
                conflict = MPConflictNameFor(now[@"name"], nil);
                NSString *folder = self.placeIdentifier;
                NSMutableDictionary *metadata =
                    [@{@"name": conflict} mutableCopy];
                if (folder.length)
                    metadata[@"parents"] = @[folder];

                NSString *boundary = [NSUUID UUID].UUIDString;
                NSMutableURLRequest *put = [NSMutableURLRequest requestWithURL:
                    [NSURL URLWithString:
                        @"https://www.googleapis.com/upload/drive/v3/files"
                        @"?uploadType=multipart&fields=id,headRevisionId"]];
                put.HTTPMethod = @"POST";
                [put setValue:[NSString stringWithFormat:
                    @"multipart/related; boundary=%@", boundary]
           forHTTPHeaderField:@"Content-Type"];
                put.HTTPBody = MPGoogleUploadBody(boundary, metadata, text);
                NSDictionary *answer = MPSend(put, token, NULL);
                if (answer[@"error"])
                    problem = answer[@"error"][@"message"];
            }
            else if (!problem)
            {
                NSString *boundary = [NSUUID UUID].UUIDString;
                NSMutableURLRequest *put = [NSMutableURLRequest requestWithURL:
                    [NSURL URLWithString:[NSString stringWithFormat:
                        @"https://www.googleapis.com/upload/drive/v3/files/%@"
                        @"?uploadType=multipart&fields=id,headRevisionId",
                        identifier]]];
                put.HTTPMethod = @"PATCH";
                [put setValue:[NSString stringWithFormat:
                    @"multipart/related; boundary=%@", boundary]
           forHTTPHeaderField:@"Content-Type"];
                put.HTTPBody = MPGoogleUploadBody(boundary, @{}, text);
                NSDictionary *answer = MPSend(put, token, NULL);
                if (answer[@"error"])
                    problem = answer[@"error"][@"message"];
                else
                    revision = answer[@"headRevisionId"];
            }
        }
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(revision, moved, conflict, problem);
        });
    });
}

@end


#pragma mark - Il delta

@implementation MPCloudService (Changes)

- (void)changesWithCompletion:(void (^)(MPCloudDelta *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        MPCloudLedger *ledger = [MPCloudLedger ledgerFor:self.identifier];
        NSString *problem = nil;
        NSString *token = [self freshToken:&problem];
        MPCloudDelta *delta = [[MPCloudDelta alloc] init];

        if (token && [self.identifier isEqualToString:@"google"])
        {
            if (!ledger.startToken.length)
            {
                // Prima volta: si chiede il segnalibro e ci si ferma lì.
                // Chiedere «cosa è cambiato dall'inizio dei tempi» a un
                // servizio è un modo di farsi dare tutto per scoprire che
                // non era cambiato niente.
                NSMutableURLRequest *start = [NSMutableURLRequest requestWithURL:
                    [NSURL URLWithString:
                        @"https://www.googleapis.com/drive/v3/changes/"
                        @"startPageToken"]];
                NSDictionary *answer = MPSend(start, token, NULL);
                if (answer[@"error"])
                    problem = answer[@"error"][@"message"];
                else
                    ledger.startToken = answer[@"startPageToken"];
                [ledger save];
            }
            else
            {
                // Il servizio racconta a pagine, e ogni pagina dice come
                // chiedere la prossima. Si va avanti finché ne dà una.
                NSString *page = ledger.startToken;
                NSMutableArray *changes = [NSMutableArray array];
                while (page.length && !problem)
                {
                    NSString *address = [NSString stringWithFormat:
                        @"https://www.googleapis.com/drive/v3/changes"
                        @"?pageToken=%@&pageSize=200"
                        @"&fields=nextPageToken,newStartPageToken,"
                        @"changes(fileId,removed,file(name,trashed,"
                        @"headRevisionId))", page];
                    NSMutableURLRequest *request =
                        [NSMutableURLRequest requestWithURL:
                            [NSURL URLWithString:address]];
                    NSDictionary *answer = MPSend(request, token, NULL);
                    if (answer[@"error"])
                    {
                        problem = answer[@"error"][@"message"];
                        break;
                    }
                    [changes addObjectsFromArray:answer[@"changes"] ?: @[]];

                    if ([answer[@"newStartPageToken"] length])
                    {
                        // Finito: il servizio dà il segnalibro nuovo, ed è
                        // quello che va tenuto per la volta dopo.
                        ledger.startToken = answer[@"newStartPageToken"];
                        page = nil;
                    }
                    else
                        page = answer[@"nextPageToken"];
                }
                if (!problem)
                {
                    delta = [ledger applyChanges:changes];
                    [ledger save];
                }
            }
        }

        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(problem ? nil : delta, problem);
        });
    });
}

@end


#pragma mark - iCloud Drive

/** iCloud Drive, che è già qui.
 *
 * Nessun consenso da dare e nessun gettone da custodire: iCloud Drive su
 * un Mac **è una cartella**, e il pezzo difficile — portare su e giù,
 * sapere chi ha scritto per ultimo, tenere le due copie quando due Mac
 * scrivono insieme — lo fa il sistema, meglio di come lo faremmo noi.
 * Quello che manca è la parte che riguarda noi: sapere *quale* cartella,
 * leggere e scrivere coordinandosi col demone invece che alle sue spalle,
 * e accorgersi che un documento si è mosso prima di scriverci sopra.
 *
 * Da qui viene anche la differenza col Drive: là si sceglie una cartella
 * *e* i documenti, uno per uno, perché il permesso è stretto. Qui la
 * cartella li porta tutti, perché il permesso è il Finder.
 */
@interface MPICloudService : MPCloudService
/// Che la cartella non c'è più, per non richiederlo al sistema ogni volta.
@property (assign, nonatomic) BOOL folderIsGone;
@end


/// Dove sta iCloud Drive su un Mac. Il nome della cartella è quello e non
/// cambia: è l'identificatore del contenitore, scritto come lo scrive il
/// sistema.
static NSString *const kMPICloudRoot =
    @"Library/Mobile Documents/com~apple~CloudDocs";

/// La cartella che si usa senza chiedere niente a nessuno.
static NSString *const kMPICloudFolder = @"MacDownNext";

/// Cosa consideriamo un documento, in una cartella qualunque.
static BOOL MPLooksLikeADocument(NSURL *url)
{
    static NSSet *kinds = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kinds = [NSSet setWithArray:@[@"md", @"markdown", @"mdown", @"mkd",
                                      @"txt", @"text", @"textbundle"]];
    });
    return [kinds containsObject:url.pathExtension.lowercaseString];
}

/// La versione di un file: quando è stato scritto e quanto è lungo. Non è
/// un numero che dà il servizio — iCloud non ne dà — ma cambia esattamente
/// quando cambia il file, che è tutto quello che ci serve per accorgerci
/// che qualcun altro ci ha messo mano.
static NSString *MPRevisionOf(NSURL *url)
{
    NSDate *when = nil;
    NSNumber *size = nil;
    [url getResourceValue:&when forKey:NSURLContentModificationDateKey
                    error:NULL];
    [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
    if (!when)
        return nil;
    return [NSString stringWithFormat:@"%.0f.%@",
            when.timeIntervalSince1970 * 1000.0, size ?: @0];
}


@implementation MPICloudService

- (NSString *)name { return @"iCloud Drive"; }
- (NSString *)identifier { return @"icloud"; }
- (NSString *)symbolName { return @"icloud"; }

/// Non c'è niente da registrare da nessuna parte: è la cartella di chi sta
/// già usando il Mac.
- (BOOL)needsAClient { return NO; }
- (BOOL)picksDocuments { return NO; }
- (BOOL)isConfigured { return YES; }
/// Non c'è niente da scollegare: il collegamento è una cartella, e una
/// cartella si cambia, non si revoca.
- (BOOL)canDisconnect { return NO; }

- (NSString *)explanation
{
    return NSLocalizedString(
        @"A folder of your iCloud Drive, chosen in the usual panel. No "
        @"account to register and nothing kept anywhere: the folder is "
        @"already yours, and macOS carries it between your machines.",
        @"What connecting iCloud Drive means");
}

- (NSString *)scopeExplanation
{
    return NSLocalizedString(
        @"Only the folder you choose, and everything in it: unlike the "
        @"other services, documents that were already there come across "
        @"too, because here the permission is the Finder.",
        @"What the iCloud Drive connection covers");
}


#pragma mark La cartella

- (NSURL *)root
{
    // La radice si può spostare da una preferenza, che non sta nel
    // pannello: serve alle prove, per non andare a scrivere nell'iCloud
    // Drive vero di chi sta facendo girare la suite.
    NSString *elsewhere = [[NSUserDefaults standardUserDefaults]
        stringForKey:[self defaultsKey:@"root"]];
    if (elsewhere.length)
        return [NSURL fileURLWithPath:elsewhere isDirectory:YES];
    return [NSURL fileURLWithPath:[NSHomeDirectory()
        stringByAppendingPathComponent:kMPICloudRoot] isDirectory:YES];
}


/** La cartella che si usa se non se ne è scelta un'altra.
 *
 * Un servizio che per essere usato chiede prima di scegliere una cartella
 * è un servizio che chiede un compito a chi voleva solo scrivere. Qui il
 * posto ovvio esiste — una cartella col nome dell'applicazione dentro
 * iCloud Drive — e se non c'è la si fa. Cambiarla resta un pulsante nelle
 * impostazioni.
 */
- (NSURL *)defaultFolder
{
    NSURL *root = [self root];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL directory = NO;
    if (![manager fileExistsAtPath:root.path isDirectory:&directory]
            || !directory)
        return nil;         // iCloud Drive non c'è su questo Mac

    NSURL *mine = [root URLByAppendingPathComponent:kMPICloudFolder
                                        isDirectory:YES];
    if ([manager fileExistsAtPath:mine.path isDirectory:&directory])
        return directory ? mine : nil;
    if (![manager createDirectoryAtURL:mine withIntermediateDirectories:NO
                            attributes:nil error:NULL])
        return nil;
    return mine;
}

/** La cartella scelta, se c'è ancora.
 *
 * Tenuta in due modi: il percorso di quando la si è scelta, che costa
 * niente da controllare, e il segnalibro, che sopravvive a uno
 * spostamento. Si guarda il percorso per primo di proposito — sciogliere
 * un segnalibro che punta a una cartella cancellata mette il sistema a
 * cercarla, e l'attesa arriva al minuto: è successo in una prova, e in
 * una prova si può aspettare, in un pannello no.
 */
- (NSURL *)folder
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *known = self.placeIdentifier;
    BOOL directory = NO;
    if (known.length && [manager fileExistsAtPath:known
                                      isDirectory:&directory] && directory)
        return [NSURL fileURLWithPath:known isDirectory:YES];

    NSData *bookmark = [[NSUserDefaults standardUserDefaults]
        dataForKey:[self defaultsKey:@"bookmark"]];
    if (!bookmark.length)
    {
        // Mai scelta: quella predefinita, fatta adesso se non c'era.
        NSURL *mine = [self defaultFolder];
        if (mine)
            [self remember:mine];
        return mine;
    }
    if (self.folderIsGone)
        return nil;
    BOOL stale = NO;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
        options:NSURLBookmarkResolutionWithoutUI
              | NSURLBookmarkResolutionWithoutMounting
        relativeToURL:nil bookmarkDataIsStale:&stale error:NULL];
    if (url && [manager fileExistsAtPath:url.path isDirectory:&directory]
            && directory)
    {
        // Spostata o rinominata: il segnalibro l'ha ritrovata, e da adesso
        // il percorso nuovo è quello che si controlla per primo.
        [self remember:url];
        return url;
    }
    // Non c'è più. Chiederlo di nuovo costerebbe un'altra attesa, e la
    // risposta sarebbe la stessa finché non se ne sceglie un'altra.
    self.folderIsGone = YES;
    return nil;
}

- (void)remember:(NSURL *)folder
{
    self.folderIsGone = NO;
    NSData *bookmark = [folder bookmarkDataWithOptions:0
        includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];
    [[NSUserDefaults standardUserDefaults] setObject:bookmark
        forKey:[self defaultsKey:@"bookmark"]];
    [self rememberPlace:folder.path named:folder.lastPathComponent];
}

- (BOOL)isLinked
{
    return [self folder] != nil;
}

/// Il nome della cartella, che quando non se n'è scelta nessuna è quello
/// della predefinita — e chiederlo è anche il momento in cui la si fa.
- (NSString *)placeName
{
    NSString *known = [super placeName];
    return known.length ? known : [self folder].lastPathComponent;
}

/// Dimenticare la cartella scelta vuol dire tornare a quella
/// predefinita, che è l'unico «scollegato» che ha senso qui.
- (void)unlink
{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:[self defaultsKey:@"bookmark"]];
    self.folderIsGone = NO;
    [super unlink];
}


/** Si sceglie nel pannello di sempre, e deve stare dentro iCloud Drive.
 *
 * Una cartella qualunque del disco funzionerebbe — e un giorno sarà un
 * altro servizio, «una cartella e basta» — ma questo qui si chiama iCloud
 * Drive e promette che quello che ci metti lo trovi sull'altro Mac. Fuori
 * di lì non sarebbe vero.
 */
- (void)link:(MPCloudPick)what
  completion:(void (^)(MPCloudLinkOutcome, NSString *))done
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.canChooseFiles = NO;
        panel.canChooseDirectories = YES;
        panel.canCreateDirectories = YES;
        panel.allowsMultipleSelection = NO;
        panel.directoryURL = [self root];
        panel.message = NSLocalizedString(
            @"Choose a folder of your iCloud Drive. What this application "
            @"writes goes in there, and what is in there already comes "
            @"across.", @"Message of the panel that picks an iCloud folder");
        panel.prompt = NSLocalizedString(@"Use This Folder",
            @"Button of the panel that picks an iCloud folder");

        if ([panel runModal] != NSModalResponseOK || !panel.URL)
        {
            if (done)
                done(MPCloudLinkCancelled, nil);
            return;
        }

        NSString *chosen = panel.URL.URLByResolvingSymlinksInPath.path;
        NSString *root = [self root].URLByResolvingSymlinksInPath.path;
        if (![chosen hasPrefix:root])
        {
            if (done)
                done(MPCloudLinkRefused, NSLocalizedString(
                    @"That folder is not in iCloud Drive. Choose one inside "
                    @"it, or nothing written there would reach your other "
                    @"machines.",
                    @"Refusing a folder outside iCloud Drive"));
            return;
        }

        [self remember:panel.URL];
        self.problem = nil;
        if (done)
            done(MPCloudLinkDone, nil);
    });
}


- (void)checkWithCompletion:(void (^)(NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *problem = nil;
        NSURL *folder = [self folder];
        if (!folder)
            problem = NSLocalizedString(
                @"That folder is not there any more. Choose it again.",
                @"The chosen iCloud folder has gone");
        else
            [self rememberVisible:(NSInteger)[self filesIn:folder].count];
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(problem);
        });
    });
}


/// Quello che c'è nella cartella, senza scendere nelle sottocartelle: una
/// cartella collegata è un posto dove si lavora, non un archivio da
/// esplorare.
- (NSArray<NSURL *> *)filesIn:(NSURL *)folder
{
    NSArray *keys = @[NSURLContentModificationDateKey, NSURLFileSizeKey,
                      NSURLIsDirectoryKey];
    NSArray<NSURL *> *inside = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:folder includingPropertiesForKeys:keys
        options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
    NSMutableArray *kept = [NSMutableArray array];
    for (NSURL *url in inside)
    {
        NSNumber *directory = nil;
        [url getResourceValue:&directory forKey:NSURLIsDirectoryKey
                        error:NULL];
        if (directory.boolValue || !MPLooksLikeADocument(url))
            continue;
        [kept addObject:url];
    }
    return kept;
}


- (MPCloudDocument *)documentAt:(NSURL *)url
{
    NSDate *when = nil;
    NSNumber *size = nil;
    [url getResourceValue:&when forKey:NSURLContentModificationDateKey
                    error:NULL];
    [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
    MPCloudDocument *document = [[MPCloudDocument alloc] init];
    document.identifier = url.lastPathComponent;
    document.name = url.lastPathComponent;
    document.revision = MPRevisionOf(url);
    document.modified = when;
    document.size = size.longLongValue;
    return document;
}


- (void)documentsWithCompletion:(void (^)(NSArray<MPCloudDocument *> *,
                                          NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSURL *folder = [self folder];
        NSMutableArray *found = [NSMutableArray array];
        NSString *problem = folder ? nil : NSLocalizedString(
            @"That folder is not there any more. Choose it again.",
            @"The chosen iCloud folder has gone");
        for (NSURL *url in [self filesIn:folder])
            [found addObject:[self documentAt:url]];
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(problem ? nil : found, problem);
        });
    });
}


/** Il file, sceso se non c'era.
 *
 * Un documento di iCloud può essere lì senza esserci: il sistema ne tiene
 * il nome e butta via il contenuto quando lo spazio serve altrove. Si
 * chiede di riportarlo e si aspetta — poco — invece di leggere zero byte e
 * chiamarlo documento vuoto.
 */
- (NSURL *)readyURLFor:(NSString *)name
{
    NSURL *folder = [self folder];
    if (!folder || !name.length)
        return nil;
    NSURL *url = [folder URLByAppendingPathComponent:name];
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:url.path])
        return nil;

    NSNumber *status = nil;
    [url getResourceValue:&status forKey:NSURLUbiquitousItemDownloadingStatusKey
                    error:NULL];
    NSString *where = (NSString *)status;
    if (where && ![where isEqualToString:
            NSURLUbiquitousItemDownloadingStatusCurrent])
    {
        [manager startDownloadingUbiquitousItemAtURL:url error:NULL];
        for (int i = 0; i < 100; i++)      // dieci secondi, non di più
        {
            [NSThread sleepForTimeInterval:0.1];
            NSString *now = nil;
            [url getResourceValue:&now
                           forKey:NSURLUbiquitousItemDownloadingStatusKey
                            error:NULL];
            if ([now isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent])
                break;
        }
    }
    return url;
}


- (void)readDocument:(NSString *)identifier
          completion:(void (^)(NSString *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __block NSString *text = nil;
        __block NSString *problem = nil;
        NSURL *url = [self readyURLFor:identifier];
        if (!url)
            problem = NSLocalizedString(@"That document is not there.",
                @"Reading a document that has gone from the folder");
        else
        {
            // Coordinata, perché dall'altra parte c'è un demone che scrive:
            // leggere alle sue spalle è come leggere un file a metà.
            NSFileCoordinator *coordinator = [[NSFileCoordinator alloc]
                initWithFilePresenter:nil];
            NSError *bad = nil;
            [coordinator coordinateReadingItemAtURL:url options:0 error:&bad
                                         byAccessor:^(NSURL *ready) {
                NSError *reading = nil;
                text = [NSString stringWithContentsOfURL:ready
                    encoding:NSUTF8StringEncoding error:&reading];
                if (!text)
                    problem = reading.localizedDescription;
            }];
            if (bad)
                problem = bad.localizedDescription;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(text, problem);
        });
    });
}


- (void)createDocumentNamed:(NSString *)name text:(NSString *)text
                 completion:(void (^)(MPCloudDocument *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSURL *folder = [self folder];
        __block MPCloudDocument *made = nil;
        __block NSString *problem = folder ? nil : NSLocalizedString(
            @"That folder is not there any more. Choose it again.",
            @"The chosen iCloud folder has gone");
        if (folder)
        {
            // Un nome già preso non si sovrascrive mai: si numera.
            NSString *wanted = name.length ? name
                : [NSLocalizedString(@"untitled",
                    @"Name for a document that has never been saved")
                        stringByAppendingPathExtension:@"md"];
            NSURL *url = [folder URLByAppendingPathComponent:wanted];
            NSFileManager *manager = [NSFileManager defaultManager];
            for (int i = 2; [manager fileExistsAtPath:url.path] && i < 100; i++)
            {
                NSString *stem = wanted.stringByDeletingPathExtension;
                NSString *extension = wanted.pathExtension;
                NSString *another = [NSString stringWithFormat:@"%@ %d",
                                     stem, i];
                if (extension.length)
                    another = [another stringByAppendingPathExtension:extension];
                url = [folder URLByAppendingPathComponent:another];
            }
            problem = [self write:text to:url];
            if (!problem)
                made = [self documentAt:url];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(made, problem);
        });
    });
}


/// Una scrittura coordinata, e il guaio in parole se non è andata.
- (NSString *)write:(NSString *)text to:(NSURL *)url
{
    __block NSString *problem = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc]
        initWithFilePresenter:nil];
    NSError *bad = nil;
    [coordinator coordinateWritingItemAtURL:url
        options:NSFileCoordinatorWritingForReplacing error:&bad
        byAccessor:^(NSURL *ready) {
        NSError *writing = nil;
        if (![text ?: @"" writeToURL:ready atomically:YES
                           encoding:NSUTF8StringEncoding error:&writing])
            problem = writing.localizedDescription;
    }];
    return problem ?: bad.localizedDescription;
}


/** Riscrive, ma solo se là dentro è ancora quello di prima.
 *
 * Sullo stesso Mac questo non succede quasi mai; con due Mac accesi sulla
 * stessa cartella succede eccome, ed è il momento in cui una copia di
 * qualcuno sparisce se non si guarda prima.
 */
/// In una cartella un allegato è una copia, e il link è il suo nome:
/// chi apre il documento da un altro Mac lo trova accanto.
- (void)uploadFile:(NSURL *)file named:(NSString *)name
        completion:(void (^)(NSString *, NSString *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSURL *folder = [self folder];
        NSString *problem = folder ? nil : NSLocalizedString(
            @"That folder is not there any more. Choose it again.",
            @"The chosen iCloud folder has gone");
        NSString *made = nil;
        if (folder)
        {
            NSFileManager *manager = [NSFileManager defaultManager];
            NSString *wanted = name.length ? name : file.lastPathComponent;
            NSString *stem = wanted.stringByDeletingPathExtension;
            NSString *extension = wanted.pathExtension;
            NSURL *destination = [folder URLByAppendingPathComponent:wanted];
            for (NSUInteger attempt = 2;
                 [manager fileExistsAtPath:destination.path] && attempt < 1000;
                 attempt++)
            {
                wanted = extension.length
                    ? [NSString stringWithFormat:@"%@-%lu.%@", stem,
                       (unsigned long)attempt, extension]
                    : [NSString stringWithFormat:@"%@-%lu", stem,
                       (unsigned long)attempt];
                destination = [folder URLByAppendingPathComponent:wanted];
            }
            NSError *copying = nil;
            if ([manager copyItemAtURL:file toURL:destination error:&copying])
                made = wanted;
            else
                problem = copying.localizedDescription;
        }
        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(made, made, problem);
        });
    });
}


- (void)writeDocument:(NSString *)identifier text:(NSString *)text
         fromRevision:(NSString *)fromRevision ifMoved:(MPCloudOnMoved)ifMoved
           completion:(void (^)(NSString *, BOOL, NSString *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSURL *folder = [self folder];
        NSURL *url = folder ? [folder URLByAppendingPathComponent:identifier]
                            : nil;
        NSString *revision = nil;
        NSString *conflict = nil;
        NSString *problem = nil;
        BOOL moved = NO;

        if (!url || ![[NSFileManager defaultManager]
                fileExistsAtPath:url.path])
        {
            problem = NSLocalizedString(@"That document is not there.",
                @"Writing a document that has gone from the folder");
        }
        else
        {
            NSString *now = MPRevisionOf(url);
            BOOL hasMoved = fromRevision.length && now.length
                && ![now isEqualToString:fromRevision];
            if (hasMoved && ifMoved == MPCloudOnMovedAsk)
            {
                moved = YES;    // non si scrive niente: decide chi scrive
            }
            else if (hasMoved && ifMoved == MPCloudOnMovedCopy)
            {
                NSString *name = MPConflictNameFor(url.lastPathComponent, nil);
                NSURL *beside = [folder URLByAppendingPathComponent:name];
                problem = [self write:text to:beside];
                if (!problem)
                {
                    conflict = name;
                    revision = MPRevisionOf(beside);
                }
            }
            else
            {
                problem = [self write:text to:url];
                if (!problem)
                    revision = MPRevisionOf(url);
            }
        }

        self.problem = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(revision, moved, conflict, problem);
        });
    });
}


/** Cosa si è mosso: qui non c'è un servizio che lo racconti, quindi si
 * guarda la cartella e si confronta col registro — che è esattamente il
 * quaderno che il registro tiene per Drive, riempito da un'altra parte.
 */
- (void)changesWithCompletion:(void (^)(MPCloudDelta *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        MPCloudLedger *ledger = [MPCloudLedger ledgerFor:self.identifier];
        NSURL *folder = [self folder];
        NSString *problem = folder ? nil : NSLocalizedString(
            @"That folder is not there any more. Choose it again.",
            @"The chosen iCloud folder has gone");

        NSMutableArray *changes = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        for (NSURL *url in [self filesIn:folder])
        {
            NSString *name = url.lastPathComponent;
            [seen addObject:name];
            [changes addObject:@{@"fileId": name,
                                 @"file": @{@"name": name,
                                            @"headRevisionId":
                                                MPRevisionOf(url) ?: @""}}];
        }
        // Quello che il registro conosce e nella cartella non c'è più.
        for (NSString *known in [ledger knownIdentifiers])
        {
            if (![seen containsObject:known])
                [changes addObject:@{@"fileId": known, @"removed": @YES}];
        }

        MPCloudDelta *delta = [ledger applyChanges:changes];
        // La prima occhiata non è un cambiamento: è il punto di partenza.
        if (!ledger.startToken.length)
        {
            ledger.startToken = @"cartella";
            delta = [[MPCloudDelta alloc] init];
        }
        [ledger save];
        [self rememberVisible:(NSInteger)seen.count];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(problem ? nil : delta, problem);
        });
    });
}

@end
