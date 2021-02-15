//
//  ConflictResolutionWizard.h
//  Strongbox
//
//  Created by Strongbox on 05/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, ConflictResolutionWizardResult) {
    kConflictWizardCancel,
    kConflictWizardResultAutoMerge,
    kConflictWizardResultAlwaysAutoMerge,
    kConflictWizardResultCompare,
    kConflictWizardResultSyncLater,
    kConflictWizardResultForcePushLocal,
    kConflictWizardResultForcePullRemote,
};

typedef void (^ConflictResolutionWizardBlock)(ConflictResolutionWizardResult result);

@interface ConflictResolutionWizard : UIViewController

@property ConflictResolutionWizardBlock completion;

@property (nonnull) NSDate* localModDate;
@property (nonnull) NSDate* remoteModified;
@property (nonnull) NSString* remoteStorage;

@end

NS_ASSUME_NONNULL_END
