//
//  IOSCompositeKeyDeterminer.h
//  Strongbox
//
//  Created by Strongbox on 01/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CompositeKeyDeterminer.h"

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"

typedef UIViewController* VIEW_CONTROLLER_PTR;
typedef DatabasePreferences* METADATA_PTR;

#else

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

typedef NSViewController* VIEW_CONTROLLER_PTR;
typedef DatabaseMetadata* METADATA_PTR;

#endif

NS_ASSUME_NONNULL_BEGIN

@interface IOSCompositeKeyDeterminer : NSObject

+ (instancetype)determinerWithViewController:(VIEW_CONTROLLER_PTR)viewController
                                    database:(METADATA_PTR)safe
                              isAutoFillOpen:(BOOL)isAutoFillOpen
  transparentAutoFillBackgroundForBiometrics:(BOOL)transparentAutoFillBackgroundForBiometrics
                         biometricPreCleared:(BOOL)biometricPreCleared
                         noConvenienceUnlock:(BOOL)noConvenienceUnlock;

- (instancetype)init NS_UNAVAILABLE;

- (void)getCredentials:(CompositeKeyDeterminedBlock)completion;

@property (readonly) BOOL isAutoFillConvenienceAutoLockPossible;

@end


NS_ASSUME_NONNULL_END
