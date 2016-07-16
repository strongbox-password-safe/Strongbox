//
//  SafesViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

// TODO: See if it's possible to do the directory browsing outside of the google drive thingie - it is - just not worth it right now, but it would be good to unify
// TODO: Find out if it's really necessary to run the storage providers on the main queue - Believe it might be, but not worth it unless there' very good reason
// TODO: Don't Allow GUIs to write during Offline!!

#import "SafesViewController.h"
#import "SafeMetaData.h"
#import "BrowseSafeView.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GoogleDriveManager.h"
#import "GTLQueryDrive.h"
#import "GTLDriveFile.h"
#import "GTLServiceDrive.h"
#import "MBProgressHUD.h"
#import "SelectSafeLocationViewController.h"
#import "SettingsView.h"
#import "IOsUtils.h"
#import "core-model/Utils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "JNKeychain.h"
#import "UIAlertView+Blocks.h"
#import "UIActionSheet+Blocks.h"
#import "GoogleDriveStorageProvider.h"
#import "DropboxStorageProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "Reachability.h"
#import "SafesCollection.h"
#import <MessageUI/MessageUI.h>

@interface SafesViewController ()  <MFMailComposeViewControllerDelegate>
@property SafesCollection *safes;
@end

@implementation SafesViewController
{
    GoogleDriveStorageProvider *_google;
    DropboxStorageProvider *_dropbox;
    LocalDeviceStorageProvider *_local;
    Reachability *_internetReachabilityDetector;
}

BOOL _isOffline; // Global Online/Offline variable

- (void)refreshView
{
    self.safes = [[SafesCollection alloc] init];
    
    [self.tableView reloadData];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.toolbar.hidden = NO;
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftBarButtonItem = ([self.safes count] > 0) ? self.editButtonItem : nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self refreshView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _google = [[GoogleDriveStorageProvider alloc] init];
    _dropbox = [[DropboxStorageProvider alloc] init];
    _local = [[LocalDeviceStorageProvider alloc] init];
    
    self.buttonDelete.enabled = NO;
    
    [self startMonitoringConnectivitity];
}

// Checks if we have an internet connection or not
- (void)startMonitoringConnectivitity
{
    _internetReachabilityDetector = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    // Internet is reachable
    _internetReachabilityDetector.reachableBlock = ^(Reachability*reach)
    {
        _isOffline = NO;
        NSLog(@"Yayyy, we have the interwebs!");
    };
    
    // Internet is not reachable
    _internetReachabilityDetector.unreachableBlock = ^(Reachability*reach)
    {
        _isOffline = YES;
        NSLog(@"Someone broke the internet :(");
    };
    
    [_internetReachabilityDetector startNotifier];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.safes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseIdentifier" forIndexPath:indexPath];

    SafeMetaData* safe = [self.safes get:[indexPath row]];
    cell.textLabel.text = safe.nickName;
    cell.detailTextLabel.text = safe.fileName;
    
    NSString* icon = safe.storageProvider == kGoogleDrive ?
                        @"product32" :
                        safe.storageProvider == kDropbox ?
                        @"dropbox-blue-32x32-nologo" :
                        @"phone";
    
    cell.imageView.image = [UIImage imageNamed:icon];
    
    return cell;
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([self isEditing])
    {
        return;
    }
    
    SafeMetaData* safe = [self.safes get:[indexPath row]];
    
    if(safe.isTouchIdEnabled && [IOsUtils isTouchIDAvailable] && safe.isEnrolledForTouchId)
    {
        [self showTouchIDAuthentication:safe];
    }
    else
    {
        [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:YES];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)promptForSafePassword:(SafeMetaData *)safe askAboutTouchIdEnrolIfAppropriate:(BOOL)askAboutTouchIdEnrol
{
    NSString* title = [NSString stringWithFormat:@"Password for %@", safe.nickName];
    NSString *text = @"Enter your password:";
    
    [UIAlertView showWithTitle:title
                       message:text
                         style:UIAlertViewStyleSecureTextInput
             cancelButtonTitle:@"Cancel"
             otherButtonTitles:@[@"Ok"]
                      tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
    {
        if (buttonIndex == 1)
        {
            UITextField *passwordTextField = [alertView textFieldAtIndex:0];
            NSString *masterPassword = passwordTextField.text;
            
            if(askAboutTouchIdEnrol && safe.isTouchIdEnabled && [IOsUtils isTouchIDAvailable])
            {
                NSString* title = [NSString stringWithFormat:@"Use Touch Id to Open Safe?"];
                [UIAlertView showWithTitle:title
                                   message:@"Would you like to use Touch Id to open this safe?"
                         cancelButtonTitle:@"No"
                         otherButtonTitles:@[@"Yes"]
                                  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
                 {
                     if (buttonIndex == 1)
                     {
                         [self openSafe:safe isTouchIdOpen:YES masterPassword:masterPassword];
                     }
                     else
                     {
                         safe.isTouchIdEnabled = NO;
                         [self.safes save];
                         
                         [self openSafe:safe isTouchIdOpen:NO masterPassword:masterPassword];
                     }
                 }];
            }
            else
            {
                [self openSafe:safe isTouchIdOpen:NO masterPassword:masterPassword];
            }
        }
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)openSafe:(SafeMetaData *)safe isTouchIdOpen:(BOOL)isTouchIdOpen masterPassword:(NSString *)masterPassword
{
    id <SafeStorageProvider> provider;
    
    if(safe.storageProvider == kGoogleDrive)
    {
        provider = _google;
    }
    else if(safe.storageProvider == kDropbox)
    {
        provider = _dropbox;
    }
    else if(safe.storageProvider == kLocalDevice)
    {
        provider = _local;
    }
    
    // Are we offline for cloud based providers?
    
    if([provider isCloudBased] && _isOffline && safe.offlineCacheEnabled && safe.offlineCacheAvailable)
    {
        NSDate* modDate = [_local getOfflineCacheFileModificationDate:safe];
    
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"dd-MMM-yyyy HH:mm:ss"];
        NSString *modDateStr = [df stringFromDate:modDate];
        
        [UIAlertView showWithTitle:@"No Internet Connectivity"
                           message:[NSString stringWithFormat:@"It looks like you are offline. Would you like to use a read-only cached version of this safe instead?\n\nLast Cached at: %@", modDateStr]
                 cancelButtonTitle:@"No" otherButtonTitles:@[@"Yes"]
                          tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
        {
            if(buttonIndex == 1)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                });
                
                NSLog(@"Reading offline cache with file id: %@", safe.offlineCacheFileIdentifier);
                
                [_local readOfflineCachedSafe:safe viewController:self completionHandler:^(NSData* data, NSError* error)
                {
                    [self onProviderReadDone:provider isTouchIdOpen:isTouchIdOpen safe:safe masterPassword:masterPassword data:data error:error isOfflineCacheMode:YES]; // RO!
                }];
            }
        }];
    }
    else
    {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];

        [provider read:safe viewController:self completionHandler:^(NSData* data, NSError* error)
        {
            [self onProviderReadDone:provider isTouchIdOpen:isTouchIdOpen safe:safe masterPassword:masterPassword data:data error:error isOfflineCacheMode:NO];
        }];
    }
}

- (void)onProviderReadDone:(id)provider isTouchIdOpen:(BOOL)isTouchIdOpen safe:(SafeMetaData *)safe masterPassword:(NSString *)masterPassword data:(NSData *)data error:(NSError *)error isOfflineCacheMode:(BOOL)isOfflineCacheMode
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        if(error != nil)
        {
            NSLog(@"Error: %@", error);
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Could not open safe" message:@"There was a problem opening the safe data file." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alertView show];
        }
        else
        {
            [self openSafeWithData:data masterPassword:masterPassword safe:safe isTouchIdOpen:isTouchIdOpen provider:provider isOfflineCacheMode:isOfflineCacheMode];
        }
    });
}

- (void)openSafeWithData:(NSData *)data masterPassword:(NSString *)masterPassword safe:(SafeMetaData *)safe isTouchIdOpen:(BOOL)isTouchIdOpen provider:(id)provider isOfflineCacheMode:(BOOL)isOfflineCacheMode
{
    NSError* error;
    SafeDatabase *openedSafe = [[SafeDatabase alloc] initExistingWithData:masterPassword data:data error:&error];
    
    if(error != nil)
    {
        if(error.code == -2 && isTouchIdOpen) // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch Id enrol.
        {
            [self saveTouchIdDetailsOnSafeOpened:safe success:NO openedSafe:nil];
        }
        else
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Could not open safe" message:error.localizedDescription delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alertView show];
        }
    }
    else
    {
        Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                                          metaData:safe
                                                   storageProvider:isOfflineCacheMode ? nil : provider // Guarantee nothing can be written!
                                                              usingOfflineCache:isOfflineCacheMode
                                                  localStorageProvider:_local
                                                                 safes:self.safes];
        
        // Update the offline cache
        
        if(safe.offlineCacheEnabled)
        {
            [viewModel updateOfflineCacheWithData:data];
        }
        
        // Update Touch Id settings
        
        if(isTouchIdOpen){
            [self saveTouchIdDetailsOnSafeOpened:safe success:YES openedSafe:openedSafe];
        }
        
        [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:viewModel];
    }
}

- (void)saveTouchIdDetailsOnSafeOpened:(SafeMetaData*)safe
                                 success:(BOOL)success
                             openedSafe:(SafeDatabase*)openedSafe
{
    if(success)
    {
        if(!safe.isEnrolledForTouchId)
        {
            NSLog(@"Safe just enrolled for touch id!");
            
            safe.isEnrolledForTouchId = YES;
            [JNKeychain saveValue:openedSafe.masterPassword forKey:safe.nickName];
            
            [UIAlertView showWithTitle:@"Touch Id Enrol Successful" message:@"You can now use Touch Id with this safe." cancelButtonTitle:@"Got it" otherButtonTitles:@[] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { } ];
        }
    }
    else
    {
        safe.isEnrolledForTouchId = NO;
        
        [JNKeychain deleteValueForKey:safe.nickName];
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Could not open safe" message:@"The stored password for Touch Id was incorrect for this safe. This safe has been removed from Touch Id." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alertView show];
        
        NSLog(@"Removed Safe from Touch Id enrol as stored password was incorrect, or incorrect password was entered on initial attempt");
    }
    
    [self.safes save];
}

//////////////////////////////////////////////////////////////////////////////////

// In a storyboard-based application, you will often want to do a little preparation before navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"segueToOpenSafeView"])
    {
        //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
        return (sender == self);
    }
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"segueToOpenSafeView"])
    {
        BrowseSafeView *vc = [segue destinationViewController];

        vc.currentGroup = nil;
        vc.viewModel = (Model*)sender;
    }
    else if ([[segue identifier] isEqualToString:@"segueToStorageType"])
    {
        SelectSafeLocationViewController *vc = [segue destinationViewController];
        
        NSString* newOrExisting = (NSString*)sender;
        vc.existing = [newOrExisting isEqualToString:@"Existing"];
        vc.safes = self.safes;
        vc.googleStorageProvider = _google;
        vc.localDeviceStorageProvider = _local;
        vc.dropboxStorageProvider = _dropbox;
    }
    else if ([[segue identifier] isEqualToString:@"segueToSettingsView"])
    {
        SettingsView *vc = [segue destinationViewController];
        vc.googleDrive = _google.googleDrive;
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate
{
    [super setEditing:editing animated:animate];
    
    if(!editing)
    {
        self.navigationItem.leftBarButtonItem = ([self.safes count] > 0) ? self.editButtonItem : nil;
    }
    
    self.buttonDelete.enabled = editing;
}

/////////////////////////////////////////////////////////////////////////////////////////////////

- (void) showTouchIDAuthentication:(SafeMetaData*)safe
{
    LAContext *localAuthContext = [[LAContext alloc] init];
    [localAuthContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                     localizedReason:@"Identify to login" reply:^(BOOL success, NSError *error) {
         if(success)
         {
             NSString *password = [JNKeychain loadValueForKey:safe.nickName];
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self openSafe:safe isTouchIdOpen:YES masterPassword:password];
             });
             
             //show logged in
             NSLog(@"Successfully authenticated");
         }
         else
         {
             NSString *failureReason;
             //depending on error show what exactly has failed
             switch (error.code)
             {
                 case LAErrorAuthenticationFailed:
                    {failureReason = @"Touch ID authentication failed";
                      NSLog(@"Authentication failed: %@", failureReason);
                     
                     dispatch_async(dispatch_get_main_queue(), ^{
                         [UIAlertView showWithTitle:@"Touch Id Failed" message:@"Touch Id Authentication Failed. You must now enter your password manually to open the safe." cancelButtonTitle:@"OK" otherButtonTitles:nil
                                           tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:NO]; }];
                     });
                    }
                     break;
                     
                 case LAErrorUserCancel:
                     failureReason = @"Touch ID authentication cancelled";
                     break;
                     
                 case LAErrorUserFallback:
                     {
                         failureReason =  @"UTouch ID authentication choose password selected";
                         NSLog(@"Authentication failed: %@", failureReason);
                         
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:NO];
                         });
                     }
                     break;
                     
                 default:
                    {
                     failureReason = @"Touch ID has not been setup or system has cancelled";
                     NSLog(@"Authentication failed: %@", failureReason);
                    
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [UIAlertView showWithTitle:@"Touch Id Failed" message:@"Touch ID has not been setup or system has cancelled. You must now enter your password manually to open the safe." cancelButtonTitle:@"OK" otherButtonTitles:nil
                                              tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:NO]; }];
                        });
                    }
                    break;
             }
             
             NSLog(@"Authentication failed: %@", failureReason);
         }
     }];
}

- (void)initiateManualImportFromUrl
{
    [UIAlertView showWithTitle:@"Enter URL" message:@"Please Enter the URL of the Safe File." style:UIAlertViewStylePlainTextInput cancelButtonTitle:@"Cancel" otherButtonTitles:@[@"Download It!"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
     {
         if(buttonIndex == 1)
         {
             NSURL* url = [NSURL URLWithString:[alertView textFieldAtIndex:0].text];
             NSLog(@"URL: %@", url);
             
             [self importFromURL:url];
         }
     }];
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// Add / Import

- (IBAction)onAddSafe:(id)sender
{
    [UIActionSheet showInView:self.view withTitle:@"Select how to add your safe" cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
            otherButtonTitles:@[@"Create New",
                                @"Open Existing",
                                @"Import from URL",
                                @"Import Email Attachment"]
                     tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex)
     {
         switch (buttonIndex) {
             case 0:
                 [self createBrandNewSafe];
                 break;
             case 1:
                 [self addExistingSafe];
                 break;
             case 2:
                 [self initiateManualImportFromUrl];
                 break;
             case 3:
                 [UIAlertView showWithTitle:@"Importing an email attachment"
                                    message:@"This is done through the Mail app. Simply make sure your email attachment has a .dat or .psafe3 extension and open the attachment in Mail. You will then be given the option to open the attachment with StrongBox. Clicking on this will start the import process."
                          cancelButtonTitle:@"Cool, Got It!" otherButtonTitles:@[] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { }];
                 break;
             default:
                 break;
         }
     }];
}

-(void) addExistingSafe
{
    [self performSegueWithIdentifier:@"segueToStorageType" sender:@"Existing"];
}

-(void) createBrandNewSafe
{
    [self performSegueWithIdentifier:@"segueToStorageType" sender:@"New"];
}

- (void)importFromURL:(NSURL *)importURL
{
    [self.navigationController popToRootViewControllerAnimated:YES];
    
    NSData *importedData = [NSData dataWithContentsOfURL:importURL];
    if(![SafeDatabase isAValidSafe:importedData])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid Safe" message:@"This is not a valid StrongBox password safe database file."
                                                       delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
        return;
    }
    
    [UIAlertView showWithTitle:@"Import Safe" message:@"You are about to import a safe. What nickname would you like to use for it?" style:UIAlertViewStylePlainTextInput cancelButtonTitle:@"Cancel" otherButtonTitles:@[@"Import"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
    {
        if(buttonIndex == 1)
        {
            UITextField *textField = [alertView textFieldAtIndex:0];
            NSString* nickName = [_safes sanitizeSafeNickName:textField.text];
        
            if(![_safes isValidNickName:nickName])
            {
                [UIAlertView showWithTitle:@"Invalid Nickname" message:@"That nickname may already exist, or is invalid, please try a different nickname." cancelButtonTitle:@"OK" otherButtonTitles:@[] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { [self importFromURL:importURL]; }];
            }
            else
            {
                [self addImportedSafe:nickName data:importedData];
                
                dispatch_async(dispatch_get_main_queue(), ^(void){ [self refreshView]; } );
            }
        }
    }];
    
    return;
}

- (void)addImportedSafe:(NSString*)nickName data:(NSData*)data
{
    if(![_safes isValidNickName:nickName])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid Nick Name" message:@"This Nick Name already exists in your safes. Please choose another one."
                                                       delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
        return;
    }

    SafeMetaData *safe = [[SafeMetaData alloc] initWithNickName:nickName storageProvider:kLocalDevice];
    NSString *desiredFilename = [NSString stringWithFormat:@"%@-strongbox.dat", nickName];
    
    [_local create:desiredFilename data:data parentReference:nil viewController:self completionHandler:
     ^(NSString *fileName, NSString *fileIdentifier, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            if (error == nil)
            {
                safe.fileIdentifier = fileIdentifier;
                safe.fileName = fileName;
                
                [self.safes add:safe];
            }
            else
            {
                NSLog(@"An error occurred: %@", error);
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error Importing Safe" message:@"There was a problem importing the safe."
                                                               delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            }
        });
    }];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)deleteSafe:(SafeMetaData *)safe
{
    if(safe.storageProvider == kLocalDevice)
    {
        [_local delete:safe completionHandler:^(NSError *error) {
            if(error != nil)
            {
                NSLog(@"Error removing local file: %@", error);
            }
            else
            {
                NSLog(@"Removed Local File Successfully.");
            }
        }];
    }
    else if(safe.offlineCacheEnabled && safe.offlineCacheAvailable){
        [_local deleteOfflineCachedSafe:safe completionHandler:^(NSError *error){
            NSLog(@"Delete Offline Cache File. Error = %@", error);
        }];
    }
}

- (IBAction)onDelete:(id)sender
{
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    
    if(selectedRows.count > 0)
    {
        NSString* message = [NSString stringWithFormat:@"Would you like to delete %@", selectedRows.count > 1 ? @"these Safes?" : @"this Safe"];
        
        [UIAlertView showWithTitle:@"Are you sure?" message:message cancelButtonTitle:@"No" otherButtonTitles:@[@"Yes"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if(buttonIndex == 1)
            {
                for(NSIndexPath *indexPath in selectedRows)
                {
                    SafeMetaData* safe = [_safes get:indexPath.row];
                    [self deleteSafe:safe];
                }
                
                NSMutableIndexSet *indicesOfItems = [NSMutableIndexSet new];
                for (NSIndexPath *selectionIndex in selectedRows)
                {
                    [indicesOfItems addIndex:selectionIndex.row];
                }

                [_safes removeSafesAt:indicesOfItems];
                [_safes save];
                
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [self setEditing:NO];
                    [self refreshView];
                });
            }
        }];
    }
}

@end
