//
//  AttachmentsPoolViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 24/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "AttachmentsPoolViewController.h"
#import "Utils.h"
#import "NSArray+Extensions.h"
#import <QuickLook/QuickLook.h>
#import "FileManager.h"
#import "NSData+Extensions.h"
#import "StreamUtils.h"
#import "Constants.h"

@interface AttachmentsPoolViewController () <QLPreviewControllerDelegate, QLPreviewControllerDataSource>

@property NSArray<NodeFileAttachment*>* fileAttachments;
@property NSArray<NodeFileAttachment*>* historicalFileAttachments;

@end

@implementation AttachmentsPoolViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.tableFooterView = [UIView new];
    
    self.fileAttachments = [self getAllFileAttachments];
    self.historicalFileAttachments = [self getAllHistoricalFileAttachments];
}

- (NSArray<NodeFileAttachment*>*)getAllFileAttachments {
    Node* root = self.viewModel.database.rootGroup;
    
    NSArray<Node*>* currentNodesWithAttachments = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && node.fields.attachments.count > 0;
    }];
    
    NSArray<NodeFileAttachment*> *fileAttachments = [currentNodesWithAttachments flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.fields.attachments;
    }];
    
    return fileAttachments;
}

- (NSArray<NodeFileAttachment*>*)getAllHistoricalFileAttachments {
    Node* root = self.viewModel.database.rootGroup;

    NSArray<Node*>* allNodesWithHistoryNodeAttachments = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && [node.fields.keePassHistory anyMatch:^BOOL(Node * _Nonnull obj) {
            return obj.fields.attachments.count > 0;
        }];
    }];

    NSArray<Node*>* allHistoricalNodesWithAttachments = [allNodesWithHistoryNodeAttachments flatMap:^id _Nonnull(Node * _Nonnull node, NSUInteger idx) {
        return [node.fields.keePassHistory filter:^BOOL(Node * _Nonnull obj) {
            return obj.fields.attachments.count > 0;
        }];
    }];
    
    NSArray<NodeFileAttachment*> *fileAttachments = [allHistoricalNodesWithAttachments flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.fields.attachments;
    }];
    
    return fileAttachments;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.viewModel.database.attachments.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"attachmentPoolCell" forIndexPath:indexPath];
 
    DatabaseAttachment* attachment = self.viewModel.database.attachments[indexPath.row];
    
    cell.textLabel.text = [self getAttachmentLikelyName:indexPath.row forDisplay:YES];
    
    NSUInteger filesize = attachment.length;
    cell.detailTextLabel.text = friendlyFileSizeString(filesize);
    cell.imageView.image = [UIImage imageNamed:@"document"];
    
    if (attachment.length < kMaxAttachmentTableviewIconImageSize) {
        NSInputStream* attStream = [attachment getPlainTextInputStream];
        NSData* data = [NSData dataWithContentsOfStream:attStream];
        UIImage* img = [UIImage imageWithData:data];
        
        if(img) { 
            @autoreleasepool { 
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(48, 48), NO, 0.0);
                
                CGRect imageRect = CGRectMake(0, 0, 48, 48);
                [img drawInRect:imageRect];
                cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
                
                UIGraphicsEndImageContext();
            }
        }
    }

    return cell;
}

- (NSString*)getAttachmentLikelyName:(NSUInteger)poolIndex forDisplay:(BOOL)forDisplay {
    NodeFileAttachment* fa = [self.fileAttachments firstOrDefault:^BOOL(NodeFileAttachment * _Nonnull obj) {
        return obj.index == poolIndex;
    }];
    
    if(fa) {
        return forDisplay ? fa.filename :
        [NSString stringWithFormat:@"%@-(%u).%@", fa.filename.stringByDeletingPathExtension, fa.index, fa.filename.pathExtension];  
    }
    
    fa = [self.historicalFileAttachments firstOrDefault:^BOOL(NodeFileAttachment * _Nonnull obj) {
        return obj.index == poolIndex;
    }];
    
    if(fa) {
        return forDisplay ?
            [NSString stringWithFormat:NSLocalizedString(@"attachment_pool_vc_filename_historical_fmt", @"%@ (Historical)"), fa.filename] :
            [NSString stringWithFormat:@"%@-(%u).%@", fa.filename.stringByDeletingPathExtension, fa.index, fa.filename.pathExtension];  
    }
    
    NSString* unknown = [NSString stringWithFormat:NSLocalizedString(@"attachment_pool_vc_filename_orphan_fmt", @"<Orphan Attachment> [%lu]"), (unsigned long)poolIndex];
    
    return unknown;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self launchAttachmentPreview:indexPath.row];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)launchAttachmentPreview:(NSUInteger)index {
    QLPreviewController *v = [[QLPreviewController alloc] init];
    v.dataSource = self;
    v.currentPreviewItemIndex = index;
    v.delegate = self;
    v.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self presentViewController:v animated:YES completion:nil];
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    [FileManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.viewModel.database.attachments.count;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    DatabaseAttachment* attachment = [self.viewModel.database.attachments objectAtIndex:index];
    
    NSString* filename = [self getAttachmentLikelyName:index forDisplay:NO];
    
    NSString* f = [FileManager.sharedInstance.tmpAttachmentPreviewPath stringByAppendingPathComponent:filename];
    
    NSInputStream* attStream = [attachment getPlainTextInputStream];
    [StreamUtils pipeFromStream:attStream to:[NSOutputStream outputStreamToFileAtPath:f append:NO]];

    NSURL* url = [NSURL fileURLWithPath:f];
    
    return url;
}

@end
