//
//  AutoType.m
//  Strongbox
//
//  Created by Strongbox on 15/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "AutoType.h"

@implementation AutoType

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.asssociations = @[];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[AutoType class]]) {
        return NO;
    }
    
    AutoType* other = (AutoType*)object;

    if (self.enabled != other.enabled) return NO;
    
    if (self.dataTransferObfuscation != other.dataTransferObfuscation) return NO;
    
    if ((self.defaultSequence == nil && other.defaultSequence != nil) || (self.defaultSequence != nil && ![self.defaultSequence isEqual:other.defaultSequence] )) {
        return NO;
    }
    
    if (self.asssociations.count != other.asssociations.count) return NO;
    
    int i=0;
    for (AutoTypeAssociation* association in self.asssociations) {
        AutoTypeAssociation* otherAssociation = other.asssociations[i++];
        if ( ![association isEqual:otherAssociation] ) return NO;
    }
    
    return YES;
}

@end
