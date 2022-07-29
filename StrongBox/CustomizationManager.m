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
        NSLog(@"Pro Bundle... customizing...");
        [AppPreferences.sharedInstance setPro:YES];
    }
    
    if ( [self isScotusEdition] ) {
        NSLog(@"SCOTUS Edition... customizing...");
        
        AppPreferences.sharedInstance.disableFavIconFeature = YES;
        AppPreferences.sharedInstance.disableReadOnlyToggles = YES;
        AppPreferences.sharedInstance.databasesAreAlwaysReadOnly = YES;
        AppPreferences.sharedInstance.disableNetworkBasedFeatures = YES;
        AppPreferences.sharedInstance.disableThirdPartyStorageOptions = YES;
        
        AppPreferences.sharedInstance.haveAskedAboutBackupSettings = YES;
        AppPreferences.sharedInstance.backupFiles = NO;
        AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = NO;
        AppPreferences.sharedInstance.hideTipJar = YES;
    }
    else if ( self.isGrapheneEdition ) {
        NSLog(@"Graphene Edition... customizing...");

        AppPreferences.sharedInstance.disableFavIconFeature = YES;
        AppPreferences.sharedInstance.disableReadOnlyToggles = NO;
        AppPreferences.sharedInstance.databasesAreAlwaysReadOnly = NO;
        AppPreferences.sharedInstance.disableNetworkBasedFeatures = YES;
        AppPreferences.sharedInstance.disableThirdPartyStorageOptions = YES;
        AppPreferences.sharedInstance.hideTipJar = YES; 
    }
    else {
        AppPreferences.sharedInstance.disableFavIconFeature = NO;
        AppPreferences.sharedInstance.disableReadOnlyToggles = NO;
        AppPreferences.sharedInstance.databasesAreAlwaysReadOnly = NO;
        AppPreferences.sharedInstance.disableNetworkBasedFeatures = NO;
        AppPreferences.sharedInstance.disableThirdPartyStorageOptions = NO;
        AppPreferences.sharedInstance.hideTipJar = NO;
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

@end
