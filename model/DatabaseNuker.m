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
#import "WorkingCopyManager.h"

#if TARGET_OS_IPHONE

#import "LocalDeviceStorageProvider.h"
#import "AppleICloudProvider.h"

#import "SyncManager.h"
#import "AppPreferences.h"

#import "Strongbox-Swift.h"

#else

#import "MacSyncManager.h"
#import "Strongbox-Swift.h"

#endif

@implementation DatabaseNuker

+ (void)nuke:(METADATA_PTR)database deleteUnderlyingIfSupported:(BOOL)deleteUnderlyingIfSupported completion:(void (^)(NSError * _Nullable))completion {
    slog(@"☢️ Nuking Database: [%@]... ⚛ - Delete Underlying = [%hhd]", database, deleteUnderlyingIfSupported);
    
    if ( !deleteUnderlyingIfSupported ) {
        return [DatabaseNuker completeDatabaseNuke:database partialError:nil completion:completion];
    }
    
    
    
    if (database.storageProvider == kCloudKit) {
#ifndef NO_NETWORKING
        [CloudKitDatabasesInteractor.shared deleteWithDatabase:database
                                             completionHandler:^(NSError * _Nullable error) {
            if ( error ) {
                slog(@"🔴 Error deleting cloudkit - will continue trying to remove: %@", error);
            }
            else {
                slog(@"🟢 CloudKit Database successfully deleted from cloud");
            }

            [DatabaseNuker completeDatabaseNuke:database partialError:error completion:completion];
        }];
#else
        [DatabaseNuker completeDatabaseNuke:database partialError:nil completion:completion];
#endif
    }
#if TARGET_OS_IPHONE
    else if (database.storageProvider == kLocalDevice) {
        [[LocalDeviceStorageProvider sharedInstance] delete:database
                                                 completion:^(NSError *error) {
            if (error != nil) {
                slog(@"🔴 Error deleting local file - will continue trying to remove: %@", error);
            }
            else {
                slog(@"Removed Local File Successfully.");
            }
            
            [DatabaseNuker completeDatabaseNuke:database partialError:error completion:completion];
        }];
    }
    else if (database.storageProvider == kiCloud) {
        [[AppleICloudProvider sharedInstance] delete:database
                                          completion:^(NSError *error) {
            if(error) {
                slog(@"Error deleting iCloud file - will continue trying to remove: %@", error);
            }
            else {
                slog(@"iCloud file removed");
            }
            
            [DatabaseNuker completeDatabaseNuke:database partialError:error completion:completion];
        }];
    }
#endif
    else {
        [DatabaseNuker completeDatabaseNuke:database partialError:nil completion:completion];
    }
}

+ (void)completeDatabaseNuke:(METADATA_PTR)database 
                partialError:(NSError* _Nullable)partialError
                  completion:(void(^)(NSError* _Nullable error))completion {
    if ( database.autoFillEnabled ) {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }
    
    

    [BackupsManager.sharedInstance deleteAllBackups:database];

    
    
    [WorkingCopyManager.sharedInstance deleteLocalWorkingCache:database.uuid];

#if TARGET_OS_IPHONE
    [database clearKeychainItems];

    
    
    if([AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:database.uuid]) {
        AppPreferences.sharedInstance.quickLaunchUuid = nil;
    }
    
    if([AppPreferences.sharedInstance.autoFillQuickLaunchUuid isEqualToString:database.uuid]) {
        AppPreferences.sharedInstance.autoFillQuickLaunchUuid = nil;
    }
    
    [database removeFromDatabasesList];
#else
    [database clearSecureItems];
    
    [SSHAgentRequestHandler.shared clearAllOfflinePublicKeys];
    
    [database remove];
#endif

    slog(@"☢️ Database Nuked. ⚛");
    
    completion(partialError);
}

@end

