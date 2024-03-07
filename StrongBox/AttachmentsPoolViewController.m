//
//  AttachmentsPoolViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 24/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AttachmentsPoolViewController.h"
#import "Utils.h"
#import "NSArray+Extensions.h"
#import <QuickLook/QuickLook.h>
#import "StrongboxiOSFilesManager.h"
#import "NSData+Extensions.h"
#import "StreamUtils.h"
#import "Constants.h"
#import "MinimalPoolHelper.h"

@interface AttachmentsPoolViewController () <QLPreviewControllerDelegate, QLPreviewControllerDataSource>

@property NSArray<KeePassAttachmentAbstractionLayer*>* attachments;

@end

@implementation AttachmentsPoolViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.tableFooterView = [UIView new];

    self.attachments = self.viewModel.database.attachmentPool;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.attachments.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"attachmentPoolCell" forIndexPath:indexPath];

    KeePassAttachmentAbstractionLayer* attachment = self.attachments[indexPath.row];

    cell.textLabel.text = [self getAttachmentLikelyName:attachment forDisplay:YES];

    NSUInteger filesize = attachment.length;
    cell.detailTextLabel.text = friendlyFileSizeString(filesize);
    cell.imageView.image = [UIImage imageNamed:@"document"];

    if (attachment.length < kMaxAttachmentTableviewIconImageSize) {
        NSData* data = attachment.nonPerformantFullData; 
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

- (NSString*)getAttachmentLikelyName:(KeePassAttachmentAbstractionLayer*)attachment forDisplay:(BOOL)forDisplay {
    Node* match = [self.viewModel.database.effectiveRootGroup firstOrDefault:YES predicate:^BOOL(Node * _Nonnull node) {
        return [node.fields.attachments.allValues anyMatch:^BOOL(KeePassAttachmentAbstractionLayer * _Nonnull obj) {
            return [obj.digestHash isEqualToString:attachment.digestHash];
        }];
    }];

    Node* historicalMatch = nil;
    if (!match) {
        match = [self.viewModel.database.effectiveRootGroup firstOrDefault:YES predicate:^BOOL(Node * _Nonnull node) {
            return [node.fields.keePassHistory anyMatch:^BOOL(Node * _Nonnull obj) {
                return [obj.fields.attachments.allValues anyMatch:^BOOL(KeePassAttachmentAbstractionLayer * _Nonnull da) {
                    return [da.digestHash isEqualToString:attachment.digestHash];
                }];
            }];
        }];
        
        historicalMatch = [match.fields.keePassHistory firstOrDefault:^BOOL(Node * _Nonnull obj) {
            return [obj.fields.attachments.allValues anyMatch:^BOOL(KeePassAttachmentAbstractionLayer * _Nonnull da) {
                return [da.digestHash isEqualToString:attachment.digestHash];
            }];
        }];
    }

    if (match) {
        Node* containerNode = historicalMatch ? historicalMatch : match;
        for (NSString* filename in containerNode.fields.attachments.allKeys) {
            KeePassAttachmentAbstractionLayer* att = containerNode.fields.attachments[filename];
            if ([att.digestHash isEqualToString:attachment.digestHash]) {
                if (!historicalMatch) {
                    NSString* foo = filename;
                    NSString* bar = [NSString stringWithFormat:@"%@ [%@]", foo, match.title];
                    return forDisplay ? bar :
                    [NSString stringWithFormat:@"%@-(%@).%@", filename.stringByDeletingPathExtension, NSUUID.UUID.UUIDString, filename.pathExtension];  
                }
                else {
                    NSString* foo = [NSString stringWithFormat:NSLocalizedString(@"attachment_pool_vc_filename_historical_fmt", @"%@ (Historical)"), filename];
                    NSString* bar = [NSString stringWithFormat:@"%@ [%@]", foo, match.title];
                    return forDisplay ? bar :
                        [NSString stringWithFormat:@"%@-(%@).%@", filename.stringByDeletingPathExtension, NSUUID.UUID.UUIDString, filename.pathExtension];  
                }
            }
        }
    }

    return [NSString stringWithFormat:NSLocalizedString(@"attachment_pool_vc_filename_orphan_fmt", @"<Orphan Attachment> [%lu]"), 0];
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
    [StrongboxFilesManager.sharedInstance deleteAllTmpAttachmentFiles];
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.attachments.count;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    KeePassAttachmentAbstractionLayer* attachment = [self.attachments objectAtIndex:index];

    NSString* filename = [self getAttachmentLikelyName:attachment forDisplay:NO];

    NSString* f = [StrongboxFilesManager.sharedInstance.tmpAttachmentPreviewPath stringByAppendingPathComponent:filename];

    NSInputStream* attStream = [attachment getPlainTextInputStream];
    [StreamUtils pipeFromStream:attStream to:[NSOutputStream outputStreamToFileAtPath:f append:NO]];

    NSURL* url = [NSURL fileURLWithPath:f];

    return url;
}

@end
