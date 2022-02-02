//
//  MacConflictResolutionWizard.h
//  MacBox
//
//  Created by Strongbox on 06/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ConflictResolutionWizardCommon.h"

NS_ASSUME_NONNULL_BEGIN

@interface MacConflictResolutionWizard : NSViewController

+ (instancetype)fromStoryboard;

@property ConflictResolutionWizardBlock completion;
@property (nonnull) NSDate* localModDate;
@property (nonnull) NSDate* remoteModified;
@property (nonnull) NSString* remoteStorage;

@end

NS_ASSUME_NONNULL_END
