//
//  Tools/diff_probe.m — the comparison engine, on two real files.
//
//  Built and run by the control suite:
//
//      diff_probe <a.md> <b.md>            the shape, row by row
//      diff_probe <a.md> <b.md> --counts   how many changed, added, taken
//
//  and the three things the panel can be told to ignore:
//
//      --paragraphs     compare paragraph against paragraph
//      --ignore-space   indentation and runs of spaces
//      --ignore-case
//
//  The shape is one character per row — = same, ~ changed, + added, - taken
//  away — which is a thing a check can compare with a string.
//

#import <Foundation/Foundation.h>

#import "MPDiff.h"


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 3)
        {
            fprintf(stderr, "uso: diff_probe <a> <b> [--counts]\n");
            return 2;
        }
        NSString *left = [NSString stringWithContentsOfFile:@(argv[1])
            encoding:NSUTF8StringEncoding error:NULL];
        NSString *right = [NSString stringWithContentsOfFile:@(argv[2])
            encoding:NSUTF8StringEncoding error:NULL];
        if (!left || !right)
        {
            fprintf(stderr, "non sono testo: %s %s\n", argv[1], argv[2]);
            return 3;
        }

        MPDiffOptions options = MPDiffOptionsStrict;
        BOOL counting = NO;
        for (int i = 3; i < argc; i++)
        {
            if (strcmp(argv[i], "--counts") == 0)
                counting = YES;
            else if (strcmp(argv[i], "--paragraphs") == 0)
                options.grain = MPDiffByParagraphs;
            else if (strcmp(argv[i], "--ignore-space") == 0)
                options.ignoringSpace = YES;
            else if (strcmp(argv[i], "--ignore-case") == 0)
                options.ignoringCase = YES;
        }

        NSArray<MPDiffRow *> *rows =
            MPDiffRowsBetweenWithOptions(left, right, options);
        NSUInteger added = 0, removed = 0, changed = 0;
        MPDiffCounts(rows, &added, &removed, &changed);

        if (counting)
        {
            printf("%lu cambiate, %lu aggiunte, %lu tolte\n",
                   (unsigned long)changed, (unsigned long)added,
                   (unsigned long)removed);
            return 0;
        }

        NSMutableString *shape = [NSMutableString string];
        for (MPDiffRow *row in rows)
        {
            switch (row.kind)
            {
                case MPDiffEqual:   [shape appendString:@"="]; break;
                case MPDiffChanged: [shape appendString:@"~"]; break;
                case MPDiffAdded:   [shape appendString:@"+"]; break;
                case MPDiffRemoved: [shape appendString:@"-"]; break;
            }
        }
        printf("%s\n", shape.UTF8String);
    }
    return 0;
}
