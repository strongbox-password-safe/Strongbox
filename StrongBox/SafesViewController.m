//
//  SafesViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafesViewController.h"
#import "SafeMetaData.h"
#import "BrowseSafeView.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GoogleDriveManager.h"
#import "SelectSafeLocationViewController.h"
#import "SettingsView.h"
#import "IOsUtils.h"
#import "Utils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "JNKeychain.h"
#import "GoogleDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "Reachability.h"
#import "SafesCollection.h"
#import <MessageUI/MessageUI.h>
#import "Alerts.h"
#import "ISMessages/ISMessages.h"

@interface SafesViewController ()  <MFMailComposeViewControllerDelegate>

@property SafesCollection *safes;

@end

@implementation SafesViewController {
    GoogleDriveStorageProvider *_google;
    DropboxV2StorageProvider *_dropbox;
    LocalDeviceStorageProvider *_local;
    Reachability *_internetReachabilityDetector;
}

BOOL _isOffline; // Global Online/Offline variable

- (void)refreshView {
    self.safes = [[SafesCollection alloc] init];
    
    [self.tableView reloadData];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.toolbar.hidden = NO;
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftBarButtonItem = ([self.safes count] > 0) ? self.editButtonItem : nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self refreshView];
    
    // TODO: Remove after 1.8 release
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    static NSString* dropboxV1MigrationKey = @"migratedV1Dropbox";
    NSInteger dropboxV1MigrationStatus = [prefs integerForKey:dropboxV1MigrationKey];
    
    if (dropboxV1MigrationStatus == 0) {
        [Alerts info:self
               title:@"Version 1.8 Dropbox Upgrade"
             message:@"Hi there,\n"
                        "This is quite a significant update due to both Google and Dropbox upgrading their APIs.\n\n"
                        "If you have Dropbox safes, Strongbox will now attempt to migrate them to version 2.\n\n"
                        "This should proceed without issue, however if you experience any problems"
                        ", then please remove and re-add the safe.\n\n"
                        "Thanks,\n"
                        "-Mark"
         completion:^{
             [self.safes migrateV1Dropbox];
             
             [prefs setInteger:1 forKey:dropboxV1MigrationKey];
         }];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _google = [[GoogleDriveStorageProvider alloc] init];
    _dropbox = [[DropboxV2StorageProvider alloc] init];
    _local = [[LocalDeviceStorageProvider alloc] init];
    
    self.buttonDelete.enabled = NO;
    
    [self startMonitoringConnectivitity];
}

- (void)startMonitoringConnectivitity {
    _internetReachabilityDetector = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    // Internet is reachable
    
    _internetReachabilityDetector.reachableBlock = ^(Reachability *reach)
    {
        _isOffline = NO;
    };
    
    // Internet is not reachable
    
    _internetReachabilityDetector.unreachableBlock = ^(Reachability *reach)
    {
        _isOffline = YES;
    };
    
    [_internetReachabilityDetector startNotifier];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.safes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseIdentifier" forIndexPath:indexPath];
    
    SafeMetaData *safe = [self.safes get:indexPath.row];
    
    cell.textLabel.text = safe.nickName;
    cell.detailTextLabel.text = safe.fileName;
    
    NSString *icon = safe.storageProvider == kGoogleDrive ?
    @"product32" :
    safe.storageProvider == kDropbox ?
    @"dropbox-blue-32x32-nologo" :
    @"phone";
    
    cell.imageView.image = [UIImage imageNamed:icon];
    
    return cell;
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        return;
    }
    
    SafeMetaData *safe = [self.safes get:indexPath.row];
    
    if (safe.isTouchIdEnabled && [IOsUtils isTouchIDAvailable] && safe.isEnrolledForTouchId) {
        [self showTouchIDAuthentication:safe];
    }
    else {
        [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:YES];
    }
}

- (void)openSafeWithTouchIdEnrolPromptIfAppropriate:(BOOL)askAboutTouchIdEnrol
                                           password:(NSString *)password
                                               safe:(SafeMetaData *)safe {
    if (askAboutTouchIdEnrol && safe.isTouchIdEnabled && [IOsUtils isTouchIDAvailable]) {
        [Alerts yesNo:self
                title:[NSString stringWithFormat:@"Use Touch Id to Open Safe?"]
              message:@"Would you like to use Touch Id to open this safe?"
               action:^(BOOL response) {
                   if (response) {
                       [self openSafe:safe
                        isTouchIdOpen:YES
                       masterPassword:password];
                   }
                   else {
                       safe.isTouchIdEnabled = NO;
                       [self.safes save];
                       [self openSafe:safe
                        isTouchIdOpen:NO
                       masterPassword:password];
                   }
               }];
    }
    else {
        [self openSafe:safe isTouchIdOpen:NO masterPassword:password];
    }
}

- (void)        promptForSafePassword:(SafeMetaData *)safe
    askAboutTouchIdEnrolIfAppropriate:(BOOL)askAboutTouchIdEnrolIfAppropriate {
    [Alerts OkCancelWithPassword:self
                           title:[NSString stringWithFormat:@"Password for %@", safe.nickName]
                         message:@"Enter Master Password"
                      completion:^(NSString *password, BOOL response) {
                          if (response) {
                              [self openSafeWithTouchIdEnrolPromptIfAppropriate:askAboutTouchIdEnrolIfAppropriate
                                                                       password:password
                                                                           safe:safe];
                          }
                      }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)  openSafe:(SafeMetaData *)safe
     isTouchIdOpen:(BOOL)isTouchIdOpen
    masterPassword:(NSString *)masterPassword {
    id <SafeStorageProvider> provider;
    
    if (safe.storageProvider == kGoogleDrive) {
        provider = _google;
    }
    else if (safe.storageProvider == kDropbox)
    {
        provider = _dropbox;
    }
    else if (safe.storageProvider == kLocalDevice)
    {
        provider = _local;
    }
    
    // Are we offline for cloud based providers?
    
    if (provider.cloudBased && _isOffline && safe.offlineCacheEnabled && safe.offlineCacheAvailable) {
        NSDate *modDate = [_local getOfflineCacheFileModificationDate:safe];
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"dd-MMM-yyyy HH:mm:ss";
        NSString *modDateStr = [df stringFromDate:modDate];
        NSString *message = [NSString stringWithFormat:@"It looks like you are offline. Would you like to use a read-only cached version of this safe instead?\n\nLast Cached at: %@", modDateStr];
        
        [Alerts yesNo:self
                title:@"No Internet Connectivity"
              message:message
               action:^(BOOL response) {
                   if (response) {
                       NSLog(@"Reading offline cache with file id: %@", safe.offlineCacheFileIdentifier);
                       
                       [_local readOfflineCachedSafe:safe
                                      viewController:self
                                          completion:^(NSData *data, NSError *error)
                        {
                            [self onProviderReadDone:provider
                                       isTouchIdOpen:isTouchIdOpen
                                                safe:safe
                                      masterPassword:masterPassword
                                                data:data
                                               error:error
                                  isOfflineCacheMode:YES];                                                                                                                               // RO!
                        }];
                   }
               }];
    }
    else {
        [provider read:safe
        viewController:self
            completion:^(NSData *data, NSError *error)
         {
             [self onProviderReadDone:provider
                        isTouchIdOpen:isTouchIdOpen
                                 safe:safe
                       masterPassword:masterPassword
                                 data:data
                                error:error
                   isOfflineCacheMode:NO];
         }];
    }
}

- (void)onProviderReadDone:(id)provider isTouchIdOpen:(BOOL)isTouchIdOpen safe:(SafeMetaData *)safe masterPassword:(NSString *)masterPassword data:(NSData *)data error:(NSError *)error isOfflineCacheMode:(BOOL)isOfflineCacheMode {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error != nil) {
            NSLog(@"Error: %@", error);
            [Alerts error:self
                    title:@"There was a problem opening the password safe file."
                    error:error];
        }
        else {
            [self openSafeWithData:data masterPassword:masterPassword safe:safe isTouchIdOpen:isTouchIdOpen provider:provider isOfflineCacheMode:isOfflineCacheMode];
        }
    });
}

- (void)openSafeWithData:(NSData *)data masterPassword:(NSString *)masterPassword safe:(SafeMetaData *)safe isTouchIdOpen:(BOOL)isTouchIdOpen provider:(id)provider isOfflineCacheMode:(BOOL)isOfflineCacheMode {
    NSError *error;
    SafeDatabase *openedSafe = [[SafeDatabase alloc] initExistingWithData:masterPassword data:data error:&error];
    
    if (error != nil) {
        if (error.code == -2 && isTouchIdOpen) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch Id enrol.
            safe.isEnrolledForTouchId = NO;
            [JNKeychain deleteValueForKey:safe.nickName];
            [self.safes save];
            
            [Alerts info:self
                   title:@"Could not open safe"
                 message:@"The stored password for Touch Id was incorrect for this safe. This safe has been removed from Touch Id."];
        }
        else {
            [Alerts error:self title:@"There was a problem opening the safe." error:error];
        }
    }
    else {
        Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                                      metaData:safe
                                               storageProvider:isOfflineCacheMode ?
                                                          nil : provider                                                         // Guarantee nothing can be written!
                                             usingOfflineCache:isOfflineCacheMode
                                          localStorageProvider:_local
                                                         safes:self.safes];
        
        if (safe.offlineCacheEnabled) {
            [viewModel updateOfflineCacheWithData:data];
        }
        
        if (isTouchIdOpen && !safe.isEnrolledForTouchId) {
            safe.isEnrolledForTouchId = YES;
            [JNKeychain saveValue:viewModel.safe.masterPassword forKey:viewModel.metadata.nickName];
            
            [ISMessages showCardAlertWithTitle:@"Touch Id Enrol Successful"
                                       message:@"You can now use Touch Id with this safe. Opening..."
                                      duration:0.75f
                                   hideOnSwipe:YES
                                     hideOnTap:YES
                                     alertType:ISAlertTypeSuccess
                                 alertPosition:ISAlertPositionTop
                                       didHide:^(BOOL finished) {
                                           [self  performSegueWithIdentifier:@"segueToOpenSafeView"
                                                                      sender:viewModel];
                                       }];
            
            [self.safes save];
        }
        else {
            [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:viewModel];
        }
    }
}

//////////////////////////////////////////////////////////////////////////////////

// In a storyboard-based application, you will often want to do a little preparation before navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:@"segueToOpenSafeView"]) {
        //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
        return (sender == self);
    }
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
        BrowseSafeView *vc = segue.destinationViewController;
        
        vc.currentGroup = nil;
        vc.viewModel = (Model *)sender;
    }
    else if ([segue.identifier isEqualToString:@"segueToStorageType"])
    {
        SelectSafeLocationViewController *vc = segue.destinationViewController;
        
        NSString *newOrExisting = (NSString *)sender;
        vc.existing = [newOrExisting isEqualToString:@"Existing"];
        vc.safes = self.safes;
        vc.googleStorageProvider = _google;
        vc.localDeviceStorageProvider = _local;
        vc.dropboxStorageProvider = _dropbox;
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate {
    [super setEditing:editing animated:animate];
    
    if (!editing) {
        self.navigationItem.leftBarButtonItem = ([self.safes count] > 0) ? self.editButtonItem : nil;
    }
    
    self.buttonDelete.enabled = editing;
}

/////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showTouchIDAuthentication:(SafeMetaData *)safe {
    LAContext *localAuthContext = [[LAContext alloc] init];
    
    [localAuthContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                     localizedReason:@"Identify to login"
                               reply:^(BOOL success, NSError *error) {
                                   [self  onTouchIdDone:success
                                                  error:error
                                                   safe:safe];
                               } ];
}

- (void)onTouchIdDone:(BOOL)success error:(NSError *)error safe:(SafeMetaData *)safe {
    if (success) {
        NSString *password = [JNKeychain loadValueForKey:safe.nickName];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openSafe:safe isTouchIdOpen:YES masterPassword:password];
        });
    }
    else {
        if (error.code == LAErrorAuthenticationFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:self
                         title:@"Touch Id Failed"
                       message:@"Touch Id Authentication Failed. You must now enter your password manually to open the safe."
                    completion:^{
                        [self promptForSafePassword:safe
                  askAboutTouchIdEnrolIfAppropriate:NO];
                    }];
            });
        }
        else if (error.code == LAErrorUserFallback)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:NO];
            });
        }
        else if (error.code != LAErrorUserCancel)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:self
                         title:@"Touch Id Failed"
                       message:@"Touch ID has not been setup or system has cancelled. You must now enter your password manually to open the safe."
                    completion:^{
                        [self promptForSafePassword:safe
                  askAboutTouchIdEnrolIfAppropriate:NO];
                    }];
            });
        }
    }
}

- (void)initiateManualImportFromUrl {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"URL"
                            title:@"Enter URL"
                          message:@"Please Enter the URL of the Safe File."
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSURL *url = [NSURL URLWithString:text];
                               NSLog(@"URL: %@", url);
                               
                               [self importFromURL:url];
                           }
                       }];
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// Add / Import

- (IBAction)onAddSafe:(id)sender {
    [Alerts actionSheet:self
              barButton:self.buttonAddSafe
                  title:@"How Would You Like To Add Your Safe?"
           buttonTitles:@[@"Create New",
                          @"Open Existing",
                          @"Import from URL",
                          @"Import Email Attachment"]
             completion:^(int response) {
                 if (response == 1) {
                     [self performSegueWithIdentifier:@"segueToStorageType" sender:@"New"];
                 }
                 else if (response == 2) {
                     [self performSegueWithIdentifier:@"segueToStorageType" sender:@"Existing"];
                 }
                 else if (response == 3) {
                     [self initiateManualImportFromUrl];
                 }
                 else if (response == 4) {
                     [Alerts info:self
                            title:@"Importing Via Email"
                          message:  @
                      "1) Send an email to yourself with your safe file attached\n"
                      "2) Ensure this file has a 'dat' or 'psafe3' extension\n"
                      "3) Once the mail has arrived in the Mail app touch the attachment\n"
                      "4) You will be given an option to 'Copy to StrongBox'\n"
                      "\n"
                      "Clicking on this will start the import process."];
                 }
             }];
}

- (void)importFromURL:(NSURL *)importURL {
    [self.navigationController popToRootViewControllerAnimated:YES];
    
    NSData *importedData = [NSData dataWithContentsOfURL:importURL];
    
    if (![SafeDatabase isAValidSafe:importedData]) {
        [Alerts warn:self
               title:@"Invalid Safe"
             message:@"This is not a valid StrongBox password safe database file."];
        
        return;
    }
    
    [self promptForImportedSafeNickName:importedData];
}

- (void)promptForImportedSafeNickName:(NSData *)data {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Nickname"
                            title:@"You are about to import a safe. What nickname would you like to use for it?"
                          message:@"Please Enter the URL of the Safe File."
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSString *nickName = [_safes sanitizeSafeNickName:text];
                               
                               if (![_safes isValidNickName:nickName]) {
                                   [Alerts   info:self
                                            title:@"Invalid Nickname"
                                          message:@"That nickname may already exist, or is invalid, please try a different nickname."
                                       completion:^{
                                           [self promptForImportedSafeNickName:data];
                                       }];
                               }
                               else {
                                   [self addImportedSafe:nickName
                                                    data:data];
                               }
                           }
                       }];
}

- (void)addImportedSafe:(NSString *)nickName data:(NSData *)data {
    [_local create:nickName
              data:data
      parentFolder:nil
    viewController:self
        completion:^(SafeMetaData *metadata, NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^(void)
                        {
                            if (error == nil) {
                                [self.safes
                                 add:metadata];
                                [self refreshView];
                            }
                            else {
                                [Alerts error:self
                                        title:@"Error Importing Safe"
                                        error:error];
                            }
                        });
     }];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)deleteSafe:(SafeMetaData *)safe {
    if (safe.storageProvider == kLocalDevice) {
        [_local delete:safe
            completion:^(NSError *error) {
                if (error != nil) {
                    NSLog(@"Error removing local file: %@", error);
                }
                else {
                    NSLog(@"Removed Local File Successfully.");
                }
            }];
    }
    else if (safe.offlineCacheEnabled && safe.offlineCacheAvailable)
    {
        [_local deleteOfflineCachedSafe:safe
                             completion:^(NSError *error) {
                                 //NSLog(@"Delete Offline Cache File. Error = %@", error);
                             }];
    }
}

- (IBAction)onDelete:(id)sender {
    NSArray *selectedRows = (self.tableView).indexPathsForSelectedRows;
    
    if (selectedRows.count > 0) {
        NSString *message = [NSString stringWithFormat:@"Would you like to delete %@", selectedRows.count > 1 ? @"these Safes?" : @"this Safe"];
        
        [Alerts yesNo:self
                title:@"Are you sure?"
              message:message
               action:^(BOOL response) {
                   if (response) {
                       for (NSIndexPath *indexPath in selectedRows) {
                           SafeMetaData *safe = [_safes get:indexPath.row];
                           [self deleteSafe:safe];
                       }
                       
                       NSMutableIndexSet *indicesOfItems = [NSMutableIndexSet new];
                       
                       for (NSIndexPath *selectionIndex in selectedRows) {
                           [indicesOfItems addIndex:selectionIndex.row];
                       }
                       
                       [_safes removeSafesAt:indicesOfItems];
                       [_safes save];
                       
                       dispatch_async(dispatch_get_main_queue(), ^(void) {
                           [self setEditing:NO];
                           [self refreshView];
                       });
                   }
               }];
    }
}

@end
