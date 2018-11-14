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
    return storageProvider == kiCloud || storageProvider == kGoogleDrive;
}

- (BOOL)isUnsupportedAutoFillProvider:(StorageProvider)storageProvider {
    return storageProvider == kLocalDevice;
}

- (BOOL)autoFillIsPossibleWithSafe:(SafeMetaData*)safeMetaData {
    if([self isUnsupportedAutoFillProvider:safeMetaData.storageProvider]) {
        return NO;
    }
    
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
        
        [Alerts info:vc title:@"Welcome to Strongbox Auto Fill" message:@"It should be noted that the following cloud providers do not support live access to your safe from App Extensions:\n\n- Dropbox\n- OneDrive\n\nIn these cases, Strongbox uses a cached local copy. Thus, there is a chance that this cache will be out of date. Please take this as a caveat. Hope you enjoy the Auto Fill extension!\n-Mark"];
    }
}

@end
