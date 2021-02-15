//
//  DuressActionHelper.m
//  Strongbox
//
//  Created by Strongbox on 08/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DuressActionHelper.h"
#import "DatabaseUnlocker.h"
#import "Alerts.h"
#import "Utils.h"
#import "AutoFillManager.h"
#import "SafesList.h"
#import "SyncManager.h"

@implementation DuressActionHelper

+ (void)performDuressAction:(UIViewController*)viewController database:(SafeMetaData*)database isAutoFillOpen:(BOOL)isAutoFillOpen completion:(UnlockDatabaseCompletionBlock)completion {
    if (database.duressAction == kOpenDummy) {
        Model *viewModel = [[Model alloc] initAsDuressDummy:isAutoFillOpen templateMetaData:database];
        completion(kUnlockDatabaseResultSuccess, viewModel, nil);
    }
    else if (database.duressAction == kPresentError) {
        NSError *error = [Utils createNSError:NSLocalizedString(@"open_sequence_duress_technical_error_message", @"There was a technical error opening the database.") errorCode:-1729];
        [Alerts error:viewController
                title:NSLocalizedString(@"open_sequence_duress_technical_error_title",@"Technical Issue")
                error:error completion:^{
            completion(kUnlockDatabaseResultError, nil, error);
        }];
    }
    else if (database.duressAction == kRemoveDatabase) {
        [self removeOrDeleteSafe:database];
        NSError *error = [Utils createNSError:NSLocalizedString(@"open_sequence_duress_technical_error_message",@"There was a technical error opening the database.") errorCode:-1729];
        [Alerts error:viewController
                title:NSLocalizedString(@"open_sequence_duress_technical_error_title",@"Technical Issue") error:error completion:^{
            completion(kUnlockDatabaseResultError, nil, error);
        }];
    }
    else {
        completion(kUnlockDatabaseResultUserCancelled, nil, nil);
    }
}

+ (void)removeOrDeleteSafe:(SafeMetaData*)database {
    [SyncManager.sharedInstance removeDatabaseAndLocalCopies:database];
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    [[SafesList sharedInstance] remove:database.uuid];
}

@end
