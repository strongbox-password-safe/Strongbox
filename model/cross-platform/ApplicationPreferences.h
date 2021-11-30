//
//  ApplicationPreferences.h
//  Strongbox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef ApplicationPreferences_h
#define ApplicationPreferences_h

#import "PasswordGenerationConfig.h"
#import "PasswordStrengthConfig.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ApplicationPreferences <NSObject>

@property (nullable) NSData* duressDummyData;
@property BOOL databasesAreAlwaysReadOnly;
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property (readonly) BOOL isProOrFreeTrial;
@property PasswordStrengthConfig* passwordStrengthConfig;

@end

NS_ASSUME_NONNULL_END

#endif /* ApplicationPreferences_h */
