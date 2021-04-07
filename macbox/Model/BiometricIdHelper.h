//
//  BiometricIdHelper.h
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

@interface BiometricIdHelper : NSObject

+ (instancetype)sharedInstance;


- (void)authorize:(DatabaseMetadata*)database completion:(void (^)(BOOL success, NSError *error))completion;
- (void)authorize:(NSString *)fallbackTitle database:(DatabaseMetadata*)database completion:(void (^)(BOOL, NSError *))completion;

- (BOOL)convenienceAvailable:(DatabaseMetadata*)database;
@property (readonly) BOOL isTouchIdUnlockAvailable;
@property (readonly) BOOL isWatchUnlockAvailable;
@property (readonly) NSString* biometricIdName;

@property BOOL dummyMode;
@property BOOL biometricsInProgress;


@end
