//
//  Tools/provider_probe.m — cosa risponde un file dentro un provider.
//
//  Dropbox, Google Drive, OneDrive e iCloud su macOS sono File Provider, e
//  i loro file dovrebbero rispondere tutti alle stesse chiavi di NSURL.
//  «Dovrebbero» è il motivo per cui questo arnese esiste: la tappa M0 della
//  roadmap della sincronizzazione è guardarlo succedere, su ogni provider,
//  per un file che è sceso e per uno che non è sceso.
//
//      Tools/provider_probe.m --file  <percorso>…        le chiavi, file per file
//      Tools/provider_probe.m --cartella <percorso> [--secondi 10]
//
//  La seconda forma è la prova che conta per la ricerca e per l'indice:
//  cammina una cartella **senza aprire niente**, conta quanti file hanno i
//  byte e quanti no, e si arrende se il provider non risponde entro il
//  tempo dato — che su un client non collegato succede, misurato.
//
//  Si compila da sé:
//      clang -fobjc-arc -framework Foundation -o probe Tools/provider_probe.m
//

#import <Foundation/Foundation.h>


/// Le cinque chiavi che descrivono un file dentro un provider, più le due
/// che dicono se i byte ci sono davvero.
static NSArray<NSURLResourceKey> *MDProviderKeys(void)
{
    return @[NSURLIsUbiquitousItemKey,
             NSURLUbiquitousItemDownloadingStatusKey,
             NSURLUbiquitousItemIsDownloadingKey,
             NSURLUbiquitousItemIsUploadedKey,
             NSURLUbiquitousItemIsUploadingKey,
             NSURLFileSizeKey,
             NSURLFileAllocatedSizeKey];
}


/// Quanto ci mette a rispondere, che è metà della misura: un provider che
/// non è collegato non dice «no», ci pensa e poi va in timeout.
static void MDPrintKeysOf(NSURL *url)
{
    NSDate *start = [NSDate date];
    NSError *error = nil;
    NSDictionary *values = [url resourceValuesForKeys:MDProviderKeys()
                                                error:&error];
    NSTimeInterval took = -[start timeIntervalSinceNow];

    printf("%s\n", url.path.UTF8String);
    printf("  %-44s %.0f ms\n", "(tempo di risposta)", took * 1000.0);
    if (!values)
    {
        printf("  errore: %s\n", error.localizedDescription.UTF8String);
        return;
    }
    for (NSURLResourceKey key in MDProviderKeys())
    {
        id value = values[key];
        printf("  %-44s %s\n", key.UTF8String,
               value ? [[value description] UTF8String] : "(niente)");
    }
    // I byte ci sono? Il modo che non dipende dal provider: un file con una
    // dimensione e zero blocchi allocati è un segnaposto.
    NSDictionary *attributes = [[NSFileManager defaultManager]
        attributesOfItemAtPath:url.path error:NULL];
    unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];
    printf("  %-44s %llu byte dichiarati\n", "(dimensione)", size);
}


/// Cammina una cartella leggendo **solo** i metadati, e conta.
static void MDWalk(NSURL *folder, NSTimeInterval limit)
{
    __block NSUInteger folders = 0, files = 0, withBytes = 0, without = 0;
    __block BOOL finished = NO;
    NSDate *start = [NSDate date];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileManager *manager = [NSFileManager defaultManager];
        // Le chiavi si chiedono all'enumeratore: così le legge mentre
        // cammina, e non si apre niente.
        NSDirectoryEnumerator *walk = [manager enumeratorAtURL:folder
            includingPropertiesForKeys:@[NSURLIsDirectoryKey,
                                         NSURLFileSizeKey,
                                         NSURLFileAllocatedSizeKey,
                                         NSURLUbiquitousItemDownloadingStatusKey]
                               options:NSDirectoryEnumerationSkipsHiddenFiles
                          errorHandler:^BOOL (NSURL *url, NSError *error) {
            fprintf(stderr, "  non si è potuto leggere %s: %s\n",
                    url.lastPathComponent.UTF8String,
                    error.localizedDescription.UTF8String);
            return YES;         // si tira avanti: una cartella sola non ferma tutto
        }];

        for (NSURL *url in walk)
        {
            NSNumber *isFolder = nil;
            [url getResourceValue:&isFolder forKey:NSURLIsDirectoryKey error:NULL];
            if (isFolder.boolValue)
            {
                folders++;
                continue;
            }
            files++;

            NSNumber *size = nil, *allocated = nil;
            [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
            [url getResourceValue:&allocated forKey:NSURLFileAllocatedSizeKey
                            error:NULL];
            if (size.unsignedLongLongValue > 0
                    && allocated.unsignedLongLongValue == 0)
                without++;
            else
                withBytes++;
        }
        finished = YES;
        dispatch_semaphore_signal(done);
    });

    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW,
                                                (int64_t)(limit * NSEC_PER_SEC)));
    printf("\n%s\n", folder.path.UTF8String);
    printf("  cartelle          %lu\n", (unsigned long)folders);
    printf("  file              %lu\n", (unsigned long)files);
    printf("  con i byte        %lu\n", (unsigned long)withBytes);
    printf("  senza i byte      %lu\n", (unsigned long)without);
    printf("  in                %.1f s%s\n", -[start timeIntervalSinceNow],
           finished ? "" : "  ← NON HA FINITO: il provider non ha risposto in tempo");
}


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSMutableArray<NSString *> *paths = [NSMutableArray array];
        BOOL folderMode = NO;
        NSTimeInterval limit = 10.0;

        for (int i = 1; i < argc; i++)
        {
            NSString *argument = @(argv[i]);
            if ([argument isEqualToString:@"--cartella"])
                folderMode = YES;
            else if ([argument isEqualToString:@"--file"])
                folderMode = NO;
            else if ([argument isEqualToString:@"--secondi"] && i + 1 < argc)
                limit = @(argv[++i]).doubleValue;
            else
                [paths addObject:argument];
        }

        if (!paths.count)
        {
            fprintf(stderr, "uso: provider_probe [--file] <percorso>…\n"
                            "     provider_probe --cartella <percorso> "
                            "[--secondi 10]\n");
            return 2;
        }

        for (NSString *path in paths)
        {
            NSURL *url = [NSURL fileURLWithPath:path.stringByExpandingTildeInPath];
            if (folderMode)
                MDWalk(url, limit);
            else
                MDPrintKeysOf(url);
        }
    }
    return 0;
}
