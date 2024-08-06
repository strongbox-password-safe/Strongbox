//
//  KeyFilesTableViewController.m
//  Strongbox
//
//  Created by Mark on 28/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeyFilesTableViewController.h"
#import "Alerts.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Utils.h"
#import "IOsUtils.h"
#import "DatabasePreferences.h"
#import "NSArray+Extensions.h"
#import "StrongboxiOSFilesManager.h"
#import "AppPreferences.h"
#import "BookmarksHelper.h"
#import "UITableView+EmptyDataSet.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "ContextMenuHelper.h"
#import "KeyFileManagement.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface KeyFilesTableViewController () <UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property NSArray<NSURL*>* keyFiles;
@property NSArray<NSURL*>* otherFiles;
@property UIDocumentPickerViewController* importDocPicker;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddKeyFile;

@property NSUInteger docPickerMode;
@property KeyFile* keyFileToSave;
@property NSURL* tmpFileToDelete;

@end

@implementation KeyFilesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = NO;
    self.tableView.tableFooterView = [UIView new];
    
    self.title = self.manageMode ?
    NSLocalizedString(@"key_files_vc_manage_title", @"Manage Key Files") :
    NSLocalizedString(@"key_files_vc_select_title", @"Select Key File");
    
    [self setupAddKeyFileMenu];
    
    [self refresh];
}

- (void)setupAddKeyFileMenu {
    __weak KeyFilesTableViewController* weakSelf = self;
    
    UIMenuElement* import = [ContextMenuHelper  getItem:NSLocalizedString(@"kfm_import_key_file_ellipsis", @"Import Key File...")
                                            systemImage:@"folder.circle"
                                                handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onImportKeyFile];
    }];
    
    UIMenuElement* create = [ContextMenuHelper  getItem:NSLocalizedString(@"kfm_create_new_key_file_ellipsis", @"Create New Key File...")
                                            systemImage:@"doc.badge.plus"
                                                handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onCreateKeyFile];
    }];
    
    UIMenuElement* recoverKeyFile = [ContextMenuHelper  getItem:NSLocalizedString(@"kfm_recover_key_file_ellipsis", @"Recover Key File...")
                                                    systemImage:@"key"
                                                        handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onRecoverKeyFile];
    }];
    
    UIMenuElement* singleUse = [ContextMenuHelper  getItem:NSLocalizedString(@"kfm_single_use_key_file_ellipsis", @"Single Use (No Import)")
                                               systemImage:@"gear"
                                                   handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onAdvancedOptions:nil];
    }];
    
    
    
#ifndef IS_APP_EXTENSION
    UIMenu* menu1 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:@[import, create]];
    
    UIMenu* menu2 = [UIMenu menuWithTitle:NSLocalizedString(@"generic_advanced_noun", @"Advanced")
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:self.manageMode ? @[recoverKeyFile] : @[singleUse, recoverKeyFile]];
    
#else
    UIMenu* menu1 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:@[import]];
    
    UIMenu* menu2 = [UIMenu menuWithTitle:NSLocalizedString(@"generic_advanced_noun", @"Advanced")
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:self.manageMode ? @[] : @[singleUse]];
#endif

    UIMenu* menu = [UIMenu menuWithTitle:@""
                                   image:nil
                              identifier:nil
                                 options:kNilOptions
                                children:@[menu1, menu2]];

    self.buttonAddKeyFile.action = nil;
    self.buttonAddKeyFile.menu = menu;
}

- (NSAttributedString *)getTitleForEmptyDataSet {
    NSString *text = NSLocalizedString(@"key_files_vc_empty_key_files_title", @"No Key Files Found. Tap '+' to import one.");
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleBody],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (void)refresh {
    [self loadKeyFiles];
    [self loadLocalFiles];
    
    [self.tableView reloadData];
}

- (void)loadLocalFiles {
    NSMutableArray* otherFiles = [NSMutableArray array];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *directoryURL = StrongboxFilesManager.sharedInstance.documentsDirectory;
    
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    
    NSDirectoryEnumerator *enumerator = [fm
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:nil];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            slog(@"%@", error);
        }
        else if (![isDirectory boolValue]) {
            if(AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles || ![self isUnlikelyKeyFile:url]) {
                [otherFiles addObject:url];
            }
        }
    }
    
    self.otherFiles = [otherFiles sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSURL* u1 = obj1;
        NSURL* u2 = obj2;
        
        return finderStringCompare(u1.lastPathComponent, u2.lastPathComponent);
    }];
}

- (void)loadKeyFiles {
    NSMutableArray* files = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *directoryURL =  StrongboxFilesManager.sharedInstance.keyFilesDirectory;
    
    NSDirectoryEnumerator *enumerator = [fm
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                         options:0
                                         errorHandler:nil];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            slog(@"%@", error);
        }
        else if (![isDirectory boolValue]) {
            [files addObject:url];
        }
    }
    
    self.keyFiles = [files sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSURL* u1 = obj1;
        NSURL* u2 = obj2;
        
        return finderStringCompare(u1.lastPathComponent, u2.lastPathComponent);
    }];
}

- (BOOL)isUnlikelyKeyFile:(NSURL*)url {
    if ([url.pathExtension localizedCaseInsensitiveCompare:@"psafe3"] == NSOrderedSame ||
        [url.pathExtension localizedCaseInsensitiveCompare:@"kdbx"] == NSOrderedSame ||
        [url.pathExtension localizedCaseInsensitiveCompare:@"kdb"] == NSOrderedSame) {

        return YES;
    }
    
    return NO;
}

- (IBAction)onCancel:(id)sender {
    if(!self.manageMode) {
        self.onDone(NO, nil, nil);
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (IBAction)onAdvancedOptions:(id)sender {
    [Alerts threeOptions:self
                   title:NSLocalizedString(@"key_files_vc_one_time_key_file_source_title", @"One Time Key File Source")
                 message:NSLocalizedString(@"key_files_vc_one_time_key_file_source_message", @"Select where you would like to choose your Key File from. This file will not be stored locally or remembered.")
       defaultButtonText:NSLocalizedString(@"key_files_vc_one_time_key_file_source_option_files", @"Files...")
        secondButtonText:NSLocalizedString(@"key_files_vc_one_time_key_file_source_option_photos", @"Photo Library...")
         thirdButtonText:NSLocalizedString(@"generic_cancel", @"Cancel")
                  action:^(int response) {
        if(response == 0) {
            UTType* type = [UTType typeWithIdentifier:(NSString*)kUTTypeItem];
            UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type]];
            
            
            vc.delegate = self;
            self.docPickerMode = 2;
            
            [self presentViewController:vc animated:YES completion:nil];
        }
        else if (response == 1) {
            UIImagePickerController *vc = [[UIImagePickerController alloc] init];
            vc.videoQuality = UIImagePickerControllerQualityTypeHigh;
            vc.delegate = self;
            BOOL available = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
            
            if(!available) {
                [Alerts info:self
                       title:NSLocalizedString(@"key_files_vc_error_photos_unavailable_title", @"Photo Library Unavailable")
                     message:NSLocalizedString(@"key_files_vc_error_photos_unavailable_message", @"Could not access Photo Library. Does Strongbox have Permission?")];
                return;
            }
            
            vc.mediaTypes = @[(NSString*)kUTTypeImage];
            vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            
            [self presentViewController:vc animated:YES completion:nil];
        }
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        NSError* error;
        NSData* data = [Utils getImageDataFromPickedImage:info error:&error];
        
        if(!data) {
            slog(@"Error: %@", error);
            [Alerts error:self
                    title:NSLocalizedString(@"key_files_vc_error_reading", @"Error Reading")
                    error:error];
        }
        else {
            slog(@"info = [%@]", info);
            
            if(self.onDone) {
                self.onDone(YES, nil, data);
                [self.navigationController popViewControllerAnimated:YES];
            }
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {

    
    NSURL* url = [urls objectAtIndex:0];
    
    if ( self.docPickerMode == 1 ) {
        [self onKeyFileSuccessfullyExported:url];
    }
    else {
        
        
        if (! [url startAccessingSecurityScopedResource] ) {
            slog(@"🔴 Could not securely access URL!");
        }
        
        __block NSData *data;
        __block NSError *err;
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
        NSError* error;

        [coordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL *newURL) {
            data = [NSData dataWithContentsOfURL:newURL options:NSDataReadingUncached error:&err];
        }];
        
        [url stopAccessingSecurityScopedResource];
        
        if(!data) {
            slog(@"Error: %@", err);
            [Alerts error:self
                    title:NSLocalizedString(@"key_files_vc_error_reading", @"There was an error reading the Key File")
                    error:err
               completion:nil];
            return;
        }
        
        if ( controller == self.importDocPicker ) { 
            [self importWithUrl:url data:data];
        }
        else {
            if(!self.manageMode) {
                self.onDone(YES, nil, data);
                [self.navigationController popViewControllerAnimated:YES];
            }
            else {
                [self refresh];
            }
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    if ( self.tmpFileToDelete ) {
        [NSFileManager.defaultManager removeItemAtURL:self.tmpFileToDelete error:nil];
        self.tmpFileToDelete = nil;
    }
}

- (void)importWithUrl:(NSURL*)url data:(NSData*)data {
    NSError* error;
    NSURL* localUrl = [self importToLocal:url.lastPathComponent data:data error:&error];
    
    if(!localUrl) {
        slog(@"Error: %@", error);
        [Alerts error:self
                title:NSLocalizedString(@"key_files_vc_error_importing", @"There was an importing the Key File (does it already exist?)")
                error:error
           completion:nil];
        return;
    }
    else {
        if(!self.manageMode) {
            self.onDone(YES, localUrl, nil);
            [self.navigationController popViewControllerAnimated:YES];
        }
        else {
            [self refresh];
        }
    }
}

- (NSURL*)importToLocal:(NSString*)filename data:(NSData*)data error:(NSError**)error {
    NSURL* destination = [StrongboxFilesManager.sharedInstance.keyFilesDirectory URLByAppendingPathComponent:filename];
    


    
    if (![[NSFileManager defaultManager] fileExistsAtPath:destination.path]) {
        NSError* err;
        NSUInteger flags = NSDataWritingWithoutOverwriting;
        if([data writeToURL:destination options:flags error:&err]) {

            return destination;
        }
        else {
            if ( error ) {
                *error = err;
            }
        }
    }
    else {
        [Alerts info:self
               title:NSLocalizedString(@"key_files_vc_error_file_already_exists_title", @"File Already Exists")
             message:NSLocalizedString(@"key_files_vc_error_file_already_exists_message", @"A file with this name already exists in the Key Files directory.")];
    }
    
    return nil;
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(section == 0) {
        return nil;
    }
    else if (section == 1) {
        return self.keyFiles.count == 0 ? nil : NSLocalizedString(@"key_files_vc_section_header_imported", @"Imported Key Files (Auto-Fill Enabled)");
    }
    else if (section == 2) {
        return self.otherFiles.count == 0 ? nil : NSLocalizedString(@"key_files_vc_section_header_local", @"Documents Folder (Auto-Fill not supported)");
    }
    
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger totalRows = (self.manageMode ? 0 : 1) + self.keyFiles.count + self.otherFiles.count;
    
    [self.tableView setEmptyTitle:(totalRows == 0) ? [self getTitleForEmptyDataSet] : nil];
    
    if(section == 0) {
        return self.manageMode ? 0 : 1;
    }
    else if(section == 1) {
        return self.keyFiles.count;
    }
    else if (section == 2) {
        return self.otherFiles.count;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"keyFileIdentifier" forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    if(indexPath.section == 0) {
        cell.textLabel.text = NSLocalizedString(@"key_files_vc_no_key_file", @"No Key File");
        cell.imageView.image = [UIImage imageNamed:@"cancel"];
        cell.imageView.tintColor = UIColor.darkGrayColor;
        
        if(self.keyFiles.count == 0 && self.otherFiles.count == 0)
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        
        cell.detailTextLabel.text = nil;
    }
    else if(indexPath.section == 1){
        NSURL* keyFile = self.keyFiles[indexPath.row];
        
        cell.textLabel.text = keyFile.lastPathComponent;
        cell.imageView.image =  [UIImage imageNamed:@"key"];
        cell.imageView.tintColor = nil;
        
        if([keyFile isEqual:self.selectedUrl]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        
        cell.detailTextLabel.text = self.manageMode ? [self getAssociatedDatabaseSubtitle:indexPath] : nil;
    }
    else if(indexPath.section == 2){
        NSURL* keyFile = self.otherFiles[indexPath.row];
        
        cell.textLabel.text = keyFile.lastPathComponent;
        cell.imageView.image =  [UIImage imageNamed:@"file"];
        cell.imageView.tintColor = nil;
        
        if([keyFile isEqual:self.selectedUrl]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        
        cell.detailTextLabel.text = self.manageMode ? [self getAssociatedDatabaseSubtitle:indexPath] : nil;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(!self.manageMode) {
        if(indexPath.section == 0) {
            self.onDone(YES, nil, nil);
        }
        else if(indexPath.section == 1) {
            NSURL* url = self.keyFiles[indexPath.row];
            self.onDone(YES, url, nil);
        }
        else if(indexPath.section == 2) {
            NSURL* url = self.otherFiles[indexPath.row];
            self.onDone(YES, url, nil);
        }
        
        [self.navigationController popViewControllerAnimated:YES];
    }
    else {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return (indexPath.section != 0);
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault
                                                                            title:NSLocalizedString(@"key_files_vc_option_remove", @"Remove")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeFile:indexPath];
    }];
    
    UITableViewRowAction *importAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault
                                                                            title:NSLocalizedString(@"key_files_vc_option_import", @"Import")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self importLocalFile:indexPath];
    }];
    importAction.backgroundColor = UIColor.systemBlueColor;
    
    return indexPath.section == 2 ? @[removeAction, importAction] : @[removeAction];
}

- (void)importLocalFile:(NSIndexPath*)indexPath {
    NSURL* url = self.otherFiles[indexPath.row];
    NSURL *destination = [StrongboxFilesManager.sharedInstance.keyFilesDirectory URLByAppendingPathComponent:url.lastPathComponent];
    

    
    [Alerts twoOptionsWithCancel:self
                           title:NSLocalizedString(@"key_files_vc_remove_after_import_title", @"Remove After Import")
                         message:NSLocalizedString(@"key_files_vc_remove_after_import_message", @"Do you want to remove the key file from the local Documents folder after import? This will mean it is not visible in iOS Files or accessible via iTunes File Sharing?")
               defaultButtonText:NSLocalizedString(@"key_files_vc_remove_after_import_option_yes", @"Yes, Remove Local Copy")
                secondButtonText:NSLocalizedString(@"key_files_vc_remove_after_import_option_no", @"No, Keep Local Copy")
                          action:^(int response) {
        
        NSError* error;
        if(response == 1) {
            if(![NSFileManager.defaultManager copyItemAtURL:url toURL:destination error:&error]) {
                [Alerts error:self
                        title:NSLocalizedString(@"key_files_vc_import_error_title", @"File could not be Imported")
                        error:error];
            }
        }
        else if (response == 0) {
            if(![NSFileManager.defaultManager moveItemAtURL:url toURL:destination error:&error]) {
                [Alerts error:self
                        title:NSLocalizedString(@"key_files_vc_import_error_title", @"File could not be Imported")
                        error:error];
            }
        }
        
        [self refresh];
    }];
}

- (void)removeFile:(NSIndexPath * _Nonnull)indexPath {
    NSError* error;
    NSURL* url;
    
    if(indexPath.section == 0) {
        return; 
    }
    else if(indexPath.section == 1) {
        url = self.keyFiles[indexPath.row];
    }
    else {
        url = self.otherFiles[indexPath.row];
    }
    
    if(![NSFileManager.defaultManager removeItemAtURL:url error:&error]) {
        [Alerts error:self
                title:NSLocalizedString(@"key_files_vc_error_file_not_removed", @"File not removed")
                error:error];
    }
    
    [self refresh];
}

- (NSString*)getAssociatedDatabaseSubtitle:(NSIndexPath*)indexPath {
    NSArray<DatabasePreferences*>* assoc = [self getAssociatedDatabase:indexPath.section == 1 ? self.keyFiles[indexPath.row] : self.otherFiles[indexPath.row]];
    
    if(assoc.count) {
        return [NSString stringWithFormat:
                NSLocalizedString(@"key_files_vc_key_file_used_by_fmt", @"Used by %@"), assoc.count > 1 ?
                NSLocalizedString(@"key_files_vc_key_file_used_by_multiple", @"multiple databases") : assoc.firstObject.nickName];
    }
    else {
        return NSLocalizedString(@"key_files_vc_key_file_used_by_none", @"No Known Database Associations");
    }
}

- (NSArray<DatabasePreferences*>*)getAssociatedDatabase:(NSURL*)url {
    return [DatabasePreferences filteredDatabases:^BOOL(DatabasePreferences * _Nonnull obj) {
        if (obj.keyFileBookmark) {
            NSURL* dbUrl = [BookmarksHelper getExpressReadOnlyUrlFromBookmark:obj.keyFileBookmark];
            return [dbUrl isEqual:url];
        }
        else {
            return NO;
        }
    }];
}



- (void)onImportKeyFile {
    UTType* type = [UTType typeWithIdentifier:(NSString*)kUTTypeItem];
    self.importDocPicker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type]];
    self.importDocPicker.delegate = self;
    self.docPickerMode = 0;
    
    [self presentViewController:self.importDocPicker animated:YES completion:nil];
}

- (void)onCreateKeyFile {
#ifndef IS_APP_EXTENSION
    __weak KeyFilesTableViewController* weakSelf = self;
    
    KeyFile* keyFile = [KeyFileManagement generateNewV2];
        
    UIViewController* vc = [SwiftUIViewFactory showKeyFileGeneratorScreenWithKeyFile:keyFile
                                                      onPrint:^{
        [weakSelf onPrintKeyFileRecoverySheet:keyFile];
    } onSave:^BOOL{
        [weakSelf dismissViewControllerAnimated:YES 
                                     completion:^{
            [weakSelf onSaveKeyFile:keyFile];
        }];

         return NO;
    } onDismiss:^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [self presentViewController:vc animated:YES completion:nil];
#endif
}

- (void)onPrintKeyFileRecoverySheet:(KeyFile*)keyFile {
#ifndef IS_APP_EXTENSION
    [keyFile printRecoverySheet:self];
#endif
}

- (void)onRecoverKeyFile {
#ifndef IS_APP_EXTENSION
    __weak KeyFilesTableViewController* weakSelf = self;

    UIViewController* vc = [SwiftUIViewFactory showKeyFileRecoveryScreenOnRecover:^(KeyFile * _Nonnull keyFile) {
        [weakSelf dismissViewControllerAnimated:YES completion:^{
            [weakSelf onSaveKeyFile:keyFile];
        }];
    } onDismiss:^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }];

    [self presentViewController:vc animated:YES completion:nil];
#endif
}

- (BOOL)onSaveKeyFile:(KeyFile*)keyFile {
    NSURL* url = [self saveKeyFileToTemp:keyFile];
    if ( !url ) {
        [Alerts error:self error:[Utils createNSError:@"Could not save tmp key file!" errorCode:1244]];
        return NO;
    }
        
    UIDocumentPickerViewController* docPicker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[url] asCopy:YES];
    docPicker.delegate = self;
    self.docPickerMode = 1;
    self.keyFileToSave = keyFile;
    self.tmpFileToDelete = url;
    
    [self presentViewController:docPicker animated:YES completion:nil];
    
    return NO;
}

- (NSURL*)saveKeyFileToTemp:(KeyFile*)keyFile {
    NSData* data = [keyFile.xml dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    if ( !data ) {
        slog(@"🔴 Could not get key file data");
        return nil;
    }

    NSString* filename = @"key-file.keyx";

    NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    NSURL* url = [NSURL fileURLWithPath:path];

    NSError* error;
    if ( ![data writeToURL:url options:NSDataWritingWithoutOverwriting error:&error] ) {
        slog(@"🔴 Error in saveKeyFileToTemp %@", error);
        return nil;
    }

    return url;
}

- (void)onKeyFileSuccessfullyExported:(NSURL*)url {
    
    
    if ( self.tmpFileToDelete ) {
        [NSFileManager.defaultManager removeItemAtURL:self.tmpFileToDelete error:nil];
        self.tmpFileToDelete = nil;
    }

    NSString* filename = url.lastPathComponent;

    [self onExportedNewKeyFileDone:self.keyFileToSave filename:filename];
}

- (void)onExportedNewKeyFileDone:(KeyFile*)keyFile filename:(NSString*)filename {
    [Alerts yesNo:self
            title:NSLocalizedString(@"kfm_key_file_saved_title", @"Key File Saved")
          message:NSLocalizedString(@"kfm_key_file_saved_import_now_question", @"Your new key file was successfully saved.\n\nWould you like to import it into Strongbox now?")
           action:^(BOOL response) {
        if ( response ) {
            [self onImportNewKeyFile:keyFile filename:filename];
        }
    }];
}

- (void)onImportNewKeyFile:(KeyFile*)keyFile filename:(NSString*)filename {
    NSData* data = [keyFile.xml dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    if ( !data ) {
        slog(@"🔴 Could not get key file data");
        return;
    }
    
    NSString *uniq = [self getUniqueImportFilename:filename];
    
    NSError* error;
    [self importToLocal:uniq data:data error:&error];
    
    if ( error ) {
        slog(@"🔴 Could not write key file... [%@]", error);
        [Alerts error:self error:error];
    }
    else {
        [self refresh];
    }
}

- (NSString*)getUniqueImportFilename:(NSString*)base {
    NSString* ext = base.pathExtension;
    NSString* withoutExt = [base stringByDeletingPathExtension];

    NSString* filename = [withoutExt stringByAppendingPathExtension:ext];
    NSURL* destination = [StrongboxFilesManager.sharedInstance.keyFilesDirectory URLByAppendingPathComponent:filename];
    
    int i = 1;
    while ( [NSFileManager.defaultManager fileExistsAtPath:destination.path] ) {
        NSString* inc = [withoutExt stringByAppendingFormat:@"-%d", i++];
        filename = [inc stringByAppendingPathExtension:ext];
        destination = [StrongboxFilesManager.sharedInstance.keyFilesDirectory URLByAppendingPathComponent:filename];
    }
    
    return filename;
}

@end
