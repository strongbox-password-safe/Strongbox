//
//  PlaintextInnerStream.m
//  Strongbox
//
//  Created by Strongbox on 31/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "PlaintextInnerStream.h"

@implementation PlaintextInnerStream

- (NSData *)key {
    return NSData.data;
}

- (NSData *)xor:(NSData *)ct {
    return ct;
}

@end
