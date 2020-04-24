//
//  ExportOptionsTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 24/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ExportOptionsTableViewController.h"
#import "Alerts.h"
#import "StrongboxUIDocument.h"
#import <MessageUI/MessageUI.h>
#import "CHCSVParser.h"
#import "Csv.h"
#import "ISMessages.h"
#import "ClipboardManager.h"
#import "Utils.h"

@interface Delegate : NSObject <CHCSVParserDelegate, UIActivityItemSource>

@property (readonly) NSArray *lines;

@end

@interface ExportOptionsTableViewController () <UIDocumentPickerDelegate, MFMailComposeViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableViewCell *cellShare;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellFiles;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEmail;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEmailCsv;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCopy;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellHtml;

@property NSURL* temporaryExportUrl;

@end

@implementation ExportOptionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = NO;
    
    self.tableView.tableFooterView = [UIView new];
    
    if (self.backupMode) {
        [self cell:self.cellEmailCsv setHidden:YES];
        [self cell:self.cellCopy setHidden:YES];
        [self cell:self.cellHtml setHidden:YES];

        [self reloadDataAnimated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.cellShare.imageView.image = [UIImage imageNamed:@"upload"];
    self.cellFiles.imageView.image = [UIImage imageNamed:@"documents"];
    self.cellEmail.imageView.image = [UIImage imageNamed:@"attach"];
    self.cellEmailCsv.imageView.image = [UIImage imageNamed:@"message"];
    self.cellCopy.imageView.image = [UIImage imageNamed:@"copy"];
    self.cellHtml.imageView.image = [UIImage imageNamed:@"document"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (cell == self.cellShare) {
        [self onShare];
    }
    else if(cell == self.cellFiles) {
        [self onFiles];
    }
    else if(cell == self.cellEmail) {
        [self exportEncryptedSafeByEmail];
    }
    else if(cell == self.cellEmailCsv) {
        [self exportCsvByEmail];
    }
    else if(cell == self.cellCopy) {
        [self copyCsv];
    }
    else if(cell == self.cellHtml) {
        [self exportHtmlByEmail];
    }
}

- (void)onShare {
    if(self.backupMode) {
        [self onShareWithData:self.encrypted];
    }
    else {
        [self.viewModel encrypt:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            if (userCancelled) { }
            else if (!data) {
                [Alerts error:self
                        title:NSLocalizedString(@"export_vc_error_encrypting", @"Could not get database data")
                        error:error];
            }
            else {
                [self onShareWithData:data];
            }
        }];
    }
}

- (void)onShareWithData:(NSData*)data {
    NSString* filename = self.backupMode ? self.metadata.fileName : self.viewModel.metadata.fileName;
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    [NSFileManager.defaultManager removeItemAtPath:f error:nil];
    
    NSError* err;
    [data writeToFile:f options:kNilOptions error:&err];
    
    if (err) {
        [Alerts error:self error:err];
        return;
    }
    
    NSURL* url = [NSURL fileURLWithPath:f];
    NSArray *activityItems = @[url]; // NB: Do not add NSString or NSData here it messes up the available apps
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    // Required for iPad... Center Popover
    
    activityViewController.popoverPresentationController.sourceView = self.view;
    activityViewController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds),0,0);
    activityViewController.popoverPresentationController.permittedArrowDirections = 0L; // Don't show the arrow as it's not really anchored
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        NSError *errorBlock;
        if([[NSFileManager defaultManager] removeItemAtURL:url error:&errorBlock] == NO) {
            NSLog(@"error deleting file %@", errorBlock);
            return;
        }
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType
{
    NSString* nickname = self.backupMode ? self.metadata.nickName : self.viewModel.metadata.nickName;
    NSString* subject = [NSString stringWithFormat:NSLocalizedString(@"export_vc_email_subject", @"Strongbox Database: '%@'"), nickname];

    return subject;
}

- (void)copyCsv {
    NSString *newStr = [[NSString alloc] initWithData:[Csv getSafeAsCsv:self.viewModel.database.rootGroup] encoding:NSUTF8StringEncoding];

    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:newStr];
    
    [ISMessages showCardAlertWithTitle:NSLocalizedString(@"export_vc_message_csv_copied", @"Database CSV Copied to Clipboard")
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

- (void)exportCsvByEmail {
    NSData *newStr = [Csv getSafeAsCsv:self.viewModel.database.rootGroup];
    NSString* attachmentName = [NSString stringWithFormat:@"%@.csv", self.viewModel.metadata.nickName];
    [self composeEmail:attachmentName mimeType:@"text/csv" data:newStr nickname:self.viewModel.metadata.nickName];
}

- (void)exportHtmlByEmail {
    NSString *html = [self.viewModel.database getHtmlPrintString:self.viewModel.metadata.nickName];
    
    NSString* attachmentName = [NSString stringWithFormat:@"%@.html", self.viewModel.metadata.nickName];
    
    [self composeEmail:attachmentName mimeType:@"text/html" data:[html dataUsingEncoding:NSUTF8StringEncoding] nickname:self.viewModel.metadata.nickName];
}

- (void)exportEncryptedSafeByEmail {
    if(!self.backupMode) {
        [self.viewModel encrypt:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            if (userCancelled) {
                return;
            }
            else if(!data) {
                [Alerts error:self
                        title:NSLocalizedString(@"export_vc_error_encrypting", @"Error Encrypting")
                        error:error];
                return;
            }
            
            NSString* likelyExtension = [DatabaseModel getDefaultFileExtensionForFormat:self.viewModel.database.format];
            NSString* appendExtension = self.viewModel.metadata.fileName.pathExtension.length ? @"" : likelyExtension;
            NSString *attachmentName = [NSString stringWithFormat:@"%@%@", self.viewModel.metadata.fileName, appendExtension];
            
            [self composeEmail:attachmentName
                      mimeType:@"application/octet-stream"
                          data:data
                      nickname:self.viewModel.metadata.nickName];
        }];
    }
    else {
        NSString* likelyExtension = [DatabaseModel getDefaultFileExtensionForFormat:self.metadata.likelyFormat];
        NSString* appendExtension = self.metadata.fileName.pathExtension.length ? @"" : likelyExtension;
        NSString *attachmentName = [NSString stringWithFormat:@"%@-%@-%@", self.metadata.fileName, iso8601DateString(self.backupItem.date), appendExtension];

        [self composeEmail:attachmentName mimeType:@"application/octet-stream" data:self.encrypted nickname:self.metadata.nickName];
    }
}

- (void)composeEmail:(NSString*)attachmentName mimeType:(NSString*)mimeType data:(NSData*)data nickname:(NSString*)nickname {
    if(![MFMailComposeViewController canSendMail]) {
        [Alerts info:self
               title:NSLocalizedString(@"export_vc_email_unavailable_title", @"Email Not Available")
             message:NSLocalizedString(@"export_vc_email_unavailable_message", @"It looks like email is not setup on this device and so the database cannot be exported by email.")];
        return;
    }
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    
    [picker setSubject:[NSString stringWithFormat:NSLocalizedString(@"export_vc_email_subject", @"Strongbox Database: '%@'"), nickname]];
    
    [picker addAttachmentData:data mimeType:mimeType fileName:attachmentName];
    
    [picker setToRecipients:[NSArray array]];
    [picker setMessageBody:[NSString stringWithFormat:NSLocalizedString(@"export_vc_email_message_body_fmt", @"Here's a copy of my '%@' Strongbox Database."), nickname] isHTML:NO];
    picker.mailComposeDelegate = self;
    
    [self presentViewController:picker animated:YES completion:^{ }];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:^{
        if(result == MFMailComposeResultFailed || error) {
            [Alerts error:self
                    title:NSLocalizedString(@"export_vc_email_error_sending", @"Error Sending")
                    error:error];
        }
        else if(result == MFMailComposeResultSent) {
            [Alerts info:self
                   title:NSLocalizedString(@"export_vc_export_successful_title", @"Export Successful")
                 message:NSLocalizedString(@"export_vc_export_successful_message", @"Your database was successfully exported.")
              completion:^{
                [self.navigationController popViewControllerAnimated:YES];
            }];
        }
    }];
}

- (void)onFiles {
    if(self.backupMode) {
        [self onFilesGotData:self.encrypted  metadata:self.metadata];
    }
    else {
        [self.viewModel encrypt:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            if (userCancelled) { }
            else if (!data) {
                [Alerts error:self
                        title:NSLocalizedString(@"export_vc_error_encrypting", @"Could not get database data")
                        error:error];
            }
            else {
                [self onFilesGotData:data metadata:self.viewModel.metadata];
            }
        }];
    }
}

- (void)onFilesGotData:(NSData*)data metadata:(SafeMetaData*)metadata {
    self.temporaryExportUrl = [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:metadata.fileName];
    
    NSError* error;
    [data writeToURL:self.temporaryExportUrl options:kNilOptions error:&error];
    if(error) {
        [Alerts error:self
                title:NSLocalizedString(@"export_vc_error_writing", @"Error Writing Database")
                error:error];
        NSLog(@"error: %@", error);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithURL:self.temporaryExportUrl inMode:UIDocumentPickerModeExportToService];
        vc.delegate = self;
        
        [self presentViewController:vc animated:YES completion:nil];
    });
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    //NSLog(@"didPickDocumentsAtURLs: %@", urls);
    NSURL* url = [urls objectAtIndex:0];
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:self.temporaryExportUrl options:kNilOptions error:&error];
    
    if(!data || error) {
        [Alerts error:self
                title:NSLocalizedString(@"export_vc_error_exporting", @"Error Exporting")
                error:error];
        NSLog(@"%@", error);
        return;
    }
    
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithData:data fileUrl:url];
    
    [document saveToURL:url
       forSaveOperation:UIDocumentSaveForCreating | UIDocumentSaveForOverwriting
      completionHandler:^(BOOL success) {
        if(!success) {
            [Alerts warn:self
                   title:NSLocalizedString(@"export_vc_error_exporting", @"Error Exporting")
                 message:@""];
        }
        else {
            [Alerts info:self
                   title:NSLocalizedString(@"export_vc_export_successful_title", @"Export Successful")
                 message:NSLocalizedString(@"export_vc_export_successful_message", @"Your database was successfully exported.")
              completion:^{
                [self.navigationController popViewControllerAnimated:YES];
            }];
        }
    }];
    
    [document closeWithCompletionHandler:nil];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
