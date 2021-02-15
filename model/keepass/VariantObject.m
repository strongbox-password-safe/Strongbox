//
//  VariantObject.m
//  Strongbox-iOS
//
//  Created by Mark on 05/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "VariantObject.h"

@implementation VariantObject

- (instancetype)initWithType:(uint8_t)type theObject:(NSObject *)theObject {
    self = [super init];
    if (self) {
        self.type = type;
        self.theObject = theObject;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Type-%d: %@", self.type, self.theObject];
}

@end
