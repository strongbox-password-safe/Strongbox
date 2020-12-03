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
    
    
    
    NSMutableDictionary<NSUUID*, NSData*>* freshCopy = [CustomIconsRationalizer removeBadCustomIconReferencesAndBuildFreshIconMap:nodes customIcons:customIcons];



    
    

    [CustomIconsRationalizer remapDuplicates:nodes customIcons:freshCopy];
    
    

    freshCopy = [CustomIconsRationalizer removeBadCustomIconReferencesAndBuildFreshIconMap:nodes customIcons:freshCopy];




    
    return freshCopy;
}

+ (NSMutableDictionary<NSUUID*, NSData*>*)removeBadCustomIconReferencesAndBuildFreshIconMap:(NSArray<Node*>*)nodes
                                                                                customIcons:(NSDictionary<NSUUID *,NSData *> *)customIcons {
    NSMutableDictionary<NSUUID*, NSData*>* fresh = [NSMutableDictionary dictionaryWithCapacity:customIcons.count];
    
    for (Node* node in nodes) {
        NSUUID* key = node.customIconUuid;
        if(customIcons[key]) {

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
    
    
    
    NSMutableArray *customIconNodes = [NSMutableArray arrayWithArray:currentCustomIconNodes];
    [customIconNodes addObjectsFromArray:allHistoricalNodesWithCustomIcons];

    return customIconNodes;
}

+ (void)remapDuplicates:(NSArray<Node*>*)nodes customIcons:(NSDictionary<NSUUID *,NSData *> *)customIcons {
    NSMutableDictionary<NSNumber*, NSUUID*>* iconDataHashMap = [NSMutableDictionary dictionary]; 
    NSMutableDictionary<NSUUID*, NSUUID*> *remappings = [NSMutableDictionary dictionary]; 
    
    for (NSUUID* currentCustomIconUuid in customIcons.allKeys) {
        NSData *currentIconData = customIcons[currentCustomIconUuid];
        
        NSNumber *hash = @(currentIconData.hash);
        NSUUID* existingUuid = [iconDataHashMap objectForKey:hash];
        
        if(existingUuid != nil) {
            NSData* existingIconData = customIcons[existingUuid];
            if([existingIconData isEqualToData:currentIconData]) {
                NSLog(@"Found Duplicate Custom Icon - [%@] => [%@]", currentCustomIconUuid, existingUuid);
                [remappings setObject:existingUuid forKey:currentCustomIconUuid]; 
            }
        }
        else {
            [iconDataHashMap setObject:currentCustomIconUuid forKey:hash];
        }
    }
    
    
    
    for (Node* node in nodes) {
        NSUUID *remapTo = remappings[node.customIconUuid];
    
        if(remapTo) {

            node.customIconUuid = remapTo;
        }
    }
}

@end
