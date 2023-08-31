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
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property PasswordStrengthConfig* passwordStrengthConfig;
@property BOOL checkPinYin;

@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;
@property BOOL appHasBeenDowngradedToFreeEdition; 
@property BOOL hasPromptedThatAppHasBeenDowngradedToFreeEdition;

@property (readonly) BOOL isPro;
- (void)setPro:(BOOL)value;

@property BOOL stripUnusedIconsOnSave;
@property BOOL useIsolatedDropbox;

@property BOOL addLegacySupplementaryTotpCustomFields;
@property BOOL addOtpAuthUrl;

@property (nullable) NSDate* lastQuickTypeMultiDbRegularClear;

@property BOOL databasesAreAlwaysReadOnly;
@property BOOL disableExport;
@property BOOL disablePrinting;
@property (nullable) NSString* businessOrganisationName;

@end

NS_ASSUME_NONNULL_END

#endif /* ApplicationPreferences_h */
