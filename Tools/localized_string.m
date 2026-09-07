//
//  localized_string.m
//  MacDown
//
//  What a bundle answers for a key, in a language.
//
//  A .strings file that is in the bundle is not yet a translation the reader
//  gets: the folder has to be an .lproj the loader recognizes, the language
//  has to be one the bundle claims, and the key has to match to the last
//  character. This asks the same question the interface asks.
//
//  Build:  clang -fobjc-arc -framework Foundation \
//              -o localized_string Tools/localized_string.m
//  Use:    localized_string <bundle> <language> <key>
//

#import <Foundation/Foundation.h>

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 4)
        {
            fprintf(stderr, "uso: %s <bundle> <lingua> <chiave>\n", argv[0]);
            return 2;
        }
        NSString *path = @(argv[1]);
        NSString *language = @(argv[2]);
        NSString *key = @(argv[3]);

        NSBundle *bundle = [NSBundle bundleWithPath:path];
        if (!bundle)
        {
            fprintf(stderr, "nessun bundle in %s\n", argv[1]);
            return 3;
        }
        // The language the reader would have, asked of the bundle the way
        // NSLocalizedString asks it.
        NSArray<NSString *> *lproj =
            [bundle pathsForResourcesOfType:@"strings"
                               inDirectory:nil
                           forLocalization:language];
        for (NSString *file in lproj)
        {
            NSDictionary *table = [NSDictionary
                dictionaryWithContentsOfFile:file];
            NSString *value = table[key];
            if (value)
            {
                printf("%s\n", value.UTF8String);
                return 0;
            }
        }
        fprintf(stderr, "«%s» non tradotta in %s\n", argv[3], argv[2]);
        return 1;
    }
}
