//
//  Tools/drive_probe.m — la misura B0: cosa vede un'applicazione desktop
//  dentro Google Drive con il solo ambito `drive.file`.
//
//  La domanda che decide la forma della prima fase, e che la documentazione
//  di Google non risponde: se l'utente sceziona una **cartella** nel Picker,
//  l'applicazione vede anche i file che ci sono dentro, o solo la cartella?
//
//  Questo arnese lo chiede a Google e stampa la risposta. Non è
//  l'applicazione: non salva niente, non scrive niente su Drive, e il
//  gettone resta in memoria e muore con il processo.
//
//      clang -fobjc-arc -framework Foundation -o drive_probe \
//          Tools/drive_probe.m
//      ./drive_probe --client-id 123-abc.apps.googleusercontent.com
//
//  Serve un client OAuth di tipo «applicazione desktop», creato nella
//  console di chi prova: sta sotto il suo account Google, non sotto il
//  nostro, ed è la ragione per cui questo passo non si può automatizzare
//  del tutto.
//
//  Cosa fa, nell'ordine:
//    1. genera la coppia PKCE e apre il browser sull'indirizzo di
//       autorizzazione, con `trigger_onepick` e `allow_folder_selection`;
//    2. ascolta su 127.0.0.1 e aspetta il richiamo, che porta `code` e
//       `picked_file_ids`;
//    3. scambia il codice con un gettone;
//    4. per ogni cosa scelta chiede `files.get`, e se è una cartella
//       chiede anche i figli con `files.list`.
//
//  L'ultimo punto **è** la misura: se i figli tornano, «collega Google
//  Drive» può voler dire «scegli la cartella dei tuoi appunti». Se non
//  tornano, l'applicazione potrà lavorare solo in una cartella creata da
//  lei.
//

#import <Foundation/Foundation.h>

#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#include <CommonCrypto/CommonDigest.h>


#pragma mark - PKCE

/// Il verificatore: quarantotto byte casuali, scritti come li vuole PKCE.
static NSString *MDRandomVerifier(void)
{
    uint8_t bytes[48];
    arc4random_buf(bytes, sizeof(bytes));
    NSString *text = [[NSData dataWithBytes:bytes length:sizeof(bytes)]
        base64EncodedStringWithOptions:0];
    text = [text stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    text = [text stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [text stringByReplacingOccurrencesOfString:@"=" withString:@""];
}


/// La sfida: lo SHA-256 del verificatore, in base64url.
static NSString *MDChallengeFor(NSString *verifier)
{
    NSData *data = [verifier dataUsingEncoding:NSASCIIStringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSString *text = [[NSData dataWithBytes:digest length:sizeof(digest)]
        base64EncodedStringWithOptions:0];
    text = [text stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    text = [text stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [text stringByReplacingOccurrencesOfString:@"=" withString:@""];
}


#pragma mark - L'ascolto sul richiamo

/// Apre una porta su 127.0.0.1 e restituisce il descrittore, o -1.
/// La porta la sceglie il sistema: un numero fisso è un numero che un
/// giorno è occupato.
static int MDListen(uint16_t *outPort)
{
    int handle = socket(AF_INET, SOCK_STREAM, 0);
    if (handle < 0)
        return -1;
    int yes = 1;
    setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
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


/// Aspetta il richiamo del browser e restituisce i parametri della query.
/// Risponde una paginetta, perché una finestra bianca dopo aver dato il
/// permesso sembra un errore.
static NSDictionary<NSString *, NSString *> *MDWaitForCallback(int listener)
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

    NSString *request = @(buffer);
    NSString *line = [request componentsSeparatedByString:@"\r\n"].firstObject;
    NSArray *parts = [line componentsSeparatedByString:@" "];
    NSString *path = parts.count > 1 ? parts[1] : @"/";

    NSString *body = @"<!doctype html><meta charset=utf-8>"
                      "<title>Fatto</title>"
                      "<body style=\"font:16px -apple-system;padding:3em\">"
                      "<p>Fatto: puoi chiudere questa scheda e tornare al "
                      "terminale.</body>";
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


#pragma mark - Le chiamate

/// Una richiesta, aspettata. Un arnese di misura può permetterselo.
static NSDictionary *MDAsk(NSURLRequest *request, NSInteger *outStatus)
{
    __block NSDictionary *answer = nil;
    __block NSInteger status = 0;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *e) {
        status = ((NSHTTPURLResponse *)response).statusCode;
        if (data)
        {
            id parsed = [NSJSONSerialization JSONObjectWithData:data options:0
                                                          error:NULL];
            answer = [parsed isKindOfClass:[NSDictionary class]] ? parsed
                   : @{@"(non JSON)": [[NSString alloc] initWithData:data
                          encoding:NSUTF8StringEncoding] ?: @""};
        }
        if (e)
            answer = @{@"(errore)": e.localizedDescription};
        dispatch_semaphore_signal(done);
    }] resume];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    if (outStatus)
        *outStatus = status;
    return answer ?: @{};
}


static NSDictionary *MDGet(NSString *address, NSString *token,
                           NSInteger *outStatus)
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:address]];
    [request setValue:[@"Bearer " stringByAppendingString:token]
   forHTTPHeaderField:@"Authorization"];
    return MDAsk(request, outStatus);
}


#pragma mark - La misura

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        // Riga per riga: questo arnese si guarda mentre lavora, anche
        // quando lo si manda in un file.
        setvbuf(stdout, NULL, _IOLBF, 0);

        NSString *clientId = nil, *clientSecret = nil;
        // Per provare l'ascolto e la lettura del richiamo senza un client
        // vero: l'indirizzo si stampa e il browser non si apre.
        BOOL openBrowser = YES;
        for (int i = 1; i < argc; i++)
        {
            NSString *argument = @(argv[i]);
            if ([argument isEqualToString:@"--client-id"] && i + 1 < argc)
                clientId = @(argv[++i]);
            else if ([argument isEqualToString:@"--client-secret"] && i + 1 < argc)
                clientSecret = @(argv[++i]);
            else if ([argument isEqualToString:@"--senza-browser"])
                openBrowser = NO;
        }
        if (!clientId.length)
        {
            fprintf(stderr,
                "uso: drive_probe --client-id <id> [--client-secret <segreto>]\n"
                "                 [--senza-browser]\n\n"
                "Serve un client OAuth di tipo «applicazione desktop».\n"
                "Il segreto, per un client desktop, è facoltativo: con PKCE\n"
                "Google lo dichiara «Optional», e questo arnese lo manda\n"
                "solo se glielo si dà.\n");
            return 2;
        }

        uint16_t port = 0;
        int listener = MDListen(&port);
        if (listener < 0)
        {
            fprintf(stderr, "non si è potuto aprire una porta su 127.0.0.1\n");
            return 1;
        }
        NSString *redirect = [NSString stringWithFormat:
            @"http://127.0.0.1:%u/richiamo", port];
        printf("1. ascolto su %s\n", redirect.UTF8String);
        printf("   (un client di tipo «applicazione desktop» accetta "
               "127.0.0.1 su qualunque porta:\n"
               "    la porta la sceglie il sistema a ogni giro, e non va "
               "registrata)\n");

        NSString *verifier = MDRandomVerifier();
        NSURLComponents *authorize = [NSURLComponents componentsWithString:
            @"https://accounts.google.com/o/oauth2/v2/auth"];
        authorize.queryItems = @[
            [NSURLQueryItem queryItemWithName:@"client_id" value:clientId],
            [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirect],
            [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
            [NSURLQueryItem queryItemWithName:@"scope"
                value:@"https://www.googleapis.com/auth/drive.file"],
            [NSURLQueryItem queryItemWithName:@"access_type" value:@"offline"],
            [NSURLQueryItem queryItemWithName:@"prompt" value:@"consent"],
            // Le due che accendono il Picker dentro il consenso: è così che
            // un'applicazione desktop lo mostra, senza JavaScript e senza
            // una vista web nostra.
            [NSURLQueryItem queryItemWithName:@"trigger_onepick" value:@"true"],
            [NSURLQueryItem queryItemWithName:@"allow_folder_selection"
                                        value:@"true"],
            [NSURLQueryItem queryItemWithName:@"allow_multiple" value:@"true"],
            [NSURLQueryItem queryItemWithName:@"code_challenge"
                value:MDChallengeFor(verifier)],
            [NSURLQueryItem queryItemWithName:@"code_challenge_method"
                                        value:@"S256"],
            [NSURLQueryItem queryItemWithName:@"state" value:@"b0"],
        ];

        printf("\n2. apro il browser. Scegli **una cartella** che contiene "
               "già qualche documento.\n\n%s\n\n",
               authorize.URL.absoluteString.UTF8String);
        // Niente AppKit in un arnese da riga di comando: `open` basta, e
        // se non parte l'indirizzo è stampato qui sopra da incollare.
        if (openBrowser)
            [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open"
                                     arguments:@[authorize.URL.absoluteString]];
        else
            printf("   (--senza-browser: aprilo a mano, o fingi il richiamo)\n");

        NSDictionary *callback = MDWaitForCallback(listener);
        close(listener);
        if (!callback)
        {
            fprintf(stderr, "il richiamo non è arrivato\n");
            return 1;
        }
        if (callback[@"error"])
        {
            printf("3. Google ha detto: %s\n",
                   [callback[@"error"] UTF8String]);
            return 1;
        }
        printf("3. tornato: %s\n", callback.description.UTF8String);

        NSString *picked = callback[@"picked_file_ids"] ?: @"";
        NSString *code = callback[@"code"] ?: @"";

        // Lo scambio del codice con il gettone.
        NSMutableArray *fields = [NSMutableArray arrayWithArray:@[
            [NSString stringWithFormat:@"client_id=%@", clientId],
            [NSString stringWithFormat:@"code=%@", code],
            [NSString stringWithFormat:@"code_verifier=%@", verifier],
            @"grant_type=authorization_code",
            [NSString stringWithFormat:@"redirect_uri=%@",
             [redirect stringByAddingPercentEncodingWithAllowedCharacters:
              [NSCharacterSet alphanumericCharacterSet]]],
        ]];
        if (clientSecret.length)
            [fields addObject:[NSString stringWithFormat:@"client_secret=%@",
                               clientSecret]];

        NSMutableURLRequest *exchange = [NSMutableURLRequest requestWithURL:
            [NSURL URLWithString:@"https://oauth2.googleapis.com/token"]];
        exchange.HTTPMethod = @"POST";
        [exchange setValue:@"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];
        exchange.HTTPBody = [[fields componentsJoinedByString:@"&"]
            dataUsingEncoding:NSUTF8StringEncoding];

        NSInteger status = 0;
        NSDictionary *tokens = MDAsk(exchange, &status);
        NSString *token = tokens[@"access_token"];
        printf("\n4. scambio del codice: HTTP %ld%s\n", (long)status,
               token ? "" : "  ← nessun gettone");
        if (!token)
        {
            printf("   %s\n", tokens.description.UTF8String);
            return 1;
        }
        printf("   gettone di rinnovo: %s\n",
               tokens[@"refresh_token"] ? "sì" : "no");

        printf("\n5. cosa si vede\n");
        if (!picked.length)
        {
            printf("   nessun file scelto: il Picker non ha restituito "
                   "picked_file_ids.\n");
            return 0;
        }

        for (NSString *identifier in [picked componentsSeparatedByString:@","])
        {
            NSString *address = [NSString stringWithFormat:
                @"https://www.googleapis.com/drive/v3/files/%@"
                @"?fields=id,name,mimeType,parents", identifier];
            NSInteger code = 0;
            NSDictionary *file = MDGet(address, token, &code);
            printf("\n   %s  HTTP %ld\n", identifier.UTF8String, (long)code);
            printf("     nome  %s\n", [file[@"name"] ?: @"—" UTF8String]);
            printf("     tipo  %s\n", [file[@"mimeType"] ?: @"—" UTF8String]);

            BOOL isFolder = [file[@"mimeType"]
                isEqualToString:@"application/vnd.google-apps.folder"];
            if (!isFolder)
                continue;

            // LA MISURA: i figli di una cartella scelta si vedono?
            NSString *query = [[NSString stringWithFormat:
                @"'%@' in parents and trashed = false", identifier]
                stringByAddingPercentEncodingWithAllowedCharacters:
                    [NSCharacterSet URLQueryAllowedCharacterSet]];
            NSString *list = [NSString stringWithFormat:
                @"https://www.googleapis.com/drive/v3/files"
                @"?q=%@&fields=files(id,name,mimeType)&pageSize=20", query];
            NSInteger listCode = 0;
            NSDictionary *children = MDGet(list, token, &listCode);
            NSArray *files = children[@"files"];
            printf("     --- i figli, con il solo drive.file: HTTP %ld, "
                   "%lu trovati\n", (long)listCode,
                   (unsigned long)files.count);
            for (NSDictionary *child in files)
                printf("         %s\n", [child[@"name"] UTF8String]);
            printf("\n     >>> RISPOSTA B0: scegliere una cartella %s\n",
                   files.count ? "DÀ accesso a quello che c'è dentro"
                               : "NON dà accesso al contenuto");
        }
    }
    return 0;
}
