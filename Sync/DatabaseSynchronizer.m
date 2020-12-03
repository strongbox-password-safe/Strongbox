//
//  DatabaseSynchronizer.m
//  Strongbox
//
//  Created by Strongbox on 18/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseSynchronizer.h"
#import "DatabaseModel.h"
#import "NSArray+Extensions.h"
#import "NSDate+Extensions.h"

@interface DatabaseSynchronizer ()

@property DatabaseModel* mine; // Mine, local here, containing changes that I have made and the copy Strongbox works with
@property DatabaseModel* theirs; 

@property NSArray<Node*> *myEntries;
@property NSArray<Node*> *theirEntries;
@property NSArray<Node*> *myGroups;
@property NSArray<Node*> *theirGroups;

@property NSDictionary<NSUUID*, Node*>* myIdToNodeMap;
@property NSDictionary<NSUUID*, Node*>* theirIdToNodeMap;






@end

@implementation DatabaseSynchronizer

+ (instancetype)newSynchronizerFor:(DatabaseModel *)mine theirs:(DatabaseModel *)theirs {
    return [[DatabaseSynchronizer alloc] initSynchronizerFor:mine theirs:theirs];
}

- (instancetype)initSynchronizerFor:(DatabaseModel *)mine theirs:(DatabaseModel *)theirs {
    self = [super init];
    if (self) {
        self.mine = mine;
        self.theirs = theirs;
        
        
        
        
        self.myEntries = self.mine.allRecords;
        self.theirEntries = self.theirs.allRecords;
        self.myGroups = self.mine.allGroups;
        self.theirGroups = self.theirs.allGroups;

        NSMutableDictionary *mutMyIdToNodeMap = [NSMutableDictionary dictionary];
        for (Node* node in self.mine.allNodes) {
            mutMyIdToNodeMap[node.uuid] = node;
        }
        self.myIdToNodeMap = mutMyIdToNodeMap.copy;
        
        NSMutableDictionary *mutTheirIdToNodeMap = [NSMutableDictionary dictionary];
        for (Node* node in self.theirs.allNodes) {
            mutTheirIdToNodeMap[node.uuid] = node;
        }
        self.theirIdToNodeMap = mutTheirIdToNodeMap.copy;
        















    }
    return self;
}

- (SyncDiffReport *)getDiff {
    SyncDiffReport* ret = [[SyncDiffReport alloc] init];
    NSMutableArray<NSUUID*> *changedNodes = NSMutableArray.array;
    
    [self.theirs preOrderTraverse:^BOOL(Node * _Nonnull node) {
        Node* myVersion = self.myIdToNodeMap[node.uuid];

        if ( !myVersion ) {
            [changedNodes addObject:node.uuid];
        }
        else if ( ![myVersion isSyncEqualTo:node] ) {
            [changedNodes addObject:node.uuid];
        }
        
        return YES;
    }];
    ret.changes = changedNodes;
    
    
    
    
    
    
    

    

    
    
    
    
    
    
    

    return ret;
}

- (void)applyDiff:(SyncDiffReport*)diff {
    
    



}

- (void)addTheirNewGroupToMine:(NSUUID*)uuid {
    Node* theirNewGroup = self.theirIdToNodeMap[uuid];
    
    
    
    
    Node* ourParentGroup = self.mine.rootGroup;
    Node* found = self.myIdToNodeMap[theirNewGroup.parent.uuid];
    if (theirNewGroup.parent != nil && theirNewGroup.parent != self.theirs.rootGroup && found) {
        ourParentGroup = found;
    }
    
    Node* ourNewGroup = [theirNewGroup cloneAsChildOf:ourParentGroup];
    
    [ourParentGroup addChild:ourNewGroup keePassGroupTitleRules:YES]; 
}

@end
