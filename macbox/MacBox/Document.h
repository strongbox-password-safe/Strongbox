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
#import "MacDatabasePreferences.h"
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kModelUpdateNotificationFullReload;
extern NSString* const kGenericRefreshAllDatabaseViewsNotification;

@interface Document : NSDocument

@property (readonly) BOOL isEditsInProgress;
@property (readonly) BOOL isDisplayingEditSheet;

@property (readonly) ViewModel* viewModel;
@property (readonly, nullable) MacDatabasePreferences* databaseMetadata;

- (void)initiateLockSequence;
- (void)onDatabaseChangedByExternalOther;

- (void)import2FAToken:(OTPToken*)token;

@end

NS_ASSUME_NONNULL_END

