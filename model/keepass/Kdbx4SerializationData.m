//
//  Kdbx4SerializationData.m
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Kdbx4SerializationData.h"

@implementation Kdbx4SerializationData

- (NSString *)description
{
    return [NSString stringWithFormat:@"innerRandomStreamId = %d, innerRandomStreamKey = %@", self.innerRandomStreamId, self.innerRandomStreamKey];
}

@end
