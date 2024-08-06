//
//  DatabaseSynchronizer.m
//  Strongbox
//
//  Created by Strongbox on 18/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseMerger.h"
#import "DatabaseModel.h"
#import "NSArray+Extensions.h"
#import "NSDate+Extensions.h"
#import "MMcGPair.h"
#import "NSUUID+Zero.h"
#import "DatabaseDiffer.h"
#import "MergeDryRunReport.h"

@interface DatabaseMerger ()

@property DatabaseModel* mine; 
@property DatabaseModel* theirs; 

@property (readonly) BOOL useEffectiveRoot;

@property (readonly) Node* myRoot;
@property (readonly) Node* theirRoot;
@property (readonly) BOOL keePassGroupTitleRules;
@property (readonly) BOOL canCompareGroupNodes;
@property (readonly) BOOL canCompareNodeLocations;
@property (readonly) BOOL canDetectDeletions;
    
@end

@implementation DatabaseMerger

+ (instancetype)mergerFor:(DatabaseModel *)mine theirs:(DatabaseModel *)theirs {
    return [[DatabaseMerger alloc] initSynchronizerFor:mine theirs:theirs];
}

- (instancetype)initSynchronizerFor:(DatabaseModel *)mine theirs:(DatabaseModel *)theirs {
    self = [super init];
    if (self) {
        self.mine = mine;
        self.theirs = theirs;
        
        
        _useEffectiveRoot = ![self.mine.effectiveRootGroup.uuid isEqual:self.theirs.effectiveRootGroup.uuid];
    }
    
    return self;
}

- (MergeDryRunReport *)dryRun {
    MergeDryRunReport* ret = [[MergeDryRunReport alloc] init];
    
    DatabaseModel* clone = [self.mine clone];
    
    DatabaseMerger *syncer = [DatabaseMerger mergerFor:clone theirs:self.theirs];

    ret.success = [syncer merge];
    if (ret.success) {
        ret.diff = [DatabaseDiffer diff:self.mine second:clone];
    }
    
    return ret;
}

- (BOOL)keePassGroupTitleRules {
    return self.mine.isUsingKeePassGroupTitleRules;
}

- (BOOL)canCompareGroupNodes {
    return (self.mine.originalFormat == kKeePass || self.mine.originalFormat == kKeePass4) && (self.theirs.originalFormat == kKeePass || self.theirs.originalFormat == kKeePass4);
}

- (BOOL)canCompareNodeLocations {
    return (self.mine.originalFormat == kKeePass || self.mine.originalFormat == kKeePass4) && (self.theirs.originalFormat == kKeePass || self.theirs.originalFormat == kKeePass4);
}

- (BOOL)canDetectDeletions {
    return (self.mine.originalFormat == kKeePass || self.mine.originalFormat == kKeePass4) && (self.theirs.originalFormat == kKeePass || self.theirs.originalFormat == kKeePass4);
}

- (Node *)myRoot {
    return self.useEffectiveRoot ? self.mine.effectiveRootGroup : self.mine.rootNode;
}

- (Node *)theirRoot {
    return self.useEffectiveRoot ? self.theirs.effectiveRootGroup : self.theirs.rootNode;
}

- (BOOL)merge {
    slog(@"DatabaseMerger::merge BEGIN");
    
    if ( ![self manageAdditionsAndEdits] ) {
        return NO;
    }
    [self.mine rebuildFastMaps];
    
    if (self.canCompareNodeLocations) {
        if (![self manageMoves]) {
            return NO;
        }
        
        [self.mine rebuildFastMaps];
    }
    
    if (self.canDetectDeletions) {
        [self manageDeletions];
        
        [self.mine rebuildFastMaps];
    }
    
    [self manageDatabaseProperties];
    
    [self.mine preSerializationPerformMaintenanceOrMigrations];

    [self.mine rebuildFastMaps];
    
    return YES;
}

- (void)manageDatabaseProperties {
    UnifiedDatabaseMetadata* me = self.mine.meta;
    UnifiedDatabaseMetadata* thee = self.theirs.meta;
    
    BOOL theirsIsNewer = thee.settingsChanged && [thee.settingsChanged isLaterThan:me.settingsChanged];
    
    if ( theirsIsNewer ) {
        me.settingsChanged = thee.settingsChanged;
        me.color = thee.color;
    }

    if( thee.databaseNameChanged && [thee.databaseNameChanged isLaterThan:me.databaseNameChanged] ) {
        me.databaseName = thee.databaseName;
        me.databaseNameChanged = thee.databaseNameChanged;
    }

    if( thee.databaseDescriptionChanged && [thee.databaseDescriptionChanged isLaterThan:me.databaseDescriptionChanged] ) {
        me.databaseDescription = thee.databaseDescription;
        me.databaseDescriptionChanged = thee.databaseDescriptionChanged;
    }
    
    if( thee.defaultUserNameChanged && [thee.defaultUserNameChanged isLaterThan:me.defaultUserNameChanged] ) {
        me.defaultUserName = thee.defaultUserName;
        me.defaultUserNameChanged = thee.defaultUserNameChanged;
    }

    
    
    NSUUID* newBin = me.recycleBinGroup;
    NSUUID* fallbackBin = thee.recycleBinGroup;
    if( thee.recycleBinChanged && [thee.recycleBinChanged isLaterThan:me.recycleBinChanged] ) {
        newBin = fallbackBin;
        fallbackBin = me.recycleBinGroup;
        
        me.recycleBinEnabled = thee.recycleBinEnabled;
        me.recycleBinChanged = thee.recycleBinChanged;
    }

    
    
    if ([self.mine getItemById:newBin]) {
        me.recycleBinGroup = newBin;
    }
    else if ([self.mine getItemById:fallbackBin]) {
        me.recycleBinGroup = fallbackBin;
    }
    else {
        me.recycleBinGroup = NSUUID.zero;
    }
    
    

    NSUUID* newEtg = me.entryTemplatesGroup;
    NSUUID* fallbackEtg = thee.entryTemplatesGroup;
    if( thee.entryTemplatesGroupChanged && [thee.entryTemplatesGroupChanged isLaterThan:me.entryTemplatesGroupChanged] ) {
        newEtg = fallbackEtg;
        fallbackEtg = me.entryTemplatesGroup;
        me.entryTemplatesGroupChanged = thee.entryTemplatesGroupChanged;
    }

    
    
    if ([self.mine getItemById:newEtg]) {
        me.entryTemplatesGroup = newEtg;
    }
    else if ([self.mine getItemById:fallbackEtg]) {
        me.entryTemplatesGroup = fallbackEtg;
    }
    else {
        me.entryTemplatesGroup = NSUUID.zero;
    }

    
    
    for (NSString* key in thee.customData.allKeys) {
        NSDate* meMod = me.customData[key].modified;
        NSDate* theeMod = thee.customData[key].modified;

        if (meMod != nil && theeMod != nil ) {
            if ( [theeMod isLaterThan:meMod] ) {
                me.customData[key] = thee.customData[key];
            }
        }
        else if ( meMod != nil ) {
            
        }
        else if ( theeMod != nil ) {
            me.customData[key] = thee.customData[key];
        }
        else
        {
            if (theirsIsNewer || ![me.customData objectForKey:key]) {
                me.customData[key] = thee.customData[key];
            }
        }
    }
}

- (BOOL)manageMoves {
    if (! [self relocateGroups] ) {
        return NO;
    }

    if (! [self relocateEntries] ) {
        return NO;
    }
    
    [self setLocationChangedToLatestForAll];
    
    return YES;
}

- (void)manageDeletions {
    NSMutableDictionary<NSUUID*, NSDate*> *combinedDeletedObjects = [self combineTheirDeletedObjectPools];
    [self doDeletionsSafely:self.myRoot combinedDeletedObjects:combinedDeletedObjects];
    [self.mine setDeletedObjects:combinedDeletedObjects];
}

- (BOOL)manageAdditionsAndEdits {
    __block BOOL error = NO;
    [self.theirRoot preOrderTraverse:^BOOL(Node * _Nonnull theirVersion) {
        if ( !self.canCompareGroupNodes && theirVersion.isGroup ) { 
            return YES;
        }
        
        Node* myVersion = [self.mine getItemById:theirVersion.uuid];
        if (myVersion) {
            if (myVersion.isGroup != theirVersion.isGroup) {
                error = YES;
                return NO;
            }
            
            if ([myVersion isSyncEqualTo:theirVersion]) { 
                return YES;
            }

            
            
            if (theirVersion.isGroup) {
                if (![self mergeTheirGroupIn:theirVersion myVersion:myVersion]) {
                    error = YES;
                }
            }
            else {
                if (! [self mergeTheirEntryIn:theirVersion myVersion:myVersion] ) {
                    error = YES;
                }
            }
        }
        else {
            if (! [self simpleMergeNewNodeIn:theirVersion] ) {
                error = YES;
            }
        }
        
        return !error;
    }];
    
    return !error;
}

- (BOOL)simpleMergeNewNodeIn:(Node*)theirVersion {
    Node* theirParentContainer = theirVersion.parent;
    Node* myEquivalentParentContainer = [self getEquivalentParentContainer:theirParentContainer];
    
    NSInteger position = [self determineBestPosition:myEquivalentParentContainer theirParentGroup:theirParentContainer theirVersion:theirVersion];
    Node *ours = [theirVersion cloneAsChildOf:myEquivalentParentContainer];
    
    return [self.mine insertChildren:@[ours] destination:myEquivalentParentContainer atPosition:position];
}

- (BOOL)mergeTheirGroupIn:(Node*)theirVersion myVersion:(Node*)myVersion {
    if ( [theirVersion.fields.modified isLaterThan:myVersion.fields.modified] ) {
        
        return [myVersion mergePropertiesInFromNode:theirVersion mergeLocationChangedDate:NO includeHistory:NO keePassGroupTitleRules:self.keePassGroupTitleRules];
    }
    else {
        return YES;
    }
}

- (BOOL)mergeTheirEntryIn:(Node*)theirVersion myVersion:(Node*)myVersion {
    BOOL theirsIsNewer = [theirVersion.fields.modified isLaterThan:myVersion.fields.modified];
    
    

    if (theirsIsNewer) {
        BOOL weAreAlreadyInTheirHistory = [self currentStateIsAlreadyInOtherEntriesHistory:myVersion nodeWithHistoryToSearch:theirVersion];
        if (!weAreAlreadyInTheirHistory) {
            Node* historicalEntry = [myVersion cloneForHistory];
            [self.mine addHistoricalNode:myVersion originalNodeForHistory:historicalEntry];
        }
    }
    else {
        BOOL theyAreAlreadyInOurHistory = [self currentStateIsAlreadyInOtherEntriesHistory:theirVersion nodeWithHistoryToSearch:myVersion];
        if (!theyAreAlreadyInOurHistory) {
            Node* historicalEntry = [theirVersion cloneForHistory];
            [self.theirs addHistoricalNode:theirVersion originalNodeForHistory:historicalEntry];
        }
    }

    BOOL ret = YES;
    if ( theirsIsNewer ) {
        
        ret = [myVersion mergePropertiesInFromNode:theirVersion mergeLocationChangedDate:NO includeHistory:NO keePassGroupTitleRules:self.keePassGroupTitleRules];
    }

    [self mergeEntryHistory:theirVersion myVersion:myVersion];
    
    return ret;
}

- (void)mergeEntryHistory:(Node*)theirVersion myVersion:(Node*)myVersion {
    NSMutableDictionary<NSDate*, Node*> *byModDate = @{}.mutableCopy;
    
    
    
    for (Node* foo in theirVersion.fields.keePassHistory) {
        if (foo.fields.modified) {
            byModDate[foo.fields.modified] = foo;
        }
    }

    for (Node* foo in myVersion.fields.keePassHistory) {
        if (foo.fields.modified) {
            byModDate[foo.fields.modified] = foo;
        }
    }
    
    
    
    NSArray<NSDate*>* mods = [byModDate.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSDate* d1 = obj1;
        NSDate* d2 = obj2;
        return [d1 compare:d2];
    }];
    
    
    
    [myVersion.fields.keePassHistory removeAllObjects];
    for (NSDate* mod in mods) {
        Node* node = byModDate[mod];
        [myVersion.fields.keePassHistory addObject:node];
    }
}

- (BOOL)currentStateIsAlreadyInOtherEntriesHistory:(Node*)nodeToCheck nodeWithHistoryToSearch:(Node*)nodeWithHistoryToSearch {
    return [nodeWithHistoryToSearch.fields.keePassHistory anyMatch:^BOOL(Node * _Nonnull obj) {
        return [obj isSyncEqualTo:nodeToCheck];
    }];
}

- (Node*)getEquivalentParentContainer:(Node*)theirParentContainer {
    Node* myEquivalentParentContainer = self.myRoot;

    if(theirParentContainer != nil && theirParentContainer != self.theirRoot) {
        Node* tmp = [self.mine getItemById:theirParentContainer.uuid];
        if (tmp) {
            myEquivalentParentContainer = tmp;
        }
    }
    
    return myEquivalentParentContainer;
}

- (BOOL)relocateGroups {
    return [self relocateGroupOrEntryNodes:YES];
}

- (BOOL)relocateEntries {
    return [self relocateGroupOrEntryNodes:NO];
}

- (BOOL)relocateGroupOrEntryNodes:(BOOL)group {
    NSArray<Node*>* nodesToCheck = group ? self.myRoot.allChildGroups : self.myRoot.allChildRecords;
    
    for (Node* myNode in nodesToCheck) {
        Node* theirVersion = [self.theirs getItemById:myNode.uuid];
        
        if (theirVersion == nil) {
            continue;
        }
        
        if ( myNode.isGroup != theirVersion.isGroup ) {
            slog(@"WARNWARN: Group / Entry Mismatch");
            return NO;
        }
   
        Node* theirParentGroup = theirVersion.parent;
        
        if(theirParentGroup == nil) {
            continue;
        }

        if([theirVersion.fields.locationChanged isLaterThan:myNode.fields.locationChanged]) {
            Node* myParentGroup = myNode.parent;
            if([myParentGroup.uuid isEqual:theirParentGroup.uuid]) {
                slog(@"Reordering Node [%@]...", myNode);
                NSInteger position = [self determineBestPosition:myParentGroup theirParentGroup:theirParentGroup theirVersion:theirVersion];
                if ( ! [myParentGroup reorderChild:myNode to:position keePassGroupTitleRules:self.keePassGroupTitleRules] ) {
                    slog(@"WARNWARN: Could not reorder parent for item!!");
                }
            }
            else {
                slog(@"Relocating Node [%@]...", myNode);
            
                Node* myEquivalentParent = [self.mine getItemById:theirParentGroup.uuid];
                    
                if (myEquivalentParent == nil) {
                    slog(@"WARNWARN: Could not find equivalent parent group");
                    continue;
                }
                
                if (group) {
                    if ([myNode contains:myEquivalentParent]) {
                        slog(@"WARNWARN: myNode contains:myEquivalentParent");
                        continue;
                    }
                }
                
                if (![myEquivalentParent validateAddChild:myNode keePassGroupTitleRules:self.keePassGroupTitleRules]) {
                    slog(@"WARNWARN: validateAddChild - Merge");
                    continue;
                }

                NSInteger position = [self determineBestPosition:myEquivalentParent theirParentGroup:theirParentGroup theirVersion:theirVersion];

                if ( ![myNode changeParent:myEquivalentParent position:position keePassGroupTitleRules:YES] ) {
                    slog(@"WARNWARN: Could not change parent for item!!");
                    return NO;
                }
            }
        }
    }
    
    return YES;
}

- (void)setLocationChangedToLatestForAll {
    [self.myRoot preOrderTraverse:^BOOL(Node * _Nonnull node) {
        Node* theirs = [self.theirs getItemById:node.uuid];

        if (theirs && [theirs.fields.locationChanged isLaterThan:node.fields.locationChanged]) {
            [node.fields touchLocationChanged:theirs.fields.locationChanged];
            node.fields.previousParentGroup = theirs.fields.previousParentGroup;
        }
        
        return YES;
    }];
}

- (NSMutableDictionary<NSUUID*, NSDate*> *)combineTheirDeletedObjectPools {
    NSMutableDictionary<NSUUID*, NSDate*> *combinedDeletedObjectsPool = self.mine.deletedObjects.mutableCopy;
        
    for (NSUUID* theirDeletedId in self.theirs.deletedObjects.allKeys) {
        NSDate* theirDeleteDate = self.theirs.deletedObjects[theirDeletedId];
        NSDate* myDeleteDate = self.mine.deletedObjects[theirDeletedId];
        
        if (myDeleteDate) {
            if ([theirDeleteDate isLaterThan:myDeleteDate]) {
                combinedDeletedObjectsPool[theirDeletedId] = theirDeleteDate;
            }
        }
        else {
            combinedDeletedObjectsPool[theirDeletedId] = theirDeleteDate;
        }
    }
    
    return combinedDeletedObjectsPool;
}

- (void)doDeletionsSafely:(Node*)group combinedDeletedObjects:(NSMutableDictionary<NSUUID*, NSDate*>*)combinedDeletedObjects {
    
    
    for (Node* subgroup in group.childGroups) {
        [self doDeletionsSafely:subgroup combinedDeletedObjects:combinedDeletedObjects];
    }

    [self applyDeletions:group.childGroups combinedDeletedObjects:combinedDeletedObjects];
    [self applyDeletions:group.childRecords combinedDeletedObjects:combinedDeletedObjects];
}

- (void)applyDeletions:(NSArray<Node*>*)items combinedDeletedObjects:(NSMutableDictionary<NSUUID*, NSDate*>*)combinedDeletedObjects {
    NSMutableArray<Node*>* toBeDeleted = @[].mutableCopy;
    
    for (Node* item in items) {
        NSDate* deletionTime = combinedDeletedObjects[item.uuid];
        if(deletionTime) {
            if ( [deletionTime isLaterThan:item.fields.modified] && item.children.count == 0) {
                [toBeDeleted addObject:item];
            }
            else {
                slog(@"Item is not safe to delete: [%@] - Will remove from our deletedObjects pool to ensure it is not deleted later.", item);
                [combinedDeletedObjects removeObjectForKey:item.uuid];
            }
        }
    }
    
    NSArray<NSUUID*>* uuids = [toBeDeleted map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }];
    
    [self.mine removeChildren:uuids];
}

- (NSUInteger)determineBestPosition:(Node*)myProspectiveParentGroup theirParentGroup:(Node*)theirParentGroup theirVersion:(Node*)theirVersion {
    
    
    NSUInteger theirIndex = [theirParentGroup.children indexOfObject:theirVersion];
    if (theirIndex == NSNotFound) {
        return -1;
    }
    
    if (theirIndex < (theirParentGroup.children.count - 1)) {
        Node* afterTheirs = theirParentGroup.children[theirIndex+1];
        Node* myEquiv = [myProspectiveParentGroup firstOrDefault:NO predicate:^BOOL(Node * _Nonnull node) {
            return [node.uuid isEqual:afterTheirs.uuid];
        }];
        
        if (myEquiv) {
            NSInteger index  = [myProspectiveParentGroup.children indexOfObject:myEquiv];
            return MAX(0, index - 1);
        }
        else if (theirIndex > 0) {
            
            
            Node* beforeTheirs = theirParentGroup.children[theirIndex-1];
            Node* myEquiv = [myProspectiveParentGroup firstOrDefault:NO predicate:^BOOL(Node * _Nonnull node) {
                return [node.uuid isEqual:beforeTheirs.uuid];
            }];
            
            if (myEquiv) {
                return [myProspectiveParentGroup.children indexOfObject:myEquiv];
            }
        }
        else if (theirIndex == 0) {
            return 0;
        }
    }
    
    
    
    return -1;
}

@end
