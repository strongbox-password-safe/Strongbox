//
//  CustomizationManager.m
//  Strongbox
//
//  Created by Strongbox on 03/06/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "CustomizationManager.h"
#import "Utils.h"
#import "Constants.h"
#import "AppPreferences.h"

@implementation CustomizationManager

+ (BOOL)isAProBundle {
    return self.isProEdition || self.isScotusEdition;
}

+ (void)applyCustomizations {
    if ( [self isAProBundle] ) {
        NSLog(@"Pro Bundle... customizing...");
        [AppPreferences.sharedInstance setPro:YES];
    }
    
    if ( [self isScotusEdition] ) {
        NSLog(@"SCOTUS Edition... customizing...");
        
        AppPreferences.sharedInstance.disableFavIconFeature = YES;
        AppPreferences.sharedInstance.disableReadOnlyToggles = YES;
        AppPreferences.sharedInstance.databasesAreAlwaysReadOnly = YES;
        AppPreferences.sharedInstance.disableNativeNetworkStorageOptions = YES;
    }
    else {
        AppPreferences.sharedInstance.disableFavIconFeature = NO;
        AppPreferences.sharedInstance.disableReadOnlyToggles = NO;
        AppPreferences.sharedInstance.databasesAreAlwaysReadOnly = NO;
        AppPreferences.sharedInstance.disableNativeNetworkStorageOptions = NO;
    }
}

+ (BOOL)isProEdition {
    NSString* bundleId = [Utils getAppBundleId];

    return [bundleId isEqualToString:Constants.proEditionBundleId];
}

+ (BOOL)isScotusEdition {
    NSString* bundleId = [Utils getAppBundleId];

    return [bundleId isEqualToString:Constants.scotusEditionBundleId];
}

@end
