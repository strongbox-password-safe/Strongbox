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

#if !TARGET_OS_IPHONE
+ (instancetype)withCustomImage:(IMAGE_TYPE_PTR)image {
    CGImageRef cgRef = [image CGImageForProposedRect:NULL context:nil hints:nil];

    if (cgRef) { 
        NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
        NSData *selectedImageData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{ }];
        return [NodeIcon withCustom:selectedImageData];
    }
    
    return nil;
}
#endif

+ (instancetype)withCustom:(NSData *)custom {
    return [NodeIcon withCustom:custom name:nil modified:nil];
}

+ (instancetype)withCustom:(NSData *)custom name:(NSString*)name modified:(NSDate*)modified {
    return [NodeIcon withCustom:custom uuid:NSUUID.UUID name:nil modified:nil];
}

+ (instancetype)withCustom:(NSData *)custom uuid:(NSUUID *)uuid name:(NSString *)name modified:(NSDate *)modified {
    return [NodeIcon withCustom:custom uuid:uuid name:nil modified:nil preferredOrder:NSIntegerMax];
}

+ (instancetype)withCustom:(NSData *)custom uuid:(NSUUID*)uuid name:(NSString*)name modified:(NSDate*)modified preferredOrder:(NSInteger)preferredOrder {
    return [[NodeIcon alloc] initWithCustom:custom uuid:uuid name:name modified:modified preferredOrder:preferredOrder];
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

- (instancetype)initWithCustom:(NSData *)custom uuid:(NSUUID*)uuid name:(NSString*)name modified:(NSDate*)modified preferredOrder:(NSInteger)preferredOrder {
    self = [super init];
    
    if (self) {
        _custom = custom;
        _uuid = uuid;
        _name = name;
        _modified = modified;
        _preferredOrder = preferredOrder;
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
        
        if ( namesEqual && modsEqual && dataEqual ) {
            return YES;
        }
        else {
            return NO;
        }
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
    return [NSString stringWithFormat:self.isCustom ? @"Custom [%@]" : @"Preset: %@", self.isCustom ? self.uuid : @(self.preset)];
}

@end
