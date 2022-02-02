//
//  ConflictResolutionWizardCommon.h
//  MacBox
//
//  Created by Strongbox on 06/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef ConflictResolutionWizardCommon_h
#define ConflictResolutionWizardCommon_h

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

NS_ASSUME_NONNULL_END

#endif /* ConflictResolutionWizardCommon_h */
