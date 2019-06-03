//
//  KeyFilesTableViewController.m
//  Strongbox
//
//  Created by Mark on 28/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "KeyFilesTableViewController.h"
#import "Alerts.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Utils.h"
#import "IOsUtils.h"
#import "Settings.h"
#import "LocalDeviceStorageProvider.h"

@interface KeyFilesTableViewController () <UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property NSArray<NSURL*>* keyFiles;
@property NSArray<NSURL*>* otherFiles;
@property UIDocumentPickerViewController* importDocPicker;

@end

@implementation KeyFilesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = NO;
    
    self.tableView.tableFooterView = [UIView new];
    
    [self loadLocalFiles];
}

- (void)loadLocalFiles {
    NSMutableArray* files = [NSMutableArray array];
    NSMutableArray* otherFiles = [NSMutableArray array];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *directoryURL =  [IOsUtils applicationDocumentsDirectory];
    
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
            // handle error
            NSLog(@"%@", error);
        }
        else if (![isDirectory boolValue]) {
            if(Settings.sharedInstance.showAllFilesInLocalKeyFiles || ![self isUnlikelyKeyFile:url]) {
                BOOL isKeyFile = [url.pathExtension caseInsensitiveCompare:@"key"] == NSOrderedSame;
                if(isKeyFile) {
                    [files addObject:url];
                }
                else {
                    [otherFiles addObject:url];
                }
            }
        }
    }

    self.keyFiles = [files copy];
    self.otherFiles = [otherFiles copy];
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
    self.onDone(NO, nil, nil);
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)onAddKeyFile:(id)sender {
    self.importDocPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
    self.importDocPicker.delegate = self;
    [self presentViewController:self.importDocPicker animated:YES completion:nil];
}

- (IBAction)onAdvancedOptions:(id)sender {
    [Alerts threeOptions:self
                   title:@"One Time Key File Source"
                 message:@"Select where you would like to choose your Key File from. This file will not be stored locally or remembered."
       defaultButtonText:@"Files..."
        secondButtonText:@"Photo Library..."
         thirdButtonText:@"Cancel"
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
                                     title:@"Photo Library Unavailable"
                                   message:@"Could not access Photo Library. Does Strongbox have Permission?"];
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
            [Alerts error:self title:@"Error Reading Image" error:error];
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
    NSError* error;
    
    // https://stackoverflow.com/questions/25520453/ios8-uidocumentpickerviewcontroller-get-nsdata
    
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
        [Alerts error:self title:@"There was an error reading the Key File" error:err completion:nil];
        return;
    }

    if (controller == self.importDocPicker) { // Import / copy Local?
        NSURL* localUrl = [self importToLocal:url data:data error:&error];
        
        if(!localUrl) {
            NSLog(@"Error: %@", error);
            [Alerts error:self title:@"There was an importing the Key File (does it already exist?)" error:error completion:nil];
            return;
        }
        else {
            self.onDone(YES, localUrl, nil);
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
    else {
        self.onDone(YES, nil, data);
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (NSURL*)importToLocal:(NSURL*)url data:(NSData*)data error:(NSError**)error {
    NSURL* destination = [[IOsUtils applicationDocumentsDirectory] URLByAppendingPathComponent:url.lastPathComponent];

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
    
    return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(section == 0) {
        return nil;
    }
    else if (section == 1) {
        return self.keyFiles.count == 0 ? nil : @"Key Files";
    }
    else if (section == 2) {
        return self.otherFiles.count == 0 ? nil : @"Other Files";
    }

    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(section == 0) {
        return 1;
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
        cell.textLabel.text = @"No Key File";
        cell.imageView.image = [UIImage imageNamed:@"cancel"];
        cell.imageView.tintColor = UIColor.darkGrayColor;
        
        if(self.keyFiles.count == 0 && self.otherFiles.count == 0)
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    else if(indexPath.section == 1){
        NSURL* keyFile = self.keyFiles[indexPath.row];
        
        cell.textLabel.text = keyFile.lastPathComponent;
        cell.imageView.image =  [UIImage imageNamed:@"key"];
        cell.imageView.tintColor = nil;
        
        if([keyFile isEqual:self.selectedUrl]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    else if(indexPath.section == 2){
        NSURL* keyFile = self.otherFiles[indexPath.row];
        
        cell.textLabel.text = keyFile.lastPathComponent;
        cell.imageView.image =  [UIImage imageNamed:@"file"];
        cell.imageView.tintColor = nil;
        
        if([keyFile isEqual:self.selectedUrl]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return (indexPath.section != 0);
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"Remove" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeFile:indexPath];
    }];
    
    return @[removeAction];
}

- (void)removeFile:(NSIndexPath * _Nonnull)indexPath {
    NSError* error;
    NSURL* url;
    
    if(indexPath.section == 0) {
        return; // WTF
    }
    else if(indexPath.section == 1) {
        url = self.keyFiles[indexPath.row];
    }
    else {
        url = self.otherFiles[indexPath.row];
    }
    
    if(![NSFileManager.defaultManager removeItemAtURL:url error:&error]) {
        [Alerts info:self title:@"File Not Removed" message:@"The file could not be removed. Either it was not found or there was an issue deleting. Try using iTunes File Sharing to remove or check if present."];
    }
    
    [self loadLocalFiles];
    [self.tableView reloadData];
}

@end
