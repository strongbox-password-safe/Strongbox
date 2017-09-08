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
#import "IOsUtils.h"
#import "Utils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "JNKeychain.h"
#import "GoogleDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "SafesCollection.h"
#import "Alerts.h"
#import "ISMessages/ISMessages.h"
#import "UpgradeViewController.h"
#import "Settings.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "SelectStorageProviderController.h"

#define kTouchId911Limit 5

@interface SafesViewController ()

@property (nonatomic, strong) SafesCollection *safes;
@property (nonatomic, strong) SKProductsRequest *productsRequest;
@property (nonatomic, strong) NSArray<SKProduct *> *validProducts;
@property (nonatomic) BOOL touchId911;

@end

@implementation SafesViewController

- (void)refreshView {
    self.safes = [[SafesCollection alloc] init];
    
    [self.tableView reloadData];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationItem.hidesBackButton = YES;
    [self.navigationItem setPrompt:nil];
    
    [self bindProOrFreeTrialUi];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self refreshView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[Settings sharedInstance] setPro:NO];
    
    
    
    [[Settings sharedInstance] startMonitoringConnectivitity];
    
    if(![[Settings sharedInstance] isPro]) {
        [self getValidIapProducts];
        
        if(![[Settings sharedInstance] isHavePromptedAboutFreeTrial]) {
            [self initializeFreeTrial];
        }
        else {
            [self promptToReviewAppIfAppropriate];
        }
    }
}

- (void)initializeFreeTrial {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *date;
    
    if(![self isReasonablyNewUser]) {
        date = [cal dateByAddingUnit:NSCalendarUnitDay value:7 toDate:[NSDate date] options:0];
        
        [Alerts info:self title:@"Upgrade Possibilites"
             message:@"Hi there, it looks like you've been using StrongBox for a while now. I have decided to move to a freemium business model to cover costs and support further development. From now, you will have a further week to evaluate the fully featured StrongBox. After this point, you will be transitioned to a more limited Lite version. You can find out more by pressing the Upgrade button below.\n-Mark\n\n* NB: You will not lose access to any existing safes." completion:nil];
    }
    else {
        date = [cal dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:[NSDate date] options:0];
        
        [Alerts info:self title:@"Upgrade Possibilites"
             message:@"Hi there, welcome to StrongBox! You will be able to use the fully featured App for one month. At that point you will be transitioned to a more limited version. To find out more you can hit the Upgrade button at anytime below. I hope you will enjoy the app, and choose to support it!\n-Mark" completion:nil];
    }
    
    [[Settings sharedInstance] setEndFreeTrialDate:date];
    [[Settings sharedInstance] setHavePromptedAboutFreeTrial:YES];
}

- (BOOL)isReasonablyNewUser {
    return [[Settings sharedInstance] getLaunchCount] <= 10;
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
    
    NSString *icon = safe.storageProvider == kGoogleDrive ? @"product32" : safe.storageProvider == kDropbox ? @"dropbox-blue-32x32-nologo" : @"phone";
    
    cell.imageView.image = [UIImage imageNamed:icon];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
//    UITableViewRowAction *exportAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"Export" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
//        ;
//    }];
//    
//    exportAction.backgroundColor = [UIColor yellowColor]; //colorWithRed:0.298 green:0.851 blue:0.3922 alpha:1.0];
//    
    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self deleteSafe:indexPath];
    }];
//
//    UITableViewRowAction *migrateAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"Migrate" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
//        ;
//    }];
//    
//    migrateAction.backgroundColor = [UIColor darkGrayColor]; //colorWithRed:0.298 green:0.851 blue:0.3922 alpha:1.0];
    
    return @[deleteAction]; //, migrateAction, exportAction];
}

- (void)deleteSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *safe = [self.safes get:indexPath.row];
    
    NSString *message = [NSString stringWithFormat:@"Are you sure you want to remove this safe from StrongBox?%@",
                         safe.storageProvider == kLocalDevice ? @"" : @" (NB: The underlying safe data file will not be deleted)"];
    
    [Alerts yesNo:self
            title:@"Are you sure?"
          message:message
           action:^(BOOL response) {
               if (response) {
                   SafeMetaData *safe = [self.safes get:indexPath.row];
                   
                   [self cleanupSafeForRemoval:safe];
                   [self.safes removeSafesAt:[NSIndexSet indexSetWithIndex:indexPath.row]];
                   [self.safes save];
                   
                   dispatch_async(dispatch_get_main_queue(), ^(void) {
                       [self setEditing:NO];
                       [self refreshView];
                   });
               }
           }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        return;
    }
    
    SafeMetaData *safe = [self.safes get:indexPath.row];
    
    if (safe.isTouchIdEnabled &&
        [IOsUtils isTouchIDAvailable] &&
        safe.isEnrolledForTouchId &&
        ([[Settings sharedInstance] isProOrFreeTrial] || self.touchId911)) {
        self.touchId911 = NO;
        [self showTouchIDAuthentication:safe];
    }
    else {
        [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:YES];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)cleanupSafeForRemoval:(SafeMetaData *)safe {
    if (safe.storageProvider == kLocalDevice) {
        [[LocalDeviceStorageProvider sharedInstance] delete:safe
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
        [[LocalDeviceStorageProvider sharedInstance] deleteOfflineCachedSafe:safe
                                 completion:^(NSError *error) {
                                     //NSLog(@"Delete Offline Cache File. Error = %@", error);
                                 }];
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (void)        promptForSafePassword:(SafeMetaData *)safe
    askAboutTouchIdEnrolIfAppropriate:(BOOL)askAboutTouchIdEnrolIfAppropriate {
    [Alerts OkCancelWithPassword:self
                           title:[NSString stringWithFormat:@"Password for %@", safe.nickName]
                         message:@"Enter Master Password"
                      completion:^(NSString *password, BOOL response) {
                          if (response) {
                              [self openSafe:safe
                               isTouchIdOpen:NO
                              masterPassword:password
                        askAboutTouchIdEnrol:askAboutTouchIdEnrolIfAppropriate];
                          }
                      }];
}

- (void)  openSafe:(SafeMetaData *)safe
     isTouchIdOpen:(BOOL)isTouchIdOpen
    masterPassword:(NSString *)masterPassword
askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol {
    id <SafeStorageProvider> provider;
    
    if (safe.storageProvider == kGoogleDrive) {
        provider = [GoogleDriveStorageProvider sharedInstance];
    }
    else if (safe.storageProvider == kDropbox)
    {
        provider = [DropboxV2StorageProvider sharedInstance];
    }
    else if (safe.storageProvider == kLocalDevice)
    {
        provider = [LocalDeviceStorageProvider sharedInstance];
    }
    
    // Are we offline for cloud based providers?
    
    if (provider.cloudBased &&
        [[Settings sharedInstance] isOffline] &&
        safe.offlineCacheEnabled &&
        safe.offlineCacheAvailable) {
        NSDate *modDate = [[LocalDeviceStorageProvider sharedInstance] getOfflineCacheFileModificationDate:safe];
        
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
                       
                       [[LocalDeviceStorageProvider sharedInstance] readOfflineCachedSafe:safe
                                      viewController:self
                                          completion:^(NSData *data, NSError *error)
                        {
                            [self onProviderReadDone:provider
                                       isTouchIdOpen:isTouchIdOpen
                                                safe:safe
                                      masterPassword:masterPassword
                                                data:data
                                               error:error
                                  isOfflineCacheMode:YES
                                askAboutTouchIdEnrol:NO];                                                                                                                               // RO!
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
                   isOfflineCacheMode:NO
              askAboutTouchIdEnrol:askAboutTouchIdEnrol];
         }];
    }
}

- (void)onProviderReadDone:(id)provider
             isTouchIdOpen:(BOOL)isTouchIdOpen
                      safe:(SafeMetaData *)safe
            masterPassword:(NSString *)masterPassword
                      data:(NSData *)data error:(NSError *)error
        isOfflineCacheMode:(BOOL)isOfflineCacheMode
      askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error != nil) {
            NSLog(@"Error: %@", error);
            [Alerts error:self
                    title:@"There was a problem opening the password safe file."
                    error:error];
        }
        else {
            [self openSafeWithData:data
                    masterPassword:masterPassword
                              safe:safe
                     isTouchIdOpen:isTouchIdOpen
                          provider:provider
                isOfflineCacheMode:isOfflineCacheMode
             askAboutTouchIdEnrol:askAboutTouchIdEnrol];
        }
    });
}

- (void)openSafeWithData:(NSData *)data
          masterPassword:(NSString *)masterPassword
                    safe:(SafeMetaData *)safe
           isTouchIdOpen:(BOOL)isTouchIdOpen
                provider:(id)provider
      isOfflineCacheMode:(BOOL)isOfflineCacheMode
askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol {
    [SVProgressHUD showWithStatus:@"Decrypting..."];
    
    NSError *error;
    PasswordDatabase *openedSafe = [[PasswordDatabase alloc] initExistingWithDataAndPassword:data password:masterPassword error:&error];
    
    [SVProgressHUD popActivity];
    
    if (error != nil) {
        if (error.code == -2) {
            if(isTouchIdOpen) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch Id enrol.
                safe.isEnrolledForTouchId = NO;
                [JNKeychain deleteValueForKey:safe.nickName];
                [self.safes save];
                
                [Alerts info:self
                       title:@"Could not open safe"
                     message:@"The stored password for Touch Id was incorrect for this safe. This safe has been removed from Touch Id."];
            }
            else {
                [Alerts info:self
                       title:@"Incorrect Password"
                     message:@"The password was incorrect for this safe."];
            }
        }
        else {
            [Alerts error:self title:@"There was a problem opening the safe." error:error];
        }
    }
    else {
        if (askAboutTouchIdEnrol && safe.isTouchIdEnabled && !safe.isEnrolledForTouchId &&
            [IOsUtils isTouchIDAvailable] && [[Settings sharedInstance] isProOrFreeTrial]) {
            [Alerts yesNo:self
                    title:[NSString stringWithFormat:@"Use Touch Id to Open Safe?"]
                  message:@"Would you like to use Touch Id to open this safe?"
                   action:^(BOOL response) {
                   if (response) {
                       safe.isEnrolledForTouchId = YES;
                       [JNKeychain saveValue:masterPassword forKey:safe.nickName];
                       [self.safes save];
                       
                       [ISMessages showCardAlertWithTitle:@"Touch Id Enrol Successful"
                                                  message:@"You can now use Touch Id with this safe. Opening..."
                                                 duration:0.75f
                                              hideOnSwipe:YES
                                                hideOnTap:YES
                                                alertType:ISAlertTypeSuccess
                                            alertPosition:ISAlertPositionTop
                                                  didHide:^(BOOL finished) {
                                                      [self onSuccessfulSafeOpen:isOfflineCacheMode provider:provider openedSafe:openedSafe safe:safe data:data];
                                                  }];
                   }
                   else{
                       safe.isTouchIdEnabled = NO;
                       [JNKeychain saveValue:masterPassword forKey:safe.nickName];
                       [self.safes save];
                       
                       [self onSuccessfulSafeOpen:isOfflineCacheMode provider:provider openedSafe:openedSafe safe:safe data:data];
                   }
            }];
        }
        else {
            [self onSuccessfulSafeOpen:isOfflineCacheMode provider:provider openedSafe:openedSafe safe:safe data:data];
        }
    }
}

-(void)onSuccessfulSafeOpen:(BOOL)isOfflineCacheMode
                provider:(id)provider
               openedSafe:(PasswordDatabase *)openedSafe
                   safe:(SafeMetaData *)safe
                     data:(NSData *)data {
    Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                                  metaData:safe
                                           storageProvider:isOfflineCacheMode ? nil : provider // Guarantee nothing can be written!
                                         usingOfflineCache:isOfflineCacheMode
                                                isReadOnly:NO // ![[Settings sharedInstance] isProOrFreeTrial]
                                                     safes:self.safes];

    if (safe.offlineCacheEnabled) {
        [viewModel updateOfflineCacheWithData:data];
    }

    [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:viewModel];
}

//////////////////////////////////////////////////////////////////////////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
        BrowseSafeView *vc = segue.destinationViewController;
        vc.viewModel = (Model *)sender;
        vc.currentGroup = vc.viewModel.rootGroup;
    }
    else if ([segue.identifier isEqualToString:@"segueToStorageType"])
    {
        SelectStorageProviderController *vc = segue.destinationViewController;
        
        NSString *newOrExisting = (NSString *)sender;
        vc.existing = [newOrExisting isEqualToString:@"Existing"];
        vc.safes = self.safes;
    }
    else if ([segue.identifier isEqualToString:@"segueToUpgrade"]) {
        UpgradeViewController* vc = segue.destinationViewController;
       
        if(self.validProducts.count > 0) {
            vc.product = [self.validProducts objectAtIndex:0];
        }
    }
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
            [self openSafe:safe isTouchIdOpen:YES masterPassword:password askAboutTouchIdEnrol:NO];
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

//////////////////////////////////////////////////////////////////////////////////////////////////
// Add / Import

- (void)initiateManualImportFromUrl {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"URL"
                            title:@"Enter URL"
                          message:@"Please Enter the URL of the Safe File."
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSURL *url = [NSURL URLWithString:text];
                               NSLog(@"URL: %@", url);
                               
                               [self importFromUrlOrEmailAttachment:url];
                           }
                       }];
}

- (IBAction)onAddSafe:(id)sender {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"How Would You Like To Add Your Safe?"
                                            message:nil
                                      preferredStyle:UIAlertControllerStyleActionSheet];

    BOOL createEnabled = [[Settings sharedInstance] isProOrFreeTrial];
    
    // Only allow have one safe in free mode
    
    BOOL addExistingEnabled = [self isAddExistingSafeAllowed];
    
    NSArray<NSString*>* buttonTitles =
        @[  (createEnabled ? @"Create New" : @"Create New [Upgrade Required]"),
            (addExistingEnabled ? @"Open Existing" : @"Open Existing [Upgrade Required]"),
            (addExistingEnabled ? @"Import from URL" :  @"Import from URL [Upgrade Required]") ,
            (addExistingEnabled ? @"Import Email Attachment" : @"Import Email Attachment [Upgrade Required]")];
    
    int index = 1;
    for (NSString *title in buttonTitles) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *a) {
                                                            [self onAddSafeActionSheetResponse:index];
                                                       }];
        
        // Disable create new button if we're not in pro/free trial mode.

        if( index == 1) {
            [action setEnabled:createEnabled];
        }
        
        if (index > 1) {
            [action setEnabled:addExistingEnabled];
        }
        
        [alertController addAction:action];
        index++;
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             [self onAddSafeActionSheetResponse:0];
                                                         }];
    [alertController addAction:cancelAction];
    
    alertController.popoverPresentationController.barButtonItem = self.buttonAddSafe;
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)onAddSafeActionSheetResponse:(int)response {
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
}

- (BOOL)isAddExistingSafeAllowed {
    return [[Settings sharedInstance] isProOrFreeTrial] || self.safes.count < 1;
}

- (void)importFromUrlOrEmailAttachment:(NSURL *)importURL {
    if([self isAddExistingSafeAllowed]) {
        [self.navigationController popToRootViewControllerAnimated:YES];
        
        NSData *importedData = [NSData dataWithContentsOfURL:importURL];
        
        if (![PasswordDatabase isAValidSafe:importedData]) {
            [Alerts warn:self
                   title:@"Invalid Safe"
                 message:@"This is not a valid StrongBox password safe database file."];
            
            return;
        }
        
        [self promptForImportedSafeNickName:importedData];
    }
    else {
        [Alerts info:self title:@"Safe cannot be added" message:@"This safe could not be added because you are using the Lite version of StrongBox. Please upgrade to enjoy full benefits."];
    }
}

- (void)promptForImportedSafeNickName:(NSData *)data {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Nickname"
                            title:@"You are about to import a safe. What nickname would you like to use for it?"
                          message:@"Please Enter the URL of the Safe File."
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSString *nickName = [self.safes sanitizeSafeNickName:text];
                               
                               if (![self.safes isValidNickName:nickName]) {
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
    [[LocalDeviceStorageProvider sharedInstance] create:nickName
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)getValidIapProducts {
    NSSet *productIdentifiers = [NSSet setWithObjects:kIapProId, nil];
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}

-(void)productsRequest:(SKProductsRequest *)request
    didReceiveResponse:(SKProductsResponse *)response
{
    NSUInteger count = [response.products count];
    if (count > 0) {
        self.validProducts = response.products;
        for (SKProduct *validProduct in self.validProducts) {
            NSLog(@"%@", validProduct.productIdentifier);
            NSLog(@"%@", validProduct.localizedTitle);
            NSLog(@"%@", validProduct.localizedDescription);
            NSLog(@"%@", validProduct.price);
        }
        
        [self refreshView];
    }
}

static BOOL shownNagScreenThisSession = NO;
- (void)segueToNagScreenIfAppropriate {
    NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];
    NSInteger nagRate = 0;
    
    if(![[Settings sharedInstance] isFreeTrial]) {
        nagRate = 10;
    }
    
    if(nagRate > 0 && !shownNagScreenThisSession && (launchCount % nagRate == 0)) {
        shownNagScreenThisSession = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
        });
    }
}

- (IBAction)onUpgrade:(id)sender {
    [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
}

- (IBAction)onTogglePro:(id)sender {
    BOOL isPro = [[Settings sharedInstance] isPro];
    
    [[Settings sharedInstance] setPro:!isPro];

    [self bindProOrFreeTrialUi];
}

-(void)bindProOrFreeTrialUi {
    self.navigationController.toolbar.hidden = [[Settings sharedInstance] isPro];
    
    //[self.buttonTogglePro setTitle:(![[Settings sharedInstance] isProOrFreeTrial] ? @"Go Pro" : @"Go Free")];
    [self.buttonTogglePro setEnabled:NO];
    [self.buttonTogglePro setTintColor: [UIColor clearColor]];
    
    [self.buttonTouchID911 setEnabled:NO];
    [self.buttonTouchID911 setTintColor: [UIColor clearColor]];
    
    //[self.buttonTogglePro setEnabled:YES];
    //[self.buttonTogglePro setTintColor:nil];
    
    if([[Settings sharedInstance] isProOrFreeTrial]) {
        [self.navItemHeader setTitle:@"Safes"];
    }
    else {
        [self.navItemHeader setTitle:@"Safes [Lite Version]"];
        
        if(([[Settings sharedInstance] getTouchId911Count] < kTouchId911Limit) &&
           ([IOsUtils isTouchIDAvailable]) &&
           [self.safes safeWithTouchIdIsAvailable]) {
            [self.buttonTouchID911 setEnabled:YES];
            [self.buttonTouchID911 setTintColor:nil];
        }
    }
    
    if(![[Settings sharedInstance] isPro]) {
        [self.buttonUpgrade setEnabled:YES];
        [self.buttonUpgrade setTintColor: [UIColor redColor]];
        
        [self segueToNagScreenIfAppropriate];
    
        NSString *upgradeButtonTitle;
        if([[Settings sharedInstance] isFreeTrial]) {
            upgradeButtonTitle = [NSString stringWithFormat:@"Upgrade Info - (%ld Trial Days Left)",
                           (long)[[Settings sharedInstance] getFreeTrialDaysRemaining]];
        }
        else {
            upgradeButtonTitle = [NSString stringWithFormat:@"Upgrade Info..."];
        }
        
        [self.buttonUpgrade setTitle:upgradeButtonTitle];
    }
    else {
        [self.buttonUpgrade setEnabled:NO];
        [self.buttonUpgrade setTintColor: [UIColor clearColor]];
    }
}

- (void)openAppStoreForReview {
    // https://itunes.apple.com/us/app/strongbox-password-safe/id897283731
    
    NSString *appId = @"897283731";
    NSString *url = [NSString stringWithFormat:@"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=%@&pageNumber=0&sortOrdering=1&type=Purple+Software&mt=8", appId];
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url ]];
}

- (void)promptToReviewAppIfAppropriate {
    NSInteger promptedForReview = [[Settings sharedInstance] isUserHasBeenPromptedForReview];
    NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];
    
    if ((launchCount % 3 == 0) && promptedForReview == 0) {
        [Alerts  threeOptions:self
                        title:@"Review StrongBox?"
                      message:@"Hi, I'm Mark. I'm the developer of StrongBox.\nI would really appreciate it if you could rate this app in the App Store for me.\n\nWould you be so kind?"
            defaultButtonText:@"Sure, take me there!"
             secondButtonText:@"Naah"
              thirdButtonText:@"Like, maybe later!"
                       action:^(int response) {
                           if (response == 0) {
                               [self openAppStoreForReview];
                               [[Settings sharedInstance] setUserHasBeenPromptedForReview:1];
                           }
                           else if (response == 1) {
                               [[Settings sharedInstance] setUserHasBeenPromptedForReview:1];
                           }
                       }];
    }
}

- (IBAction)onTouchID911:(id)sender {
    NSString *message = [NSString stringWithFormat:@"You can enable Touch ID temporarily up to a maximum of %d times under the free version of StrongBox. This is to allow you to possibly recover from a situation where you've forgotten your master password because you were using Touch ID before. This may allow you access to your safe after you've decided not to upgrade to the Pro version. Once you have access to your safe you can then change your master password. This is an emergency, temporary and convenenience feature only. You SHOULD ALWAYS know your master password. Please upgrade if you'd like to continue using Touch ID.\n\nDo you want to enable emergency Touch ID for your next safe open?", kTouchId911Limit];
    
    [Alerts yesNo:self
            title:@"Emergency Touch ID Activation"
          message:message
           action:^(BOOL response) {
        if(response) {
            self.touchId911 = YES;
            [[Settings sharedInstance] incrementTouchId911Count];
            
            [Alerts info:self title:@"Emergency Touch ID Enabled" message:@"You can use Touch ID now for your next Safe Open. If you do not know your Master Password you should change it immediately in Settings. You can also export the safe to another application. Otherwise I would ask you to consider supporting the app by upgrading.\n\n-Mark"];
        }
    }];
}

@end
