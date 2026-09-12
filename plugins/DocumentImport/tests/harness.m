//
//  tests/harness.m — the converter, on the command line.
//
//  MDMarkdownFromWordXML and MDMarkdownFromOpenDocumentXML take XML and
//  give back Markdown, and neither needs a window; this is the shortest
//  thing that can call them. Markdown on the standard output, the pictures
//  and whatever was left behind on the standard error, so that a check can
//  look at either one.
//
//      harness --word document.xml [rels.xml [numbering.xml]]
//      harness --odt content.xml
//
//  The folder the picture links point at is «media», which is what the
//  expected files were written against.
//

#import <Foundation/Foundation.h>

#import "MDOfficeImport.h"


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 3)
        {
            fprintf(stderr, "uso: harness --word|--odt file.xml [...]\n");
            return 2;
        }
        NSString *(^read)(const char *) = ^(const char *path) {
            if (!path) return (NSString *)nil;
            return [NSString stringWithContentsOfFile:@(path)
                encoding:NSUTF8StringEncoding error:NULL];
        };
        MDImportResult *result;
        if (strcmp(argv[1], "--word") == 0)
        {
            result = MDMarkdownFromWordXML(read(argv[2]),
                argc > 3 ? read(argv[3]) : nil,
                argc > 4 ? read(argv[4]) : nil, @"media");
        }
        else
        {
            result = MDMarkdownFromOpenDocumentXML(read(argv[2]), @"media");
        }
        printf("%s", result.markdown.UTF8String);
        for (MDImportPicture *picture in result.pictures)
            fprintf(stderr, "picture\t%s\t%s\n",
                    picture.entry.UTF8String, picture.name.UTF8String);
        for (NSString *lost in result.lost)
            fprintf(stderr, "lost\t%s\n", lost.UTF8String);
    }
    return 0;
}
