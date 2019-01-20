//
//  FileAttachmentsViewControllerTableViewController.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "FileAttachmentsViewControllerTableViewController.h"
#import <QuickLook/QuickLook.h>
#import "DatabaseAttachment.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import "Alerts.h"

@interface FileAttachmentsViewControllerTableViewController () <QLPreviewControllerDataSource, QLPreviewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIDocumentPickerDelegate>
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAdd;

@property NSMutableArray<UiAttachment*> *workingAttachments;
@property BOOL dirty;

@end

@implementation FileAttachmentsViewControllerTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
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

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"No Attachments";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"Tap the + button in the top right corner to add an attachment";
    
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
    
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Remove" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeAttachment:indexPath];
    }];
    
    UITableViewRowAction *renameAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Rename" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self renameAttachment:indexPath];
    }];
    
    return @[removeAction, renameAction];
}

- (void)removeAttachment:(NSIndexPath*)indexPath {
    [Alerts yesNo:self title:@"Are you sure?" message:@"Are you sure you want to remove this attachment?" action:^(BOOL response) {
        if(response) {
            UiAttachment* attachment = [self.workingAttachments objectAtIndex:indexPath.row];
            [self.workingAttachments removeObject:attachment];
            
            self.dirty = YES;
            [self refresh];
        }
    }];
}

- (void)renameAttachment:(NSIndexPath*)indexPath {
    UiAttachment* attachment = [self.workingAttachments objectAtIndex:indexPath.row];

    Alerts *x = [[Alerts alloc] initWithTitle:@"Filename" message:@"Enter a filename for this item"];
    
    [x OkCancelWithTextFieldNotEmpty:self
                        textFieldText:attachment.filename
                       completion:^(NSString *text, BOOL response) {
        if(response) {
            attachment.filename = text;
            self.dirty = YES;
            [self refresh];
        }
    }];
}

- (IBAction)onAddAttachment:(id)sender {
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:@"Attachment Location"
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray<NSString*>* buttonTitles =
    @[  @"Photos",
        @"Files"];
    
    int index = 1;
    for (NSString *title in buttonTitles) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *a) {
                                                           [self onAddAttachmentLocationResponse:index];
                                                       }];
        [alertController addAction:action];
        index++;
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             [self onAddAttachmentLocationResponse:0];
                                                         }];
    [alertController addAction:cancelAction];
    
    UIBarButtonItem* bb = self.navigationItem.rightBarButtonItem;
    
    alertController.popoverPresentationController.barButtonItem = bb;
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)onAddAttachmentLocationResponse:(int)response {
    if(response == 2) {
        UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
        vc.delegate = self;
        
        [self presentViewController:vc animated:YES completion:nil];
    }
    else if(response == 1) {
        UIImagePickerController *vc = [[UIImagePickerController alloc] init];
        vc.delegate = self;
        vc.videoQuality = UIImagePickerControllerQualityTypeHigh;

        BOOL available = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum];

        if(!available) {
            [Alerts info:self title:@"Source Unavailable" message:@"Could not access photos source."];
            return;
        }

        vc.mediaTypes = @[(NSString*)kUTTypeMovie, (NSString*)kUTTypeImage];
        vc.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;

        [self presentViewController:vc animated:YES completion:nil];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];
    
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
    
    if(!data) {
        NSLog(@"Error: %@", error);
        [Alerts warn:self title:@"Error Reading" message:@"Could not read the data for this item."];
        return;
    }
    
    NSString *filename = [url.absoluteString lastPathComponent];
    
    Alerts *x = [[Alerts alloc] initWithTitle:@"Filename" message:@"Enter a filename for this item"];
    
    [x OkCancelWithTextFieldNotEmpty:self
                       textFieldText:filename
                          completion:^(NSString *text, BOOL response) {
                              if(response) {
                                  [self addAttachment:text data:data];
                              }
                          }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    NSLog(@"Image Pick did finish: [%@]", info);
   
    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];

    BOOL isImage = UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage) != 0;

    NSURL *url;
    NSData* data;
    
    if(isImage) {
        if (@available(iOS 11.0, *)) {
            url =  [info objectForKey:UIImagePickerControllerImageURL];
        } else {
            UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
            
            if(!image) {
                [Alerts warn:self title:@"Error Reading" message:@"Could not read the data for this item."];
                return;
            }
            
            data = UIImagePNGRepresentation(image);
        }
    }
    else {
        url =  [info objectForKey:UIImagePickerControllerMediaURL];
    }
    
    NSError* error;
    NSString *filename = @"attachment.png";
    
    if(url) {
        data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
        filename = [url.absoluteString lastPathComponent];
    }
    
    if(!data) {
        NSLog(@"Error: %@", error);
        
        [picker dismissViewControllerAnimated:YES completion:^{
            [Alerts warn:self title:@"Error Reading" message:@"Could not read the data for this item."];
        }];
        return;
    }
    
    Alerts *x = [[Alerts alloc] initWithTitle:@"Filename" message:@"Enter a filename for this item"];
    
    [x OkCancelWithTextFieldNotEmpty:picker
                       textFieldText:filename
                          completion:^(NSString *text, BOOL response) {
          [picker dismissViewControllerAnimated:YES completion:NULL];
          
          if(response) {
              [self addAttachment:text data:data];
          }
      }];
}

- (void)addAttachment:(NSString*)filename data:(NSData*)data {
    UiAttachment* attachment = [[UiAttachment alloc] initWithFilename:filename data:data];
    
    [self.workingAttachments addObject:attachment];
    
    self.dirty = YES;
    
    [self refresh];
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        NSString* path = [NSString pathWithComponents:@[NSTemporaryDirectory(), file]];
        
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.workingAttachments.count;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    UiAttachment* attachment = [self.workingAttachments objectAtIndex:index];
    
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:attachment.filename];
    [attachment.data writeToFile:f atomically:YES];
    NSURL* url = [NSURL fileURLWithPath:f];
   
    return url;
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.workingAttachments.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FileAttachmentReuseIdentifier" forIndexPath:indexPath];
    
    UiAttachment* attachment = [self.workingAttachments objectAtIndex:indexPath.row];
    
    cell.textLabel.text = attachment.filename;
    cell.detailTextLabel.text = fileSizeString(attachment.data.length);
    
    UIImage* img = [UIImage imageWithData:attachment.data];
    if(img) {
        @autoreleasepool { // Prevent App Extension Crash
            UIGraphicsBeginImageContextWithOptions(cell.imageView.bounds.size, NO, 0.0);
            
            CGRect imageRect = cell.imageView.bounds;
            [img drawInRect:imageRect];
            cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
            
            UIGraphicsEndImageContext();
        }
    }
    else {
        cell.imageView.image = [UIImage imageNamed:@"page_white_text-48x48"];
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

static NSString* fileSizeString(size_t size) {
    return [[[NSByteCountFormatter alloc] init] stringFromByteCount:size];
}

@end
