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
#import "QuickViewController.h"
#import "Settings.h"
#import "iCloudSafesCoordinator.h"
#import "Alerts.h"
#import "mach/mach.h"

#import "GoogleDriveManager.h"

@interface CredentialProviderViewController ()

@property (nonatomic, strong) UINavigationController* quickLaunch;
@property (nonatomic, strong) UINavigationController* safesList;
@property (nonatomic, strong) NSArray<ASCredentialServiceIdentifier *> * serviceIdentifiers;

@end

@implementation CredentialProviderViewController

-(void)viewDidLoad {
    [super viewDidLoad];

    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"MainInterface" bundle:nil];

    self.safesList = [mainStoryboard instantiateViewControllerWithIdentifier:@"SafesListNavigationController"];
    self.quickLaunch = [mainStoryboard instantiateViewControllerWithIdentifier:@"QuickLaunchNavigationController"];
    
    ((SafesListTableViewController*)(self.safesList.topViewController)).rootViewController = self;
    ((QuickViewController*)(self.quickLaunch.topViewController)).rootViewController = self;

    [iCloudSafesCoordinator.sharedInstance initializeiCloudAccessWithCompletion:^(BOOL available) {
        NSLog(@"iCloud Access Initialized...");
    }];
}

- (void)didReceiveMemoryWarning {
    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX MEMORY WARNING RECEIVED: %f XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX", [self __getMemoryUsedPer1]);
    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
}


- (float)__getMemoryUsedPer1
{
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS)
    {
        float used_bytes = info.resident_size;
        float total_bytes = [NSProcessInfo processInfo].physicalMemory;
        //NSLog(@"Used: %f MB out of %f MB (%f%%)", used_bytes / 1024.0f / 1024.0f, total_bytes / 1024.0f / 1024.0f, used_bytes * 100.0f / total_bytes);
        return used_bytes / total_bytes;
    }
    return 1;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(Settings.sharedInstance.useQuickLaunchAsRootView) {
        [self showQuickLaunchView];
    }
    else {
        [self showSafesListView];
    }
}

- (void)showQuickLaunchView {
    [self dismissViewControllerAnimated:NO completion:nil];
    [self presentViewController:self.quickLaunch animated:NO completion:nil];
}

- (void)showSafesListView {
    [self dismissViewControllerAnimated:NO completion:nil];
    [self presentViewController:self.safesList animated:NO completion:nil];
}

- (BOOL)isLiveAutoFillProvider:(StorageProvider)storageProvider {
    return storageProvider == kiCloud || storageProvider == kWebDAV || storageProvider == kSFTP;
}

- (BOOL)autoFillIsPossibleWithSafe:(SafeMetaData*)safeMetaData {
    if([self isLiveAutoFillProvider:safeMetaData.storageProvider]) {
        return YES;
    }
    
    return safeMetaData.autoFillCacheEnabled && safeMetaData.autoFillCacheAvailable;
}

- (SafeMetaData*)getPrimarySafe {
    return [SafesList.sharedInstance.snapshot firstObject];
}

- (NSArray<ASCredentialServiceIdentifier *> *)getCredentialServiceIdentifiers {
    return self.serviceIdentifiers;
}

- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers
{
    NSLog(@"ServiceIdentifiers = %@", serviceIdentifiers);
    
    self.serviceIdentifiers = serviceIdentifiers;
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
        
        [Alerts info:vc title:@"Welcome to Strongbox Auto Fill" message:@"It should be noted that the following storage providers do not support live access to your database from App Extensions:\n\n- Dropbox\n- OneDrive\n- Google Drive\n- Local Device\n\nIn these cases, Strongbox can use a cached local copy. Thus, there is a chance that this cache will be out of date. Please take this as a caveat. Hope you enjoy the Auto Fill extension!\n-Mark"];
    }
}

@end
