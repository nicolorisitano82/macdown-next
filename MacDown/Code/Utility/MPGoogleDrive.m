//
//  MPGoogleDrive.m
//  MacDown
//

#import "MPGoogleDrive.h"

#import <Security/Security.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#include <CommonCrypto/CommonDigest.h>


/// Il servizio sotto cui il portachiavi tiene le nostre cose.
static NSString *const kMPKeychainService = @"MacDown Next — Google Drive";
static NSString *const kMPSecretAccount = @"client-secret";
static NSString *const kMPRefreshAccount = @"refresh-token";

static NSString *const kMPClientIdKey = @"googleDriveClientIdentifier";
static NSString *const kMPAccountKey = @"googleDriveAccountName";
static NSString *const kMPFolderIdKey = @"googleDriveFolderIdentifier";
static NSString *const kMPFolderNameKey = @"googleDriveFolderName";

static NSString *const kMPScope = @"https://www.googleapis.com/auth/drive.file";


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


NSString *MPGooglePKCEChallenge(NSString *verifier)
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


#pragma mark - L'indirizzo del consenso

NSURL *MPGoogleConsentURL(NSString *clientIdentifier, NSString *redirect,
                          NSString *challenge)
{
    NSURLComponents *url = [NSURLComponents componentsWithString:
        @"https://accounts.google.com/o/oauth2/v2/auth"];
    url.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"client_id" value:clientIdentifier],
        [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirect],
        [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
        [NSURLQueryItem queryItemWithName:@"scope" value:kMPScope],
        [NSURLQueryItem queryItemWithName:@"access_type" value:@"offline"],
        [NSURLQueryItem queryItemWithName:@"prompt" value:@"consent"],
        // Le due che, su desktop, *sono* il Picker.
        [NSURLQueryItem queryItemWithName:@"trigger_onepick" value:@"true"],
        [NSURLQueryItem queryItemWithName:@"allow_folder_selection"
                                    value:@"true"],
        [NSURLQueryItem queryItemWithName:@"code_challenge" value:challenge],
        [NSURLQueryItem queryItemWithName:@"code_challenge_method"
                                    value:@"S256"],
    ];
    return url.URL;
}


#pragma mark - L'ascolto del richiamo

/// Una porta sola su 127.0.0.1, scelta dal sistema. Un client desktop
/// accetta il loopback su qualunque porta, quindi non c'è niente da
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


static NSDictionary *MPAcceptCallback(int listener)
{
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
        @"The page the browser shows after Google hands the permission back");
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


#pragma mark -

@interface MPGoogleDrive ()
@property (assign, nonatomic) BOOL linking;
@end


@implementation MPGoogleDrive

+ (instancetype)sharedDrive
{
    static MPGoogleDrive *drive = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ drive = [[MPGoogleDrive alloc] init]; });
    return drive;
}


#pragma mark - Quello che sappiamo di chi ci usa

- (NSString *)clientIdentifier
{
    return [[NSUserDefaults standardUserDefaults]
        stringForKey:kMPClientIdKey] ?: @"";
}

- (void)setClientIdentifier:(NSString *)identifier
{
    NSString *clean = [identifier stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    [[NSUserDefaults standardUserDefaults] setObject:clean
                                              forKey:kMPClientIdKey];
}

- (NSString *)clientSecret
{
    return MPKeychainRead(kMPSecretAccount) ?: @"";
}

- (void)setClientSecret:(NSString *)secret
{
    MPKeychainWrite(kMPSecretAccount,
                    [secret stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]]);
}

- (BOOL)isConfigured
{
    return [self.clientIdentifier containsString:@"apps.googleusercontent.com"];
}

- (BOOL)isLinked
{
    return MPKeychainRead(kMPRefreshAccount).length > 0;
}

- (NSString *)accountName
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kMPAccountKey];
}

- (NSString *)folderIdentifier
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kMPFolderIdKey];
}

- (NSString *)folderName
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kMPFolderNameKey];
}


- (void)unlink
{
    MPKeychainWrite(kMPRefreshAccount, nil);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in @[kMPAccountKey, kMPFolderIdKey, kMPFolderNameKey])
        [defaults removeObjectForKey:key];
}


#pragma mark - Il collegamento

- (void)linkWithCompletion:(void (^)(MPGoogleLinkOutcome, NSString *))done
{
    void (^answer)(MPGoogleLinkOutcome, NSString *) =
        ^(MPGoogleLinkOutcome outcome, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.linking = NO;
            if (done)
                done(outcome, message);
        });
    };

    if (!self.isConfigured)
    {
        answer(MPGoogleLinkBroken, NSLocalizedString(
            @"There is no client ID yet.",
            @"Refusing to link Google Drive without a client ID"));
        return;
    }
    if (self.linking)
        return;
    self.linking = YES;

    NSString *verifier = MPRandomVerifier();
    NSString *clientIdentifier = self.clientIdentifier;
    NSString *secret = self.clientSecret;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        uint16_t port = 0;
        int listener = MPListenOnLoopback(&port);
        if (listener < 0)
        {
            answer(MPGoogleLinkBroken, NSLocalizedString(
                @"No port on this Mac would answer.",
                @"The loopback listener could not be opened"));
            return;
        }
        NSString *redirect = [NSString stringWithFormat:
            @"http://127.0.0.1:%u/macdown-google", port];

        NSURL *consent = MPGoogleConsentURL(clientIdentifier, redirect,
                                            MPGooglePKCEChallenge(verifier));
        [[NSWorkspace sharedWorkspace] openURL:consent];

        NSDictionary *callback = MPAcceptCallback(listener);
        close(listener);
        if (!callback)
        {
            answer(MPGoogleLinkCancelled, nil);
            return;
        }
        if (callback[@"error"])
        {
            answer(MPGoogleLinkRefused, callback[@"error"]);
            return;
        }

        [self finishWithCode:callback[@"code"]
                    verifier:verifier
                    redirect:redirect
                      secret:secret
                      picked:callback[@"picked_file_ids"]
                      answer:answer];
    });
}


/// Lo scambio del codice, e poi il nome di quello che è stato scelto.
- (void)finishWithCode:(NSString *)code
              verifier:(NSString *)verifier
              redirect:(NSString *)redirect
                secret:(NSString *)secret
                picked:(NSString *)picked
                answer:(void (^)(MPGoogleLinkOutcome, NSString *))answer
{
    NSMutableArray *fields = [NSMutableArray arrayWithArray:@[
        [NSString stringWithFormat:@"client_id=%@", self.clientIdentifier],
        [NSString stringWithFormat:@"code=%@", code ?: @""],
        [NSString stringWithFormat:@"code_verifier=%@", verifier],
        @"grant_type=authorization_code",
        [NSString stringWithFormat:@"redirect_uri=%@",
         [redirect stringByAddingPercentEncodingWithAllowedCharacters:
          [NSCharacterSet alphanumericCharacterSet]]],
    ]];
    if (secret.length)
        [fields addObject:[NSString stringWithFormat:@"client_secret=%@",
                           secret]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:@"https://oauth2.googleapis.com/token"]];
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
        if (![tokens isKindOfClass:[NSDictionary class]] || !tokens[@"access_token"])
        {
            // Le parole di Google, non le nostre: un token scaduto e un
            // client sbagliato si distinguono solo così.
            NSString *said = tokens[@"error_description"] ?: tokens[@"error"]
                          ?: e.localizedDescription;
            answer(MPGoogleLinkRefused, said);
            return;
        }
        if (tokens[@"refresh_token"])
            MPKeychainWrite(kMPRefreshAccount, tokens[@"refresh_token"]);

        [self rememberPicked:picked withToken:tokens[@"access_token"]];
        answer(MPGoogleLinkDone, nil);
    }] resume];
}


/// Chiede a Drive come si chiama quello che la persona ha scelto, così il
/// pannello dice «Appunti» invece di un identificatore.
- (void)rememberPicked:(NSString *)picked withToken:(NSString *)token
{
    NSString *first = [picked componentsSeparatedByString:@","].firstObject;
    if (!first.length)
        return;

    NSString *address = [NSString stringWithFormat:
        @"https://www.googleapis.com/drive/v3/files/%@?fields=id,name,mimeType",
        first];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:address]];
    [request setValue:[@"Bearer " stringByAppendingString:token]
   forHTTPHeaderField:@"Authorization"];

    NSData *data = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *got = nil;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *body, NSURLResponse *r, NSError *e) {
        got = body;
        dispatch_semaphore_signal(done);
    }] resume];
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW,
                                                20 * NSEC_PER_SEC));
    data = got;
    if (!data)
        return;

    NSDictionary *file = [NSJSONSerialization JSONObjectWithData:data
                                                         options:0 error:NULL];
    if (![file isKindOfClass:[NSDictionary class]] || !file[@"id"])
        return;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:file[@"id"] forKey:kMPFolderIdKey];
    [defaults setObject:file[@"name"] ?: @"" forKey:kMPFolderNameKey];
}

@end
