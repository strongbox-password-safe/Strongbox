//
//  NodeIcon.h
//  Strongbox
//
//  Created by Strongbox on 22/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    typedef UIImage* IMAGE_TYPE_PTR;
#else
    #import <Cocoa/Cocoa.h>
    typedef NSImage* IMAGE_TYPE_PTR;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface NodeIcon : NSObject

+ (instancetype)withCustom:(NSData*)custom;
+ (instancetype)withCustom:(NSData *)custom preferredKeePassSerializationUuid:(NSUUID*_Nullable)preferredKeePassSerializationUuid;
+ (instancetype)withPreset:(NSInteger)preset;

- (instancetype)init NS_UNAVAILABLE;

@property (readonly) BOOL isCustom;
@property (readonly) NSInteger preset;
@property (readonly) NSData* custom;
@property (readonly) NSUInteger estimatedStorageBytes;
@property (readonly, nullable) NSUUID* preferredKeePassSerializationUuid; 

@property IMAGE_TYPE_PTR cachedImage;

@end

NS_ASSUME_NONNULL_END
