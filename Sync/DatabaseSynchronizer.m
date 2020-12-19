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
#import "Pair.h"
#import "DatabaseSearchAndSorter.h"

@interface DatabaseSynchronizer ()

@property DatabaseModel* mine; 
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
    
    NSMutableArray<Node*> *onlyInTheirs = NSMutableArray.array;
    NSMutableArray<Pair<Node*, Node*>*> *nodesWithDiffs = NSMutableArray.array;

    __weak id weakSelf = self;
    SyncComparisonParams* params = [[SyncComparisonParams alloc] init];
    params.compareNodeAttachmentBlock = ^BOOL(NodeFileAttachment * _Nonnull a, NodeFileAttachment * _Nonnull b) {
        return [weakSelf compareNodeAttachment:a b:b];
    };
    
    [self.theirs preOrderTraverse:^BOOL(Node * _Nonnull theirVersion) {
        Node* myVersion = self.myIdToNodeMap[theirVersion.uuid];

        if ( !myVersion ) {
            [onlyInTheirs addObject:theirVersion];
            [changedNodes addObject:theirVersion.uuid];
        }
        else if ( ![myVersion isSyncEqualTo:theirVersion params:params] ) {
            [nodesWithDiffs addObject:[Pair pairOfA:myVersion andB:theirVersion]];
            [changedNodes addObject:theirVersion.uuid];
        }
        
        return YES;
    }];
    
    ret.changes = changedNodes;    
    ret.onlyInTheirs = onlyInTheirs;
    ret.differentFromOurs = nodesWithDiffs;
    
    
    
    

    
    
    









    
    
    
    






    
    
    
    






    
    
    






    
    
    














    
    
    













    
    









    
    return ret;
}

- (BOOL)compareNodeAttachment:(NodeFileAttachment*)a b:(NodeFileAttachment*)b {
    UiAttachment* alpha = [self.mine getUiAttachment:a];
    UiAttachment* beta = [self.theirs getUiAttachment:b];
    
    if ( [alpha.filename compare:beta.filename] != NSOrderedSame ) {
        return NO;
    }
    
    return [alpha.dbAttachment.digestHash isEqualToString:beta.dbAttachment.digestHash];
}

- (void)applyDiff:(SyncDiffReport*)diff {
    
    
    
    
    
    

    

    
    
    
    
    
    
    
    
    
    
    

    

    
    
    
    

    
    

    
    

    
    

    

    

    

    

    

    

    

    
}


















@end
