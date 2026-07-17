//
//  CustomizationManager.m
//  MacBox
//
//  Created by Strongbox on 13/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "MacCustomizationManager.h"
#import "Settings.h"
#import "Utils.h"
#import "Constants.h"

#import "Strongbox-Swift.h"

@implementation MacCustomizationManager

+ (void)applyCustomizations {
    if ( [self isAProBundle] || [self isSetapp] ) {
        slog(@"Pro Bundle... customizing...");
        [Settings.sharedInstance setPro:YES];
    } else {
        slog(@"Not Pro Bundle");
    }

    if ( StrongboxProductBundle.isZeroEdition ) {
        slog(@"Graphene Edition... customizing...");
        
        Settings.sharedInstance.disableWiFiSyncClientMode = YES;
        Settings.sharedInstance.disableNetworkBasedFeatures = YES;
        Settings.sharedInstance.databasesAreAlwaysReadOnly = NO;
    }
    else {
        Settings.sharedInstance.disableWiFiSyncClientMode = NO;
        Settings.sharedInstance.databasesAreAlwaysReadOnly = NO;
        Settings.sharedInstance.disableNetworkBasedFeatures = NO;
    }
}

+ (BOOL)isUnifiedBundle {
    return MacCustomizationManager.isUnifiedFreemiumBundle || MacCustomizationManager.isUnifiedProBundle;
}

+ (BOOL)isUnifiedProBundle {
    return StrongboxProductBundle.isUnifiedProBundle;
}

+ (BOOL)isAProBundle {
    return StrongboxProductBundle.isAProBundle;
}

+ (BOOL)isSetapp {
    return StrongboxProductBundle.isSetapp;
}

+ (BOOL)isUnifiedFreemiumBundle {
    return StrongboxProductBundle.isUnifiedFreemiumBundle;
}

+ (BOOL)supportsTipJar {
    return StrongboxProductBundle.supportsTipJar;
}

@end
