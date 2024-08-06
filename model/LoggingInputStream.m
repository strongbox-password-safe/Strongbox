//
//  LoggingInputStream.m
//  Strongbox
//
//  Created by Strongbox on 31/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "LoggingInputStream.h"

@interface LoggingInputStream ()

@property NSInputStream* inner;
@property NSInteger readCount;
@end

@implementation LoggingInputStream

- (instancetype)initWithStream:(NSInputStream *)stream {
    self = [super init];
    if (self) {
        self.inner = stream;
    }
    return self;
}

- (void)open {
    slog(@"Open");

    [self.inner open];
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    NSInteger ret = [self.inner read:buffer maxLength:len];
    
    if (ret > 0) {
        self.readCount += ret;
    }
    
    slog(@"Read with Max Length %lu - read %ld - totalRead = [%ld]", (unsigned long)len, (long)ret, (long)self.readCount);
    
    return ret;
}

- (BOOL)hasBytesAvailable {
    slog(@"Has Bytes Available");

    return self.inner.hasBytesAvailable;
}

- (void)close {
    slog(@"Close");

    [self.inner close];
}

@end
