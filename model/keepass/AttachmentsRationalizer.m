//
//  AttachmentsRationalizer.m
//  Strongbox-iOS
//
//  Created by Mark on 04/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "AttachmentsRationalizer.h"
#import "NSArray+Extensions.h"

@implementation AttachmentsRationalizer

+ (NSArray<DatabaseAttachment *> *)rationalizeAttachments:(NSArray<DatabaseAttachment *> *)attachments root:(Node *)root {
    NSArray<Node*>* allNodesWithAttachments = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && node.fields.attachments.count > 0;
    }];
    
    // 1. Node Attachment could point to non existent db attachment = Pretty bad corruption or inconsistency somehow...
    
    removeBadReferences(attachments, allNodesWithAttachments);
    
    // 2. There could be duplicate attachment files in the database attachment list. Remove and replace any references to the single
    //    instance.
    
    NSArray<NodeFileAttachment*> *allNodeAttachments =
        [allNodesWithAttachments flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.fields.attachments;
        }];
    
    remapDuplicates(attachments, allNodeAttachments);
    
    // 3. Database Attachment could be unused by any node
    
    return removeUnused(attachments, allNodeAttachments);
}

static void removeBadReferences(NSArray<DatabaseAttachment*>* attachments, NSArray<Node*>* aNodes) {
    for (Node* node in aNodes) {
        NSMutableArray<NodeFileAttachment*>* toBeRemoved = [NSMutableArray array];
        for (NodeFileAttachment *nodeAttachment in node.fields.attachments) {
            if(nodeAttachment.index < 0 || nodeAttachment.index >= attachments.count) {
                // Out of bounds - remove the attachment
                NSLog(@"Removing %@ because it points at non existent database attachment", nodeAttachment);
                [toBeRemoved addObject:nodeAttachment];
            }
        }
        
        [node.fields.attachments removeObjectsInArray:toBeRemoved];
    }
}

static void remapDuplicates(NSArray<DatabaseAttachment*> *attachments, NSArray<NodeFileAttachment*> *allNodeAttachments) {
    NSMutableDictionary<NSNumber*, NSNumber*>* attachmentHashMap = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSNumber*, NSNumber*> *remappings = [NSMutableDictionary dictionary];
    
    for (int i=0;i<attachments.count;i++) {
        DatabaseAttachment *current = attachments[i];
        NSNumber *hash = @(current.data.hash);
        NSNumber* originalIndex = [attachmentHashMap objectForKey:hash];
        
        if(originalIndex != nil) {
            NSLog(@"Possible Duplicate, performing full comparison...");
            
            DatabaseAttachment *original = attachments[originalIndex.intValue];
            if([original.data isEqualToData:current.data]) {
                NSLog(@"Definite Duplicate... ");
                [remappings setObject:originalIndex forKey:@(i)];
            }
        }
        else {
            [attachmentHashMap setObject:@(i) forKey:@(current.data.hash)];
        }
    }
    
    //NSLog(@"Remaps Required: %@", remappings);
    
    // Perform Remap...
    
    for (NodeFileAttachment* att in allNodeAttachments) {
        NSNumber* mapTo = [remappings objectForKey:@(att.index)];
    
        if(mapTo != nil) {
            att.index = mapTo.intValue;
        }
    }
}

static NSArray<DatabaseAttachment*>* removeUnused(NSArray<DatabaseAttachment*>* attachments, NSArray<NodeFileAttachment*> *allNodeAttachments) {
    // We need to remove that item and then shift everything referencing above that down 1
    
    NSArray* allIndices = [allNodeAttachments map:^id _Nonnull(NodeFileAttachment * _Nonnull obj, NSUInteger idx) {
        return @(obj.index);
    }];
    
    NSMutableOrderedSet *usedIndicesSet = [NSMutableOrderedSet orderedSetWithArray:allIndices];

    NSMutableArray<DatabaseAttachment*> *usedAttachments = [NSMutableArray array];
    
    int i=0;
    for (NSNumber* index in usedIndicesSet) {
        [usedAttachments addObject:attachments[index.intValue]];
        
        // Remap anything with index=index to i
        
        if(index.intValue != i) {
            NSLog(@"Remapping anything at %d => %d", index.intValue, i);
            
            for (NodeFileAttachment* att in allNodeAttachments) {
                if(att.index == index.intValue) {
                    att.index = i;
                }
            }
        }
        
        i++;
    }
    
    return usedAttachments;
}

@end
