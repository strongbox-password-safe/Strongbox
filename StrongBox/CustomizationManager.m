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
#import "Strongbox-Swift.h"

@interface CustomizationManager ()

@property (readonly, class) BOOL isScotusEdition;
@property (readonly, class) BOOL isGrapheneEdition;

@end

@implementation CustomizationManager

+ (void)applyCustomizations {
    if ( [self isAProBundle] ) {
        slog(@"Pro Bundle... customizing...");
        [AppPreferences.sharedInstance setPro:YES];
    }
    
    if ( [self isScotusEdition] ) {
        slog(@"SCOTUS Edition... customizing...");
        
        AppPreferences.sharedInstance.disableFavIconFeature = YES;
        AppPreferences.sharedInstance.disableWiFiSyncClientMode = YES;
        
        AppPreferences.sharedInstance.databasesAreAlwaysReadOnly = YES;
        AppPreferences.sharedInstance.disableNetworkBasedFeatures = YES;
        AppPreferences.sharedInstance.disableThirdPartyStorageOptions = YES;
        AppPreferences.sharedInstance.haveAskedAboutBackupSettings = YES;
        AppPreferences.sharedInstance.backupFiles = NO;
        AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = NO;
    }
    else if ( self.isGrapheneEdition ) {
        slog(@"Graphene Edition... customizing...");
        
        AppPreferences.sharedInstance.disableFavIconFeature = YES;
        AppPreferences.sharedInstance.disableWiFiSyncClientMode = YES;
        AppPreferences.sharedInstance.databasesAreAlwaysReadOnly = NO;
        AppPreferences.sharedInstance.disableNetworkBasedFeatures = YES;
        AppPreferences.sharedInstance.disableThirdPartyStorageOptions = YES;
    }
    else {
        AppPreferences.sharedInstance.disableFavIconFeature = NO;
        AppPreferences.sharedInstance.disableWiFiSyncClientMode = NO;
        AppPreferences.sharedInstance.databasesAreAlwaysReadOnly = NO;
        AppPreferences.sharedInstance.disableNetworkBasedFeatures = NO;
        AppPreferences.sharedInstance.disableThirdPartyStorageOptions = NO;
    }

    AppPreferences.sharedInstance.hideTipJar = !StrongboxProductBundle.supportsTipJar;
    
    if ( self.isBusinessEdition ) {
        [MDMConfigManager.sharedInstance applyConfigToApp];
    }
}

+ (BOOL)isAProBundle {
    return StrongboxProductBundle.isAProBundle;
}

+ (BOOL)isUnifiedProEdition {
    return StrongboxProductBundle.isUnifiedProBundle;
}

+ (BOOL)isScotusEdition {
    return StrongboxProductBundle.isScotusEdition;
}

+ (BOOL)isGrapheneEdition {
    return StrongboxProductBundle.isZeroEdition;
}

+ (BOOL)isBusinessEdition {
    return StrongboxProductBundle.isBusinessBundle;
}

@end
