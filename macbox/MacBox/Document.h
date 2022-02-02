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
@property (nullable) NSString* selectedItem; 
@property BOOL wasJustLocked; 
@property (readonly) BOOL isModelLocked;

- (void)lock:(NSString* _Nullable)selectedItem;

- (void)unlock:(CompositeKeyFactors *)compositeKeyFactors
viewController:(NSViewController *)viewController
alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
fromConvenience:(BOOL)fromConvenience
    completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion;

- (void)checkForRemoteChanges;
     
@end

NS_ASSUME_NONNULL_END

