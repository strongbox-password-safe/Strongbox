//
//  Settings.h
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationParameters.h"

@interface Settings : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic) BOOL revealDetailsImmediately;
@property (nonatomic) BOOL fullVersion;

@property (nonatomic, readonly) BOOL freeTrial;
@property (nonatomic, readonly) NSInteger freeTrialDaysRemaining;
@property (nonatomic, strong) NSDate* endFreeTrialDate;
@property (nonatomic) NSInteger autoLockTimeoutSeconds;
@property (nonatomic, strong) PasswordGenerationParameters *passwordGenerationParameters;

@property (nonatomic) BOOL doNotAutoFillFromClipboard;
@property (nonatomic) BOOL doNotAutoFillFromMostPopularFields;

- (NSString*)getBiometricIdName;
    
@end
