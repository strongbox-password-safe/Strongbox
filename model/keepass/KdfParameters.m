//
//  KdfParameters.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KdfParameters.h"

static NSString* const keyUuid = @"$UUID";

@implementation KdfParameters

- (instancetype)initWithUuid:(NSUUID*)uuid parameters:(NSDictionary<NSString*, NSObject*>*)parameters
{
    self = [super init];
    if (self) {
        self.uuid = uuid;
        self.parameters = parameters;
    }
    return self;
}

+ (instancetype)fromHeaders:(NSDictionary<NSString*, NSObject*>*)headers {
    NSData* uuidData = (NSData*)[headers objectForKey:keyUuid];
    
    if(!uuidData) {
        return nil;
    }
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:uuidData.bytes];
    
    if(!uuid) {
        return nil;
    }
    
    return [[KdfParameters alloc] initWithUuid:uuid parameters:headers];
}

@end
