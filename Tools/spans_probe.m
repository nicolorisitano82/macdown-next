//
//  Tools/spans_probe.m — `[testo]{...}` on the command line.
//
//  The rewriting the application does before it parses, asked about one
//  string and printed. Everything it needs is two files and Foundation, so
//  the control suite can build it in a second and ask it what a document
//  would become without opening a window.
//
//      spans_probe 'Una [parola]{style="color:#c00"} qui'
//

#import <Foundation/Foundation.h>

#import "MPAttributedSpans.h"


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 2)
        {
            fprintf(stderr, "uso: spans_probe '<markdown>'\n");
            return 2;
        }
        printf("%s", MPMarkdownWithAttributedSpans(@(argv[1])).UTF8String);
    }
    return 0;
}
