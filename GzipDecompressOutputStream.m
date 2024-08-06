//
//  GzipDecompressOutputStream.m
//  Strongbox
//
//  Created by Strongbox on 26/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "GzipDecompressOutputStream.h"
#import <zlib.h>
#import "Utils.h"

@interface GzipDecompressOutputStream ()

@property NSOutputStream* outputStream;
@property z_stream* stream;
@property NSError* error;

@end

@implementation GzipDecompressOutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream {
    if (self = [super init]) {
        if (outputStream == nil) {
            return nil;
        }
        
        self.stream = malloc(sizeof(z_stream));
        if (self.stream == NULL) {
            return nil;
        }
        memset(self.stream, 0, sizeof(z_stream));

        self.stream->zalloc = Z_NULL;
        self.stream->zfree = Z_NULL;
        self.stream->avail_in = (uInt)0;
        self.stream->next_in = (uint8_t*)nil;
        self.stream->total_out = 0;
        self.stream->avail_out = 0;

        if (inflateInit2(self.stream, 47) != Z_OK) {
            slog(@"Error initializing z_stream");
            free(self.stream);
            self.stream = nil;
            return nil;
        }

        self.outputStream = outputStream;
    }
    
    return self;
}

- (void)open {
    if (self.outputStream) {
        [self.outputStream open];
    }
}

- (void)close {
    if (self.outputStream) {
        [self.outputStream close];
        self.outputStream = nil;
    }
    
    if (self.stream) {
        free(self.stream);
        self.stream = nil;
    }
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    self.stream->avail_in = (uInt)len;
    self.stream->next_in = (uint8_t*)buffer;

    uInt remainingIn = self.stream->avail_in;
    size_t totalWritten = 0;

    uint8_t* decompressed = malloc(len);

    while (remainingIn > 0) {
        self.stream->next_out = decompressed;
        self.stream->avail_out = (uInt)len;
        
        int status = inflate (self.stream, Z_SYNC_FLUSH);

        if(status == Z_STREAM_END) {
            if (inflateEnd(self.stream) != Z_OK) {
                slog(@"ERROR inflateEnd GZIP! %d", status);
                self.error = [Utils createNSError:@"ERROR inflateEnd GZIP!." errorCode:status];
                free(decompressed);
                return -1;
            }
        }
        else if (status != Z_OK) {
            slog(@"Error: %d", status);
            self.error = [Utils createNSError:[NSString stringWithFormat:@"ERROR Error: %d GZIP!", status] errorCode:status];
            free(decompressed);
            return -1;
        }
        
        size_t writtenThisTime = len - self.stream->avail_out;
        
        if ( writtenThisTime > 0 ) {
            NSInteger res = [self.outputStream write:decompressed maxLength:writtenThisTime];
            if ( res < 0 ) {
                slog(@"GzipDecompressOutputStream: Could not write to output stream.");
                return res;
            } 
        }
        

        totalWritten += writtenThisTime;
        


        remainingIn = self.stream->avail_in;
    }
    
    free(decompressed);
    return totalWritten;
}

- (NSError *)streamError {
    return self.error ? self.error : self.outputStream.streamError;
}

@end
