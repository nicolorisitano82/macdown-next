//
//  MPWebClipper.m
//  MacDown
//

#import "MPWebClipper.h"
#import "MPMarkdownFromRichText.h"
#import "MPUtilities.h"

/// Enough for any article; a page bigger than this is not an article.
static const NSUInteger kMPClipSizeLimit = 8 * 1024 * 1024;


/// Everything between a tag and its match, tag included, gone.
static NSString *MPHTMLWithoutElement(NSString *html, NSString *tag)
{
    NSString *pattern = [NSString stringWithFormat:
        @"<%@\\b[^>]*>[\\s\\S]*?</%@\\s*>", tag, tag];
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:pattern
                             options:NSRegularExpressionCaseInsensitive
                               error:NULL];
    return [regex stringByReplacingMatchesInString:html options:0
        range:NSMakeRange(0, html.length) withTemplate:@""];
}

/// The contents of the first element of that name, or nil.
static NSString *MPHTMLInsideElement(NSString *html, NSString *tag)
{
    NSString *pattern = [NSString stringWithFormat:
        @"<%@\\b[^>]*>([\\s\\S]*?)</%@\\s*>", tag, tag];
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:pattern
                             options:NSRegularExpressionCaseInsensitive
                               error:NULL];
    NSTextCheckingResult *match = [regex firstMatchInString:html options:0
        range:NSMakeRange(0, html.length)];
    if (!match)
        return nil;
    return [html substringWithRange:[match rangeAtIndex:1]];
}


NSString *MPReadableHTMLFragment(NSString *html)
{
    if (!html.length)
        return @"";

    NSString *clean = html;
    // Comments first: a commented-out script is still a script to a regex.
    NSRegularExpression *comments = [NSRegularExpression
        regularExpressionWithPattern:@"<!--[\\s\\S]*?-->" options:0
                               error:NULL];
    clean = [comments stringByReplacingMatchesInString:clean options:0
        range:NSMakeRange(0, clean.length) withTemplate:@""];

    for (NSString *tag in @[@"script", @"style", @"noscript", @"template",
                            @"svg", @"nav", @"header", @"footer", @"aside",
                            @"form", @"iframe"])
    {
        clean = MPHTMLWithoutElement(clean, tag);
    }

    // If the page says which part is the article, believe it.
    for (NSString *tag in @[@"article", @"main"])
    {
        NSString *inside = MPHTMLInsideElement(clean, tag);
        if (inside.length > 200)
            return inside;
    }
    NSString *body = MPHTMLInsideElement(clean, @"body");
    return body.length ? body : clean;
}


/// Whether an address already says where it starts from.
NS_INLINE BOOL MPHasItsOwnScheme(NSString *address)
{
    static NSRegularExpression *scheme = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        scheme = [NSRegularExpression regularExpressionWithPattern:
            @"^[a-zA-Z][a-zA-Z0-9+.-]*:" options:0 error:NULL];
    });
    return [scheme numberOfMatchesInString:address options:0
                                     range:NSMakeRange(0, address.length)] > 0;
}


NSString *MPHTMLWithAbsoluteAddresses(NSString *html, NSURL *base)
{
    if (!html.length || !base)
        return html ?: @"";

    static NSRegularExpression *addresses = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        addresses = [NSRegularExpression regularExpressionWithPattern:
            @"\\b(?:href|src)\\s*=\\s*([\"'])(.*?)\\1"
            options:NSRegularExpressionCaseInsensitive error:NULL];
    });

    NSMutableString *absolute = [html mutableCopy];
    NSArray *matches = [addresses matchesInString:html options:0
                                            range:NSMakeRange(0, html.length)];
    // Backwards, so that a replacement never moves the next match.
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator)
    {
        NSRange range = [match rangeAtIndex:2];
        NSString *address = [html substringWithRange:range];
        NSString *trimmed = [address stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // An anchor stays an anchor, and an address that already says where
        // it starts from is left exactly as the page wrote it.
        if (!trimmed.length || [trimmed hasPrefix:@"#"]
            || MPHasItsOwnScheme(trimmed))
            continue;

        NSURL *resolved = [NSURL URLWithString:trimmed relativeToURL:base];
        NSString *whole = resolved.absoluteURL.absoluteString;
        if (whole.length)
            [absolute replaceCharactersInRange:range withString:whole];
    }
    return absolute;
}


NSString *MPTitleOfHTML(NSString *html)
{
    NSString *title = MPHTMLInsideElement(html, @"title");
    if (!title.length)
        title = MPHTMLInsideElement(html, @"h1");
    if (!title.length)
        return nil;

    // Tags inside a heading, and the entities either brings with it.
    NSRegularExpression *tags = [NSRegularExpression
        regularExpressionWithPattern:@"<[^>]+>" options:0 error:NULL];
    title = [tags stringByReplacingMatchesInString:title options:0
        range:NSMakeRange(0, title.length) withTemplate:@""];
    title = MPStringByUnescapingHTMLEntities(title);

    // One line, whatever the source did with its whitespace.
    NSArray *words = [title componentsSeparatedByCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *kept = [NSMutableArray array];
    for (NSString *word in words)
    {
        if (word.length)
            [kept addObject:word];
    }
    title = [kept componentsJoinedByString:@" "];
    return title.length ? title : nil;
}


NSString *MPClippedMarkdown(NSString *html, NSURL *url, NSDate *when)
{
    NSString *body = [MPMarkdownFromRichText markdownFromHTML:
        MPHTMLWithAbsoluteAddresses(MPReadableHTMLFragment(html), url)];
    body = [body stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!body.length)
        return nil;

    NSString *title = MPTitleOfHTML(html) ?: url.host ?: @"Pagina";

    NSDateFormatter *day = [[NSDateFormatter alloc] init];
    day.dateFormat = @"yyyy-MM-dd HH:mm";
    day.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

    // Front matter, which this editor already reads, so the source survives
    // being pasted into another document — and a clipping without its
    // address and date is a quotation without a source.
    return [NSString stringWithFormat:
        @"---\ntitle: \"%@\"\nsource: %@\nclipped: %@\n---\n\n# %@\n\n%@\n",
        [title stringByReplacingOccurrencesOfString:@"\"" withString:@"'"],
        url.absoluteString ?: @"", [day stringFromDate:when ?: [NSDate date]],
        title, body];
}


/// A title turned into something that can be a file name, or nil.
static NSString *MPSlugOfTitle(NSString *name)
{
    NSMutableCharacterSet *allowed =
        [NSMutableCharacterSet alphanumericCharacterSet];
    // The full stop stays: a host is mostly full stops, and it is the name
    // a page with no title falls back to.
    [allowed addCharactersInString:@"-_. àèéìòùáíóúäöüçñ"];

    NSMutableString *slug = [NSMutableString string];
    for (NSUInteger i = 0; i < name.length && slug.length < 60; i++)
    {
        unichar c = [name characterAtIndex:i];
        [slug appendString:[allowed characterIsMember:c]
            ? [NSString stringWithCharacters:&c length:1] : @"-"];
    }
    // Nothing leading that would make it a hidden file, or a path.
    NSString *trimmed = [slug stringByTrimmingCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@" -."]];
    trimmed = [trimmed stringByReplacingOccurrencesOfString:@".."
                                                 withString:@"."];
    return trimmed.length ? trimmed : nil;
}

NSString *MPFileNameForClipping(NSString *title, NSURL *url)
{
    // The title, then what the page is called by its address, then a word
    // rather than nothing. A title of punctuation slugs to nothing, which
    // is the same as having none.
    NSString *name = MPSlugOfTitle(title ?: @"")
        ?: MPSlugOfTitle(url.host ?: @"")
        ?: @"pagina";
    return [name stringByAppendingPathExtension:@"md"];
}


@implementation MPWebClipper

+ (void)clipURL:(NSURL *)url
     completion:(void (^)(NSString *, NSString *, NSError *))done
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 30.0;
    // Said plainly rather than pretending to be a browser: a page that
    // refuses this is a page that has decided not to be clipped.
    [request setValue:@"MacDown Next (web clipping)"
        forHTTPHeaderField:@"User-Agent"];

    void (^answer)(NSString *, NSString *, NSError *) =
        ^(NSString *markdown, NSString *title, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done(markdown, title, error);
        });
    };

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request completionHandler:
        ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error)
        {
            answer(nil, nil, error);
            return;
        }
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (status != 200)
        {
            answer(nil, nil, [NSError errorWithDomain:NSURLErrorDomain
                code:NSURLErrorBadServerResponse userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    NSLocalizedString(@"The server answered %ld.",
                                      @"Web clipping"), (long)status]}]);
            return;
        }
        if (data.length > kMPClipSizeLimit)
        {
            answer(nil, nil, [NSError errorWithDomain:NSURLErrorDomain
                code:NSURLErrorDataLengthExceedsMaximum userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(
                    @"The page is too big to be an article.",
                    @"Web clipping")}]);
            return;
        }

        // The charset the response declares, and UTF-8 when it declares
        // nothing — which is what a page written this decade will be.
        NSStringEncoding encoding = NSUTF8StringEncoding;
        if (response.textEncodingName)
        {
            CFStringEncoding named = CFStringConvertIANACharSetNameToEncoding(
                (__bridge CFStringRef)response.textEncodingName);
            if (named != kCFStringEncodingInvalidId)
                encoding = CFStringConvertEncodingToNSStringEncoding(named);
        }
        NSString *html = [[NSString alloc] initWithData:data
                                               encoding:encoding];
        if (!html.length && encoding != NSUTF8StringEncoding)
        {
            html = [[NSString alloc] initWithData:data
                                         encoding:NSUTF8StringEncoding];
        }
        if (!html.length)
        {
            answer(nil, nil, [NSError errorWithDomain:NSURLErrorDomain
                code:NSURLErrorCannotDecodeContentData userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(
                    @"The page could not be read as text.",
                    @"Web clipping")}]);
            return;
        }

        NSURL *final = response.URL ?: url;
        NSString *markdown = MPClippedMarkdown(html, final, [NSDate date]);
        if (!markdown)
        {
            answer(nil, nil, [NSError errorWithDomain:NSURLErrorDomain
                code:NSURLErrorZeroByteResource userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(
                    @"There was no text in the page worth keeping.",
                    @"Web clipping")}]);
            return;
        }
        answer(markdown, MPTitleOfHTML(html), nil);
    }];
    [task resume];
}

@end
