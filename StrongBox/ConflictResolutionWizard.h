//
//  ConflictResolutionWizard.h
//  Strongbox
//
//  Created by Strongbox on 05/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConflictResolutionWizardCommon.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConflictResolutionWizard : UIViewController

@property ConflictResolutionWizardBlock completion;

@property (nonnull) NSDate* localModDate;
@property (nonnull) NSDate* remoteModified;
@property (nonnull) NSString* remoteStorage;

@end

NS_ASSUME_NONNULL_END
