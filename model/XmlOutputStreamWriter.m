//
//  XmlOutputStreamWriter.m
//  Strongbox
//
//  Created by Strongbox on 14/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "XmlOutputStreamWriter.h"
#import "Utils.h"

@interface XmlOutputStreamWriter ()

@property NSOutputStream* outputStream;
@property NSError* error;

@end

@implementation XmlOutputStreamWriter

- (instancetype)initWithOutputStream:(NSOutputStream *)outputStream {
    self = [super init];
    
    if (self) {
        self.outputStream = outputStream;
    }
    
    return self;
}

- (void)write:(NSString *)value {
    NSInteger wrote;
    
    @autoreleasepool {
        NSData* utf8 = [value dataUsingEncoding:NSUTF8StringEncoding];
        wrote = [self.outputStream write:utf8.bytes maxLength:utf8.length];
    }
    
    
    















    
    if ( wrote < 0 ) {
        slog(@"WARNWARN: Could not write XML data to output stream...");
        self.error = self.outputStream.streamError ? self.outputStream.streamError : [Utils createNSError:@"There was an error writing to output stream from XmlOutputStreamWriter." errorCode:-1];
    }
}

- (NSError *)streamError {
    return self.error;
}

@end
