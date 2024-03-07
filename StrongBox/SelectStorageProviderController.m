//
//  SelectStorageProviderController.m
//  StrongBox
//
//  Created by Mark on 08/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SelectStorageProviderController.h"
#import "LocalDeviceStorageProvider.h"
#import "CustomStorageProviderTableViewCell.h"
#import "DatabaseModel.h"
#import "Alerts.h"
#import "StorageBrowserTableViewController.h"

#ifndef NO_SFTP_WEBDAV_SP
#import "SFTPStorageProvider.h"
#import "WebDAVStorageProvider.h"
#endif

#import <MobileCoreServices/MobileCoreServices.h>
#import "StrongboxiOSFilesManager.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "AppPreferences.h"
#import "NSString+Extensions.h"
#import "SafeStorageProviderFactory.h"
#import "Serializator.h"

#import "WebDAVConnectionsViewController.h"
#import "SFTPConnectionsViewController.h"

#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS

#import "GoogleDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"

#endif

#import "AppleICloudProvider.h"
#import "Strongbox-Swift.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "NSArray+Extensions.h"

NSString *const kSectionThirdParty = @"3rd_party";
NSString *const kSectionOwnServer = @"own_servers";
NSString *const kSectioniOSNative = @"native";
NSString *const kSectionStrongboxWifiSync = @"wifi-sync";
NSString *const kSectionMiscellaneous = @"misc";

static NSString* kWifiBrowserResultsUpdatedNotification = @"wifiBrowserResultsUpdated";

@interface SelectStorageProviderController () <UIDocumentPickerDelegate>

@property MutableOrderedDictionary<NSString*, NSArray<NSNumber*>*> *providersForSectionMap;
@property NSArray<WiFiSyncServerConfig*> *wiFiSyncDevices;

@end

@implementation SelectStorageProviderController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(self.existing) {
        [self.navigationItem setPrompt:NSLocalizedString(@"sspc_select_where_existing_stored", @"Select where your existing database is stored")];
    }
    else {
        [self.navigationItem setPrompt:NSLocalizedString(@"sspc_select_where_store_new", @"Select where you would like to store your new database")];
    }

    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;
}

- (void)loadWiFiSyncDevices {
#ifndef NO_SFTP_WEBDAV_SP
    NSMutableArray<WiFiSyncServerConfig*>* allWiFiSyncDevices = [WiFiSyncBrowser.shared.availableServers mutableCopy];
    
    NSArray<WiFiSyncServerConfig*>* wiFiSyncDevices = allWiFiSyncDevices;
    
    if ( WiFiSyncServer.shared.isRunning ) { 
        NSString* myName = WiFiSyncServer.shared.lastRegisteredServiceName;
        
        if ( myName.length ) {
            wiFiSyncDevices = [allWiFiSyncDevices filter:^BOOL(WiFiSyncServerConfig * _Nonnull obj) {
                return ![obj.name isEqualToString:myName];
            }];
        }
    }

    self.wiFiSyncDevices = wiFiSyncDevices;
#else
    self.wiFiSyncDevices = @[];
#endif
}

- (void)observeWiFiSyncDevices {
    [NSNotificationCenter.defaultCenter addObserver:self 
                                           selector:@selector(onWiFiDevicesChanged)
                                               name:kWifiBrowserResultsUpdatedNotification
                                             object:nil];
}

- (void)onWiFiDevicesChanged {
    [self refresh];
}

- (void)refresh {
    [self loadWiFiSyncDevices];
    
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    





    self.providersForSectionMap = [[MutableOrderedDictionary alloc] init];
    
    
    
    if ( self.existing ) {
        self.providersForSectionMap[kSectioniOSNative] = @[@(kFilesAppUrlBookmark)];

        if ( !AppPreferences.sharedInstance.disableWiFiSyncClientMode && StrongboxProductBundle.supportsWiFiSync ) {
            [self loadWiFiSyncDevices];
            [self observeWiFiSyncDevices];
            
            self.providersForSectionMap[kSectionStrongboxWifiSync] = @[@(-1)]; 
        }
    }
    else {
        self.providersForSectionMap[kSectioniOSNative] = AppPreferences.sharedInstance.disableNetworkBasedFeatures ? @[@(kFilesAppUrlBookmark), @(kLocalDevice)] : @[@(kLocalDevice), @(kFilesAppUrlBookmark), @(kiCloud)];
    }
    
    
    
    if ( !AppPreferences.sharedInstance.disableThirdPartyStorageOptions && !AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        self.providersForSectionMap[kSectionThirdParty] = @[
            @(kTwoDrive),
            @(kDropbox),
            @(kGoogleDrive),
        ];
    }
    
    
    
    if ( !AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        self.providersForSectionMap[kSectionOwnServer] = @[
            @(kWebDAV),
            @(kSFTP),
        ];
    }
    
    
    
    if ( self.existing && !AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        BOOL showTransferOverLanServer = !AppPreferences.sharedInstance.disableNetworkBasedFeatures && StrongboxProductBundle.supportsWiFiSync;
        
        self.providersForSectionMap[kSectionMiscellaneous] = showTransferOverLanServer ? @[ @(-1), @(-1) ] : @[ @(-1) ]; 
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.providersForSectionMap.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString* sectionName = self.providersForSectionMap.keys[section];
    
    if ( [sectionName isEqualToString:kSectionStrongboxWifiSync] ) {
        return MAX( self.wiFiSyncDevices.count, 1); 
    }
    else {
        return self.providersForSectionMap[sectionName].count;
    }
}

- (void)getWifiSyncCell:(CustomStorageProviderTableViewCell *)cell 
              indexPath:(NSIndexPath * _Nonnull)indexPath {
    if ( self.wiFiSyncDevices.count == 0 ) {
        if ( AppPreferences.sharedInstance.wiFiSyncHasRequestedNetworkPermissions ) {
            if ( WiFiSyncBrowser.shared.isRunning ) {
                cell.text.text = NSLocalizedString(@"wifi_sync_no_devices_found", @"No Devices Found");
                cell.text.font = FontManager.sharedInstance.regularFont;
                cell.image.image = [UIImage systemImageNamed:@"externaldrive.fill.badge.wifi"];
                cell.text.textColor = UIColor.secondaryLabelColor;
                cell.userInteractionEnabled = NO;
                cell.image.tintColor = UIColor.secondaryLabelColor;
            }
            else {
                if ( WiFiSyncBrowser.shared.networkPermissionsDenied ) {
                    cell.text.text = NSLocalizedString(@"wifi_sync_local_network_access_denied", @"Local Network Access Denied");
                    cell.userInteractionEnabled = YES;
                }
                else {
                    cell.text.text = WiFiSyncBrowser.shared.lastError ? WiFiSyncBrowser.shared.lastError : NSLocalizedString(@"alerts_unknown_error", @"Unknown Error");
                    cell.userInteractionEnabled = NO;
                }
                
                cell.text.font = FontManager.sharedInstance.regularFont;
                cell.text.textColor = UIColor.systemOrangeColor;

                UIImage* image = [UIImage systemImageNamed:@"externaldrive.fill.badge.wifi"];
                
                if (@available(iOS 15.0, *)) {
                    UIImageSymbolConfiguration* config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.systemRedColor, UIColor.systemOrangeColor]];
                    image = [image imageByApplyingSymbolConfiguration:config];
                }
                
                cell.image.image = image;
            }
        }
        else {
            cell.text.text = NSLocalizedString(@"wifi_sync_allow_network_access", @"Allow Local Network Access...");
            cell.text.font = FontManager.sharedInstance.headlineFont;
            
            if (@available(iOS 16.0, *)) {
                UIImage* image = [UIImage systemImageNamed:@"person.badge.shield.checkmark.fill"];
                
                UIImageSymbolConfiguration* config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.systemOrangeColor, UIColor.secondaryLabelColor]];
                image = [image imageByApplyingSymbolConfiguration:config];
            
                cell.image.tintColor = nil;
                cell.image.image = image;
            }
            else {
                cell.image.image = [UIImage systemImageNamed:@"person.fill.checkmark"];
                cell.image.tintColor = UIColor.linkColor;
            }
            
            cell.text.textColor = UIColor.linkColor;
            cell.userInteractionEnabled = YES;
        }
    }
    else {
        cell.text.text = self.wiFiSyncDevices[indexPath.row].name;
        cell.text.textColor = UIColor.labelColor;
        
        UIImage* image = [UIImage systemImageNamed:@"externaldrive.fill.badge.wifi"];
        
        if (@available(iOS 15.0, *)) {
            UIImageSymbolConfiguration* config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.systemGreenColor, UIColor.systemBlueColor]];
            image = [image imageByApplyingSymbolConfiguration:config];
        }
        
        cell.image.image = image;
        cell.userInteractionEnabled = YES;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomStorageProviderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"storageProviderReuseIdentifier" forIndexPath:indexPath];

    NSString* sectionName = self.providersForSectionMap.keys[indexPath.section];
    NSArray<NSNumber*>* providers = self.providersForSectionMap[sectionName];
    
    cell.text.textColor = UIColor.labelColor;
    cell.userInteractionEnabled = YES;
    cell.image.tintColor = nil;
    cell.text.font = FontManager.sharedInstance.headlineFont;
    
    if ( sectionName == kSectionMiscellaneous ) {
        cell.text.font = FontManager.sharedInstance.regularFont;
        
        if ( indexPath.row == 0 ) {
            cell.text.text = NSLocalizedString(@"sspc_copy_from_url_action", @"Copy from URL...");
            cell.image.image =  [UIImage imageNamed:@"cloud-url"];
        }
        else {
            cell.text.text = NSLocalizedString(@"safes_vc_wifi_transfer", @"Transfer Over Local Network");
            cell.image.image =  [UIImage systemImageNamed:@"network"];
        }
    }
    else if ( [sectionName isEqualToString:kSectionStrongboxWifiSync] ) {
        [self getWifiSyncCell:cell indexPath:indexPath];
    }
    else {
        NSNumber* providerId = providers[indexPath.row];

        cell.text.text = providerId.intValue == kFilesAppUrlBookmark ? NSLocalizedString(@"sspc_ios_files_storage_location", @"Files") : [SafeStorageProviderFactory getStorageDisplayNameForProvider:providerId.intValue];
        cell.image.image = providerId.intValue == kFilesAppUrlBookmark ? [UIImage systemImageNamed:@"folder.circle"] : [SafeStorageProviderFactory getImageForProvider:providerId.intValue];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* sectionName = self.providersForSectionMap.keys[indexPath.section];
    NSArray<NSNumber*>* providers = self.providersForSectionMap[sectionName];
    
    if ( sectionName == kSectionMiscellaneous ) {
        if ( indexPath.row == 0 ) {
            [self initiateManualImportFromUrl];
        }
        else {
            [self onAddThroughLocalNetworkServer];
        }
    }
    else if ( [sectionName isEqualToString:kSectionStrongboxWifiSync] ) {
        if ( AppPreferences.sharedInstance.wiFiSyncHasRequestedNetworkPermissions ) {
            if ( WiFiSyncBrowser.shared.isRunning ) {
                if ( self.wiFiSyncDevices.count > 0 ) {
                    if ( AppPreferences.sharedInstance.isPro ) {
                        WiFiSyncServerConfig* config = self.wiFiSyncDevices[indexPath.row];
                        [self getWiFiSyncConnectionPassCodeAndBrowse:config];
                    }
                    else {
                        [Alerts info:self
                               title:NSLocalizedString(@"mac_autofill_pro_feature_title", @"Pro Feature")
                             message:NSLocalizedString(@"wifi_sync_pro_feature_notice", @"Wi-Fi Sync is a Pro feature.\n\nUpgrade now to enjoy.")];
                    }
                }
            }
            else {
                if ( WiFiSyncBrowser.shared.networkPermissionsDenied ) {
                    [Utils openStrongboxSettingsAndPermissionsScreen];
                }
            }
        }
        else {
            __weak SelectStorageProviderController* weakSelf = self;
            
            [WiFiSyncBrowser.shared startBrowsing:NO
                                       completion:^(BOOL success) {
                AppPreferences.sharedInstance.wiFiSyncHasRequestedNetworkPermissions = YES;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf refresh];
                });
            }];
        }
    }
    else {
        NSNumber* providerId = providers[indexPath.row];
        
        if (providerId.intValue == kFilesAppUrlBookmark) {
            if (self.existing) {
                [self onAddThroughFilesApp];
            }
            else {
                [self onCreateThroughFilesApp];
            }
        }
#ifndef NO_SFTP_WEBDAV_SP
        else if ( providerId.intValue == kWebDAV ) {
            [self getWebDAVConnection];
        }
        else if ( providerId.intValue == kSFTP ) {
            [self getSFTPConnection];
        }
#endif
        else if ( providerId.intValue == kLocalDevice ) {
            [Alerts yesNo:self
                    title:NSLocalizedString(@"sspc_local_device_storage_warning_title", @"Local Device Database Caveat")
                  message:NSLocalizedString(@"sspc_local_device_storage_warning_message", @"Since a local database is only stored on this device, any loss of this device will lead to the loss of all passwords stored within this database. You may want to consider using a cloud storage provider, such as the ones supported by Strongbox to avoid catastrophic data loss.\n\nWould you still like to proceed with creating a local device database?")
                   action:^(BOOL response) {
                if (response) {
                    id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:providerId.intValue];
                    [self segueToBrowserOrAdd:provider];
                }
            }];
        }
        else {
            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:providerId.intValue];
            [self segueToBrowserOrAdd:provider];
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* sectionName = self.providersForSectionMap.keys[section];

    if ( self.providersForSectionMap[sectionName].count == 0 ) {
        return nil;
    }
    
    if ( [sectionName isEqualToString:kSectionOwnServer] ) {
        return NSLocalizedString(@"select_storage_header_servers", @"Servers");
    }
    else if ( [sectionName isEqualToString:kSectioniOSNative] ) {
        return NSLocalizedString(@"select_storage_header_built_in", @"Built-In");
    }
    else if ( [sectionName isEqualToString:kSectionStrongboxWifiSync] ) {
        return NSLocalizedString(@"storage_provider_name_wifi_sync", @"Wi-Fi Sync");
    }
    else if ( [sectionName isEqualToString:kSectionMiscellaneous] ) {
        return NSLocalizedString(@"select_storage_header_one_time_copy", @"One Time Copy Options");
    }
    else if ( [sectionName isEqualToString:kSectionThirdParty] ) {
        return NSLocalizedString(@"select_storage_header_third_party", @"Third Party Integrations");
    }
    else {
        return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString* sectionName = self.providersForSectionMap.keys[section];
    
    if ( self.providersForSectionMap[sectionName].count == 0 ) {
        return nil;
    }
    
    if ( [sectionName isEqualToString:kSectionOwnServer] ) {
        return NSLocalizedString(@"select_storage_footer_servers", @"For advanced users, connect to your NAS or other personal server anywhere on your network or the Internet via these standard protocols.");
    }
    else if ( [sectionName isEqualToString:kSectionStrongboxWifiSync] ) {
        return NSLocalizedString(@"select_storage_footer_wifi", @"Use Strongbox's advanced 'Wi-Fi Sync' to stay up to date without the use of a server via Wi-Fi (or any LAN connection). This is a Pro feature.");
    }
    else if ( [sectionName isEqualToString:kSectioniOSNative] ) {
        return self.existing ? NSLocalizedString(@"select_storage_footer_files_only", @"Connect to your database via the Files app.") : NSLocalizedString(@"select_storage_footer_files_or_local_device", @"Connect to your database via the Files app or store your database on this device (don't forget to backup though).");
    }
    else if ( [sectionName isEqualToString:kSectionMiscellaneous] ) {
        return NSLocalizedString(@"select_storage_footer_one_time_copy", @"Use these methods to transfer a database into Strongbox as a local copy. This does not maintain a connection with any server or sync anywhere after the initial transfer.");
    }
    else if ( [sectionName isEqualToString:kSectionThirdParty] ) {
        return NSLocalizedString(@"select_storage_footer_third_party", @"We've integrated with these popular online drives. These integrations often provide superior sync than using the built-in Files app.");
    }
    else {
        return nil;
    }
}

- (void)onAddThroughLocalNetworkServer {
    [self performSegueWithIdentifier:@"segueToLocalHttpServer" sender:nil];
}

- (void)initiateManualImportFromUrl {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:NSLocalizedString(@"sspc_manual_import_placeholder_url", @"URL")
                            title:NSLocalizedString(@"sspc_manual_import_enter_url_title", @"Enter URL")
                          message:NSLocalizedString(@"sspc_manual_import_enter_url_message", @"Please Enter the URL of the Database File.")
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSURL *url = text.urlExtendedParse;
                               NSLog(@"URL: %@", url);
                               
                               if (url) {
                                   [self importFromManualUiUrl:url];
                               }
                           }
                       }];
}

- (void)onCreateThroughFilesApp {
    self.onDone([SelectedStorageParameters parametersForFilesApp:nil withProvider:FilesAppUrlBookmarkProvider.sharedInstance]);
}

- (void)onAddThroughFilesApp {
    UTType* type = [UTType typeWithIdentifier:(NSString*)kUTTypeItem];
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type]];
    vc.delegate = self;
    [self presentViewController:vc animated:YES completion:nil];
}



#ifndef NO_SFTP_WEBDAV_SP
- (void)getWebDAVConnection {
    WebDAVConnectionsViewController* vc = [WebDAVConnectionsViewController instantiateFromStoryboard];
    vc.selectMode = YES;
    vc.onSelected = ^(WebDAVSessionConfiguration * _Nonnull connection) {
        WebDAVStorageProvider* sp = [[WebDAVStorageProvider alloc] init];
        sp.explicitConnection = connection;
        sp.maintainSessionForListing = YES;
        [self segueToBrowserOrAdd:sp];
    };
    
    [vc presentFromViewController:self];
}

- (void)getSFTPConnection {
    SFTPConnectionsViewController* vc = [SFTPConnectionsViewController instantiateFromStoryboard];
    vc.selectMode = YES;
    vc.onSelected = ^(SFTPSessionConfiguration * _Nonnull connection) {
        SFTPStorageProvider* sp = [[SFTPStorageProvider alloc] init];
        sp.explicitConnection = connection;
        sp.maintainSessionForListing = YES;
        [self segueToBrowserOrAdd:sp];
    };
    
    [vc presentFromViewController:self];
}

#endif

- (void)getWiFiSyncConnectionPassCodeAndBrowse:(WiFiSyncServerConfig*)config {
    __weak SelectStorageProviderController* weakSelf = self;
    
    UIViewController* vc = [SwiftUIViewFactory makeWiFiSyncPasscodeViewController:config 
                                                                          onDone:^(WiFiSyncServerConfig * _Nonnull config, NSString * _Nullable passcode) {
        WiFiSyncStorageProvider *sp = [[WiFiSyncStorageProvider alloc] init];
            
        config.passcode = passcode;
        sp.explicitConnectionConfig = config;
            
        [weakSelf segueToBrowserOrAdd:sp];
    }];

    [self presentViewController:vc animated:YES completion:nil];
}




- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];

    self.onDone([SelectedStorageParameters parametersForFilesApp:url withProvider:FilesAppUrlBookmarkProvider.sharedInstance]);
}

- (void)importFromManualUiUrl:(NSURL *)importURL {
    NSError* error;
    NSData *importedData = [NSData dataWithContentsOfURL:importURL options:kNilOptions error:&error];  
    
    if(error) {
        [Alerts error:self
                title:NSLocalizedString(@"sspc_manual_import_error_title", @"Error Reading from URL")
                error:error];
        return;
    }
    
    if (![Serializator isValidDatabaseWithPrefix:importedData error:&error] ) {
        [Alerts error:self
                title:NSLocalizedString(@"sspc_error_invalid_database", @"Invalid Database")
                error:error];
        
        return;
    }
    
    self.onDone([SelectedStorageParameters parametersForManualDownload:importedData]);
}

- (void)segueToBrowserOrAdd:(id<SafeStorageProvider>)provider {
    if ( provider.privacyOptInRequired ) {
        [Alerts checkThirdPartyLibOptInOK:self completion:^(BOOL optInOK) {
            if (optInOK) {
                [self continueSegueToBrowserOrAdd:provider];
            }
        }];
    }
    else {
        [self continueSegueToBrowserOrAdd:provider];
    }
}

- (void)continueSegueToBrowserOrAdd:(id<SafeStorageProvider>)provider {
    BOOL storageBrowseRequired = (self.existing && provider.browsableExisting) || (!self.existing && provider.browsableNew);

    if (storageBrowseRequired) {
        [self performSegueWithIdentifier:@"SegueToBrowser" sender:provider];
    }
    else {
        if(self.existing) {
            [Alerts info:self
                   title:@"Error Selecting Storage Provider"
                 message:@"Please contact support@strongboxsafe.com if you receive this message. It looks like there is a problem with this Storage provider"
              completion:^{
                self.onDone(SelectedStorageParameters.userCancelled); 
            }];
        }
        else {
            self.onDone([SelectedStorageParameters parametersForNativeProviderCreate:provider folder:nil]);
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"SegueToBrowser"]) {
        StorageBrowserTableViewController *vc = segue.destinationViewController;
        
        vc.existing = self.existing;
        vc.safeStorageProvider = sender;
        vc.parentFolder = nil;
        vc.onDone = self.onDone;
    }
}

- (IBAction)onCancel:(id)sender {
    self.onDone([SelectedStorageParameters userCancelled]);
}

@end
