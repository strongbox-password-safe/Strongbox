//
//  DatabaseUnlocker.m
//  Strongbox
//
//  Created by Strongbox on 07/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DatabaseUnlocker.h"
#import "Alerts.h"
#import "Serializator.h"
#import "SVProgressHUD.h"
#import "Utils.h"
#import "Kdbx4Serialization.h"
#import "AutoFillManager.h"
#import "KeePassCiphers.h"
#import "AppPreferences.h"
#import "WorkingCopyManager.h"
#import "StrongboxErrorCodes.h"

@interface DatabaseUnlocker ()

@property (nonnull) UIViewController* viewController;
@property (nonnull) SafeMetaData* database;
@property (nonnull) UnlockDatabaseCompletionBlock completion;
@property BOOL keyFromConvenience;
@property BOOL forcedReadOnly;
@property BOOL isAutoFillOpen;
@property BOOL offlineMode;

@end

@implementation DatabaseUnlocker

+ (instancetype)unlockerForDatabase:(SafeMetaData*)database
                     viewController:(UIViewController*)viewController
                      forceReadOnly:(BOOL)forcedReadOnly
                     isAutoFillOpen:(BOOL)isAutoFillOpen
                        offlineMode:(BOOL)offlineMode {
    return [[DatabaseUnlocker alloc] initWithDatabase:database
                                       viewController:viewController
                                       forcedReadOnly:forcedReadOnly
                                       isAutoFillOpen:isAutoFillOpen
                                          offlineMode:offlineMode];
}

- (instancetype)initWithDatabase:(SafeMetaData*)database
                  viewController:(UIViewController*)viewController
                  forcedReadOnly:(BOOL)forcedReadOnly
                  isAutoFillOpen:(BOOL)isAutoFillOpen
                     offlineMode:(BOOL)offlineMode {
    self = [super init];
    if (self) {
        self.database = database;
        self.viewController = viewController;
        self.forcedReadOnly = forcedReadOnly;
        self.isAutoFillOpen = isAutoFillOpen;
        self.offlineMode = offlineMode;
    }
    return self;
}

+ (Model*)expressTryUnlockWithKey:(SafeMetaData *)database key:(CompositeKeyFactors *)key {
    if ( key.yubiKeyCR ) { 
        return nil;
    }
    
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache2:database.uuid];

    if(localCopyUrl == nil) {
        return nil;
    }
    
    NSError* error;
    BOOL valid = [Serializator isValidDatabase:localCopyUrl error:&error];
    if (!valid) {
        return nil;
    }
    
    __block DatabaseModel* ret = nil;

    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    [Serializator fromUrl:localCopyUrl ckf:key completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, NSError * _Nullable error) {
        if (!(userCancelled || error || !model) ) {
            ret = model;
        }
        dispatch_group_leave(group);
    }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    return ret ? [[Model alloc] initWithDatabase:ret
                                        metaData:database
                                  forcedReadOnly:NO
                                      isAutoFill:NO] : nil;
}

- (void)unlockLocalWithKey:(CompositeKeyFactors*)key
        keyFromConvenience:(BOOL)keyFromConvenience
                completion:(UnlockDatabaseCompletionBlock)completion {
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache2:self.database.uuid];

    if(localCopyUrl == nil) {
        [Alerts warn:self.viewController
               title:NSLocalizedString(@"open_sequence_couldnt_open_local_title", @"Could Not Open Local Copy")
             message:NSLocalizedString(@"open_sequence_couldnt_open_local_message", @"Could not open Strongbox's local copy of this database. A online sync is required.")];
        completion(kUnlockDatabaseResultUserCancelled, nil, nil);
        return;
    }
    

    [self unlockAtUrl:localCopyUrl key:key keyFromConvenience:keyFromConvenience completion:completion];
}

- (void)unlockAtUrl:(NSURL*)url
                key:(CompositeKeyFactors*)key
 keyFromConvenience:(BOOL)keyFromConvenience
         completion:(UnlockDatabaseCompletionBlock)completion {
    if ( self.isAutoFillOpen && !AppPreferences.sharedInstance.haveWarnedAboutAutoFillCrash && [DatabaseUnlocker isAutoFillLikelyToCrash:url] ) { 
        AppPreferences.sharedInstance.haveWarnedAboutAutoFillCrash = YES;

        [Alerts warn:self.viewController
               title:NSLocalizedString(@"open_sequence_autofill_creash_likely_title", @"AutoFill Crash Likely")
             message:NSLocalizedString(@"open_sequence_autofill_creash_likely_message", @"Your database has encryption settings that may cause iOS Password AutoFill extensions to be terminated due to excessive resource consumption. This will mean AutoFill appears not to work. Unfortunately this is an Apple imposed limit. You could consider reducing the amount of resources consumed by your encryption settings (Memory in particular with Argon2 to below 64MB).")
        completion:^{
            [self unlockAtUrl:url key:key keyFromConvenience:keyFromConvenience completion:completion];
        }];
        
        return;
    }
    
    self.keyFromConvenience = keyFromConvenience;
    self.completion = completion;

    NSError* error;
    BOOL valid = [Serializator isValidDatabase:url error:&error];
    if (!valid) {
        [self openSafeWithDataDone:nil error:error];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:NSLocalizedString(@"open_sequence_progress_decrypting", @"Decrypting...")];
    });

    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        DatabaseFormat format = [Serializator getDatabaseFormat:url];
        if(!self.keyFromConvenience && (format == kKeePass || format == kKeePass4) && key.isAmbiguousEmptyOrNullPassword) {
            [self autoDetermineEmptyOrNullAmbiguousPassword:url key:key keyFromConvenience:keyFromConvenience completion:completion];
        }
        else {
            [Serializator fromUrl:url ckf:key completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, NSError * _Nullable error) {
                [self onGotDatabaseModelFromData:userCancelled model:model error:error];
            }];
        }
    });
}

- (void)onGotDatabaseModelFromData:(BOOL)userCancelled
                             model:(DatabaseModel*)model
                             error:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [SVProgressHUD dismiss];
        
        if (userCancelled) {
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
        }
        else {
            [self openSafeWithDataDone:model error:error];
        }
    });
}

- (void)openSafeWithDataDone:(DatabaseModel*)dbModel
                       error:(NSError*)error {
    [SVProgressHUD dismiss];
    
    if (dbModel == nil) {
        UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
        [gen notificationOccurred:UINotificationFeedbackTypeError];
        
        if(error && error.code == StrongboxErrorCodes.incorrectCredentials) {
            if(self.keyFromConvenience) { 
                self.database.isEnrolledForConvenience = NO;
                self.database.convenienceMasterPassword = nil;
                self.database.conveniencePin = nil;
                self.database.autoFillConvenienceAutoUnlockPassword = nil;
                self.database.isTouchIdEnabled = NO;
                self.database.hasBeenPromptedForConvenience = NO; 
                
                [SafesList.sharedInstance update:self.database];
            
                [Alerts info:self.viewController
                       title:NSLocalizedString(@"open_sequence_problem_opening_title", @"Could not open database")
                     message:NSLocalizedString(@"open_sequence_problem_opening_convenience_incorrect_message", @"The Convenience Password or Key File were incorrect for this database. Convenience Unlock Disabled.")
                  completion:^{
                    self.completion(kUnlockDatabaseResultIncorrectCredentials, nil, error);
                }];
            }
            else {
                if (dbModel.ckfs.keyFileDigest) {
                    [Alerts info:self.viewController
                           title:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_title", @"Incorrect Credentials")
                         message:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message_verify_key_file", @"The credentials were incorrect for this database. Are you sure you are using this key file?\n\nNB: A key files are not the same as your database file.")
                      completion:^{
                        self.completion(kUnlockDatabaseResultIncorrectCredentials, nil, error);
                    }];

                }
                else {
                    [Alerts info:self.viewController
                           title:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_title", @"Incorrect Credentials")
                         message:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message", @"The credentials were incorrect for this database.")
                      completion:^{
                        self.completion(kUnlockDatabaseResultIncorrectCredentials, nil, error);
                    }];
                }
            }
            return;
        }
        
        if (!error) {
            NSLog(@"WARNWARN - No database but error not set?!");
            error = [Utils createNSError:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.") errorCode:-1];
        }

        self.completion(kUnlockDatabaseResultError, nil, error);
    }
    else {
        [self onSuccessfulSafeOpen:dbModel];
    }
}

- (void)onSuccessfulSafeOpen:(DatabaseModel *)openedSafe {
    UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    Model *viewModel = [[Model alloc] initWithDatabase:openedSafe
                                              metaData:self.database
                                        forcedReadOnly:self.forcedReadOnly
                                            isAutoFill:self.isAutoFillOpen
                                           offlineMode:self.offlineMode];
    
    if(self.database.autoFillEnabled && self.database.quickTypeEnabled && !self.isAutoFillOpen) { 
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:openedSafe databaseUuid:self.database.uuid displayFormat:self.database.quickTypeDisplayFormat];
    }
    
    if ( !self.isAutoFillOpen ) { 
        
        
        self.database.likelyFormat = openedSafe.originalFormat;
        self.database.unlockCount++;
        
        [SafesList.sharedInstance update:self.database];
    }

    BOOL enrolled = self.database.isEnrolledForConvenience;
    if ( enrolled ) {
        BOOL convenienceEnabled = self.database.isTouchIdEnabled || self.database.conveniencePin != nil;
        NSString* pw = self.database.convenienceMasterPassword;
        BOOL expired = (pw == nil) && (self.database.conveniencePasswordHasExpired) && (self.database.convenienceExpiryPeriod != -1); 

        if ( convenienceEnabled && expired ) {
            NSLog(@"XXXX - Convenience Unlock enabled, successful open, and password expired... re-enrolling...");
            self.database.convenienceMasterPassword = openedSafe.ckfs.password;
        }
    }
    
    self.completion(kUnlockDatabaseResultSuccess, viewModel, nil);
}



- (void)autoDetermineEmptyOrNullAmbiguousPassword:(NSURL*)url
                                              key:(CompositeKeyFactors*)key
                               keyFromConvenience:(BOOL)keyFromConvenience
                                       completion:(UnlockDatabaseCompletionBlock)completion {
    
    
    
    
    
    
    
    
    
    
    
    
    CompositeKeyFactors *emptyPw = [CompositeKeyFactors password:@"" keyFileDigest:key.keyFileDigest yubiKeyCR:key.yubiKeyCR];
    CompositeKeyFactors *nilPw = [CompositeKeyFactors password:nil keyFileDigest:key.keyFileDigest yubiKeyCR:key.yubiKeyCR];

    CompositeKeyFactors *firstCheck = self.database.emptyOrNilPwPreferNilCheckFirst ? nilPw : emptyPw;
    CompositeKeyFactors *secondCheck = self.database.emptyOrNilPwPreferNilCheckFirst ? emptyPw : nilPw;
    
    [Serializator fromUrl:url
                      ckf:firstCheck
               completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, NSError * _Nullable error) {
        if(model == nil && error && error.code == StrongboxErrorCodes.incorrectCredentials) {
            NSLog(@"INFO: Empty/Nil Password check didn't work first time! will try alternative password...");
            
            self.database.emptyOrNilPwPreferNilCheckFirst = !self.database.emptyOrNilPwPreferNilCheckFirst;
            [SafesList.sharedInstance update:self.database];
            
            if ( secondCheck.yubiKeyCR != nil ) {
                
                [Alerts info:self.viewController
                       title:NSLocalizedString(@"yubikey_fast_unlock_title", @"Determining Fast Unlock for YubiKey")
                     message:NSLocalizedString(@"yubikey_fast_unlock_message", @"Strongbox is determining the fastest way to unlock this database. You will be asked to scan your YubiKey once again.")
                  completion:^{
                    [Serializator fromUrl:url
                                      ckf:secondCheck
                               completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, NSError * _Nullable error) {
                        [self onGotDatabaseModelFromData:userCancelled model:model error:error];
                    }];
                }];
            }
            else {
                [Serializator fromUrl:url
                                  ckf:secondCheck
                           completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, NSError * _Nullable error) {
                    [self onGotDatabaseModelFromData:userCancelled model:model error:error];
                }];
            }
        }
        else {
            [self onGotDatabaseModelFromData:userCancelled model:model error:error];
        }
    }];
}



+ (BOOL)isAutoFillLikelyToCrash:(NSURL*)url {
    DatabaseFormat format = [Serializator getDatabaseFormat:url];
    
    if(format == kKeePass4) {     
        NSInputStream* inputStream = [NSInputStream inputStreamWithURL:url];
        CryptoParameters* params = [Kdbx4Serialization getCryptoParams:inputStream];
        

        if(params && params.kdfParameters && ( [params.kdfParameters.uuid isEqual:argon2dCipherUuid()] || [params.kdfParameters.uuid isEqual:argon2idCipherUuid()])) {
            static NSString* const kParameterMemory = @"M";
            static uint64_t const kMaxArgon2Memory =  64 * 1024 * 1024;
                        
            VariantObject* vo = params.kdfParameters.parameters[kParameterMemory];
            if(vo && vo.theObject) {
                uint64_t memory = ((NSNumber*)vo.theObject).longLongValue;
                if(memory > kMaxArgon2Memory) {
                    return YES;
                }
            }
        }
    }
    
    

    static const NSUInteger kProbablyTooLargeToOpenInAutoFillSizeBytes = 15 * 1024 * 1024; 

    NSError* error;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    
    if (error == nil && attributes.fileSize > kProbablyTooLargeToOpenInAutoFillSizeBytes) {
        return YES;
    }

    return NO;
}

@end
