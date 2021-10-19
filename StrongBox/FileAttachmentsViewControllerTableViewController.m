//
//  FileAttachmentsViewControllerTableViewController.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FileAttachmentsViewControllerTableViewController.h"
#import <QuickLook/QuickLook.h>
#import "DatabaseAttachment.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import "Alerts.h"
#import "Utils.h"
#import "SVProgressHUD.h"
#import "AddAttachmentHelper.h"
#import "NSArray+Extensions.h"
#import "FileManager.h"
#import "StreamUtils.h"
#import "NSData+Extensions.h"
#import "Constants.h"
#import "UITableView+EmptyDataSet.h"

@interface FileAttachmentsViewControllerTableViewController () <QLPreviewControllerDataSource, QLPreviewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAdd;
@property NSMutableDictionary<NSString*, DatabaseAttachment*> *workingAttachments;
@property BOOL dirty;

@end

@implementation FileAttachmentsViewControllerTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
        
    self.tableView.tableFooterView = [UIView new];
    
    self.tableView.rowHeight = 55.0f;
    
    self.workingAttachments = self.attachments ? [self.attachments mutableCopy] : [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setToolbarHidden:NO];
    
    [self refresh];
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.buttonAdd.enabled = !self.readOnly && (self.format != kKeePass1 || self.workingAttachments.count == 0);
        [self.tableView reloadData];
    });
}

- (IBAction)onDone:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if(self.onDoneWithChanges && self.dirty) {
        self.attachments = self.workingAttachments;
        self.onDoneWithChanges();
    }
}

- (IBAction)onCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSAttributedString *)getTitleForEmptyDataSet {
    NSString *text = NSLocalizedString(@"file_attachments_view_controller_empty_attachments_text", @"No Attachments");
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)getDescriptionForEmptyDataSet
{
    NSString *text = NSLocalizedString(@"file_attachments_view_controller_empty_attachments_description", @"Tap the + button in the top right corner to add an attachment");
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if(self.readOnly) {
        return @[];
    }
    
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                            title:NSLocalizedString(@"generic_remove", @"Remove")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeAttachment:indexPath];
    }];
    
    UITableViewRowAction *renameAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                            title:NSLocalizedString(@"casg_rename_action", @"Rename")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self renameAttachment:indexPath];
    }];
    
    return @[removeAction, renameAction];
}

- (void)removeAttachment:(NSIndexPath*)indexPath {
    NSString* filename = self.workingAttachments.allKeys[indexPath.row];
    
    [Alerts yesNo:self title:@"Are you sure?" message:@"Are you sure you want to remove this attachment?" action:^(BOOL response) {
        if(response) {
            [self.workingAttachments removeObjectForKey:filename];
            self.dirty = YES;
            [self refresh];
        }
    }];
}

- (void)renameAttachment:(NSIndexPath*)indexPath { 
    NSString* filename = self.workingAttachments.allKeys[indexPath.row];
    DatabaseAttachment* attachment = self.workingAttachments[filename];
    
    Alerts *x = [[Alerts alloc] initWithTitle:@"Filename" message:@"Enter a filename for this item"];
    
    [x OkCancelWithTextFieldNotEmpty:self
                        textFieldText:filename
                       completion:^(NSString *text, BOOL response) {
        if(response) {
            self.workingAttachments[text] = attachment;
            [self.workingAttachments removeObjectForKey:filename];
            
            self.dirty = YES;
            [self refresh];
        }
    }];
}

- (IBAction)onAddAttachment:(id)sender {
    NSArray* usedFilenames = self.workingAttachments.allKeys;
    
    [AddAttachmentHelper.sharedInstance beginAddAttachmentUi:self usedFilenames:usedFilenames onAdd:^(NSString * _Nonnull filename, DatabaseAttachment * _Nonnull databaseAttachment) {
        self.workingAttachments[filename] = databaseAttachment;
        self.dirty = YES;
        [self refresh];
    }];
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    [FileManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.workingAttachments.count;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    NSString* filename = self.workingAttachments.allKeys[index];
    DatabaseAttachment* attachment = self.workingAttachments[filename];
   
    NSString* f = [FileManager.sharedInstance.tmpAttachmentPreviewPath stringByAppendingPathComponent:filename];
    
    NSInputStream* inputStream = [attachment getPlainTextInputStream];

    NSOutputStream* os = [NSOutputStream outputStreamToFileAtPath:f append:NO];
    
    if (![StreamUtils pipeFromStream:inputStream to:os]) {
        return nil;
    }
    
    NSURL* url = [NSURL fileURLWithPath:f];
   
    return url;
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.workingAttachments.count == 0) {
        [self.tableView setEmptyTitle:[self getTitleForEmptyDataSet] description:[self getDescriptionForEmptyDataSet]];

    }
    else {
        [self.tableView setEmptyTitle:nil];
    }

    return self.workingAttachments.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FileAttachmentReuseIdentifier" forIndexPath:indexPath];
    
    NSString* filename = self.workingAttachments.allKeys[indexPath.row];
    DatabaseAttachment* attachment = self.workingAttachments[filename];
    
    cell.textLabel.text = filename;
    cell.detailTextLabel.text = friendlyFileSizeString(attachment.length);
    cell.imageView.image = [UIImage imageNamed:@"document"];

    if (attachment.length < kMaxAttachmentTableviewIconImageSize) {
        NSData* data = attachment.nonPerformantFullData; 
        UIImage* img = [UIImage imageWithData:data];

        if(img) {
            @autoreleasepool { 
                UIGraphicsBeginImageContextWithOptions(cell.imageView.bounds.size, NO, 0.0);
                
                CGRect imageRect = cell.imageView.bounds;
                [img drawInRect:imageRect];
                cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
                
                UIGraphicsEndImageContext();
            }
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    QLPreviewController *v = [[QLPreviewController alloc] init];
    v.dataSource = self;
    v.currentPreviewItemIndex = indexPath.row;
    v.delegate = self;
    
    [self presentViewController:v animated:YES completion:nil];
}

@end
