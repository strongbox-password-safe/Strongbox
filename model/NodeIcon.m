//
//  NodeIcon.m
//  Strongbox
//
//  Created by Strongbox on 22/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "NodeIcon.h"
#import "NSData+Extensions.h"

@implementation NodeIcon

+ (instancetype)withCustom:(NSData *)custom {
    return [[NodeIcon alloc] initWithCustom:custom preferredKeePassSerializationUuid:nil];
}

+ (instancetype)withCustom:(NSData *)custom preferredKeePassSerializationUuid:(NSUUID*_Nullable)preferredKeePassSerializationUuid {
    return [[NodeIcon alloc] initWithCustom:custom preferredKeePassSerializationUuid:preferredKeePassSerializationUuid];
}

+ (instancetype)withPreset:(NSInteger)preset {
    return [[NodeIcon alloc] initWithPreset:preset];
}

- (instancetype)initWithPreset:(NSInteger)preset {
    self = [super init];
    if (self) {
        _preset = preset;
    }
    return self;
}

- (instancetype)initWithCustom:(NSData *)custom preferredKeePassSerializationUuid:(NSUUID*_Nullable)preferredKeePassSerializationUuid {
    self = [super init];
    if (self) {
        _custom = custom;
        _preferredKeePassSerializationUuid = preferredKeePassSerializationUuid;
    }
    return self;
}

- (NSUInteger)estimatedStorageBytes {
    return self.isCustom ? (NSUInteger)((double)self.custom.length * 0.75f) : 0UL; 
}

- (BOOL)isCustom {
    return self.custom != nil;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    
    if (object == nil) {
        return NO;
    }
    
    if (![object isKindOfClass:[NodeIcon class]]) {
        return NO;
    }
    
    NodeIcon* other = (NodeIcon*)object;

    if (self.isCustom != other.isCustom) {
        return NO;
    }
    
    if (self.isCustom) {
        return [self.custom.sha1.hexString isEqualToString:other.custom.sha1.hexString];
    }
    else {
        return self.preset == other.preset;
    }
}
    
- (NSUInteger)hash {
    if (self.isCustom) {
        return self.custom.sha1.hash;
    }
    else {
        return self.preset;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:self.isCustom ? @"Custom" : @"Preset: %ld", (long)self.preset];
}

@end
