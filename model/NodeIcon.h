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
+ (instancetype)withCustom:(NSData*)custom name:(NSString*_Nullable)name modified:(NSDate*_Nullable)modified;
+ (instancetype)withCustom:(NSData *)custom uuid:(NSUUID*_Nullable)uuid name:(NSString*_Nullable)name modified:(NSDate*_Nullable)modified;
+ (instancetype)withPreset:(NSInteger)preset;

- (instancetype)init NS_UNAVAILABLE;

@property (readonly) BOOL isCustom;
@property (readonly) NSInteger preset;
@property (readonly) NSData* custom;
@property (readonly, nullable) NSString* name; 
@property (readonly, nullable) NSDate* modified;  
@property (readonly) NSUInteger estimatedStorageBytes;
@property (readonly, nullable) NSUUID* uuid;

@property IMAGE_TYPE_PTR cachedImage;

@end

NS_ASSUME_NONNULL_END
