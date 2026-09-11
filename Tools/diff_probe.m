//
//  Tools/diff_probe.m — the comparison engine, on two real files.
//
//  Built and run by the control suite:
//
//      diff_probe <a.md> <b.md>            the shape, row by row
//      diff_probe <a.md> <b.md> --counts   how many changed, added, taken
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

        NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(left, right);
        NSUInteger added = 0, removed = 0, changed = 0;
        MPDiffCounts(rows, &added, &removed, &changed);

        if (argc > 3 && strcmp(argv[3], "--counts") == 0)
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
