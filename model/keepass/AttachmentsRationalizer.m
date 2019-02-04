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
//
//    int i = 0;
//    for (DatabaseAttachment* dbA in attachments) {
//        NSLog(@"%d => %lu", i++, (unsigned long)dbA.data.length);
//    }

    NSArray<NodeFileAttachment*> *allNodeAttachments =
    [allNodesWithAttachments flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.fields.attachments;
    }];

//    for (NodeFileAttachment* fA in allNodeAttachments) {
//        NSLog(@"%@ - %d", fA.filename, fA.index);
//    }
    
    // 1. Node Attachment could point to non existent db attachment = Pretty bad corruption or inconsistency somehow...
    
    //NSLog(@"Removing Bad References...");
    removeBadReferences(attachments, allNodesWithAttachments);
    
    // 2. There could be duplicate attachment files in the database attachment list. Remove and replace any references to the single
    //    instance.

    //NSLog(@"Removing Duplicates...");
    remapDuplicates(attachments, allNodeAttachments);
    
    // 3. Database Attachment could be unused by any node
    
    //NSLog(@"Removing Unused...");
    NSArray* ret = removeUnused(attachments, allNodeAttachments);

//
//    i = 0;
//    for (DatabaseAttachment* dbA in ret) {
//        NSLog(@"%d => %lu", i++, (unsigned long)dbA.data.length);
//    }
//
//    allNodeAttachments =
//    [allNodesWithAttachments flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
//        return obj.fields.attachments;
//    }];
//
//    for (NodeFileAttachment* fA in allNodeAttachments) {
//        NSLog(@"%@ - %d", fA.filename, fA.index);
//    }
    
    return ret;
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
    
    NSArray<NSNumber*>* allIndices = [allNodeAttachments map:^id _Nonnull(NodeFileAttachment * _Nonnull obj, NSUInteger idx) {
        return @(obj.index);
    }];
    
    NSOrderedSet *usedIndicesSet = [NSOrderedSet orderedSetWithArray:[allIndices sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }]];

    NSMutableArray<DatabaseAttachment*> *usedAttachments = [NSMutableArray array];

    //NSLog(@"Checking: %@", usedIndicesSet);
    
    int i=0;
    for (NSNumber* index in usedIndicesSet) {

        [usedAttachments addObject:attachments[index.intValue]];
        
        // TODO: This has crashed in a report from Apple, probably a corrupt file, but best not to crash...
        
//        2   CoreFoundation                    0x19cb2402c _CFThrowFormattedException + 116 (CFObject.m:1958)
//        3   CoreFoundation                    0x19caa5624 -[__NSArrayM objectAtIndexedSubscript:] + 228 (NSArrayM.m:291)
//        4   Strongbox                         0x104f1b298 +[AttachmentsRationalizer rationalizeAttachments:root:] + 2320 (AttachmentsRationalizer.m:136)
//        5   Strongbox                         0x104e8282c -[StrongboxDatabase initWithRootGroup:metadata:masterPassword:keyFileDigest:attachments:customIco... + 276 (StrongboxDatabase.m:53)
//                                                            6   Strongbox                         0x104ecf5d8 -[KeePassDatabase open:password:keyFileDigest:error:] + 3564 (KeePassDatabase.m:142)
//                                                            7   Strongbox                         0x104eec564 -[DatabaseModel initExistingWithDataAndPassword:password:keyFileDigest:error:] + 376 (DatabaseModel.m:131)
//                                                            8   Strongbox                         0x104e7c8e8 __62-[OpenSafeSequenceHelper openSafeWithData:provider:cacheMode:]_block_invoke + 144 (OpenSafeSequenceHelper.m:472)
//                                                            9   libdispatch.dylib                 0x19c5b3d58 _dispatch_call_block_and_release + 32 (init.c:1372)
//                                                            10  libdispatch.dylib                 0x19c5b52f0 _dispatch_client_callout + 20 (object.m:511)
//                                                            11  libdispatch.dylib                 0x19c5b7f20 _dispatch_queue_override_invoke + 668 (inline_internal.h:2441)
//                                                            12  libdispatch.dylib                 0x19c5c40d4 _dispatch_root_queue_drain + 348 (inline_internal.h:2482)
//                                                            13  libdispatch.dylib                 0x19c5c4940 _dispatch_worker_thread2 + 120 (queue.c:6072)
//                                                            14  libsystem_pthread.dylib           0x19c7b4bc0 _pthread_wqthread 
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
