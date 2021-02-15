//
//  SerializationData.m
//  StrongboxTests
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SerializationData.h"

@implementation SerializationData

-(NSString *)description {
    NSString* base64ProtectedStreamKey = [self.protectedStreamKey base64EncodedStringWithOptions:kNilOptions];
    return [NSString stringWithFormat:@"transformRounds = %llu, compressionFlags = %d, innerRandomStreamId = %d, protectedStreamKey(base64)=%@",
            self.transformRounds, self.compressionFlags, self.innerRandomStreamId, base64ProtectedStreamKey];
}
@end
