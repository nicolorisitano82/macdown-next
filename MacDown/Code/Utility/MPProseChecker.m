//
//  MPProseChecker.m
//  MacDown
//

#import "MPProseChecker.h"
#import "NSColor+HTML.h"
#import "NSJSONSerialization+File.h"


@implementation MPProseIssue
@end


/// A compiled category: one regex covering its whole word list.
@interface MPProseCategory : NSObject
@property (copy, nonatomic) NSString *identifier;
@property (copy, nonatomic) NSString *name;
@property (strong, nonatomic) NSColor *color;
@property (strong, nonatomic) NSRegularExpression *regex;
@end

@implementation MPProseCategory
@end


@interface MPProseChecker ()
@property (copy, nonatomic) NSArray<MPProseCategory *> *categories;
@property (strong, nonatomic) MPProseCategory *repeated;
/// Doublings that are meant, lowercased, matched against the whole hit.
@property (copy, nonatomic) NSSet<NSString *> *repeatedExceptions;
@property (strong, nonatomic) NSRegularExpression *skipRegex;
@end


@implementation MPProseChecker

+ (instancetype)sharedChecker
{
    static MPProseChecker *checker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        checker = [[self alloc] init];
    });
    return checker;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    // Fenced code, indented code, inline code and link destinations. Matches
    // inside any of these are not prose and are dropped.
    _skipRegex = [[NSRegularExpression alloc] initWithPattern:
        @"```[\\s\\S]*?```"          // fenced block
        @"|~~~[\\s\\S]*?~~~"         // fenced block, tilde form
        @"|`[^`\\n]*`"               // inline code
        @"|^(?: {4}|\\t).*$"         // indented code line
        @"|\\]\\([^)]*\\)"           // link destination
        @"|<[^>\\s]+>"               // autolink or raw tag
                                                     options:
        NSRegularExpressionAnchorsMatchLines error:NULL];

    [self loadLists];
    return self;
}

- (BOOL)ready
{
    return self.categories.count > 0 || self.repeated != nil;
}

#pragma mark - Loading

/// Escapes a list entry for use inside a regex, and lets a phrase match with
/// any run of whitespace — including a line break — between its words.
NS_INLINE NSString *MPProsePattern(NSString *entry, BOOL isPhrase)
{
    NSString *escaped =
        [NSRegularExpression escapedPatternForString:entry];
    if (!isPhrase)
        return escaped;

    // The escaped form has literal spaces; widen them.
    return [escaped stringByReplacingOccurrencesOfString:@" "
                                             withString:@"\\s+"];
}

- (MPProseCategory *)categoryFromDictionary:(NSDictionary *)info
{
    NSString *identifier = info[@"id"];
    NSString *name = info[@"name"];
    NSString *colorName = info[@"color"];
    if (![identifier isKindOfClass:[NSString class]]
            || ![name isKindOfClass:[NSString class]])
        return nil;

    NSMutableArray<NSString *> *alternatives = [NSMutableArray array];
    for (NSString *word in info[@"words"])
    {
        if ([word isKindOfClass:[NSString class]] && word.length)
            [alternatives addObject:MPProsePattern(word, NO)];
    }
    for (NSString *phrase in info[@"phrases"])
    {
        if ([phrase isKindOfClass:[NSString class]] && phrase.length)
            [alternatives addObject:MPProsePattern(phrase, YES)];
    }
    if (!alternatives.count)
        return nil;

    // Longest first, so "in order to" wins over a shorter overlapping entry.
    [alternatives sortUsingComparator:^NSComparisonResult(NSString *a,
                                                          NSString *b) {
        if (a.length > b.length) return NSOrderedAscending;
        if (a.length < b.length) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSString *pattern = [NSString stringWithFormat:@"\\b(?:%@)\\b",
        [alternatives componentsJoinedByString:@"|"]];
    NSRegularExpression *regex = [[NSRegularExpression alloc]
        initWithPattern:pattern
                options:NSRegularExpressionCaseInsensitive error:NULL];
    if (!regex)
        return nil;

    MPProseCategory *category = [[MPProseCategory alloc] init];
    category.identifier = identifier;
    // Translated where a translation exists, and left as written where it
    // does not — the lists are meant to be extended, and someone's own
    // category should appear as they named it.
    category.name = NSLocalizedString(name, @"Prose issue category");
    category.regex = regex;
    category.color = [colorName isKindOfClass:[NSString class]]
        ? [NSColor colorWithHTMLName:colorName] : nil;
    if (!category.color)
        category.color = [NSColor systemOrangeColor];
    return category;
}

- (void)loadLists
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"prose-issues"
                                         withExtension:@"json"
                                          subdirectory:@"Data"];
    if (!url)
        return;

    NSDictionary *root = [NSJSONSerialization JSONObjectWithFileAtURL:url
                                                             options:0
                                                               error:NULL];
    if (![root isKindOfClass:[NSDictionary class]])
        return;

    NSMutableArray<MPProseCategory *> *categories = [NSMutableArray array];
    for (NSDictionary *info in root[@"categories"])
    {
        if (![info isKindOfClass:[NSDictionary class]])
            continue;
        MPProseCategory *category = [self categoryFromDictionary:info];
        if (category)
            [categories addObject:category];
    }
    self.categories = categories;

    NSDictionary *repeatedInfo = root[@"repeated"];
    if ([repeatedInfo isKindOfClass:[NSDictionary class]])
    {
        MPProseCategory *repeated = [[MPProseCategory alloc] init];
        repeated.identifier = repeatedInfo[@"id"] ?: @"repeated";
        repeated.name = NSLocalizedString(
            repeatedInfo[@"name"] ?: @"Repeated words",
            @"Prose issue category");
        NSString *colorName = repeatedInfo[@"color"];
        repeated.color = [colorName isKindOfClass:[NSString class]]
            ? [NSColor colorWithHTMLName:colorName] : nil;
        if (!repeated.color)
            repeated.color = [NSColor systemRedColor];

        // A word, then the same word again with only whitespace between. The
        // backreference is why this one is not part of a word list.
        repeated.regex = [[NSRegularExpression alloc] initWithPattern:
            @"\\b(\\w+)\\s+\\1\\b"
                                                             options:
            NSRegularExpressionCaseInsensitive error:NULL];
        self.repeated = repeated.regex ? repeated : nil;

        NSMutableSet<NSString *> *allowed = [NSMutableSet set];
        for (NSString *phrase in repeatedInfo[@"exceptions"])
        {
            if ([phrase isKindOfClass:[NSString class]] && phrase.length)
                [allowed addObject:phrase.lowercaseString];
        }
        self.repeatedExceptions = allowed;
    }
}

#pragma mark - Checking

- (NSArray<MPProseIssue *> *)issuesInString:(NSString *)text
{
    if (!text.length || !self.ready)
        return @[];

    NSRange whole = NSMakeRange(0, text.length);
    NSArray<NSTextCheckingResult *> *skips =
        [self.skipRegex matchesInString:text options:0 range:whole];

    NSMutableArray<MPProseIssue *> *issues = [NSMutableArray array];
    NSMutableArray<MPProseCategory *> *all =
        [self.categories mutableCopy] ?: [NSMutableArray array];
    if (self.repeated)
        [all addObject:self.repeated];

    for (MPProseCategory *category in all)
    {
        NSArray<NSTextCheckingResult *> *matches =
            [category.regex matchesInString:text options:0 range:whole];
        for (NSTextCheckingResult *match in matches)
        {
            BOOL skip = NO;
            for (NSTextCheckingResult *span in skips)
            {
                if (NSIntersectionRange(span.range, match.range).length)
                {
                    skip = YES;
                    break;
                }
            }
            if (skip)
                continue;

            // Some doublings are meant. Italian is full of them — piano
            // piano, via via, man mano — and flagging those would make the
            // whole category untrustworthy.
            if (category == self.repeated)
            {
                NSString *hit = [[text substringWithRange:match.range]
                    lowercaseString];
                // Whitespace inside the match may be a line break.
                NSArray<NSString *> *words = [hit componentsSeparatedByCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSMutableArray<NSString *> *kept = [NSMutableArray array];
                for (NSString *word in words)
                {
                    if (word.length)
                        [kept addObject:word];
                }
                hit = [kept componentsJoinedByString:@" "];
                if ([self.repeatedExceptions containsObject:hit])
                    continue;
            }

            MPProseIssue *issue = [[MPProseIssue alloc] init];
            issue.range = match.range;
            issue.text = [text substringWithRange:match.range];
            issue.categoryIdentifier = category.identifier;
            issue.categoryName = category.name;
            issue.color = category.color;
            [issues addObject:issue];
        }
    }

    [issues addObjectsFromArray:[self headingsMissingTheirSpaceIn:text
                                                       skipping:skips]];

    [issues sortUsingComparator:^NSComparisonResult(MPProseIssue *a,
                                                    MPProseIssue *b) {
        if (a.range.location != b.range.location)
        {
            return a.range.location < b.range.location
                ? NSOrderedAscending : NSOrderedDescending;
        }
        // Longer first, so the wider reading of an overlap survives.
        if (a.range.length != b.range.length)
        {
            return a.range.length > b.range.length
                ? NSOrderedAscending : NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    // One underline per stretch of text. Lists overlap by nature — "potrebbe
    // essere" is hedging and a passive tell at once — and reporting it twice
    // would double the count and draw the underline twice. The first match
    // wins, which is the earliest category in the resource.
    NSMutableArray<MPProseIssue *> *distinct = [NSMutableArray array];
    for (MPProseIssue *issue in issues)
    {
        MPProseIssue *previous = distinct.lastObject;
        if (previous
                && NSIntersectionRange(previous.range, issue.range).length)
            continue;
        [distinct addObject:issue];
    }
    return distinct;
}

/** Lines whose hashes are stuck to their text.
 *
 * `##Trump: la proposta` reads as a heading to whoever wrote it and as a
 * paragraph to every Markdown there is, this editor included. Reported
 * with the correction, since there is only one thing it can mean.
 *
 * A single hash is different: `#riunione` is a hashtag, and a common one.
 * So one hash is only reported when what follows it has a space in it —
 * more than one word is a sentence, and a sentence is a heading.
 */
- (NSArray<MPProseIssue *> *)headingsMissingTheirSpaceIn:(NSString *)text
    skipping:(NSArray<NSTextCheckingResult *> *)skips
{
    static NSRegularExpression *stuck = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stuck = [NSRegularExpression regularExpressionWithPattern:
            @"^(#{1,6})([^#\\s].*)$"
            options:NSRegularExpressionAnchorsMatchLines error:NULL];
    });

    NSMutableArray<MPProseIssue *> *found = [NSMutableArray array];
    NSArray *matches = [stuck matchesInString:text options:0
                                        range:NSMakeRange(0, text.length)];
    for (NSTextCheckingResult *match in matches)
    {
        NSRange hashes = [match rangeAtIndex:1];
        NSRange rest = [match rangeAtIndex:2];

        BOOL inCode = NO;
        for (NSTextCheckingResult *span in skips)
        {
            if (NSIntersectionRange(span.range, match.range).length)
            {
                inCode = YES;
                break;
            }
        }
        if (inCode)
            continue;

        if (hashes.length == 1
            && [text rangeOfString:@" " options:0 range:rest].location
                == NSNotFound)
            continue;       // A hashtag, not a heading.

        MPProseIssue *issue = [[MPProseIssue alloc] init];
        issue.range = hashes;
        issue.text = [text substringWithRange:hashes];
        issue.categoryIdentifier = @"heading-space";
        issue.categoryName = NSLocalizedString(@"heading without its space",
            @"Prose issue: hashes stuck to the heading text");
        issue.color = [NSColor systemPurpleColor];
        issue.replacement = [issue.text stringByAppendingString:@" "];
        [found addObject:issue];
    }
    return found;
}


- (NSString *)summaryForIssues:(NSArray<MPProseIssue *> *)issues
{
    if (!issues.count)
        return nil;

    NSCountedSet *counts = [NSCountedSet set];
    NSMutableDictionary<NSString *, NSString *> *names =
        [NSMutableDictionary dictionary];
    for (MPProseIssue *issue in issues)
    {
        [counts addObject:issue.categoryIdentifier];
        names[issue.categoryIdentifier] = issue.categoryName;
    }

    NSMutableArray<MPProseCategory *> *ordered =
        [self.categories mutableCopy] ?: [NSMutableArray array];
    if (self.repeated)
        [ordered addObject:self.repeated];

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (MPProseCategory *category in ordered)
    {
        NSUInteger count = [counts countForObject:category.identifier];
        if (!count)
            continue;
        // "Qualifiers: 2" rather than "2 qualifiers", so the line reads
        // correctly for any count without needing a plural for every name.
        [parts addObject:[NSString stringWithFormat:@"%@: %lu",
            category.name, (unsigned long)count]];
    }
    return [parts componentsJoinedByString:@" · "];
}

@end
