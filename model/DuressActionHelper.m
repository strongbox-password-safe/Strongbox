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

+ (void)performDuressAction:(UIViewController*)viewController
                   database:(SafeMetaData*)database
             isAutoFillOpen:(BOOL)isAutoFillOpen
                 completion:(UnlockDatabaseCompletionBlock)completion {
    if (database.duressAction == kOpenDummy) {
        [self openDummy:database isAutoFillOpen:isAutoFillOpen completion:completion];
    }
    else if (database.duressAction == kPresentError) {
        [self displayTechnicalError:viewController completion:completion];
    }
    else if (database.duressAction == kRemoveDatabase) {
        [self removeOrDeleteSafe:database];
        [self displayTechnicalError:viewController completion:completion];
    }
    else if (database.duressAction == kOpenDummyAndRemoveDatabase) {
        [self removeOrDeleteSafe:database];
        [self openDummy:database isAutoFillOpen:isAutoFillOpen completion:completion];
    }
    else {
        completion(kUnlockDatabaseResultUserCancelled, nil, nil);
    }
}

+ (void)openDummy:(SafeMetaData * _Nonnull)database isAutoFillOpen:(BOOL)isAutoFillOpen completion:(UnlockDatabaseCompletionBlock _Nonnull)completion {
    Model *viewModel = [[Model alloc] initAsDuressDummy:isAutoFillOpen templateMetaData:database];
    completion(kUnlockDatabaseResultSuccess, viewModel, nil);
}

+ (void)displayTechnicalError:(UIViewController * _Nonnull)viewController completion:(UnlockDatabaseCompletionBlock _Nonnull)completion {
    NSError *error = [Utils createNSError:NSLocalizedString(@"open_sequence_duress_technical_error_message", @"There was a technical error opening the database.") errorCode:-1729];

    completion(kUnlockDatabaseResultError, nil, error);
}

+ (void)removeOrDeleteSafe:(SafeMetaData*)database {
    [SyncManager.sharedInstance removeDatabaseAndLocalCopies:database];
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    [[SafesList sharedInstance] remove:database.uuid];
}

@end
