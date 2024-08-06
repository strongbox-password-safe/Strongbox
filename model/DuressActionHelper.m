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
#import "DatabasePreferences.h"
#import "SyncManager.h"
#import "DatabaseNuker.h"

@implementation DuressActionHelper

+ (void)performDuressAction:(UIViewController*)viewController
                   database:(DatabasePreferences*)database
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

+ (void)openDummy:(DatabasePreferences * _Nonnull)database isAutoFillOpen:(BOOL)isAutoFillOpen completion:(UnlockDatabaseCompletionBlock _Nonnull)completion {
    Model *viewModel = [[Model alloc] initAsDuressDummy:isAutoFillOpen templateMetaData:database];
    completion(kUnlockDatabaseResultSuccess, viewModel, nil);
}

+ (void)displayTechnicalError:(UIViewController * _Nonnull)viewController completion:(UnlockDatabaseCompletionBlock _Nonnull)completion {
    NSError *error = [Utils createNSError:NSLocalizedString(@"open_sequence_duress_technical_error_message", @"There was a technical error opening the database.") errorCode:-1729];

    completion(kUnlockDatabaseResultError, nil, error);
}

+ (void)removeOrDeleteSafe:(DatabasePreferences*)database {
#ifndef IS_APP_EXTENSION
    [DatabaseNuker nuke:database deleteUnderlyingIfSupported:YES completion:^(NSError * _Nullable error) {
        if ( error ) {
            slog(@"🔴 Error nuking: [%@]", error);
        }
    }];
#endif
}

@end
