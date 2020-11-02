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
@property DatabaseModel* theirs; // Theirs, remote, the one out there we need to push to and sync up with if 'they' have made any changes

@property NSArray<Node*> *myEntries;
@property NSArray<Node*> *theirEntries;
@property NSArray<Node*> *myGroups;
@property NSArray<Node*> *theirGroups;
@property NSDictionary<NSUUID*, Node*>* myIdToNodeMap;
@property NSDictionary<NSUUID*, Node*>* theirIdToNodeMap;
@property NSSet<NSUUID*>* allMyEntryIds;
@property NSSet<NSUUID*>* allTheirEntryIds;
@property NSSet<NSUUID*>* allMyGroupIds;
@property NSSet<NSUUID*>* allTheirGroupIds;

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
        
        // TODO: Is root group the right base? or should we be doing it from the very root?
        // Fast Access Read-Only
        
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
        
        self.allMyEntryIds = [NSSet setWithArray:[self.myEntries map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }]];

        self.allTheirEntryIds = [NSSet setWithArray:[self.theirEntries map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }]];
        
        self.allMyGroupIds = [NSSet setWithArray:[self.myGroups map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }]];

        self.allTheirGroupIds = [NSSet setWithArray:[self.theirGroups map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }]];
    }
    return self;
}

- (SyncDiffReport *)getDiff {
    SyncDiffReport* ret = [[SyncDiffReport alloc] init];
    
    // New Groups from 'theirs'

    NSMutableSet<NSUUID*>* mutTheirNewGroups = self.allTheirGroupIds.mutableCopy;
    [mutTheirNewGroups minusSet:self.allMyGroupIds];
    ret.theirNewGroups = mutTheirNewGroups.copy;
    
    // New Entries from 'theirs' that are not in mine
    
    NSMutableSet<NSUUID*>* mutTheirNewEntries = self.allTheirEntryIds.mutableCopy;
    [mutTheirNewEntries minusSet:self.allMyEntryIds];
    ret.theirNewEntries = mutTheirNewEntries.copy;
    
    // Edited Groups
    
    NSMutableSet<NSUUID*> *groupsInCommon = self.allMyGroupIds.mutableCopy;
    [groupsInCommon intersectSet:self.allTheirGroupIds];
    ret.theirEditedGroups = [self getEditedSet:groupsInCommon];
    
    // Edited Entries

    NSMutableSet<NSUUID*> *entriesInCommon = self.allMyEntryIds.mutableCopy;
    [entriesInCommon intersectSet:self.allTheirEntryIds];
    ret.theirEditedEntries = [self getEditedSet:entriesInCommon];

    // Moves

    // Deletions

    // Attachments?
    
    // Custom Icons?
    
    // Database Properties
    
    // Credentials Changed

    return ret;
}

- (void)applyDiff:(SyncDiffReport*)diff {
    
}

- (NSSet<NSUUID*>*)getEditedSet:(NSSet<NSUUID*>*)itemsForComparison {
    NSArray<NSUUID*>* edited = [itemsForComparison.allObjects filter:^BOOL(NSUUID * _Nonnull obj) {
        Node* mine = self.myIdToNodeMap[obj];
        Node* theirs = self.theirIdToNodeMap[obj];

        if (mine == nil || theirs == nil) {
            NSLog(@"WARNWARN: Unexpected result - mine or theirs not found in checking for edited groups [%@] - [%@]", mine, theirs);
        }
        else {
            NSLog(@"%@ => %@", mine.fields.modified, theirs.fields.modified);
            return [theirs.fields.modified isLaterThan:mine.fields.modified];
        }
        
        return NO;
    }];
    
    return [NSSet setWithArray:edited];
}

@end
