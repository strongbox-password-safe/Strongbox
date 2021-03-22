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
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "FileManager.h"
#import "AppPreferences.h"
#import "BookmarksHelper.h"
#import "UITableView+EmptyDataSet.h"

@interface KeyFilesTableViewController () <UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property NSArray<NSURL*>* keyFiles;
@property NSArray<NSURL*>* otherFiles;
@property UIDocumentPickerViewController* importDocPicker;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonOptions;

@end

@implementation KeyFilesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = NO;
    self.tableView.tableFooterView = [UIView new];
    
    self.title = self.manageMode ?
    NSLocalizedString(@"key_files_vc_manage_title", @"Manage Key Files") :
    NSLocalizedString(@"key_files_vc_select_title", @"Select Key File");
    self.buttonOptions.enabled = !self.manageMode;
    self.buttonOptions.tintColor = self.manageMode ? UIColor.clearColor : nil;
    
    [self refresh];
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
    NSURL *directoryURL = FileManager.sharedInstance.documentsDirectory;
    
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
            
            NSLog(@"%@", error);
        }
        else if (![isDirectory boolValue]) {
            if(AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles || ![self isUnlikelyKeyFile:url]) {
                [otherFiles addObject:url];
            }
        }
    }

    self.otherFiles = [otherFiles copy];
}

- (void)loadKeyFiles {
    NSMutableArray* files = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *directoryURL =  FileManager.sharedInstance.keyFilesDirectory;
    
    NSDirectoryEnumerator *enumerator = [fm
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                         options:0
                                         errorHandler:nil];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            
            NSLog(@"%@", error);
        }
        else if (![isDirectory boolValue]) {
            [files addObject:url];
        }
    }
    
    self.keyFiles = [files copy];
}

- (BOOL)isUnlikelyKeyFile:(NSURL*)url {
    if ([url.pathExtension localizedCaseInsensitiveCompare:@"psafe3"] == NSOrderedSame ||
        [url.pathExtension localizedCaseInsensitiveCompare:@"kdbx"] == NSOrderedSame ||
        [url.pathExtension localizedCaseInsensitiveCompare:@"kdb"] == NSOrderedSame) {
        NSLog(@"Filtering Local File as Unlikely Key File [%@]", url.lastPathComponent);
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

- (IBAction)onAddKeyFile:(id)sender {
    self.importDocPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
    self.importDocPicker.delegate = self;
    [self presentViewController:self.importDocPicker animated:YES completion:nil];
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
                          UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
                          vc.delegate = self;
                          
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
            NSLog(@"Error: %@", error);
            [Alerts error:self
                    title:NSLocalizedString(@"key_files_vc_error_reading", @"Error Reading")
                    error:error];
        }
        else {
            NSLog(@"info = [%@]", info);

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
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];

    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"

    [self documentPicker:controller didPickDocumentAtURL:url];
    
    #pragma GCC diagnostic pop
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-implementations"

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url { 
    NSLog(@"didPickDocumentAtURL: %@", url);

    NSError* error;
    
    
    
    [url startAccessingSecurityScopedResource];
    
    __block NSData *data;
    __block NSError *err;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
    [coordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL *newURL) {
        data = [NSData dataWithContentsOfURL:newURL options:NSDataReadingUncached error:&err];
    }];
    
    [url stopAccessingSecurityScopedResource];
    
    if(!data) {
        NSLog(@"Error: %@", err);
        [Alerts error:self
                title:NSLocalizedString(@"key_files_vc_error_reading", @"There was an error reading the Key File")
                error:err
           completion:nil];
        return;
    }

    if (controller == self.importDocPicker) { 
        NSURL* localUrl = [self importToLocal:url data:data error:&error];
        
        if(!localUrl) {
            NSLog(@"Error: %@", error);
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

#pragma GCC diagnostic pop

- (NSURL*)importToLocal:(NSURL*)url data:(NSData*)data error:(NSError**)error {
    NSURL* destination = [FileManager.sharedInstance.keyFilesDirectory URLByAppendingPathComponent:url.lastPathComponent];
    
    NSLog(@"Source: %@", url);
    NSLog(@"Destination: %@", destination);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:destination.path]) {
        NSError* err;
        NSUInteger flags = NSDataWritingWithoutOverwriting;
        if([data writeToURL:destination options:flags error:&err]) {
            NSLog(@"Imported Key File Successfully: %@", destination.lastPathComponent);
            return destination;
        }
        else {
            *error = err;
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
    NSURL *destination = [FileManager.sharedInstance.keyFilesDirectory URLByAppendingPathComponent:url.lastPathComponent];
    
    NSLog(@"Importing Local Key File: [%@] => [%@]", url, destination);
    
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
    NSArray<SafeMetaData*>* assoc = [self getAssociatedDatabase:indexPath.section == 1 ? self.keyFiles[indexPath.row] : self.otherFiles[indexPath.row]];
    
    if(assoc.count) {
        return [NSString stringWithFormat:
                NSLocalizedString(@"key_files_vc_key_file_used_by_fmt", @"Used by %@"), assoc.count > 1 ?
                NSLocalizedString(@"key_files_vc_key_file_used_by_multiple", @"multiple databases") : assoc.firstObject.nickName];
    }
    else {
        return NSLocalizedString(@"key_files_vc_key_file_used_by_none", @"No Known Database Associations");
    }
}

- (NSArray<SafeMetaData*>*)getAssociatedDatabase:(NSURL*)url {
    return [SafesList.sharedInstance.snapshot filter:^BOOL(SafeMetaData * _Nonnull obj) {
        if (obj.keyFileBookmark) {
            NSURL* dbUrl = [BookmarksHelper getExpressReadOnlyUrlFromBookmark:obj.keyFileBookmark];
            return [dbUrl isEqual:url];
        }
        else {
            return NO;
        }
    }];
}

@end
