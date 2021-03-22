//
//  CredentialProviderViewController.h
//  Strongbox AutoFill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <AuthenticationServices/AuthenticationServices.h>
#import "StorageProvider.h"
#import "SafeMetaData.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(12.0))
@interface CredentialProviderViewController : ASCredentialProviderViewController

- (BOOL)autoFillIsPossibleWithSafe:(SafeMetaData*)safeMetaData;

- (NSArray<ASCredentialServiceIdentifier *> *)getCredentialServiceIdentifiers;

- (void)exitWithUserCancelled:(SafeMetaData*_Nullable)unlockedDatabase;

- (void)exitWithCredential:(Model*)model item:(Node*)item;
- (void)exitWithCredential:(SafeMetaData*)database user:(NSString*)user password:(NSString*)password;

- (void)exitWithErrorOccurred:(NSError*)error;

- (void)onboardForAutoFillConvenienceAutoUnlock:(UIViewController*)viewController database:(SafeMetaData*)database completion:(void (^)(void))completion;
- (void)markLastUnlockedAtTime:(SafeMetaData*)database;

@end

NS_ASSUME_NONNULL_END
