//
//  KeyFile.h
//  MacBox
//
//  Created by Strongbox on 27/03/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kKeyFileRootElementName;
extern NSString* const kKeyElementName;
extern NSString* const kDataElementName;
extern NSString* const kMetaElementName;
extern NSString* const kVersionElementName;
extern NSString* const kVersionTwoPointOhText;
extern NSString* const kHashAttributeName;

@interface KeyFile : NSObject

+ (instancetype)newV2;
+ (instancetype _Nullable)fromHexCodes:(NSString*)codes;

@property (readonly) NSString* hashString;
@property (readonly) NSString* formattedHex;
@property (readonly) NSString* xml;

#ifndef IS_APP_EXTENSION

#if TARGET_OS_IPHONE
- (void)printRecoverySheet:(UIViewController*)viewController;
#else
- (void)printRecoverySheet;
#endif
    
#endif

@end

NS_ASSUME_NONNULL_END
