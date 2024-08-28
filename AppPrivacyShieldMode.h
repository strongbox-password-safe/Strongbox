//
//  AppPrivacyShieldMode.h
//  Strongbox
//
//  Created by Strongbox on 16/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef AppPrivacyShieldMode_h
#define AppPrivacyShieldMode_h

typedef NS_ENUM (NSInteger, AppPrivacyShieldMode) {
    kAppPrivacyShieldModeNone,
    kAppPrivacyShieldModeBlur,
    kAppPrivacyShieldModePixellate,
    kAppPrivacyShieldModeBlueScreen,
    kAppPrivacyShieldModeBlackScreen,
    kAppPrivacyShieldModeDarkLogo,
    kAppPrivacyShieldModeRed,
    kAppPrivacyShieldModeGreen,
    kAppPrivacyShieldModeLightLogo,
    kAppPrivacyShieldModeWhite,
};

#endif /* AppPrivacyShieldMode_h */
