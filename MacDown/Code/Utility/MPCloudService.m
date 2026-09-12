//
//  MPCloudService.m
//  MacDown
//

#import "MPCloudService.h"

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


@implementation MPCloudDocument
@end


@implementation MPCloudService

+ (NSArray<MPCloudService *> *)services
{
    static NSArray *services = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        services = @[[[NSClassFromString(@"MPGoogleDriveService") alloc] init],
                     [[NSClassFromString(@"MPDropboxService") alloc] init]];
    });
    return services;
}


#pragma mark Da riempire nelle sottoclassi

- (NSString *)name { return @""; }
- (NSString *)identifier { return @""; }
/// Se il pannello lo lascia toccare. Un servizio che non c'è ancora si
/// mostra lo stesso: nasconderlo vorrebbe dire far cercare alla gente una
/// cosa che è in programma.
- (BOOL)available { return YES; }
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
                    @"&fields=files(id,name,mimeType,headRevisionId)"
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
                [@{@"name": name ?: @"senza nome.md"} mutableCopy];
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
           completion:(void (^)(NSString *, NSString *, NSString *))done
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *problem = nil, *conflict = nil, *revision = nil;
        NSString *token = [self freshToken:&problem];
        if (token)
        {
            // Drive non ha una precondizione da offrire su files.update:
            // si guarda la versione **subito prima**, e se si è mossa non
            // si scrive sopra. Non è atomico e non finge di esserlo: è la
            // finestra più stretta che l'API lasci.
            NSMutableURLRequest *look = [NSMutableURLRequest requestWithURL:
                [NSURL URLWithString:[NSString stringWithFormat:
                    @"https://www.googleapis.com/drive/v3/files/%@"
                    @"?fields=id,name,headRevisionId", identifier]]];
            NSDictionary *now = MPSend(look, token, NULL);
            if (now[@"error"])
                problem = now[@"error"][@"message"];

            NSString *head = now[@"headRevisionId"];
            BOOL moved = fromRevision.length && head.length
                      && ![head isEqualToString:fromRevision];

            if (!problem && moved)
            {
                // Accanto, non sopra: quello che c'è là fuori non è più
                // quello da cui siamo partiti, e qualcuno lo ha scritto.
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
                done(revision, conflict, problem);
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
