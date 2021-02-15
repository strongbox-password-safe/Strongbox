//
//  Keys.m
//  Strongbox
//
//  Created by Mark on 05/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Keys.h"

@implementation Keys

- (NSString *)description
{
    return [NSString stringWithFormat:@"HMAC KEY: %@", [self.hmacKey base64EncodedStringWithOptions:kNilOptions]];
}

@end
