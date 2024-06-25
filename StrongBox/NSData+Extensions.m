//
//  NSData__Extensions.m
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NSData+Extensions.h"
#import <CommonCrypto/CommonCrypto.h>
#import "StreamUtils.h"

@implementation NSData (Extensions)

+ (instancetype)dataWithContentsOfStream:(NSInputStream*)inputStream {
    NSOutputStream* outputStream = [NSOutputStream outputStreamToMemory];
    
    if (![StreamUtils pipeFromStream:inputStream to:outputStream] ) {
        return nil;
    }
    
    return [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
}

- (NSData *)sha1 {
    uint8_t digest[CC_SHA1_DIGEST_LENGTH] = { 0 };
    
    CC_SHA1(self.bytes, (CC_LONG)self.length, digest);
    
    return [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

- (NSData *)sha256 {
    uint8_t digest[CC_SHA256_DIGEST_LENGTH] = { 0 };
    
    CC_SHA256(self.bytes, (CC_LONG)self.length, digest);
    
    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

- (NSString *)upperHexString {
    const unsigned char *dataBuffer = (const unsigned char *)self.bytes;
    
    if (!dataBuffer) {
        return [NSString string];
    }
    
    NSUInteger dataLength = self.length;
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lX", (unsigned long)dataBuffer[i]]];
    }
    
    NSString* ret = hexString.uppercaseString;
    
    return ret; 
}

- (NSString *)base64String {
    return [self base64EncodedStringWithOptions:kNilOptions];
}

@end
