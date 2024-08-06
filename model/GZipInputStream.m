//
//  ZLibMMcG.m
//  Strongbox
//
//  Created by Mark on 07/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "GZipInputStream.h"
#import <zlib.h>
#import "DatabaseModel.h"
#import "Utils.h"
#import "Constants.h"

@interface GZipInputStream ()

@property z_stream* stream;
@property BOOL done;

@property NSData* innerData;

@property NSInputStream* innerStream;

@property uint8_t *workingData;
@property size_t workingDataLength;

@property size_t debugDecompresedTotal;

@property NSError* error;

@end

@implementation GZipInputStream

- (instancetype)initWithStream:(NSInputStream *)innerStream {
    if (self = [super init]) {
        if (!innerStream) {
            slog(@"Inner Stream NIL");
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
        
        self.innerStream = innerStream;
    }
    
    return self;
}

- (instancetype)initWithData:(NSData *)data {
    if (self = [super init]) {
        if (!data || data.length == 0 || !isGzippedData(data)) {
            slog(@"Data empty or not GZIPed");
            return nil;
        }
        
        self.stream = malloc(sizeof(z_stream));
        if (self.stream == NULL) {
            return nil;
        }
        memset(self.stream, 0, sizeof(z_stream));
        
        self.stream->zalloc = Z_NULL;
        self.stream->zfree = Z_NULL;
        self.stream->avail_in = (uInt)data.length;
        self.stream->next_in = (uint8_t*)data.bytes;
        self.stream->total_out = 0;
        self.stream->avail_out = 0;
        
        if (inflateInit2(self.stream, 47) != Z_OK) {
            slog(@"Error initializing z_stream");
            free(self.stream);
            self.stream = nil;
            return nil;
        }
        
        self.innerData = data;
    }
    
    return self;
}



- (void)open {
    if (self.innerStream) {
        [self.innerStream open];
    }
}

- (void)close {
    if (self.innerStream) {
        [self.innerStream close];
        self.innerStream = nil;
    }
    
    self.innerData = nil;
    
    if (self.stream) {
        free(self.stream);
        self.stream = nil;
    }
    
    if (self.workingData) {
        free(self.workingData);
    }
    self.workingData = nil;
}

- (void)fillWorkingBuffer {
    if (self.workingData == nil) {
        self.workingData = malloc(kStreamingSerializationChunkSize);
    }
    
    NSInteger read = [self.innerStream read:self.workingData maxLength:kStreamingSerializationChunkSize];
    
    if (read < 0) {
        self.error = self.innerStream.streamError;
        free(self.workingData);
        self.workingData = nil;
    }
    
    self.workingDataLength = read;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if(self.done) {
        return 0;
    }

    NSInteger ret = 0;
    if (self.innerData) {
        ret = [self readFromData:buffer maxLength:len];
    }
    else {
        ret = [self readFromStream:buffer maxLength:len];
    }
    
    self.debugDecompresedTotal += ret;
    
    
    
    return ret;
}

- (NSInteger)readFromStream:(uint8_t *)buffer maxLength:(NSUInteger)len {
    self.stream->next_out = buffer;
    self.stream->avail_out = (uInt)len;
    
    int status;
    do {
        if (self.stream->avail_in == 0) {
            [self fillWorkingBuffer];
            if (self.workingData == nil) {
                self.error = self.error ? self.error : [Utils createNSError:@"Could not read enough data into Working Data from input stream." errorCode:-1];
                return -1;
            }
            
            self.stream->avail_in = (uInt)self.workingDataLength;
            self.stream->next_in = (uint8_t*)self.workingData;
            if (self.stream-> avail_in == 0) {
                status = Z_STREAM_END;
                break;
            }
        }
        
        status = inflate (self.stream, Z_SYNC_FLUSH);
    } while (status == Z_OK && self.stream->avail_out > 0);
    
    NSUInteger read = len - self.stream->avail_out;
    
    if(status == Z_STREAM_END) {
        if (inflateEnd(self.stream) == Z_OK) {
            self.done = YES;

            if ( self.stream ) {
                free(self.stream);
                self.stream = nil;
            }
            
            if (self.workingData) {
                free(self.workingData);
                self.workingData = nil;
            }
        }
        else {
            slog(@"ERROR inflateEnd GZIP! %d", status);
            self.error = [Utils createNSError:@"ERROR inflateEnd GZIP!." errorCode:status];
            return -1;
        }
    }
    else if (status != Z_OK) {
        slog(@"ERROR Reading GZIP! %d", status);
        self.error = [Utils createNSError:@"ERROR Reading GZIP!." errorCode:status];
        return -1;
    }
    
    return read;
}

- (NSInteger)readFromData:(uint8_t *)buffer maxLength:(NSUInteger)len {
    self.stream->next_out = buffer;
    self.stream->avail_out = (uInt)len;
    
    int status = inflate (self.stream, Z_SYNC_FLUSH);
    
    if(status == Z_OK || status == Z_STREAM_END) {
        NSUInteger read = len - self.stream->avail_out;
        
        if(status == Z_STREAM_END) {
            if (inflateEnd(self.stream) == Z_OK) {
                self.done = YES;
                self.innerData = nil;
                if (self.stream) {
                    free(self.stream);
                    self.stream = nil;
                }
            }
            else {
                slog(@"ERROR inflateEnd GZIP! %d", status);
                return -1;
            }
        }

        return read;
    }
    else {
        slog(@"ERROR Reading GZIP! %d", status);
        return -1;
    }
    
    return 0;
}

BOOL isGzippedData(NSData* data) {
    const UInt8 *bytes = (const UInt8 *)data.bytes;
    return (data.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b);
}

- (NSError *)streamError {
    return self.innerStream.streamError ? self.innerStream.streamError : self.error;
}

@end
