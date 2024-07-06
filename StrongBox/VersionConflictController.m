//
//  VersionConflictController.m
//  Strongbox
//
//  Created by Mark on 25/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "VersionConflictController.h"
#import "Utils.h"
#import "Alerts.h"
#import "ExportHelper.h"
#import "NSDate+Extensions.h"

@interface VersionConflictController ()

@property NSMutableArray<NSFileVersion*> *versions;

@end

@implementation VersionConflictController

NSDateFormatter* _dateFormatter;

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.navigationItem setPrompt:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController.toolbar setHidden:YES];
    self.navigationController.toolbarHidden = YES;
    
    NSMutableArray * fileVersions = [NSMutableArray array];
    
    NSURL* theUrl = [NSURL URLWithString:self.url];
    NSFileVersion * currentVersion = [NSFileVersion currentVersionOfItemAtURL:theUrl];
    [fileVersions addObject:currentVersion];
    
    NSArray * otherVersions = [NSFileVersion otherVersionsOfItemAtURL:theUrl];
    [fileVersions addObjectsFromArray:otherVersions];
    
    for (NSFileVersion * fileVersion in fileVersions) {
        [self.versions addObject:fileVersion];
    }
    
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    
    self.versions = [NSMutableArray array];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.versions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"versionCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    
    
    
    NSFileVersion * fileVersion = [self.versions objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [NSString stringWithFormat:@"Modified on %@", fileVersion.localizedNameOfSavingComputer];
    
    cell.detailTextLabel.text = [_dateFormatter stringFromDate:fileVersion.modificationDate];
    
    return cell;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSFileVersion *version = [self.versions objectAtIndex:indexPath.row];
    
    UIContextualAction* action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:NSLocalizedString(@"generic_export", @"Export")
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self exportVersion:version indexPath:indexPath completion:completionHandler];
    }];
    
    return [UISwipeActionsConfiguration configurationWithActions:@[action]];
}

- (void)exportVersion:(NSFileVersion*)version indexPath:(NSIndexPath *)indexPath completion:(void (^)(BOOL))completion {
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:version.URL options:kNilOptions error:&error];
    
    if ( error ) {
        [Alerts error:self error:error completion:^{
            completion(NO);
        }];
    }
    else {
        [self exportData:version data:data indexPath:indexPath completion:completion];
    }
}

- (void)exportData:(NSFileVersion*)version data:(NSData*)data indexPath:(NSIndexPath *)indexPath completion:(void (^)(BOOL))completion {
    NSString* baseFilename = self.url.lastPathComponent;
    NSString* extension = baseFilename.pathExtension;
    NSString* withoutExtension = [baseFilename.lastPathComponent stringByDeletingPathExtension];
    NSString* newFileName = [withoutExtension stringByAppendingFormat:@"-%@", version.modificationDate.fileNameCompatibleDateTime];
    NSString* filename = [newFileName stringByAppendingPathExtension:extension];
    
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    [NSFileManager.defaultManager removeItemAtPath:f error:nil];
    
    NSError* error;
    [data writeToFile:f options:kNilOptions error:&error];
    
    if (error) {
        [Alerts error:self error:error completion:^{
            completion(NO);
        }];
        return;
    }
    
    NSURL* fileUrl = [NSURL fileURLWithPath:f];
    
    NSArray *activityItems = @[fileUrl];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    
    
    CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
    activityViewController.popoverPresentationController.sourceView = self.tableView;
    activityViewController.popoverPresentationController.sourceRect = rect;
    activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        NSError* removeError;
        [NSFileManager.defaultManager removeItemAtURL:fileUrl error:&removeError];
        
        if ( completed ) {
            [Alerts info:self
                   title:NSLocalizedString(@"generic_export", @"Export")
                 message:NSLocalizedString(@"export_vc_export_successful_title", @"Export Successful")
              completion:^{
                completion(completed);
            }];
        }
        else {
            completion(completed);
        }
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [Alerts areYouSure:self
               message:NSLocalizedString(@"ays_select_icloud_conflict_version", @"Are you sure you want to choose this version as the correct version going forward?\n\nRemember you can export any other version now for later merge by sliding left.")
                action:^(BOOL response) {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        if ( response ) {
            [self selectVersion:indexPath];
        }
    }];
}

- (void)selectVersion:(NSIndexPath*)indexPath {
    NSFileVersion *version = [self.versions objectAtIndex:indexPath.row];
    
    NSURL* fileURL = [NSURL URLWithString:self.url];
    
    if (![version isEqual:[NSFileVersion currentVersionOfItemAtURL:fileURL]]) {
        [version replaceItemAtURL:fileURL options:0 error:nil];
    }
    
    [NSFileVersion removeOtherVersionsOfItemAtURL:fileURL error:nil];
    NSArray* conflictVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
    
    for (NSFileVersion* fileVersion in conflictVersions) {
        fileVersion.resolved = YES;
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end
