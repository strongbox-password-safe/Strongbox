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

@interface Document : NSDocument

@property (readonly) ViewModel* viewModel;
@property (readonly, nullable) MacDatabasePreferences* databaseMetadata;
@property BOOL wasJustLocked; 

- (void)initiateLockSequence;
 
- (void)onDatabaseChangedByExternalOther;

@end

NS_ASSUME_NONNULL_END

