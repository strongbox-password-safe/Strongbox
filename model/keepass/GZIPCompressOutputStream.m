//
//  GZIPCompressOutputStream.m
//  Strongbox
//
//  Created by Strongbox on 07/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "GZIPCompressOutputStream.h"
#import <zlib.h>
#import "Utils.h"

@interface GZIPCompressOutputStream ()

@property NSOutputStream* outputStream;
@property z_stream* stream;
@property NSError* error;

@property BOOL closed;
@property BOOL opened;

@end

const int kChunkSize = 32 * 1024;

@implementation GZIPCompressOutputStream

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
        self.stream->opaque = Z_NULL;
        self.stream->avail_in = (uInt)0;
        self.stream->next_in = (uint8_t*)nil;
        self.stream->total_out = 0;
        self.stream->avail_out = 0;

        if (deflateInit2(self.stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) != Z_OK) {
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
    if ( self.opened ){
        return;
    }
    self.opened = YES;
}

- (void)close {
    if ( self.closed ) {
        return;
    }
    self.closed = YES;
    
    uint8_t finalBlock[kChunkSize]; 

    do {
        self.stream->next_out = finalBlock;
        self.stream->avail_out = (uInt)kChunkSize;
        
        int status = deflate(self.stream, Z_FINISH);
        if (status != Z_OK && status != Z_STREAM_END ) {
            slog(@"Error: %d", status);
            self.error = [Utils createNSError:[NSString stringWithFormat:@"ERROR deflateEnd Error: %d GZIP!", status] errorCode:status];
            return;
        }
        
        size_t writtenThisTime = kChunkSize - self.stream->avail_out;



        if ( writtenThisTime > 0 ) {
            NSInteger res = [self.outputStream write:finalBlock maxLength:writtenThisTime];
            if ( res < 0 ) {
                slog(@"GZIPCompressOutputStream: Could not write to output stream.");
                return;
            }
        }
    } while ( self.stream->avail_out == 0 );
    
    int status;
    if ( (status = deflateEnd(self.stream)) != Z_OK ) {
        slog(@"ERROR deflateEnd GZIP! %d", status);
        self.error = [Utils createNSError:@"ERROR deflateEnd GZIP!." errorCode:status];
    }
    
    if (self.stream) {
        free(self.stream);
        self.stream = nil;
    }
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    self.stream->avail_in = (uInt)len;
    self.stream->next_in = (uint8_t*)buffer;

    size_t totalWritten = 0;

    uint8_t compressed[kChunkSize];
    
    while ( self.stream->avail_in > 0 ) {
        self.stream->next_out = compressed;
        self.stream->avail_out = (uInt)kChunkSize;
        
        int status = deflate(self.stream, Z_NO_FLUSH);

        if (status != Z_OK) {
            slog(@"Error: %d", status);
            self.error = [Utils createNSError:[NSString stringWithFormat:@"ERROR deflateEnd Error: %d GZIP!", status] errorCode:status];
            return -1;
        }
        
        size_t writtenThisTime = kChunkSize - self.stream->avail_out;



        if ( writtenThisTime > 0 ) {
            NSInteger res = [self.outputStream write:compressed maxLength:writtenThisTime];
            if ( res < 0 ) {
                slog(@"GZIPCompressOutputStream: Could not write to output stream.");
                return res;
            }
        }
        
        totalWritten += writtenThisTime;
    }
    
    return totalWritten;
}

- (NSError *)streamError {
    return self.error ? self.error : self.outputStream.streamError;
}

@end
