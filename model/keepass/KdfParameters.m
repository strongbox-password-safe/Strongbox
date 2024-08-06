//
//  KdfParameters.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KdfParameters.h"
#import "KeePassCiphers.h"
#import "KeePassConstants.h"

@implementation KdfParameters

- (instancetype)initWithParameters:(NSDictionary<NSString*, VariantObject*>*)parameters
{
    self = [super init];
    if (self) {
        VariantObject *variant = (VariantObject*)[parameters objectForKey:kKdfParametersKeyUuid];
        
        if(!variant) {
            slog(@"Missing required $UUID Entry!");
            return nil;
        }
        
        _parameters = parameters;
    }
    return self;
}
-(NSUUID *)uuid {
    VariantObject *variant = (VariantObject*)[_parameters objectForKey:kKdfParametersKeyUuid];
    NSData* uuidData = variant ? (NSData*)variant.theObject : nil;
    if(!uuidData) {
        return nil;
    }
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:uuidData.bytes];
    
    if(!uuid) {
        return nil;
    }
    
    return uuid;
}

@end
