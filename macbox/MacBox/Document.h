//
//  Document.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "CompositeKeyFactors.h"
#import "DatabaseMetadata.h"
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kModelUpdateNotificationLongRunningOperationStart; 
extern NSString* const kModelUpdateNotificationLongRunningOperationDone;
extern NSString* const kModelUpdateNotificationFullReload;
extern NSString* const kModelUpdateNotificationDatabaseChangedByOther;
extern NSString* const kModelUpdateNotificationSyncDone;

extern NSString* const kNotificationUserInfoParamKey;

extern NSString* const kNotificationUserInfoLongRunningOperationStatus;
@interface Document : NSDocument

@property (readonly) ViewModel* viewModel;
@property (readonly, nullable) DatabaseMetadata* databaseMetadata;

- (instancetype)initWithDatabase:(DatabaseModel*)database; 


- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController*)viewController
              completion:(void (^)(BOOL success, NSError * _Nullable))completion;

- (void)performFullInteractiveSync:(NSViewController*)viewController key:(CompositeKeyFactors*)key;

- (void)reloadFromLocalWorkingCopy:(NSViewController*)viewController
                               key:(CompositeKeyFactors*)key
                      selectedItem:(NSString *)selectedItem;

@property (readonly) BOOL isModelLocked;
- (void)checkForRemoteChanges;
     
@end

NS_ASSUME_NONNULL_END

