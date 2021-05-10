//
//  NodeIcon.m
//  Strongbox
//
//  Created by Strongbox on 22/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NodeIcon.h"
#import "NSData+Extensions.h"
#import "NSDate+Extensions.h"

@implementation NodeIcon

+ (instancetype)withCustom:(NSData *)custom {
    return [self withCustom:custom name:nil modified:nil];
}

+ (instancetype)withCustom:(NSData *)custom name:(NSString*)name modified:(NSDate*)modified {
    return [[NodeIcon alloc] initWithCustom:custom uuid:nil name:name modified:modified];
}

+ (instancetype)withCustom:(NSData *)custom uuid:(NSUUID*_Nullable)uuid name:(NSString*)name modified:(NSDate*)modified {
    return [[NodeIcon alloc] initWithCustom:custom uuid:uuid name:name modified:modified];
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

- (instancetype)initWithCustom:(NSData *)custom uuid:(NSUUID*_Nullable)uuid name:(NSString*)name modified:(NSDate*)modified {
    self = [super init];
    if (self) {
        _custom = custom;
        _uuid = uuid;
        _name = name;
        _modified = modified;
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

    if ( self.isCustom != other.isCustom ) {
        return NO;
    }
    
    if ( self.isCustom ) {
        BOOL namesEqual =  !((self.name == nil && other.name != nil) || (self.name != nil && ![self.name isEqualToString:other.name] ));
        
        BOOL modsEqual =  !((self.modified == nil && other.modified != nil) || (self.modified != nil && ![self.modified isEqualToDateWithinEpsilon:other.modified] ));
        
        BOOL dataEqual = [self.custom.sha1.hexString isEqualToString:other.custom.sha1.hexString];
        
        return namesEqual && modsEqual && dataEqual;
    }
    else {
        return self.preset == other.preset;
    }
}
    
- (NSUInteger)hash {
    if (self.isCustom) {
        return [NSString stringWithFormat:@"%lu-%@-%f", (unsigned long)self.custom.sha1.hash, self.name, self.modified.timeIntervalSince1970].hash;
    }
    else {
        return self.preset;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:self.isCustom ? @"Custom" : @"Preset: %ld", (long)self.preset];
}

@end
