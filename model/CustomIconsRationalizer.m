//
//  CustomIconsRationalizer.m
//  Strongbox
//
//  Created by Mark on 22/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CustomIconsRationalizer.h"
#import "NSArray+Extensions.h"

@implementation CustomIconsRationalizer

+ (NSMutableDictionary<NSUUID *,NSData *> *)rationalize:(NSDictionary<NSUUID *,NSData *> *)customIcons root:(Node *)root {
    NSArray<Node*> *nodes = [CustomIconsRationalizer getAllNodesReferencingCustomIcons:root];
//    NSLog(@"Before Rationalization: Icon Map Count = [%lu]. Node Count = [%lu]", (unsigned long)customIcons.allKeys.count, (unsigned long)nodes.count);
    
    // 1. Node could point to non existent custom icon - clean those up and get a clean copy of the custom icon db
    
    NSMutableDictionary<NSUUID*, NSData*>* freshCopy = [CustomIconsRationalizer removeBadCustomIconReferencesAndBuildFreshIconMap:nodes customIcons:customIcons];

//    NSLog(@"First removal of bad references fresh = [%@]", freshCopy.allKeys);

    // 2. There could be duplicate custom icons in the database. Remove and replace any references to the single
    //    instance.

    [CustomIconsRationalizer remapDuplicates:nodes customIcons:freshCopy];
    
    // 3. Custom Icon could now be unused by any node... remove

    freshCopy = [CustomIconsRationalizer removeBadCustomIconReferencesAndBuildFreshIconMap:nodes customIcons:freshCopy];

//    NSLog(@"Second removal of bad references fresh = [%@]", freshCopy.allKeys);

//    NSLog(@"After Rationalization: Icon Map Count = [%lu]. Node Count = [%lu]", (unsigned long)freshCopy.allKeys.count, (unsigned long)nodes.count);
    
    return freshCopy;
}

+ (NSMutableDictionary<NSUUID*, NSData*>*)removeBadCustomIconReferencesAndBuildFreshIconMap:(NSArray<Node*>*)nodes
                                                                                customIcons:(NSDictionary<NSUUID *,NSData *> *)customIcons {
    NSMutableDictionary<NSUUID*, NSData*>* fresh = [NSMutableDictionary dictionaryWithCapacity:customIcons.count];
    
    for (Node* node in nodes) {
        NSUUID* key = node.customIconUuid;
        if(customIcons[key]) {
//            NSLog(@"[%@]-[%@] = [%@]", node.title, key, customIcons[key]);
            fresh[key] = customIcons[key];
        }
        else {
            NSLog(@"Removed bad Custom Icon reference [%@]-[%@]", node.title, key);
            node.customIconUuid = nil;
        }
    }
    
    return fresh;
}

+ (NSArray<Node*>*)getAllNodesReferencingCustomIcons:(Node *)root {
    NSArray<Node*>* currentCustomIconNodes = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.customIconUuid != nil;
    }];
    
    NSArray<Node*>* allNodesWithHistoryAndCustomIcons = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && [node.fields.keePassHistory anyMatch:^BOOL(Node * _Nonnull obj) {
            return obj.customIconUuid != nil;
        }];
    }];
    
    NSArray<Node*>* allHistoricalNodesWithCustomIcons = [allNodesWithHistoryAndCustomIcons flatMap:^id _Nonnull(Node * _Nonnull node, NSUInteger idx) {
        return [node.fields.keePassHistory filter:^BOOL(Node * _Nonnull obj) {
            return obj.customIconUuid != nil;
        }];
    }];
    
    //
    
    NSMutableArray *customIconNodes = [NSMutableArray arrayWithArray:currentCustomIconNodes];
    [customIconNodes addObjectsFromArray:allHistoricalNodesWithCustomIcons];

    return customIconNodes;
}

+ (void)remapDuplicates:(NSArray<Node*>*)nodes customIcons:(NSDictionary<NSUUID *,NSData *> *)customIcons {
    NSMutableDictionary<NSNumber*, NSUUID*>* iconDataHashMap = [NSMutableDictionary dictionary]; // Hash of Custom Icon Data => UUID (This will be the only UUID kept)
    NSMutableDictionary<NSUUID*, NSUUID*> *remappings = [NSMutableDictionary dictionary]; // UUID A => (Should be Remapped to) UUID B
    
    for (NSUUID* currentCustomIconUuid in customIcons.allKeys) {
        NSData *currentIconData = customIcons[currentCustomIconUuid];
        
        NSNumber *hash = @(currentIconData.hash);
        NSUUID* existingUuid = [iconDataHashMap objectForKey:hash];
        
        if(existingUuid != nil) {
            NSData* existingIconData = customIcons[existingUuid];
            if([existingIconData isEqualToData:currentIconData]) {
                NSLog(@"Found Duplicate Custom Icon - [%@] => [%@]", currentCustomIconUuid, existingUuid);
                [remappings setObject:existingUuid forKey:currentCustomIconUuid]; // Current Icon UUID should be remapped to our original as we have an exact match
            }
        }
        else {
            [iconDataHashMap setObject:currentCustomIconUuid forKey:hash];
        }
    }
    
    // Perform Remap...
    
    for (Node* node in nodes) {
        NSUUID *remapTo = remappings[node.customIconUuid];
    
        if(remapTo) {
//            NSLog(@"Remapping Custom Icon of [%@] with UUID=[%@] to [%@]", node.title, node.customIconUuid, remapTo);
            node.customIconUuid = remapTo;
        }
    }
}

@end
