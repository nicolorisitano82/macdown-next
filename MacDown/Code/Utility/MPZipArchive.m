//
//  MPZipArchive.m
//  MacDown
//

#import "MPZipArchive.h"
#import <compression.h>


#pragma mark - CRC32

static uint32_t MPCRC32(NSData *data)
{
    static uint32_t table[256];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for (uint32_t i = 0; i < 256; i++)
        {
            uint32_t c = i;
            for (int k = 0; k < 8; k++)
                c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
            table[i] = c;
        }
    });

    uint32_t crc = 0xFFFFFFFFu;
    const uint8_t *bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++)
        crc = table[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
    return crc ^ 0xFFFFFFFFu;
}

#pragma mark - Little-endian access

NS_INLINE uint16_t MPRead16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
NS_INLINE uint32_t MPRead32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8)
         | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
NS_INLINE void MPAppend16(NSMutableData *d, uint16_t v) {
    uint8_t b[2] = {(uint8_t)(v & 0xFF), (uint8_t)(v >> 8)};
    [d appendBytes:b length:2];
}
NS_INLINE void MPAppend32(NSMutableData *d, uint32_t v) {
    uint8_t b[4] = {(uint8_t)(v & 0xFF), (uint8_t)((v >> 8) & 0xFF),
                    (uint8_t)((v >> 16) & 0xFF), (uint8_t)((v >> 24) & 0xFF)};
    [d appendBytes:b length:4];
}

#pragma mark - Entries

@implementation MPZipEntry
@end

/// Reads the central directory. Sizes and CRCs come from there rather than
/// from the local headers, which may defer them to a data descriptor.
NSArray<MPZipEntry *> *MPZipRead(NSData *zip)
{
    const uint8_t *base = zip.bytes;
    NSUInteger length = zip.length;
    if (length < 22)
        return nil;

    // End of central directory, scanning back past any trailing comment.
    NSInteger eocd = -1;
    NSUInteger lowest = length > 65557 ? length - 65557 : 0;
    for (NSInteger i = (NSInteger)length - 22; i >= (NSInteger)lowest; i--)
    {
        if (MPRead32(base + i) == 0x06054b50) { eocd = i; break; }
    }
    if (eocd < 0)
        return nil;

    uint16_t count = MPRead16(base + eocd + 10);
    uint32_t cdOffset = MPRead32(base + eocd + 16);

    NSMutableArray<MPZipEntry *> *entries = [NSMutableArray array];
    NSUInteger p = cdOffset;
    for (uint16_t i = 0; i < count; i++)
    {
        if (p + 46 > length || MPRead32(base + p) != 0x02014b50)
            return nil;
        uint16_t method = MPRead16(base + p + 10);
        uint32_t crc = MPRead32(base + p + 16);
        uint32_t csize = MPRead32(base + p + 20);
        uint32_t usize = MPRead32(base + p + 24);
        uint16_t nameLen = MPRead16(base + p + 28);
        uint16_t extraLen = MPRead16(base + p + 30);
        uint16_t commentLen = MPRead16(base + p + 32);
        uint32_t localOffset = MPRead32(base + p + 42);

        NSString *name = [[NSString alloc]
            initWithBytes:base + p + 46 length:nameLen
                 encoding:NSUTF8StringEncoding];

        // Local header, to find where the payload actually starts.
        if (localOffset + 30 > length
            || MPRead32(base + localOffset) != 0x04034b50)
            return nil;
        uint16_t localNameLen = MPRead16(base + localOffset + 26);
        uint16_t localExtraLen = MPRead16(base + localOffset + 28);
        NSUInteger dataStart = localOffset + 30 + localNameLen + localExtraLen;
        if (dataStart + csize > length)
            return nil;

        MPZipEntry *entry = [MPZipEntry new];
        entry.name = name;
        entry.method = method;
        entry.crc = crc;
        entry.uncompressedSize = usize;
        entry.payload = [zip subdataWithRange:NSMakeRange(dataStart, csize)];
        [entries addObject:entry];

        p += 46 + nameLen + extraLen + commentLen;
    }
    return entries;
}

/// Raw DEFLATE, which is what zip method 8 holds.
static NSData *MPInflate(NSData *deflated, uint32_t expectedSize)
{
    if (!expectedSize)
        return [NSData data];
    NSMutableData *out = [NSMutableData dataWithLength:expectedSize];
    size_t written = compression_decode_buffer(
        out.mutableBytes, expectedSize,
        deflated.bytes, deflated.length, NULL, COMPRESSION_ZLIB);
    if (written != expectedSize)
        return nil;
    return out;
}

/// Writes entries back out. Anything rebuilt is stored uncompressed, which a
/// zip reader handles the same as deflated and spares us an encoder.
NSData *MPZipWrite(NSArray<MPZipEntry *> *entries)
{
    NSMutableData *out = [NSMutableData data];
    NSMutableArray<NSNumber *> *offsets = [NSMutableArray array];

    for (MPZipEntry *e in entries)
    {
        [offsets addObject:@(out.length)];
        NSData *nameData = [e.name dataUsingEncoding:NSUTF8StringEncoding];
        MPAppend32(out, 0x04034b50);
        MPAppend16(out, 20);            // version needed
        MPAppend16(out, 0);             // flags
        MPAppend16(out, e.method);
        MPAppend16(out, 0);             // time
        MPAppend16(out, 0x21);          // date: 1980-01-01
        MPAppend32(out, e.crc);
        MPAppend32(out, (uint32_t)e.payload.length);
        MPAppend32(out, e.uncompressedSize);
        MPAppend16(out, (uint16_t)nameData.length);
        MPAppend16(out, 0);             // extra
        [out appendData:nameData];
        [out appendData:e.payload];
    }

    NSUInteger cdStart = out.length;
    NSUInteger i = 0;
    for (MPZipEntry *e in entries)
    {
        NSData *nameData = [e.name dataUsingEncoding:NSUTF8StringEncoding];
        MPAppend32(out, 0x02014b50);
        MPAppend16(out, 20);            // version made by
        MPAppend16(out, 20);            // version needed
        MPAppend16(out, 0);             // flags
        MPAppend16(out, e.method);
        MPAppend16(out, 0);
        MPAppend16(out, 0x21);
        MPAppend32(out, e.crc);
        MPAppend32(out, (uint32_t)e.payload.length);
        MPAppend32(out, e.uncompressedSize);
        MPAppend16(out, (uint16_t)nameData.length);
        MPAppend16(out, 0);             // extra
        MPAppend16(out, 0);             // comment
        MPAppend16(out, 0);             // disk
        MPAppend16(out, 0);             // internal attrs
        MPAppend32(out, 0);             // external attrs
        MPAppend32(out, (uint32_t)offsets[i++].unsignedLongLongValue);
        [out appendData:nameData];
    }

    // Measured before the record itself is appended, or it counts its own
    // bytes as part of the directory.
    NSUInteger cdSize = out.length - cdStart;

    MPAppend32(out, 0x06054b50);
    MPAppend16(out, 0);
    MPAppend16(out, 0);
    MPAppend16(out, (uint16_t)entries.count);
    MPAppend16(out, (uint16_t)entries.count);
    MPAppend32(out, (uint32_t)cdSize);
    MPAppend32(out, (uint32_t)cdStart);
    MPAppend16(out, 0);
    return out;
}

NSData *MPDataFromEntry(MPZipEntry *entry)
{
    if (!entry)
        return nil;
    return entry.method == 8
        ? MPInflate(entry.payload, entry.uncompressedSize)
        : entry.payload;
}

NSString *MPStringFromEntry(NSArray<MPZipEntry *> *entries,
                                   NSString *name)
{
    for (MPZipEntry *e in entries)
    {
        if (![e.name isEqualToString:name])
            continue;
        NSData *raw = MPDataFromEntry(e);
        if (!raw)
            return nil;
        return [[NSString alloc] initWithData:raw
                                     encoding:NSUTF8StringEncoding];
    }
    return nil;
}

MPZipEntry *MPStoredEntry(NSString *name, NSData *data)
{
    MPZipEntry *e = [MPZipEntry new];
    e.name = name;
    e.method = 0;
    e.crc = MPCRC32(data);
    e.payload = data;
    e.uncompressedSize = (uint32_t)data.length;
    return e;
}
