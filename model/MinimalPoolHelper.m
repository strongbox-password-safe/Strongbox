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

+ (NSArray<DatabaseAttachment*>*)getMinimalAttachmentPool:(Node*)rootNode {
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

    NSArray<DatabaseAttachment*>* allAttachments = [allNodesWithAttachments flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.fields.attachments.allValues;
    }];
    
    
    
    NSMutableDictionary<NSString*, DatabaseAttachment*>* attachmentsByHash = NSMutableDictionary.dictionary;
    for (DatabaseAttachment* attachment in allAttachments) {
        attachmentsByHash[attachment.digestHash] = attachment;
    }

    return attachmentsByHash.allValues;
}

+ (NSDictionary<NSUUID *,NSData *> *)getMinimalIconPool:(Node *)rootNode {
    NSArray<Node*>* allNodes = [MinimalPoolHelper getAllNodesReferencingCustomIcons:rootNode];
    
    NSDictionary<NSString*, NSArray<Node*>*> *groupBySha1 = [allNodes groupBy:^id _Nonnull(Node * _Nonnull obj) {
        return obj.icon.custom.sha1.hexString;
    }];
    
    NSMutableDictionary<NSUUID*, NSData*> *ret = NSMutableDictionary.dictionary;
    
    for (NSString* sha1 in groupBySha1.allKeys) {
        NSArray<Node*>* group = groupBySha1[sha1];
        NSArray<NodeIcon*> *nodeIcons = [group map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.icon;
        }];
        
        
        
        NodeIcon* preferred = [nodeIcons firstOrDefault:^BOOL(NodeIcon * _Nonnull obj) {
            return obj.preferredKeePassSerializationUuid != nil;
        }];
                
        NSUUID* preferredUuid = preferred ? preferred.preferredKeePassSerializationUuid : NSUUID.UUID;
        preferred = preferred ? preferred : nodeIcons.firstObject;
        
        ret[preferredUuid] = preferred.custom;
    }
    
    return ret;
}

+ (NSArray<Node*>*)getAllNodesReferencingCustomIcons:(Node *)root {
    NSArray<Node*>* currentCustomIconNodes = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.icon != nil && node.icon.isCustom;
    }];
    
    NSArray<Node*>* allNodesWithHistoryAndCustomIcons = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && [node.fields.keePassHistory anyMatch:^BOOL(Node * _Nonnull obj) {
            return obj.icon != nil && obj.icon.isCustom;
        }];
    }];
    
    NSArray<Node*>* allHistoricalNodesWithCustomIcons = [allNodesWithHistoryAndCustomIcons flatMap:^id _Nonnull(Node * _Nonnull node, NSUInteger idx) {
        return [node.fields.keePassHistory filter:^BOOL(Node * _Nonnull obj) {
            return obj.icon != nil && obj.icon.isCustom;
        }];
    }];
    
    NSMutableArray *customIconNodes = [NSMutableArray arrayWithArray:currentCustomIconNodes];
    [customIconNodes addObjectsFromArray:allHistoricalNodesWithCustomIcons];

    return customIconNodes;
}

@end
