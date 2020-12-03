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
    NSArray<Node*>* currentNodesWithAttachments = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && node.fields.attachments.count > 0;
    }];

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
    
    
    
    NSMutableArray *allNodesWithAttachments = [NSMutableArray arrayWithArray:currentNodesWithAttachments];
    [allNodesWithAttachments addObjectsFromArray:allHistoricalNodesWithAttachments];

    
    
    removeBadReferences(attachments, allNodesWithAttachments);
    
    
    

    NSArray<NodeFileAttachment*> *allNodeAttachments =
    [allNodesWithAttachments flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.fields.attachments;
    }];

    remapDuplicates(attachments, allNodeAttachments);
    
    
    
    NSArray* ret = removeUnused(attachments, allNodeAttachments);
    
    return ret;
}

static void removeBadReferences(NSArray<DatabaseAttachment*>* attachments, NSArray<Node*>* aNodes) {
    for (Node* node in aNodes) {
        NSMutableArray<NodeFileAttachment*>* toBeRemoved = [NSMutableArray array];
        for (NodeFileAttachment *nodeAttachment in node.fields.attachments) {
            if(nodeAttachment.index < 0 || nodeAttachment.index >= attachments.count) {
                
                NSLog(@"Removing %@ because it points at non existent database attachment", nodeAttachment);
                [toBeRemoved addObject:nodeAttachment];
            }
        }
        
        [node.fields.attachments removeObjectsInArray:toBeRemoved];
    }
}

static void remapDuplicates(NSArray<DatabaseAttachment*> *attachments, NSArray<NodeFileAttachment*> *allNodeAttachments) {
    NSMutableDictionary<NSString*, NSNumber*>* attachmentHashMap = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSNumber*, NSNumber*> *remappings = [NSMutableDictionary dictionary];
    
    for (int i=0;i<attachments.count;i++) {
        DatabaseAttachment *current = attachments[i];
        NSString* digestHash = current.digestHash;
        NSNumber* originalIndex = [attachmentHashMap objectForKey:digestHash];
        
        if(originalIndex != nil) {
            DatabaseAttachment *original = attachments[originalIndex.intValue];
            if ( [original.digestHash isEqualToString:current.digestHash] ) {
                NSLog(@"Found Definite Duplicate... ");
                [remappings setObject:originalIndex forKey:@(i)];
            }
        }
        else {
            [attachmentHashMap setObject:@(i) forKey:current.digestHash];
        }
    }
    
    
    
    
    
    for (NodeFileAttachment* att in allNodeAttachments) {
        NSNumber* mapTo = [remappings objectForKey:@(att.index)];
    
        if(mapTo != nil) {
            att.index = mapTo.intValue;
        }
    }
}

static NSArray<DatabaseAttachment*>* removeUnused(NSArray<DatabaseAttachment*>* attachments, NSArray<NodeFileAttachment*> *allNodeAttachments) {
    
    
    NSArray<NSNumber*>* allIndices = [allNodeAttachments map:^id _Nonnull(NodeFileAttachment * _Nonnull obj, NSUInteger idx) {
        return @(obj.index);
    }];
    
    NSOrderedSet *usedIndicesSet = [NSOrderedSet orderedSetWithArray:[allIndices sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }]];

    NSMutableArray<DatabaseAttachment*> *usedAttachments = [NSMutableArray array];

    int i=0;
    for (NSNumber* index in usedIndicesSet) {
        if(index.intValue >= attachments.count || index.intValue < 0) {
            
            
            
            
            

            NSLog(@"Node attachment index [%d] outside of database attachments range [0-%lu]", index.intValue, (unsigned long)attachments.count);
            continue;
        }
        
        [usedAttachments addObject:attachments[index.intValue]];
        
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
