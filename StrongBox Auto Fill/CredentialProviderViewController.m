//
//  CredentialProviderViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "CredentialProviderViewController.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "SafesListTableViewController.h"
#import "Settings.h"
#import "iCloudSafesCoordinator.h"
#import "Alerts.h"
#import "mach/mach.h"
#import "QuickTypeRecordIdentifier.h"
#import "OTPToken+Generation.h"
#import "Utils.h"
#import "GoogleDriveManager.h"
#import "OpenSafeSequenceHelper.h"
#import "AutoFillManager.h"
#import "LocalDeviceStorageProvider.h"

@interface CredentialProviderViewController ()

@property (nonatomic, strong) UINavigationController* safesList;
@property (nonatomic, strong) NSArray<ASCredentialServiceIdentifier *> * serviceIdentifiers;

@property BOOL quickTypeMode;

@end

@implementation CredentialProviderViewController

+ (void)initialize {
    if(self == [CredentialProviderViewController class]) {
        [iCloudSafesCoordinator.sharedInstance initializeiCloudAccessWithCompletion:^(BOOL available) {
            NSLog(@"iCloud Access Initialized...");
        }];
    }
}

// QuickType Support...

-(void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    NSLog(@"provideCredentialWithoutUserInteractionForIdentity: [%@]", credentialIdentity);
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain
                                                                      code:ASExtensionErrorCodeUserInteractionRequired
                                                                  userInfo:nil]];
}

- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    self.quickTypeMode = YES;
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    NSLog(@"prepareInterfaceToProvideCredentialForIdentity: [%@] => Found: [%@]", credentialIdentity, identifier);
    
    if(identifier) {
        SafeMetaData* safe = [SafesList.sharedInstance.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
            return [obj.uuid isEqualToString:identifier.databaseId];
        }];
        
        if(safe) {
            // Delay a litte to avoid UI Weirdness glitch
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                BOOL useAutoFillCache = ![self liveAutoFillIsPossibleWithSafe:safe];

                [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                                   safe:safe
                                                      openAutoFillCache:useAutoFillCache
                                                    canConvenienceEnrol:NO
                                                         isAutoFillOpen:YES
                                                 manualOpenOfflineCache:NO
                                            biometricAuthenticationDone:NO
                                                             completion:^(Model * _Nullable model, NSError * _Nullable error) {
                                                                 NSLog(@"AutoFill: Open Database: Model=[%@] - Error = [%@]", model, error);
                    if(model) {
                        [self onOpenedQuickType:model identifier:identifier];
                    }
                    else if(error == nil) {
                        [self cancel:nil]; // User cancelled
                    }
                    else {
                        [Alerts error:self
                                title:NSLocalizedString(@"cred_vc_error_opening_title", @"Strongbox: Error Opening Database")
                                error:error
                           completion:^{
                            [self.extensionContext cancelRequestWithError:error ? error : [Utils createNSError:@"Could not open database" errorCode:-1]];
                        }];
                    }
                }];
            });
        }
        else {
            [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
            
            [Alerts info:self
                   title:@"Strongbox: Unknown Database"
                 message:@"This appears to be a reference to an older Strongbox database which can no longer be found. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill."
              completion:^{
                [self.extensionContext cancelRequestWithError:[Utils createNSError:@"Could not find this database in Strongbox any longer." errorCode:-1]];
            }];
        }
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [Alerts info:self title:@"Strongbox: Error Locating Entry" message:@"Strongbox could not find this entry, it is possibly stale. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill." completion:^{
            
            [self.extensionContext cancelRequestWithError:[Utils createNSError:@"Could not find this record in Strongbox any longer." errorCode:-1]];
        }];
    }
}

- (void)onOpenedQuickType:(Model*)model identifier:(QuickTypeRecordIdentifier*)identifier {
    Node* node = [model.database.rootGroup.allChildRecords firstOrDefault:^BOOL(Node * _Nonnull obj) {
        return [obj.uuid.UUIDString isEqualToString:identifier.nodeId]; // PERF
    }];
    
    if(node) {
        NSString* user = [model.database dereference:node.fields.username node:node];
        NSString* password = [model.database dereference:node.fields.password node:node];
        
        //NSLog(@"Return User/Pass from Node: [%@] - [%@] [%@]", user, password, node);

        ASPasswordCredential *cred = [[ASPasswordCredential alloc] initWithUser:user password:password];
        
        // Copy TOTP code if configured to do so...
        
        if(!Settings.sharedInstance.doNotCopyOtpCodeOnAutoFillSelect && node.fields.otpToken) {
            NSString* value = node.fields.otpToken.password;
            if (value.length) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = value;
                NSLog(@"Copied TOTP to Pasteboard...");
            }
        }
        
        [self.extensionContext completeRequestWithSelectedCredential:cred completionHandler:nil];
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [Alerts info:self title:@"Strongbox: Error Locating This Record" message:@"Strongbox could not find this record in the database any longer. It is possibly stale. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill." completion:^{
            [self.extensionContext cancelRequestWithError:[Utils createNSError:@"Could not find record in database" errorCode:-1]];
        }];
    }
}

- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers
{
    NSLog(@"prepareCredentialListForServiceIdentifiers = %@", serviceIdentifiers);
    self.serviceIdentifiers = serviceIdentifiers;
    self.quickTypeMode = NO;
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"MainInterface" bundle:nil];
    
    self.safesList = [mainStoryboard instantiateViewControllerWithIdentifier:@"SafesListNavigationController"];
    ((SafesListTableViewController*)(self.safesList.topViewController)).rootViewController = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(!self.quickTypeMode) {
        [self showSafesListView];
    }
}

- (void)showSafesListView {
    if(self.presentedViewController) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
    
    if(!self.safesList) {
        [Alerts warn:self title:@"Error" message:@"There was an error loading the Safes List View. Please mail support@strongboxsafe.com to inform the developer." completion:^{
            [self.extensionContext cancelRequestWithError:[Utils createNSError:@"There was an error loading the Safes List View" errorCode:-1]];
        }];
    }
    else {
        [self presentViewController:self.safesList animated:NO completion:nil];
    }
}

- (BOOL)isLiveAutoFillProvider:(StorageProvider)storageProvider {
    return  storageProvider == kFilesAppUrlBookmark ||
            storageProvider == kiCloud ||
            storageProvider == kWebDAV ||
            storageProvider == kSFTP;
}

- (BOOL)liveAutoFillIsPossibleWithSafe:(SafeMetaData*)safeMetaData {
    if(!safeMetaData.autoFillEnabled || safeMetaData.alwaysUseCacheForAutoFill) {
        return NO;
    }
    
    if([self isLiveAutoFillProvider:safeMetaData.storageProvider]) {
        return YES;
    }
    
    if(safeMetaData.storageProvider == kLocalDevice) {
        return [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:safeMetaData];
    }
    
    return NO;
}

- (BOOL)autoFillIsPossibleWithSafe:(SafeMetaData*)safeMetaData {
    if(!safeMetaData.autoFillEnabled) {
        return NO;
    }
    
    if([self isLiveAutoFillProvider:safeMetaData.storageProvider] && !safeMetaData.alwaysUseCacheForAutoFill) {
        return YES;
    }
    
    if(safeMetaData.storageProvider == kLocalDevice && [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:safeMetaData]) {
        return YES;
    }
    
    return safeMetaData.autoFillCacheAvailable;
}

- (NSArray<ASCredentialServiceIdentifier *> *)getCredentialServiceIdentifiers {
    return self.serviceIdentifiers;
}

- (IBAction)cancel:(id)sender
{
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserCanceled userInfo:nil]];
}

- (void)onCredentialSelected:(NSString*)username password:(NSString*)password
{
    ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:username password:password];
    [self.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
}

void showWelcomeMessageIfAppropriate(UIViewController *vc) { 
    if(!Settings.sharedInstance.hasShownAutoFillLaunchWelcome) {
        Settings.sharedInstance.hasShownAutoFillLaunchWelcome = YES;
        
        [Alerts info:vc title:@"Welcome to Strongbox Auto Fill"
             message:@"It should be noted that the following storage providers do not support live access to your database from App Extensions:" \
         "\n\n- Dropbox"\
         "\n- OneDrive"\
         "\n- Google Drive"\
         "\n- 'Files' based databases"\
         "\n- Non Auto-Fill Enabled Local Databases\n\n"\
         "In these cases, Strongbox can use a cached local copy. Thus, there is a chance that this cache will be out of date. Please take this as a caveat. Hope you enjoy Auto Fill!\n-Mark"];
    }
}

//- (void)didReceiveMemoryWarning {
//    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
//    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
//    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX MEMORY WARNING RECEIVED: %f XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX", [self __getMemoryUsedPer1]);
//    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
//    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
//}
//
//- (float)__getMemoryUsedPer1
//{
//    struct mach_task_basic_info info;
//    mach_msg_type_number_t size = sizeof(info);
//    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
//    if (kerr == KERN_SUCCESS)
//    {
//        float used_bytes = info.resident_size;
//        float total_bytes = [NSProcessInfo processInfo].physicalMemory;
//        //NSLog(@"Used: %f MB out of %f MB (%f%%)", used_bytes / 1024.0f / 1024.0f, total_bytes / 1024.0f / 1024.0f, used_bytes * 100.0f / total_bytes);
//        return used_bytes / total_bytes;
//    }
//    return 1;
//}

@end
