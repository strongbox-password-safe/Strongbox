//
//  ChangeMasterPasswordWindowController.h
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSAdvancedTextField.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "YubiKeyConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface CreateFormatAndSetCredentialsWizard : NSWindowController



@property (nonatomic) NSString* titleText;
@property BOOL createSafeWizardMode;

@property DatabaseFormat initialDatabaseFormat;
@property NSString* initialKeyFileBookmark;
@property YubiKeyConfiguration *initialYubiKeyConfiguration;



@property (nonatomic, readonly) DatabaseFormat selectedDatabaseFormat;

@property (nonatomic, readonly) NSString* selectedPassword;
@property (nonatomic, readonly) NSString* selectedKeyFileBookmark;
@property (nonatomic, readonly) YubiKeyConfiguration* selectedYubiKeyConfiguration;

- (CompositeKeyFactors *)generateCkfFromSelectedFactors:(NSViewController*)yubiKeyInteractionVc error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
