//
//  AttachmentsHelper.m
//  Strongbox
//
//  Created by Strongbox on 22/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "MinimalPoolHelper.h"
#import "NSArray+Extensions.h"
#import "NSData+Extensions.h"

@implementation MinimalPoolHelper

+ (NSArray<KeePassAttachmentAbstractionLayer*>*)getMinimalAttachmentPool:(Node*)rootNode {
    NSArray<Node*>* currentNodesWithAttachments = [rootNode filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && node.fields.attachments.count > 0;
    }];

    NSArray<Node*>* allNodesWithHistoryNodeAttachments = [rootNode filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && [node.fields.keePassHistory anyMatch:^BOOL(Node * _Nonnull obj) {
            return obj.fields.attachments.count > 0;
        }];
    }];

    NSArray<Node*>* allHistoricalNodesWithAttachments = [allNodesWithHistoryNodeAttachments flatMap:^id _Nonnull(Node * _Nonnull node, NSUInteger idx) {
        return [node.fields.keePassHistory filter:^BOOL(Node * _Nonnull obj) {
            return obj.fields.attachments.count > 0;
        }];
    }];
    
    NSMutableArray<Node*>* allNodesWithAttachments = currentNodesWithAttachments.mutableCopy;
    [allNodesWithAttachments addObjectsFromArray:allHistoricalNodesWithAttachments];

    NSArray<KeePassAttachmentAbstractionLayer*>* allAttachments = [allNodesWithAttachments flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.fields.attachments.allValues;
    }];
    
    
    
    NSMutableDictionary<NSString*, KeePassAttachmentAbstractionLayer*>* attachmentsByHash = NSMutableDictionary.dictionary;
    for (KeePassAttachmentAbstractionLayer* attachment in allAttachments) {
        attachmentsByHash[attachment.digestHash] = attachment;
    }

    return attachmentsByHash.allValues;
}

@end
