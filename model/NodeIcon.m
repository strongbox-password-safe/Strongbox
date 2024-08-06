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
#import "Utils.h"

@interface NodeIcon ()

@property (nullable) IMAGE_TYPE_PTR customIconCache;

@end

@implementation NodeIcon

+ (NodeIcon *)defaultNodeIcon {
    return [NodeIcon withPreset:0];
}

+ (instancetype)withCustomImage:(IMAGE_TYPE_PTR)image {
#if !TARGET_OS_IPHONE
    CGImageRef cgRef = [image CGImageForProposedRect:NULL context:nil hints:nil];

    if (cgRef) { 
        NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
        NSData *selectedImageData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{ }];
        return [NodeIcon withCustom:selectedImageData];
    }
    
    return nil;
#else
    return [NodeIcon withCustom:UIImagePNGRepresentation(image)]; 
#endif
}

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
    return self.isCustom ? (NSUInteger)((double)self.custom.length) : 0UL; 
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
        
        BOOL dataEqual = [self.custom.sha1.upperHexString isEqualToString:other.custom.sha1.upperHexString];
        
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

- (IMAGE_TYPE_PTR)customIcon {
    if ( self.customIconCache ) {
        
        return self.customIconCache;
    }
    else {
        return [self loadCustomIcon];
    }
}

- (NSUInteger)customIconWidth {
    return self.isCustom ? self.customIcon.size.width : 0;
}

- (NSUInteger)customIconHeight {
    return self.isCustom ? self.customIcon.size.width : 0;
}

- (IMAGE_TYPE_PTR)loadCustomIcon {  
    @try {
        if ( !self.isCustom || self.custom == nil ) {
            return nil;
        }
        
        
        
#if TARGET_OS_IPHONE
        IMAGE_TYPE_PTR img = [UIImage imageWithData:self.custom];
#else
        IMAGE_TYPE_PTR img = [[NSImage alloc] initWithData:self.custom];
#endif
        
        if(!img) {
            return nil;
        }
        
        IMAGE_TYPE_PTR image;
        
        image = image ? image : img;
        
        if ( image ) {
            self.customIconCache = image;
        }
        else {
            slog(@"WARNWARN: Couldn't Load Image!");
        }
        
        return image;
    } @catch (NSException *exception) {
        slog(@"Exception in getCustomIcon: [%@]", exception);
        return nil;
    } @finally { }
}

@end
