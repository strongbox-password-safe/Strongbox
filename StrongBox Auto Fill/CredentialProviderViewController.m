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

@interface CredentialProviderViewController ()

@property (nonatomic, strong) UINavigationController* quickLaunch;
@property (nonatomic, strong) UINavigationController* safesList;
@property (nonatomic, strong) NSArray<ASCredentialServiceIdentifier *> * serviceIdentifiers;

@end

@implementation CredentialProviderViewController

-(void)viewDidLoad {
    [super viewDidLoad];

    NSLog(@"viewDidLoad");
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"MainInterface" bundle:nil];

    self.safesList = [mainStoryboard instantiateViewControllerWithIdentifier:@"SafesListNavigationController"];
    self.quickLaunch = [mainStoryboard instantiateViewControllerWithIdentifier:@"QuickLaunchNavigationController"];
    
    ((SafesListTableViewController*)(self.safesList.topViewController)).rootViewController = self;
    ((QuickViewController*)(self.quickLaunch.topViewController)).rootViewController = self;
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


- (BOOL)isUnsupportedAutoFillProvider:(StorageProvider)storageProvider {
    return
    storageProvider == kOneDrive ||
    storageProvider == kLocalDevice ||
    storageProvider == kDropbox;
    // ||
    //storageProvider == kGoogleDrive;
}

- (SafeMetaData*)getPrimarySafe {
    return [SafesList.sharedInstance.snapshot firstObject];
}

- (NSArray<ASCredentialServiceIdentifier *> *)getCredentialServiceIdentifiers {
    return self.serviceIdentifiers;
}

- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers
{
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

@end
