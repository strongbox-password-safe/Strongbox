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

@interface Delegate : NSObject <CHCSVParserDelegate>

@property (readonly) NSArray *lines;

@end

@interface ExportOptionsTableViewController () <UIDocumentPickerDelegate, MFMailComposeViewControllerDelegate>

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
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.cellFiles.imageView.image = [UIImage imageNamed:@"documents"];
    self.cellEmail.imageView.image = [UIImage imageNamed:@"attach"];
    self.cellEmailCsv.imageView.image = [UIImage imageNamed:@"message"];
    self.cellCopy.imageView.image = [UIImage imageNamed:@"copy"];
    self.cellHtml.imageView.image = [UIImage imageNamed:@"document"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if(cell == self.cellFiles) {
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
    [self composeEmail:attachmentName mimeType:@"text/csv" data:newStr];
}

- (void)exportHtmlByEmail {
    NSString *html = [self.viewModel.database getHtmlPrintString:self.viewModel.metadata.nickName];
    
    NSString* attachmentName = [NSString stringWithFormat:@"%@.html", self.viewModel.metadata.nickName];
    
    [self composeEmail:attachmentName mimeType:@"text/html" data:[html dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)exportEncryptedSafeByEmail {
    [self.viewModel encrypt:^(NSData * _Nullable safeData, NSError * _Nullable error) {
        if(!safeData) {
            [Alerts error:self
                    title:NSLocalizedString(@"export_vc_error_encrypting", @"Error Encrypting")
                    error:error];
            return;
        }
        
        NSString* likelyExtension = [DatabaseModel getDefaultFileExtensionForFormat:self.viewModel.database.format];
        NSString* appendExtension = self.viewModel.metadata.fileName.pathExtension.length ? @"" : likelyExtension;
        NSString *attachmentName = [NSString stringWithFormat:@"%@%@", self.viewModel.metadata.fileName, appendExtension];
        
        [self composeEmail:attachmentName mimeType:@"application/octet-stream" data:safeData];
    }];
}

- (void)composeEmail:(NSString*)attachmentName mimeType:(NSString*)mimeType data:(NSData*)data {
    if(![MFMailComposeViewController canSendMail]) {
        [Alerts info:self
               title:NSLocalizedString(@"export_vc_email_unavailable_title", @"Email Not Available")
             message:NSLocalizedString(@"export_vc_email_unavailable_message", @"It looks like email is not setup on this device and so the database cannot be exported by email.")];
        return;
    }
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    
    [picker setSubject:[NSString stringWithFormat:NSLocalizedString(@"export_vc_email_subject", @"Strongbox Database: '%@'"), self.viewModel.metadata.nickName]];
    
    [picker addAttachmentData:data mimeType:mimeType fileName:attachmentName];
    
    [picker setToRecipients:[NSArray array]];
    [picker setMessageBody:[NSString stringWithFormat:NSLocalizedString(@"export_vc_email_message_body_fmt", @"Here's a copy of my '%@' Strongbox Database."), self.viewModel.metadata.nickName] isHTML:NO];
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
    [self.viewModel encrypt:^(NSData * _Nullable data, NSError * _Nullable err) {
        if(!data) {
            [Alerts error:self
                    title:NSLocalizedString(@"export_vc_error_encrypting", @"Could not get database data")
                    error:err];
            return;
        }
        
        self.temporaryExportUrl = [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:self.viewModel.metadata.fileName];
        
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
    }];
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

@end
