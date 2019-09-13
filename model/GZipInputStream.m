//
//  ZLibMMcG.m
//  Strongbox
//
//  Created by Mark on 07/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "GZipInputStream.h"
#import <zlib.h>

@interface GZipInputStream ()

@property NSData* source;
@property z_stream* stream;
@property BOOL done;

@end

@implementation GZipInputStream

- (instancetype)initWithData:(NSData *)data {
    self = [super initWithData:data];
    if (self) {
        if (!data || data.length == 0 || !isGzippedData(data)) {
            NSLog(@"Data empty or not GZIPed");
            return nil;
        }
        
        self.source = data;
        self.stream = malloc(sizeof(z_stream));
        if (self.stream == NULL) {
            return nil;
        }
        memset(self.stream, 0, sizeof(z_stream));
        
        self.stream->zalloc = Z_NULL;
        self.stream->zfree = Z_NULL;
        self.stream->avail_in = (uint)self.source.length;
        self.stream->next_in = (Bytef *)self.source.bytes;
        self.stream->total_out = 0;
        self.stream->avail_out = 0;
        
        if (inflateInit2(self.stream, 47) != Z_OK) {
            NSLog(@"Error initializing z_stream");
            free(self.stream);
            self.stream = nil;
            return nil;
        }
    }

    return self;
}

- (void)open { }

- (void)close {
    self.source = nil;
    if (self.stream) {
        free(self.stream);
        self.stream = nil;
    }
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if(self.done) {
        return 0;
    }
    
    self.stream->next_out = buffer;
    self.stream->avail_out = (uInt)len;
    
    int status = inflate (self.stream, Z_SYNC_FLUSH);
    
    if(status == Z_OK || status == Z_STREAM_END) {
        NSUInteger read = len - self.stream->avail_out;
        
        if(status == Z_STREAM_END) {
            if (inflateEnd(self.stream) == Z_OK) {
                self.done = YES;
                self.source = nil;
                if (self.stream) {
                    free(self.stream);
                    self.stream = nil;
                }
            }
            else {
                NSLog(@"ERROR inflateEnd GZIP! %d", status);
            }
        }

        return read;
    }
    else {
        NSLog(@"ERROR Reading GZIP! %d", status);
    }
    
    return 0;
}

BOOL isGzippedData(NSData* data) {
    const UInt8 *bytes = (const UInt8 *)data.bytes;
    return (data.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b);
}

@end
