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

@interface CreateDatabaseOrSetCredentialsWizard : NSWindowController

+ (instancetype)newCreateDatabaseWizard;
+ (instancetype)newSetCredentialsWizard:(DatabaseFormat)format
                        keyFileBookmark:(NSString* _Nullable)keyFileBookmark
                          yubiKeyConfig:(YubiKeyConfiguration*_Nullable)yubiKeyConfig;

@property BOOL allowFormatSelection;



@property (nonatomic, readonly) DatabaseFormat selectedDatabaseFormat;
@property (nonatomic, readonly, nullable) NSString* selectedPassword;
@property (nonatomic, readonly) NSString* selectedNickname;
@property (nonatomic, readonly, nullable) NSString* selectedKeyFileBookmark;

@property (nonatomic, readonly, nullable) YubiKeyConfiguration* selectedYubiKeyConfiguration;

- (CompositeKeyFactors * _Nullable)generateCkfFromSelectedFactors:(NSViewController*)yubiKeyInteractionVc error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
