//
//  DatabaseNuke.m
//  Strongbox
//
//  Created by Strongbox on 07/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import "DatabaseNuker.h"
#import "AutoFillManager.h"
#import "BackupsManager.h"

#if TARGET_OS_IPHONE

#import "SyncManager.h"
#import "AppPreferences.h"

#else

#import "MacSyncManager.h"
#import "Strongbox-Swift.h"

#endif

@implementation DatabaseNuker

+ (void)nuke:(METADATA_PTR)database {
    NSLog(@"☢️ Nuking Database: [%@]... ⚛", database);

    if ( database.autoFillEnabled ) {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }

    [BackupsManager.sharedInstance deleteAllBackups:database];

#if TARGET_OS_IPHONE
    [SyncManager.sharedInstance removeDatabaseAndLocalCopies:database];
    [database clearKeychainItems];
    
    
    
    if([AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:database.uuid]) {
        AppPreferences.sharedInstance.quickLaunchUuid = nil;
    }
    
    if([AppPreferences.sharedInstance.autoFillQuickLaunchUuid isEqualToString:database.uuid]) {
        AppPreferences.sharedInstance.autoFillQuickLaunchUuid = nil;
    }
    
    
    
    [database removeFromDatabasesList];
#else
    [MacSyncManager.sharedInstance removeDatabaseAndLocalCopies:database];
    [database clearSecureItems];
    
    [SSHAgentRequestHandler.shared clearAllOfflinePublicKeys];
    
    [database remove];
#endif

    NSLog(@"☢️ Database Nuked. ⚛");
}

@end

