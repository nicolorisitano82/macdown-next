//
//  MDDrawioFile.m
//  MacDown Next — draw.io plug-in
//

#import "MDDrawioFile.h"
#import "MDDrawioStrings.h"
#import <zlib.h>

NSString * const MDDrawioErrorDomain = @"MDDrawioErrorDomain";


@implementation MDDrawioPage

- (instancetype)initWithName:(NSString *)name xml:(NSString *)xml
{
    self = [super init];
    if (!self)
        return nil;
    _name = [name copy] ?: @"";
    _xml = [xml copy];
    return self;
}

@end


NSData *MDDrawioInflate(NSData *data, BOOL raw)
{
    if (!data.length)
        return nil;

    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    // Negative window bits: no header and no checksum to look for, which
    // is how `pako.deflateRaw` leaves a page of a diagram. Plus 32: read
    // whichever header is there, gzip or zlib.
    int window = raw ? -MAX_WBITS : (MAX_WBITS + 32);
    if (inflateInit2(&stream, window) != Z_OK)
        return nil;

    stream.next_in = (Bytef *)data.bytes;
    stream.avail_in = (uInt)data.length;

    NSMutableData *out = [NSMutableData data];
    unsigned char buffer[16384];
    int status = Z_OK;
    do {
        stream.next_out = buffer;
        stream.avail_out = sizeof(buffer);
        status = inflate(&stream, Z_NO_FLUSH);
        if (status != Z_OK && status != Z_STREAM_END)
        {
            inflateEnd(&stream);
            return nil;
        }
        [out appendBytes:buffer length:sizeof(buffer) - stream.avail_out];
    } while (status != Z_STREAM_END);

    inflateEnd(&stream);
    return out.length ? out : nil;
}


NSString *MDDrawioXMLFromCompactPayload(NSString *payload)
{
    NSString *trimmed = [payload stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length)
        return nil;

    NSData *deflated = [[NSData alloc] initWithBase64EncodedString:trimmed
        options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *raw = MDDrawioInflate(deflated, YES);
    if (!raw)
        return nil;

    NSString *escaped = [[NSString alloc] initWithData:raw
                                             encoding:NSUTF8StringEncoding];
    NSString *xml = escaped.stringByRemovingPercentEncoding ?: escaped;

    // The point of every step above was to arrive at a model. If it is not
    // one, one of the guesses was wrong and saying so beats handing the
    // viewer rubbish.
    if (![xml containsString:@"<mxGraphModel"])
        return nil;
    return xml;
}


NSString *MDDrawioXMLFromPNG(NSData *png)
{
    static const unsigned char signature[8] =
        {0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a};
    if (png.length < sizeof(signature)
            || memcmp(png.bytes, signature, sizeof(signature)) != 0)
        return nil;

    const unsigned char *bytes = png.bytes;
    NSUInteger at = sizeof(signature);

    // Walk the chunks looking for the one draw.io writes. Everything in a
    // PNG after the signature is length, type, data, checksum.
    while (at + 12 <= png.length)
    {
        uint32_t length = ((uint32_t)bytes[at] << 24)
            | ((uint32_t)bytes[at + 1] << 16)
            | ((uint32_t)bytes[at + 2] << 8) | (uint32_t)bytes[at + 3];
        NSString *type = [[NSString alloc]
            initWithBytes:bytes + at + 4 length:4
                 encoding:NSASCIIStringEncoding];
        NSUInteger dataAt = at + 8;
        if (dataAt + length + 4 > png.length)
            return nil;

        if ([type isEqualToString:@"tEXt"] || [type isEqualToString:@"zTXt"])
        {
            NSData *chunk = [NSData dataWithBytes:bytes + dataAt
                                           length:length];
            // Keyword, a zero, then the value.
            NSUInteger split = length;
            for (NSUInteger i = 0; i < length; i++)
            {
                if (((const unsigned char *)chunk.bytes)[i] == 0)
                {
                    split = i;
                    break;
                }
            }
            NSString *keyword = [[NSString alloc]
                initWithBytes:chunk.bytes length:split
                     encoding:NSASCIIStringEncoding];
            if ([keyword isEqualToString:@"mxfile"] && split < length)
            {
                NSUInteger from = split + 1;
                // A compressed text chunk states its method in one byte
                // and then holds zlib data, which is not what tEXt does.
                if ([type isEqualToString:@"zTXt"])
                    from += 1;
                NSData *value = [chunk subdataWithRange:
                    NSMakeRange(from, length - from)];
                NSString *escaped = [[NSString alloc] initWithData:value
                    encoding:NSUTF8StringEncoding];
                if (!escaped.length)
                    return nil;
                return escaped.stringByRemovingPercentEncoding ?: escaped;
            }
        }

        if ([type isEqualToString:@"IDAT"] || [type isEqualToString:@"IEND"])
            return nil;   // the text draw.io writes comes before the pixels
        at = dataAt + length + 4;
    }
    return nil;
}


@implementation MDDrawioFile

+ (instancetype)fileWithURL:(NSURL *)url error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data.length)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:MDDrawioErrorDomain
                code:MDDrawioErrorNotADiagram userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    MDLocalizedString(@"%@ could not be read.",
                                      @"Drawio plug-in"),
                    url.lastPathComponent]}];
        }
        return nil;
    }
    return [self fileWithData:data error:error];
}

+ (instancetype)fileWithData:(NSData *)data error:(NSError **)error
{
    NSString *text = MDDrawioXMLFromPNG(data);
    if (!text)
    {
        text = [[NSString alloc] initWithData:data
                                     encoding:NSUTF8StringEncoding];
    }
    if (!text.length)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:MDDrawioErrorDomain
                code:MDDrawioErrorNotADiagram userInfo:@{
                NSLocalizedDescriptionKey: MDLocalizedString(
                    @"The file is not a draw.io diagram: it is neither XML "
                    @"nor a PNG carrying one inside.", @"Drawio plug-in")}];
        }
        return nil;
    }

    NSError *parseError = nil;
    NSXMLDocument *document = [[NSXMLDocument alloc]
        initWithXMLString:text options:NSXMLDocumentTidyXML
                    error:&parseError];
    NSXMLElement *root = document.rootElement;
    if (!root)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:MDDrawioErrorDomain
                code:MDDrawioErrorNotADiagram userInfo:@{
                NSLocalizedDescriptionKey: MDLocalizedString(
                    @"The file could not be read as XML.",
                    @"Drawio plug-in"),
                NSUnderlyingErrorKey: parseError ?: [NSNull null]}];
        }
        return nil;
    }

    // An "editable SVG" is a picture with the whole file hidden in an
    // attribute, which is the same trick as the PNG one level up.
    if ([root.name isEqualToString:@"svg"])
    {
        NSString *inside =
            [root attributeForName:@"content"].stringValue;
        NSData *carried = [inside dataUsingEncoding:NSUTF8StringEncoding];
        if (carried.length)
            return [self fileWithData:carried error:error];
    }

    NSMutableArray *pages = [NSMutableArray array];

    // A model on its own is a one-page file. draw.io writes this when a
    // diagram is exported rather than saved.
    if ([root.name isEqualToString:@"mxGraphModel"])
    {
        [pages addObject:[[MDDrawioPage alloc] initWithName:@""
                                                        xml:root.XMLString]];
    }
    else
    {
        for (NSXMLElement *diagram in [root elementsForName:@"diagram"])
        {
            NSString *name =
                [diagram attributeForName:@"name"].stringValue ?: @"";
            NSString *inside = [diagram.stringValue
                stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];

            NSString *xml = nil;
            NSArray *models = [diagram elementsForName:@"mxGraphModel"];
            if (models.count)
                xml = ((NSXMLElement *)models.firstObject).XMLString;
            else
                xml = MDDrawioXMLFromCompactPayload(inside);

            if (!xml)
                continue;   // reported below, by what is missing
            [pages addObject:[[MDDrawioPage alloc] initWithName:name
                                                            xml:xml]];
        }
    }

    if (!pages.count)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:MDDrawioErrorDomain
                code:MDDrawioErrorNoPages userInfo:@{
                NSLocalizedDescriptionKey: MDLocalizedString(
                    @"There is no readable page in the file.",
                    @"Drawio plug-in")}];
        }
        return nil;
    }

    MDDrawioFile *file = [[self alloc] init];
    file->_pages = [pages copy];
    return file;
}

@end
