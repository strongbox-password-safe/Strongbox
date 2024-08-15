//
//  PlaintextInnerStream.m
//  Strongbox
//
//  Created by Strongbox on 31/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PlaintextInnerStream.h"

@implementation PlaintextInnerStream

- (NSData *)key {
    return NSData.data;
}

- (NSData *)doTheXor:(NSData *)ct {
    return ct;
}

@end
