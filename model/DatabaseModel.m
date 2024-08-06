#import "DatabaseModel.h"
#import "Utils.h"
#import "PasswordMaker.h"
#import "SprCompilation.h"
#import "NSArray+Extensions.h"
#import "NSMutableArray+Extensions.h"
#import "NSData+Extensions.h"
#import "NSDate+Extensions.h"
#import "KeePassConstants.h"
#import "ConcurrentMutableDictionary.h"
#import "MinimalPoolHelper.h"
#import "NSString+Extensions.h"
#import "FastMaps.h"
#import "CrossPlatform.h"
#import "Node+KeeAgentSSH.h"
#import "Constants.h"
#import "Node+Passkey.h"

#if TARGET_OS_IPHONE
#import "KissXML.h" 
#endif

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

static NSString* const kKeePass1BackupGroupName = @"Backup";
static const DatabaseFormat kDefaultDatabaseFormat = kKeePass4;
static NSString* const kPrintingStylesheet = @"<head><style type=\"text/css\"> \
    body { width: 800px; } \
    .database-title { font-size: 36pt; text-align: center; } \
    .group-title { font-size: 20pt; margin-top:20px; margin-bottom: 5px; text-align: center; font-weight: bold; } \
    .entry-table {  border-collapse: collapse; margin-bottom: 10px; width: 800px; border: 1px solid black; } \
    .entry-title { font-weight: bold; font-size: 16pt; padding: 5px; } \
    table td, table th { border: 1px solid black; } \
    .entry-field-label { width: 100px; padding: 2px; } \
    .entry-field-value { font-family: Menlo; padding: 2px; max-width: 700px; word-wrap: break-word; } \
    </style></head>";

@interface DatabaseModel ()

@property (nonatomic, readonly) NSMutableDictionary<NSUUID*, NSDate*> *mutableDeletedObjects;
@property (nonatomic) NSDictionary<NSUUID*, NodeIcon*> *backingIconPool;
@property (nonatomic) DatabaseFormat format;
@property (nonatomic, nonnull, readonly) UnifiedDatabaseMetadata* metadata;
@property (readonly) FastMaps* fastMaps;

@property (readonly) id<ApplicationPreferences> preferences;

@end

@implementation DatabaseModel

- (instancetype)init {
    return [self initWithFormat:kDefaultDatabaseFormat];
}

- (instancetype)clone {
    CompositeKeyFactors* ckfClone = [self.ckfs clone];
    UnifiedDatabaseMetadata* metadataClone = [self.metadata clone];
    Node* treeClone = [self.rootNode clone:YES];
    
    return [[DatabaseModel alloc] initWithFormat:self.originalFormat
                             compositeKeyFactors:ckfClone
                                        metadata:metadataClone
                                            root:treeClone
                                  deletedObjects:self.deletedObjects
                                        iconPool:self.iconPool];
}

- (instancetype)initWithFormat:(DatabaseFormat)format {
    return [self initWithFormat:format
            compositeKeyFactors:CompositeKeyFactors.unitTestDefaults];
}

- (instancetype)initWithCompositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors {
    return [self initWithFormat:kDefaultDatabaseFormat
            compositeKeyFactors:compositeKeyFactors];
}

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors {
    return [self initWithFormat:format
            compositeKeyFactors:compositeKeyFactors
                       metadata:[UnifiedDatabaseMetadata withDefaultsForFormat:format]];
}

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata*)metadata
{
    return [self initWithFormat:format
            compositeKeyFactors:compositeKeyFactors
                       metadata:metadata
                           root:nil];
}

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata *)metadata
                          root:(Node *)root {
    return [self initWithFormat:format
            compositeKeyFactors:compositeKeyFactors
                       metadata:metadata
                           root:root
                 deletedObjects:@{}
                       iconPool:@{}];
}

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata*)metadata
                          root:(Node *_Nullable)root
                deletedObjects:(NSDictionary<NSUUID *,NSDate *> *)deletedObjects
                      iconPool:(NSDictionary<NSUUID *,NodeIcon *> *)iconPool {
    if (self = [super init]) {
        _format = format;
        _ckfs = compositeKeyFactors;
        _metadata = metadata;
        
        _rootNode = root ? root : [self initializeRoot];
        [self rebuildFastMaps];
        
        _mutableDeletedObjects = deletedObjects.mutableCopy;
        _backingIconPool = iconPool.mutableCopy;
    }
    return self;
}



- (Node*)   initializeRoot {
    Node* rootGroup = [[Node alloc] initAsRoot:nil childRecordsAllowed:self.format != kKeePass1];
    
    if (self.format != kPasswordSafe) {
        
        
        
        NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
        if ([rootGroupName isEqualToString:@"generic_database"]) { 
            rootGroupName = kDefaultRootGroupName;
        }
        Node* keePassRootGroup = [[Node alloc] initAsGroup:rootGroupName parent:rootGroup keePassGroupTitleRules:YES uuid:nil];
        
        [self addChildren:@[keePassRootGroup] destination:rootGroup];
    }
    
    return rootGroup;
}



- (id<ApplicationPreferences>)preferences {
    return CrossPlatformDependencies.defaults.applicationPreferences;
}



- (NSArray<KeePassAttachmentAbstractionLayer *> *)attachmentPool {
    return [MinimalPoolHelper getMinimalAttachmentPool:self.rootNode];
}

- (NSDictionary<NSUUID *,NodeIcon *> *)iconPool {
    const BOOL stripUnusedIcons = self.preferences.stripUnusedIconsOnSave;
    const BOOL stripUnusedHistoricalIcons = self.preferences.stripUnusedIconsOnSave;
    
    NSArray<Node*>* allNodes = [self getAllNodesReferencingCustomIcons:self.rootNode includeHistorical:!stripUnusedHistoricalIcons];
    
    
    
    
    
    NSMutableDictionary<NSUUID*, NodeIcon*>* newIconPool = stripUnusedIcons ? @{}.mutableCopy : self.backingIconPool.mutableCopy;
    
    for (Node* node in allNodes) {
        NodeIcon* icon = node.icon;
        
        if ( newIconPool[icon.uuid] == nil ) {
            
            newIconPool[icon.uuid] = icon;
        }
    }
    
    
    
    self.backingIconPool = newIconPool.copy;
    
    return self.backingIconPool.copy;
}

- (NSArray<Node*>*)getAllNodesReferencingCustomIcons:(Node *)root includeHistorical:(BOOL)includeHistorical {
    NSArray<Node*>* currentCustomIconNodes = [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.icon != nil && node.icon.isCustom;
    }];
    
    if ( !includeHistorical ) {
        return currentCustomIconNodes;
    }
    
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

- (DatabaseFormat)originalFormat {
    return self.format;
}

- (void)changeKeePassFormat:(DatabaseFormat)newFormat {
    if ( self.format == kKeePass || self.format == kKeePass4 ) {
        self.format = newFormat;
    }
}

- (UnifiedDatabaseMetadata *)meta {
    return self.metadata;
}

- (Node *)effectiveRootGroup {
    if ( self.format == kKeePass || self.format == kKeePass4 ) {
        
        
        
        
        
        
        if(self.rootNode.children.count > 0) {
            return [self.rootNode.children objectAtIndex:0];
        }
        else {
            return self.rootNode; 
        }
    }
    else {
        return self.rootNode;
    }
}

- (BOOL)isUsingKeePassGroupTitleRules {
    return self.format != kPasswordSafe;
}

- (NSURL *)launchableUrlForItem:(Node *)item {
    NSString *urlString = [self dereference:item.fields.url node:item];
    
    return [self launchableUrlForUrlString:urlString];
}

- (NSURL *)launchableUrlForUrlString:(NSString*)urlString {
    if (!urlString.length) {
        return nil;
    }
    
    NSURL* url = urlString.urlExtendedParse;
    if (!url) {
        return nil;
    }
    
    NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    
    if ( !components.scheme.length ) { 
        urlString = [NSString stringWithFormat:@"https:
        url = urlString.urlExtendedParse;
    }
    
    return url;
}




- (void)addHistoricalNode:(Node *)item {
    Node* cloneForHistory = [item cloneForHistory];
    [self addHistoricalNode:item originalNodeForHistory:cloneForHistory];
}

- (void)addHistoricalNode:(Node*)item originalNodeForHistory:(Node*)originalNodeForHistory {
    BOOL shouldAddHistory = YES; 
    
    if(shouldAddHistory && !item.isGroup && originalNodeForHistory != nil) {
        [item.fields.keePassHistory addObject:originalNodeForHistory];
    }
    
    
}



- (BOOL)setItemTitle:(Node *)item title:(NSString *)title {
    Node* originalNodeForHistory = [item cloneForHistory];
    
    BOOL ret = [item setTitle:title keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules];
    
    if (ret) {
        [self addHistoricalNode:item originalNodeForHistory:originalNodeForHistory];
        [item touch:YES touchParents:NO];
        
        [self rebuildFastMaps];
    }
    
    return ret;
}

- (BOOL)addTag:(NSUUID*)itemId tag:(NSString*)tag {
    return [self addTagToItems:@[itemId] tag:tag];
}

- (BOOL)removeTag:(NSUUID*)itemId tag:(NSString*)tag {
    return [self removeTagFromItems:@[itemId] tag:tag];
}

- (void)deleteTag:(NSString*)tag {
    NSArray<NSUUID*>* ids = [self getItemIdsForTag:tag];
    
    [self removeTagFromItems:ids tag:tag];
}

- (void)renameTag:(NSString*)from to:(NSString*)to {
    NSArray<NSUUID*>* ids = [self getItemIdsForTag:from];
    
    [self removeTagFromItems:ids tag:from touchAndAddHistory:NO];
    
    [self addTagToItems:ids tag:to];
}

- (BOOL)addTagToItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag {
    BOOL modifiedSomething = NO;
    
    NSArray<Node*>* items = [self getItemsById:ids];
    
    for (Node* item in items) {
        if ( [item.fields.tags containsObject:tag] ) {
            continue;
        }
        
        [self addHistoricalNode:item];
        [item touch:YES touchParents:NO];
        modifiedSomething = YES;
        
        [item.fields.tags addObject:tag];
    }
    
    [self rebuildFastMaps];
    
    return modifiedSomething;
}

- (BOOL)removeTagFromItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag {
    return [self removeTagFromItems:ids tag:tag touchAndAddHistory:YES];
}

- (BOOL)removeTagFromItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag touchAndAddHistory:(BOOL)touchAndAddHistory {
    BOOL modifiedSomething = NO;
    NSArray<Node*>* items = [self getItemsById:ids];
    
    for (Node* item in items) {
        if ( ![item.fields.tags containsObject:tag] ) {
            continue;
        }
        
        if ( touchAndAddHistory ) {
            [self addHistoricalNode:item];
            [item touch:YES touchParents:NO];
            modifiedSomething = YES;
        }
        
        [item.fields.tags removeObject:tag];
    }
    
    [self rebuildFastMaps];
    
    return modifiedSomething;
}



- (BOOL)validateMoveItems:(const NSArray<Node*>*)items destination:(Node*)destination {
    NSArray<Node*>* minimalItems = [self getMinimalNodeSet:items].allObjects;
    
    BOOL invalid = [minimalItems anyMatch:^BOOL(Node * _Nonnull obj) {
        return obj.parent == nil || ![obj validateChangeParent:destination keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules];
    }];
    
    return !invalid;
}

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination {
    return [self moveItems:items destination:destination date:NSDate.date undoData:nil];
}

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination undoData:(NSArray<NodeHierarchyReconstructionData*>**)undoData {
    return [self moveItems:items destination:destination date:NSDate.date undoData:undoData];
}

- (BOOL)moveItems:(const NSArray<Node *> *_Nonnull)items
      destination:(Node*_Nonnull)destination
             date:(NSDate*_Nonnull)date
         undoData:(NSArray<NodeHierarchyReconstructionData*>**)undoData {
    NSArray<Node*>* minimalItems = [self getMinimalNodeSet:items].allObjects;
    
    BOOL invalid = [minimalItems anyMatch:^BOOL(Node * _Nonnull obj) {
        return obj.parent == nil || ![obj validateChangeParent:destination keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules];
    }];
    
    if (invalid) {
        return NO;
    }
    
    if (undoData) {
        *undoData = [self getHierarchyCloneForReconstruction:items];
    }
    
    
    
    
    BOOL rollback = NO;
    
    NSMutableArray<Node*> *rollbackTo = NSMutableArray.array;
    for(Node* itemToMove in minimalItems) {
        [rollbackTo addObject:itemToMove.parent];
        
        if(![itemToMove changeParent:destination keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules]) {
            rollback = YES;
            slog(@"Error Changing Parents. [%@]", itemToMove);
            break;
        }
    }
    
    if (rollback) {
        int i = 0;
        for (Node* previousParent in rollbackTo) {
            [minimalItems[i++] changeParent:previousParent keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules];
        }
    }
    else {
        for(Node* itemToMove in minimalItems) { 
            [itemToMove touchLocationChanged:date]; 
        }
    }
    
    [self rebuildFastMaps]; 
    
    return !rollback;
}

- (void)undoMove:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    
    
    
    
    for (NodeHierarchyReconstructionData* reconItem in undoData) {
        Node* originalMovedItem = [self getItemById:reconItem.clonedNode.uuid];
        
        if (originalMovedItem && originalMovedItem.parent ) {
            [originalMovedItem.parent removeChild:originalMovedItem];
        }
        else {
            
            slog(@"WARNWARN: Could not find original moved item! [%@]", reconItem);
        }
    }
    
    
    
    [self reconstruct:undoData];
}



- (BOOL)validateAddChild:(Node *)item destination:(Node *)destination {
    return [self validateAddChildren:@[item] destination:destination];
}

- (BOOL)validateAddChildren:(NSArray<Node *>*)items destination:(Node *)destination {
    if ( items == nil || destination == nil ) {
        return NO;
    }
    
    for ( Node* item in items ) {
        if (! [destination validateAddChild:item keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules] ) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)addChildren:(NSArray<Node *> *)items destination:(Node *)destination {
    return [self addChildren:items destination:destination suppressFastMapsRebuild:NO];
}

- (BOOL)addChildren:(NSArray<Node *> *)items destination:(Node *)destination suppressFastMapsRebuild:(BOOL)suppressFastMapsRebuild {
    return [self insertChildren:items destination:destination atPosition:-1 suppressFastMapsRebuild:suppressFastMapsRebuild];
}

- (BOOL)insertChild:(Node *)item destination:(Node *)destination atPosition:(NSInteger)position {
    return [self insertChildren:@[item] destination:destination atPosition:position];
}

- (BOOL)insertChildren:(NSArray<Node *>*)items
           destination:(Node *)destination
            atPosition:(NSInteger)position {
    return [self insertChildren:items destination:destination atPosition:position suppressFastMapsRebuild:NO];
}

- (BOOL)insertChildren:(NSArray<Node *> *)items destination:(Node *)destination atPosition:(NSInteger)position suppressFastMapsRebuild:(BOOL)suppressFastMapsRebuild {
    if ( ![self validateAddChildren:items destination:destination] ) {
        return NO;
    }
    
    if ( items == nil || destination == nil ) {
        return NO;
    }
    
    for ( Node* item in items ) {
        if ( ![destination insertChild:item keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules atPosition:position] ) {
            slog(@"🔴 Error inserting child item!");
        }
    }
    
    if ( !suppressFastMapsRebuild ) {
        [self rebuildFastMaps];
    }
    
    return YES;
}

- (void)removeChildren:(NSArray<NSUUID *>*)itemIds {
    if ( itemIds == nil ) {
        return;
    }
    
    NSArray<Node*>* items = [self getItemsById:itemIds];
    for ( Node* item in items ) {
        if ( item && item.parent ) {
            [item.parent removeChild:item];
        }
        else {
            slog(@"🔴 WARN: Not removing Node from Parent (at least one is nil) [node=%@, parent=%@]", item, item.parent);
        }
    }
    
    [self rebuildFastMaps];
}



- (NSInteger)reorderItem:(NSUUID*)nodeId idx:(NSInteger)idx {
    Node* node = [self getItemById:nodeId];
    
    if ( node ) {
        return [self reorderItem:node to:idx];
    }
    
    slog(@"🔴 reorderItem - failed could not find item");
    
    return -1;
}

- (NSInteger)reorderChildFrom:(NSUInteger)from to:(NSInteger)to parentGroup:(Node *)parentGroup {
    
    
    if (from < 0 || from >= parentGroup.children.count) {
        return -1;
    }
    if(from == to) {
        return from;
    }
    
    
    
    Node* item = parentGroup.children[from];
    
    return [self reorderItem:item to:to];
}

- (NSInteger)reorderItem:(Node *)item to:(NSInteger)to {
    
    
    if (item.parent == nil) {
        slog(@"WARNWARN: Cannot change order of item, parent is nil");
        return -1;
    }
    
    NSInteger currentIndex = [item.parent.children indexOfObject:item];
    if (currentIndex == NSNotFound) {
        slog(@"WARNWARN: Cannot change order of item, item not found in parent!");
        return -1;
    }
    
    if (to >= item.parent.children.count || to < -1) {
        to = -1;
    }
    
    
    BOOL ret = [item.parent reorderChild:item to:to keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules];
    
    if (ret) {
        [item touchLocationChanged];
    }
    else {
        return -1;
    }
    
    
    
    return currentIndex;
}



- (void)setDeletedObjects:(NSDictionary<NSUUID *,NSDate *> *)deletedObjects {
    [self.mutableDeletedObjects removeAllObjects];
    [self.mutableDeletedObjects addEntriesFromDictionary:deletedObjects];
}

- (void)reconstruct:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    for (NodeHierarchyReconstructionData* recon in undoData) {
        Node* parent = recon.clonedNode.parent;
        
        if (!parent) {
            continue; 
        }
        
        [parent insertChild:recon.clonedNode keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules atPosition:-1];
        
        NSUInteger currentIndex = parent.children.count - 1;
        if (currentIndex != recon.index) {
            if (! [parent reorderChildAt:currentIndex to:recon.index keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules] ) {
                slog(@"WARNWARN: Could not reorder child from %lu to %lu during reconstruction.", (unsigned long)currentIndex, (unsigned long)recon.index);
            }
        }
    }
    
    [self rebuildFastMaps];
}

- (void)unDelete:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    [self reconstruct:undoData];
    
    for (NodeHierarchyReconstructionData* recon in undoData) {
        
        NSArray<NSUUID*>* childIds = [recon.clonedNode.allChildren map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }];
        
        [self.mutableDeletedObjects removeObjectForKey:recon.clonedNode.uuid];
        [self.mutableDeletedObjects removeObjectsForKeys:childIds];
    }
}

- (BOOL)deleteAllGroupItems:(Node*)group deletionDate:(NSDate*)deletionDate {
    BOOL deletedSomething = NO;
    
    for (Node* entry in group.childRecords) {
        if ( entry && entry.parent ) {
            [entry.parent removeChild:entry];
            deletedSomething = YES;
            self.mutableDeletedObjects[entry.uuid] = deletionDate;
        }
        else {
            slog(@"🔴 WARN: Not removing Node from Parent (at least one is nil) [node=%@, parent=%@]", entry, entry.parent);
        }
    }
    
    for (Node* subgroup in group.childGroups) {
        if ([self deleteAllGroupItems:subgroup deletionDate:deletionDate] ) {
            deletedSomething = YES;
        }
        
        self.mutableDeletedObjects[subgroup.uuid] = deletionDate;
    }
    
    return deletedSomething;
}

- (void)deleteItems:(const NSArray<Node *> *)items {
    [self deleteItems:items undoData:nil];
}

- (void)deleteItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>**)undoData {
    NSDate* now = NSDate.date;
    NSSet<Node*> *minimalNodeSet = [self getMinimalNodeSet:items];
    
    if (undoData) {
        *undoData = [self getHierarchyCloneForReconstruction:items];
    }
    
    BOOL deletedSomething = NO;
    
    for (Node* item in minimalNodeSet) {
        if (item.parent == nil || ![item.parent contains:item]) { 
            slog(@"WARNWARN: Attempt to delete item with no parent");
            return;
        }
        
        if ( item.isGroup ) {
            if ( [self deleteAllGroupItems:item deletionDate:now] ) {
                deletedSomething = YES;
            }
        }
        
        if ( item && item.parent ) {
            [item.parent removeChild:item];
            deletedSomething = YES;
        }
        else {
            slog(@"🔴 WARN: Not removing Node from Parent (at least one is nil) [node=%@, parent=%@]", item, item.parent);
        }
        
        self.mutableDeletedObjects[item.uuid] = now;
    }
    
    if ( deletedSomething ) { 
        [self rebuildFastMaps];
    }
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    return [self recycleItems:items undoData:nil];
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>**)undoData {
    if (!self.recycleBinEnabled) {
        slog(@"🔴 WARNWARN: Attempt to recycle item when recycle bin disabled!");
        return NO;
    }
    
    if(self.recycleBinNode == nil) {     
        [self createNewRecycleBinNode];
    }
    
    NSDate* now = NSDate.date;
    NSSet<Node*> *minimalNodeSet = [self getMinimalNodeSet:items];
    
    BOOL ret = [self moveItems:minimalNodeSet.allObjects destination:self.recycleBinNode date:now undoData:undoData];
    
    if (ret) {
        for (Node* item in minimalNodeSet) { 
            [item touchAt:now]; 
        }
    }
    
    return ret;
}

- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    [self undoMove:undoData];
}

- (void)setRecycleBinEnabled:(BOOL)recycleBinEnabled {
    self.metadata.recycleBinEnabled = recycleBinEnabled;
    
    [self rebuildFastMaps];
}

- (void)setRecycleBinNodeUuid:(NSUUID *)recycleBinNode {
    self.metadata.recycleBinGroup = recycleBinNode;
    
    [self rebuildFastMaps];
}

- (void)setRecycleBinChanged:(NSDate *)recycleBinChanged {
    self.metadata.recycleBinChanged = recycleBinChanged;
    
    [self rebuildFastMaps];
}

- (void)createNewRecycleBinNode {
    NSString* title = NSLocalizedString(@"generic_recycle_bin_name", @"Recycle Bin");
    
    Node* recycleBin = [[Node alloc] initAsGroup:title parent:self.effectiveRootGroup keePassGroupTitleRules:self.isUsingKeePassGroupTitleRules uuid:nil];
    
    recycleBin.icon = [NodeIcon withPreset:43];
    
    
    
    recycleBin.fields.enableSearching = @(NO);
    recycleBin.fields.enableAutoType = @(NO);
    
    [self addChildren:@[recycleBin] destination:self.effectiveRootGroup];
    
    self.recycleBinNodeUuid = recycleBin.uuid;
    self.recycleBinChanged = [NSDate date];
    
    [self rebuildFastMaps];
}




- (NSArray<Node *> *)filterItems:(BOOL)includeGroups includeEntries:(BOOL)includeEntries searchableOnly:(BOOL)searchableOnly {
    return [self filterItems:includeGroups includeEntries:includeEntries searchableOnly:searchableOnly includeExpired:YES];
}

- (NSArray<Node *> *)filterItems:(BOOL)includeGroups includeEntries:(BOOL)includeEntries searchableOnly:(BOOL)searchableOnly includeExpired:(BOOL)includeExpired {
    return [self filterItems:includeGroups includeEntries:includeEntries searchableOnly:searchableOnly includeExpired:includeExpired includeRecycled:NO];
}

- (NSArray<Node *> *)filterItems:(BOOL)includeGroups includeEntries:(BOOL)includeEntries searchableOnly:(BOOL)searchableOnly includeExpired:(BOOL)includeExpired includeRecycled:(BOOL)includeRecycled {
    return [self filterItems:includeGroups includeEntries:includeEntries searchableOnly:searchableOnly includeExpired:includeExpired includeRecycled:includeRecycled trueRoot:NO];
}

- (NSArray<Node *> *)filterItems:(BOOL)includeGroups
                  includeEntries:(BOOL)includeEntries
                  searchableOnly:(BOOL)searchableOnly
                  includeExpired:(BOOL)includeExpired
                 includeRecycled:(BOOL)includeRecycled
                        trueRoot:(BOOL)trueRoot {
    Node* root = trueRoot ? self.rootNode : self.effectiveRootGroup;
    DatabaseFormat format = self.format;
    Node* keePass1BackupNode = (format == kKeePass1) ? self.keePass1BackupNode : nil;
    Node* kp2RecycleBin = (format == kKeePass || format == kKeePass4 ) ? self.recycleBinNode : nil;
    Node* recycler = kp2RecycleBin ? kp2RecycleBin : keePass1BackupNode;
    
    return [root filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        if (!includeGroups && node.isGroup) {
            return NO;
        }
        
        if (!includeEntries && !node.isGroup) {
            return NO;
        }
        
        if ( searchableOnly ) {
            if ( format == kKeePass || format == kKeePass4 ) {
                if ( !node.isSearchable ) {
                    return NO;
                }
            }
        }
        
        if ( !includeRecycled ) {
            if ( recycler != nil && (node == recycler || [recycler contains:node]) ) {
                return NO;
            }
        }
        
        if ( !includeExpired && node.expired ) {
            return NO;
        }
        
        return YES;
    }];
}

- (StringSearchMatchType)isTitleMatches:(NSString*)searchText
                                   node:(Node*)node
                            dereference:(BOOL)dereference
                            checkPinYin:(BOOL)checkPinYin {
    NSString* foo = [self maybeDeref:node.title node:node maybe:dereference];
    return [foo isSearchMatch:searchText checkPinYin:checkPinYin];
}

- (StringSearchMatchType)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference  checkPinYin:(BOOL)checkPinYin {
    NSString* foo = [self maybeDeref:node.fields.username node:node maybe:dereference];
    return [foo isSearchMatch:searchText checkPinYin:checkPinYin];
}

- (StringSearchMatchType)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    NSString* foo = [self maybeDeref:node.fields.password node:node maybe:dereference];
    return [foo isSearchMatch:searchText checkPinYin:checkPinYin];
}

- (StringSearchMatchType)isEmailMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    NSString* email = node.fields.email;
    
    NSString* foo = [self maybeDeref:email node:node maybe:dereference];
    return [foo isSearchMatch:searchText checkPinYin:checkPinYin];
}

- (StringSearchMatchType)isNotesMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    NSString* foo = [self maybeDeref:node.fields.notes node:node maybe:dereference];
    return [foo isSearchMatch:searchText checkPinYin:checkPinYin];
}

- (StringSearchMatchType)isTagsMatches:(NSString*)searchText node:(Node*)node checkPinYin:(BOOL)checkPinYin {
    for ( NSString* tag in node.fields.tags ) {
        StringSearchMatchType matchType = [tag isSearchMatch:searchText checkPinYin:checkPinYin];
        if ( matchType != kStringSearchMatchTypeNoMatch ) {
            return matchType;
        }
    }
    
    return kStringSearchMatchTypeNoMatch;
}

- (StringSearchMatchType)isPathMatches:(NSString*)searchText node:(Node*)node checkPinYin:(BOOL)checkPinYin {
    Node* current = node;
    while (current != nil && current != self.effectiveRootGroup) {
        StringSearchMatchType matchType = [current.title isSearchMatch:searchText checkPinYin:checkPinYin];
        
        if ( matchType != kStringSearchMatchTypeNoMatch  ) {
            return matchType;
        }
        
        current = current.parent;
    }
    
    return NO;
}

- (StringSearchMatchType)isUrlMatches:(NSString*)searchText
                                 node:(Node*)node
                          dereference:(BOOL)dereference
                          checkPinYin:(BOOL)checkPinYin
             includeAssociatedDomains:(BOOL)includeAssociatedDomains {
    NSString* foo = [self maybeDeref:node.fields.url node:node maybe:dereference];
    
    StringSearchMatchType matchType = [self isDiscreteUrlMatch:foo searchText:searchText checkPinYin:checkPinYin includeAssociatedDomains:includeAssociatedDomains];
    
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        return matchType;
    }
    
    for (NSString* altUrl in node.fields.alternativeUrls) {
        NSString* foo = [self maybeDeref:altUrl node:node maybe:dereference];
        
        StringSearchMatchType matchType = [self isDiscreteUrlMatch:foo searchText:searchText checkPinYin:checkPinYin includeAssociatedDomains:includeAssociatedDomains];
        
        if ( matchType != kStringSearchMatchTypeNoMatch  ) {
            return matchType;
        }
        
    }
    
    return kStringSearchMatchTypeNoMatch;
}

- (StringSearchMatchType)isDiscreteUrlMatch:(NSString*)url searchText:(NSString*)searchText checkPinYin:(BOOL)checkPinYin includeAssociatedDomains:(BOOL)includeAssociatedDomains {
    if ( [url.lowercaseString hasPrefix:kOtpAuthScheme] ) {
        
        
        
        return kStringSearchMatchTypeNoMatch;
    }
    
    StringSearchMatchType matchType = [url isSearchMatch:searchText checkPinYin:checkPinYin];
    
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        return matchType;
    }
    
    if ( includeAssociatedDomains ) {
        NSSet<NSString*>* associateds = [BrowserAutoFillManager getAssociatedDomainsWithUrl:url];
        for ( NSString* associated in associateds ) {
            StringSearchMatchType matchType = [associated isSearchMatch:searchText checkPinYin:checkPinYin];
            if ( matchType != kStringSearchMatchTypeNoMatch  ) {
                return matchType;
            }
        }
    }
    
    return kStringSearchMatchTypeNoMatch;
}

- (StringSearchMatchType)isAllFieldsMatches:(NSString*)searchText
                                       node:(Node*)node
                                dereference:(BOOL)dereference
                                checkPinYin:(BOOL)checkPinYin
                   includeAssociatedDomains:(BOOL)includeAssociatedDomains {
    return [self isAllFieldsMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin includeAssociatedDomains:includeAssociatedDomains matchField:nil];
}

- (StringSearchMatchType)isAllFieldsMatches:(NSString *)searchText
                                       node:(Node *)node
                                dereference:(BOOL)dereference
                                checkPinYin:(BOOL)checkPinYin
                   includeAssociatedDomains:(BOOL)includeAssociatedDomains
                                 matchField:(DatabaseSearchMatchField *)matchField {
    StringSearchMatchType matchType = [self isTitleMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        if ( matchField ) {
            *matchField = kDatabaseSearchMatchFieldTitle;
        }
        return matchType;
    }
    matchType = [self isUsernameMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        if ( matchField ) {
            *matchField = kDatabaseSearchMatchFieldUsername;
        }
        return matchType;
    }
    matchType = [self isPasswordMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        if ( matchField ) {
            *matchField = kDatabaseSearchMatchFieldPassword;
        }
        
        return matchType;
    }
    matchType = [self isEmailMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        if ( matchField ) {
            *matchField = kDatabaseSearchMatchFieldEmail;
        }
        
        return matchType;
    }
    matchType = [self isUrlMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin includeAssociatedDomains:includeAssociatedDomains];
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        if ( matchField ) {
            *matchField = kDatabaseSearchMatchFieldUrl;
        }
        
        return matchType;
    }
    matchType = [self isNotesMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        if ( matchField ) {
            *matchField = kDatabaseSearchMatchFieldNotes;
        }
        
        return matchType;
    }
    matchType = [self isTagsMatches:searchText node:node checkPinYin:checkPinYin];
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        if ( matchField ) {
            *matchField = kDatabaseSearchMatchFieldTag;
        }
        
        return matchType;
    }
    
    if (self.format == kKeePass4 || self.format == kKeePass) {
        
        
        for (NSString* key in node.fields.customFields.allKeys) {
            
            if ( ![NodeFields isAlternativeURLCustomFieldKey:key] && ![NodeFields isTotpCustomFieldKey:key]) {
                NSString* value = node.fields.customFields[key].value;
                NSString* derefed = [self maybeDeref:value node:node maybe:dereference];
                
                
                StringSearchMatchType matchType = [key isSearchMatch:searchText checkPinYin:checkPinYin];
                
                if ( matchType != kStringSearchMatchTypeNoMatch  ) {
                    if ( matchField ) {
                        *matchField = kDatabaseSearchMatchFieldCustomField;
                    }
                    
                    return matchType;
                }
                
                matchType = [derefed isSearchMatch:searchText checkPinYin:checkPinYin];
                if ( matchType != kStringSearchMatchTypeNoMatch  ) {
                    if ( matchField ) {
                        *matchField = kDatabaseSearchMatchFieldCustomField;
                    }
                    
                    return matchType;
                }
                
            }
        }
    }
    
    if (self.format != kPasswordSafe) {
        for ( NSString* obj in node.fields.attachments.allKeys ) {
            StringSearchMatchType matchType = [obj isSearchMatch:searchText checkPinYin:checkPinYin];
            if ( matchType != kStringSearchMatchTypeNoMatch ) {
                if ( matchField ) {
                    *matchField = kDatabaseSearchMatchFieldAttachment;
                }
                
                return matchType;
            }
        }
    }
    
    
    
    matchType = [self isPathMatches:searchText node:node checkPinYin:checkPinYin];
    if ( matchType != kStringSearchMatchTypeNoMatch  ) {
        if ( matchField ) {
            *matchField = kDatabaseSearchMatchFieldPath;
        }
        
        return matchType;
    }
    
    return kStringSearchMatchTypeNoMatch;
}

- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText {
    NSArray* split = [searchText componentsSeparatedByString:@" "];
    NSMutableSet<NSString*>* unique = [NSMutableSet setWithArray:split];
    [unique removeObject:@""];
    
    
    
    return [unique.allObjects sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [@(((NSString*)obj2).length) compare:@(((NSString*)obj1).length)];
    }];
}

- (BOOL)isKeePass2Format {
    return self.format == kKeePass || self.format == kKeePass4;
}




- (void)rebuildFastMaps {
    
    
    NSMutableDictionary<NSUUID*, Node*>* uuidMap = NSMutableDictionary.dictionary;
    
    NSMutableSet<NSUUID*> *expirySet = NSMutableSet.set;
    NSMutableSet<NSUUID*> *excludedFromAuditSet = NSMutableSet.set;
    NSMutableSet<NSUUID*> *attachmentSet = NSMutableSet.set;
    NSMutableSet<NSUUID*> *keeAgentSshKeysSet = NSMutableSet.set;
    NSMutableSet<NSUUID*> *passkeysSet = NSMutableSet.set;
    NSMutableSet<NSUUID*> *totpSet = NSMutableSet.set;
    NSMutableDictionary<NSString*, NSMutableSet<NSUUID*>*>* tagMap = NSMutableDictionary.dictionary;
    NSCountedSet<NSString*> *usernameSet = NSCountedSet.set;
    NSCountedSet<NSString*> *emailSet = NSCountedSet.set;
    NSCountedSet<NSString*> *urlSet = NSCountedSet.set;
    NSCountedSet<NSString*> *customFieldKeySet = NSCountedSet.set;
    
    NSInteger entryTotalCount = 0;
    NSInteger groupTotalCount = 0;
    
    if ( self.rootNode ) {
        uuidMap[self.rootNode.uuid] = self.rootNode;
        
        
        
        for (Node* node in self.rootNode.allChildren) { 
            Node* existing = uuidMap[node.uuid];
            
            if ( existing ) {
                slog(@"🔴 WARNWARN: Duplicate ID in database => [%@] - [%@] - [%@]", existing, node, node.uuid);
            }
            else {
                uuidMap[node.uuid] = node;
            }
            
            if ( node.isGroup ) {
                groupTotalCount++;
            }
            else {
                entryTotalCount++;
            }
        }
        
        FastMaps* newMaps = [[FastMaps alloc] initWithUuidMap:uuidMap
                                              withExpiryDates:expirySet
                                              withAttachments:attachmentSet
                                          withKeeAgentSshKeys:keeAgentSshKeysSet
                                                 withPasskeys:passkeysSet
                                                    withTotps:totpSet
                                                       tagMap:tagMap
                                                  usernameSet:usernameSet
                                                     emailSet:emailSet
                                                       urlSet:urlSet
                                            customFieldKeySet:customFieldKeySet
                                              entryTotalCount:entryTotalCount
                                              groupTotalCount:groupTotalCount
                                            excludedFromAudit:excludedFromAuditSet];
        
        _fastMaps = newMaps;
        
        
        
        DatabaseFormat format = self.format;
        Node* keePass1BackupNode = (format == kKeePass1) ? self.keePass1BackupNode : nil;
        Node* kp2RecycleBin = (format == kKeePass || format == kKeePass4 ) ? self.recycleBinNode : nil;
        Node* recycler = kp2RecycleBin ? kp2RecycleBin : keePass1BackupNode;
        
        for (Node* node in self.rootNode.allChildren) { 
            if ( recycler != nil && (node == recycler || [recycler contains:node]) ) {
                continue;
            }
            
            if ( self.format == kKeePass || self.format == kKeePass4 ) {
                if ( !node.isSearchable ) {
                    continue;
                }
            }
            
            
            
            if ( node.fields.expires != nil ) {
                [expirySet addObject:node.uuid];
            }
            
            
            
            if ( !node.fields.qualityCheck ) {
                [excludedFromAuditSet addObject:node.uuid];
            }
            
            
            
            if ( node.fields.attachments.count > 0 ) {
                [attachmentSet addObject:node.uuid];
            }
            
            
            
            if ( node.keeAgentSshKeyViewModel ) {
                [keeAgentSshKeysSet addObject:node.uuid];
            }
            
            
            
            if ( node.passkey ) {
                [passkeysSet addObject:node.uuid];
            }
            
            
            
            if ( node.fields.otpToken != nil ) {
                [totpSet addObject:node.uuid];
            }
            
            
            
            for ( NSString* tag in node.fields.tags ) {
                NSMutableSet<NSUUID*>* set = tagMap[tag];
                
                if ( set == nil ) {
                    tagMap[tag] = NSMutableSet.set;
                    set = tagMap[tag];
                }
                
                [set addObject:node.uuid];
            }
            
            
            
            NSString* username = [Utils trim:node.fields.username];
            if ( username.length ) {
                [usernameSet addObject:username];
            }
            
            
            
            NSString* email = [Utils trim:node.fields.email];
            if ( email.length ) {
                [emailSet addObject:email];
            }
            
            
            
            for (NSString* key in node.fields.customFields.allKeys) {
                [customFieldKeySet addObject:key];
            }
            
            
            
            NSString* url = [Utils trim:node.fields.url];
            if ( url.length ) {
                [urlSet addObject:url];
            }
        }
    }
    
    FastMaps* newMaps = [[FastMaps alloc] initWithUuidMap:uuidMap
                                          withExpiryDates:expirySet
                                          withAttachments:attachmentSet
                                      withKeeAgentSshKeys:keeAgentSshKeysSet
                                             withPasskeys:passkeysSet
                                                withTotps:totpSet
                                                   tagMap:tagMap
                                              usernameSet:usernameSet
                                                 emailSet:emailSet
                                                   urlSet:urlSet
                                        customFieldKeySet:customFieldKeySet
                                          entryTotalCount:entryTotalCount
                                          groupTotalCount:groupTotalCount
                                        excludedFromAudit:excludedFromAuditSet];
    
    _fastMaps = newMaps;
    
    
    
}

- (NSArray<NSUUID *> *)getItemIdsForTag:(NSString *)tag {
    NSSet<NSUUID*> *ret = self.fastMaps.tagMap[tag];
    
    return ret ? ret.allObjects : @[];
}

- (Node *)getItemById:(NSUUID *)uuid {
    if ( uuid ) {
        NSArray* ret = [self getItemsById:@[uuid]];
        return ret ? ret.firstObject : nil;
    }
    else {
        slog(@"🔴 getItemById called with nil!");
        return nil;
    }
}

- (NSArray<Node*>*)getItemsById:(NSArray<NSUUID*>*)ids {
    if (ids == nil) {
        return nil;
    }
    
    return [ids map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        return self.fastMaps.uuidMap[obj];
    }];
}

- (Node *)getItemByCrossSerializationFriendlyId:(NSString*)serializationId {
    if (serializationId.length < 1) {
        return nil;
    }
    
    NSString* prefix = [serializationId substringToIndex:1];
    NSString* suffix = [serializationId substringFromIndex:1];
    
    if (self.format != kPasswordSafe || [prefix isEqualToString:@"R"]) {
        NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:suffix];
        if (uuid) {
            return [self getItemById:uuid];
        }
    }
    else if ([prefix isEqualToString:@"G"]) { 
        return [self.rootNode firstOrDefault:YES predicate:^BOOL(Node * _Nonnull node) {
            NSString *testId = [self getCrossSerializationFriendlyId:node];
            return [testId isEqualToString:serializationId];
        }];
    }
    
    return nil;
}

- (NSString *)getCrossSerializationFriendlyIdId:(NSUUID *)nodeId {
    Node* node = [self getItemById:nodeId];
    return [self getCrossSerializationFriendlyId:node];
}

- (NSString *)getCrossSerializationFriendlyId:(Node *)node {
    if (!node) {
        return nil;
    }
    
    
    
    
    
    
    BOOL groupCanUseUuid = self.format != kPasswordSafe;
    
    NSString *identifier;
    if(node.isGroup && !groupCanUseUuid) {
        NSArray<NSString*> *titleHierarchy = [node getTitleHierarchy];
        identifier = [titleHierarchy componentsJoinedByString:@":"];
    }
    else {
        identifier = [node.uuid UUIDString];
    }
    
    return [NSString stringWithFormat:@"%@%@", node.isGroup ? @"G" : @"R",  identifier];
}

- (NSSet<NSString*> *)urlSet {
    return [self.fastMaps.urlSet copy];
}

- (NSSet<NSString*> *)usernameSet {
    return [self.fastMaps.usernameSet copy];
}

- (NSSet<NSString*> *)emailSet {
    return [self.fastMaps.emailSet copy];
}

- (NSSet<NSString*> *)customFieldKeySet {
    return [self.fastMaps.customFieldKeySet copy];
}

- (NSString *)mostPopularEmail {
    return [self mostFrequentInCountedSet:self.fastMaps.emailSet];
}

- (NSArray<NSString*>*)mostPopularEmails {
    return [self orderedByMostFrequentDescending:self.fastMaps.emailSet];
}

- (NSString *)mostPopularUsername {
    return [self mostFrequentInCountedSet:self.fastMaps.usernameSet];
}

- (NSArray<NSString*>*)mostPopularUsernames {
    return [self orderedByMostFrequentDescending:self.fastMaps.usernameSet];
}

- (NSSet<NSString*> *)tagSet { 
    NSArray<NSString*>* trimmed = [self.fastMaps.tagMap.allKeys map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [Utils trim:obj];
    }];
    
    NSArray* filtered = [trimmed filter:^BOOL(NSString * _Nonnull obj) {
        return obj.length > 0;
    }];

    return [NSSet setWithArray:filtered];
}

- (NSArray<NSString*>*)mostPopularTags {
    NSMutableArray<NSString*>* tags = self.fastMaps.tagMap.allKeys.mutableCopy;
    
    [tags removeObject:kCanonicalFavouriteTag]; 

    NSArray<NSString*>* sorted = [tags sortedArrayUsingComparator:^(id obj1, id obj2) {
        NSString* tag1 = obj1;
        NSString* tag2 = obj2;
        
        NSSet<NSUUID*>* set1 = self.fastMaps.tagMap[tag1];
        NSSet<NSUUID*>* set2 = self.fastMaps.tagMap[tag2];
        
        set1 = set1 == nil ? NSSet.set : set1;
        set2 = set2 == nil ? NSSet.set : set2;
        
        NSUInteger n = set1.count;
        NSUInteger m = set2.count;
        
        return (n <= m) ? (n < m)? NSOrderedDescending : NSOrderedSame : NSOrderedAscending;
    }];
    
    return sorted;
}

- (NSArray<Node *> *)expirySetEntries {
    return [self getItemsById:self.fastMaps.withExpiryDates.allObjects];
}

- (NSArray<Node *> *)expiredEntries {
    return [self.expirySetEntries filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.expired;
    }];
}

- (NSArray<Node *> *)nearlyExpiredEntries {
    return [self.expirySetEntries filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.nearlyExpired;
    }];
}

- (NSArray<Node *> *)totpEntries {
    return [self getItemsById:self.fastMaps.withTotps.allObjects];
}

- (NSArray<Node *> *)attachmentEntries {
    return [self getItemsById:self.fastMaps.withAttachments.allObjects];
}

- (NSArray<Node *> *)keeAgentSSHKeyEntries {
    return [self getItemsById:self.fastMaps.withKeeAgentSshKeys.allObjects];
}

- (NSArray<Node *> *)passkeyEntries {
    return [self getItemsById:self.fastMaps.withPasskeys.allObjects];
}

- (void)excludeFromAudit:(NSUUID *)nodeId exclude:(BOOL)exclude {
    Node* node = [self getItemById:nodeId];
    
    BOOL shouldQualityCheck = !exclude;
    
    if ( node && node.fields.qualityCheck != shouldQualityCheck ) { 
        node.fields.qualityCheck = shouldQualityCheck;
        
        [self rebuildFastMaps];
    }
    else {
        slog(@"⚠️ Could not find item or item is already in this audit exclusion state. WARNWARN");
    }
}

- (BOOL)isExcludedFromAudit:(NSUUID *)nodeId {
    Node* node = [self getItemById:nodeId];
    return !node.fields.qualityCheck;
    
    
}

- (NSArray<Node *> *)excludedFromAuditItems {
    __weak DatabaseModel* weakSelf = self;
    
    return [self.fastMaps.excludedFromAudit.allObjects map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        return [weakSelf getItemById:obj];
    }];
}

- (NSArray<Node *> *)allSearchableNoneExpiredEntries {
    return [self filterItems:NO includeEntries:YES searchableOnly:YES includeExpired:NO];
}

- (NSArray<Node *> *)allSearchableAndRecycledEntries {
    return [self filterItems:NO includeEntries:YES searchableOnly:YES includeExpired:NO includeRecycled:YES];
}

- (NSArray<Node *> *)allSearchableEntries {
    return [self filterItems:NO includeEntries:YES searchableOnly:YES];
}

- (NSArray<Node *> *)allSearchableGroups {
    return [self filterItems:YES includeEntries:NO searchableOnly:YES];
}

- (NSArray<Node *> *)allSearchableIncludingRecycled {
    return [self filterItems:YES includeEntries:YES searchableOnly:YES includeExpired:YES includeRecycled:YES];
}

- (NSArray<Node *> *)allSearchableTrueRootIncludingRecycled {
    return [self filterItems:YES includeEntries:YES searchableOnly:YES includeExpired:YES includeRecycled:YES trueRoot:YES];
}

- (NSArray<Node *> *)allSearchable {
    return [self filterItems:YES includeEntries:YES searchableOnly:YES];
}

- (NSArray<Node *> *)allSearchableTrueRoot {
    return [self filterItems:YES includeEntries:YES searchableOnly:YES includeExpired:YES includeRecycled:NO trueRoot:YES];
}

- (NSArray<Node *> *)allActiveEntries {
    return [self filterItems:NO includeEntries:YES searchableOnly:NO];
}

- (NSArray<Node *> *)allActiveGroups {
    return [self filterItems:YES includeEntries:NO searchableOnly:NO];
}

- (NSArray<Node *> *)allActive {
    return [self filterItems:YES includeEntries:YES searchableOnly:NO];
}

- (NSInteger)fastEntryTotalCount {
    return self.fastMaps.entryTotalCount;
}

- (NSInteger)fastGroupTotalCount {
    return self.fastMaps.groupTotalCount - (self.rootNode == self.effectiveRootGroup ? 0 : 1); 
}

- (NSArray*)orderedByMostFrequentDescending:(NSCountedSet<NSString*>*)bag {
    return [bag.allObjects sortedArrayUsingComparator:^(id obj1, id obj2) {
        NSUInteger n = [bag countForObject:obj1];
        NSUInteger m = [bag countForObject:obj2];
        return (n <= m) ? (n < m)? NSOrderedDescending : NSOrderedSame : NSOrderedAscending;
    }];
}

- (NSString*)mostFrequentInCountedSet:(NSCountedSet<NSString*>*)bag {
    NSString *mostOccurring = nil;
    NSUInteger highest = 0;
    
    for (NSString *s in bag) {
        if ([bag countForObject:s] > highest) {
            highest = [bag countForObject:s];
            mostOccurring = s;
        }
    }
    
    return mostOccurring;
}

- (NSSet<Node*>*)getMinimalNodeSet:(const NSArray<Node*>*)nodes {
    
    
    
    NSArray<Node*>* groups = [nodes filter:^BOOL(Node * _Nonnull obj) {
        return obj.isGroup;
    }];
    
    NSArray<Node*>* minimalNodeSet = [nodes filter:^BOOL(Node * _Nonnull node) {
        BOOL alreadyContained = [groups anyMatch:^BOOL(Node * _Nonnull group) {
            return [group contains:node];
        }];
        return !alreadyContained;
    }];
    
    return [NSSet setWithArray:minimalNodeSet];
}

- (BOOL)isDereferenceableText:(NSString*)text {
    return self.format != kPasswordSafe && [SprCompilation.sharedInstance isSprCompilable:text];
}

- (NSString*)maybeDeref:(NSString*)text node:(Node*)node maybe:(BOOL)maybe {
    return maybe ? [self dereference:text node:node] : text;
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    if(self.format == kPasswordSafe || !text.length) {
        return text;
    }
    
    NSError* error = nil;
    
    BOOL isCompilable = [SprCompilation.sharedInstance isSprCompilable:text];
    
    NSString* compiled = isCompilable ? [SprCompilation.sharedInstance sprCompile:text node:node database:self error:&error] : text;
    
    if(error) {
        slog(@"WARN: SPR Compilation ERROR: [%@]", error);
    }
    
    return compiled ? compiled : @""; 
}

- (BOOL)preOrderTraverse:(BOOL (^)(Node * _Nonnull))function {
    return [self.rootNode preOrderTraverse:function];
}

- (NSString *)getPathDisplayString:(Node *)vm {
    return [self getPathDisplayString:vm includeRootGroup:NO rootGroupNameInsteadOfSlash:NO includeFolderEmoji:NO joinedBy:@" ▸ "];
}

- (NSString *)getPathDisplayString:(Node *)vm
                  includeRootGroup:(BOOL)includeRootGroup
       rootGroupNameInsteadOfSlash:(BOOL)rootGroupNameInsteadOfSlash
                includeFolderEmoji:(BOOL)includeFolderEmoji
                          joinedBy:(NSString*)joinedBy {
    NSMutableArray<NSString*> *hierarchy = [NSMutableArray array];
    
    Node* current = vm;
    while (current != nil && current != self.effectiveRootGroup) {
        NSString* title = includeFolderEmoji ? [NSString stringWithFormat:@"📂 %@", current.title] : current.title;
        [hierarchy insertObject:title atIndex:0];
        current = current.parent;
    }
    
    if ( includeRootGroup ) {
        NSString* rootGroupName = (rootGroupNameInsteadOfSlash && self.effectiveRootGroup) ? self.effectiveRootGroup.title : @"/";
        NSString* title = includeFolderEmoji ? [NSString stringWithFormat:@"📂 %@", rootGroupName] : rootGroupName;
        [hierarchy insertObject:title atIndex:0];
    }
    
    if ( includeRootGroup && !rootGroupNameInsteadOfSlash && [joinedBy isEqualToString:@"/"] && hierarchy.count > 1 ) { 
        [hierarchy removeObjectAtIndex:0];
    }
    
    return [hierarchy componentsJoinedByString:joinedBy];
}

- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm {
    return [self getSearchParentGroupPathDisplayString:vm prependSlash:NO];
}

- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm prependSlash:(BOOL)prependSlash {
    if(!vm || vm.parent == nil || vm.parent == self.effectiveRootGroup) {
        return @"/";
    }
    
    NSMutableArray<NSString*> *hierarchy = [NSMutableArray array];
    
    Node* current = vm;
    while (current.parent != nil && current.parent != self.effectiveRootGroup) {
        [hierarchy insertObject:current.parent.title atIndex:0];
        current = current.parent;
    }
    
    NSString *path = [hierarchy componentsJoinedByString:@"/"];
    
    if ( prependSlash ) {
        return [NSString stringWithFormat:@"/%@", path];
    }
    
    return path;
}

- (Node *)recycleBinNode {
    return self.recycleBinNodeUuid ? [self getItemById:self.recycleBinNodeUuid] : nil;
}

- (BOOL)recycleBinEnabled {
    return self.metadata.recycleBinEnabled;
}

- (NSUUID *)recycleBinNodeUuid {
    return self.metadata.recycleBinGroup;
}

- (NSDate *)recycleBinChanged {
    return self.metadata.recycleBinChanged;
}

- (void)emptyRecycleBin {
    if ( self.isKeePass2Format && self.recycleBinNode && self.recycleBinEnabled ) {
        [self deleteItems:self.recycleBinNode.children];
    }
}

- (Node*)keePass1BackupNode {
    return [self.effectiveRootGroup firstOrDefault:NO predicate:^BOOL(Node * _Nonnull node) {
        return [node.title isEqualToString:kKeePass1BackupGroupName];
    }];
}

- (NSDictionary<NSUUID *,NSDate *> *)deletedObjects {
    return self.mutableDeletedObjects.copy;
}

- (BOOL)isInRecycled:(NSUUID *)itemId {
    Node* item = [self getItemById:itemId];
    
    if ( item && self.recycleBinNode ) {
        if([self.recycleBinNode contains:item] || [self.recycleBinNode.uuid isEqual:itemId]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)canRecycle:(NSUUID *)itemId {
    BOOL willRecycle = self.recycleBinEnabled;
    
    Node* item = [self getItemById:itemId];
    if(item && self.recycleBinEnabled && self.recycleBinNode) {
        if([self.recycleBinNode contains:item] || [self.recycleBinNode.uuid isEqual:itemId]) {
            willRecycle = NO;
        }
    }
    
    return willRecycle;
}

- (NSArray<NodeHierarchyReconstructionData*>*)getHierarchyCloneForReconstruction:(const NSArray<Node*>*)items {
    return [items map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        NodeHierarchyReconstructionData* recon = [[NodeHierarchyReconstructionData alloc] init];
        
        recon.index = [obj.parent.children indexOfObject:obj];
        recon.clonedNode = [obj clone:YES];
        
        return recon;
    }];
}



- (NSString*)getHtmlPrintStringForItems:(NSString*)databaseName items:(NSArray<Node*>*)items {
    
    
    NSMutableString* ret = [NSMutableString stringWithFormat:@"<html>%@\n<body>\n    <h1 class=\"database-title\">%@</h1>\n<h4>Printed: %@</h6>    ", kPrintingStylesheet, [self htmlStringFromString:databaseName], NSDate.date.iso8601DateString];
    
    NSArray<Node*>* sorted = [items sortedArrayUsingComparator:finderStyleNodeComparator];

    for(Node* node in sorted) {
        if ( node.isGroup ) {
            continue;
        }
        
        [ret appendString:[self getHtmlStringForNode:node]];
        [ret appendString:@"    </tr>\n"];
    }
    
    [ret appendString:@"</body>\n</html>"];
    return ret.copy;
}

- (NSString*)getHtmlPrintString:(NSString*)databaseName {
    NSArray<Node*>* sortedGroups = [self.effectiveRootGroup.allChildGroups sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString* path1 = [self getPathDisplayString:obj1];
        NSString* path2 = [self getPathDisplayString:obj2];
        return finderStringCompare(path1, path2);
    }];
    
    NSMutableArray* allGroups = sortedGroups.mutableCopy;
    [allGroups addObject:self.effectiveRootGroup];
    if ( self.recycleBinNode ) {
        [allGroups removeObject:self.recycleBinNode];
    }
    
    
    
    
    
    NSMutableString* ret = [NSMutableString stringWithFormat:@"<html>%@\n<body>\n    <h1 class=\"database-title\">%@</h1>\n<h4>Printed: %@</h6>    ", kPrintingStylesheet, [self htmlStringFromString:databaseName], NSDate.date.iso8601DateString];
    
    for(Node* group in allGroups) {
        if ( group.childRecords.count == 0 ) {
            continue;
        }
        
        [ret appendFormat:@"    <div class=\"group-title\">%@</div>\n", [self htmlStringFromString:[self getPathDisplayString:group]]];
        
        NSMutableArray* nodeStrings = @[].mutableCopy;
        
        NSArray* sorted = [group.childRecords sortedArrayUsingComparator:finderStyleNodeComparator];
        
        for(Node* entry in sorted) {
            NSString* nodeString = [self getHtmlStringForNode:entry];
            [nodeStrings addObject:nodeString];
        }
        
        NSString* groupString = [nodeStrings componentsJoinedByString:@"\n    "];
        
        [ret appendString:groupString];
        [ret appendString:@"    </tr>\n"];
    }
    
    [ret appendString:@"</body>\n</html>"];
    return ret.copy;
}

- (NSString*)getHtmlStringForNode:(Node*)entry {
    NSMutableString* str = [NSMutableString string];
    
    [str appendFormat:@"        <table class=\"entry-table\"><tr class=\"entry-title\"><td colspan=\"100\">%@</td></tr>\n", [self dereference:entry.title node:entry]];
    
    if(entry.fields.username.length) {
        [str appendString:[self getHtmlEntryFieldRow:@"Username" value: [self dereference:entry.fields.username node:entry]]];
        [str appendString:@"\n"];
    }
    
    
    
    [str appendString:[self getHtmlEntryFieldRow:@"Password" value:[self dereference:entry.fields.password node:entry]]];
    [str appendString:@"\n"];

    if(entry.fields.url.length) {
        [str appendString:[self getHtmlEntryFieldRow:@"URL" value:[self dereference:entry.fields.url node:entry]]];
        [str appendString:@"\n"];
    }
    
    if ( entry.fields.email.length) {
        [str appendString:[self getHtmlEntryFieldRow:@"Email" value:entry.fields.email]];
        [str appendString:@"\n"];
    }
    
    if (entry.fields.notes.length) {
        [str appendString:[self getHtmlEntryFieldRow:@"Notes" value:[self dereference:entry.fields.notes node:entry]]];
        [str appendString:@"\n"];
    }
    
    
    
    if(entry.fields.expires) {
        [str appendString:[self getHtmlEntryFieldRow:@"Expires" value:entry.fields.expires.iso8601DateString]];
        [str appendString:@"\n"];
    }

    
    
    if(entry.fields.customFieldsNoEmail.count) {
        for (NSString* key in entry.fields.customFields.allKeys) {
            StringValue* v = entry.fields.customFields[key];
            [str appendString:[self getHtmlEntryFieldRow:key value:v.value]];
            [str appendString:@"\n"];
        }
    }
    
    [str appendString:@"</table>\n"];
    
    return str.copy;
}

- (NSString*)getHtmlEntryFieldRow:(NSString*)label value:(NSString*)value {
    return [NSString stringWithFormat:@"        <tr class=\"entry-field-row\"><td class=\"entry-field-label\">%@</td><td class = \"entry-field-value\">%@</td></tr>", label, [self htmlStringFromString:value]];
}

- (NSString*)htmlStringFromString:(NSString*)str {
    NSXMLNode *textNode = [NSXMLNode textWithStringValue:str];
    NSString *escapedString = textNode.XMLString;
    
    return [[escapedString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br>"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
}



- (void)preSerializationPerformMaintenanceOrMigrations {
    
    
    
    
    [self migrateOlderPasskeysForUsernameIssue]; 
    
    [self trimKeePassHistory];
}

- (void)migrateOlderPasskeysForUsernameIssue {
    for ( Node* node in self.passkeyEntries ) {
        StringValue *usernameSv = node.fields.customFields[@"KPXC_PASSKEY_USERNAME"];
        
        if ( usernameSv == nil ) {
            slog(@"🟢 Migrate older Passkey format for node %@", node.uuid);
            [node.fields setCustomField:@"KPXC_PASSKEY_USERNAME" value:[StringValue valueWithString:node.fields.username protected:NO]];
        }
    }
}

- (void)trimKeePassHistory {
    [self trimKeePassHistory:self.metadata.historyMaxItems maxSize:self.metadata.historyMaxSize];
}

- (void)trimKeePassHistory:(NSNumber*)maxItems maxSize:(NSNumber*)maxSize {
    for(Node* record in self.rootNode.allChildRecords) {
        [self trimNodeKeePassHistory:record maxItems:maxItems maxSize:maxSize];
    }
}

- (BOOL)trimNodeKeePassHistory:(Node*)node maxItems:(NSNumber*)maxItemsNum maxSize:(NSNumber*)maxSizeNum {
    bool trimmed = false;
    
    NSInteger maxItems = maxItemsNum != nil ? maxItemsNum.integerValue : kDefaultHistoryMaxItems;
    NSInteger maxSize = maxSizeNum != nil ? maxSizeNum.integerValue : kDefaultHistoryMaxSize;
    
    if(maxItems >= 0)
    {
        while(node.fields.keePassHistory.count > maxItems)
        {
            [self removeOldestHistoryItem:node];
            trimmed = YES;
        }
    }
    
    if(maxSize >= 0)
    {
        while(true)
        {
            NSUInteger histSize = 0;
            
            for (Node* historicalNode in node.fields.keePassHistory) {
                histSize += [self getEstimatedSize:historicalNode];
            }
            
            if(histSize > maxSize)
            {
                [self removeOldestHistoryItem:node];
                trimmed = YES;
            }
            else {
                break;
            }
        }
    }
    
    return trimmed;
}

- (NSUInteger)getEstimatedSize:(Node*)node {
    
    NSUInteger fixedStructuralSizeGuess = 256;
    
    NSUInteger basicFields = node.title.length +
    node.fields.username.length +
    node.fields.password.length +
    node.fields.url.length +
    node.fields.notes.length;
    
    NSUInteger customFields = 0;
    for (NSString* key in node.fields.customFields.allKeys) {
        customFields += key.length + node.fields.customFields[key].value.length;
    }
    
    
    
    NSUInteger historySize = 0;
    for (Node* historyNode in node.fields.keePassHistory) {
        historySize += [self getEstimatedSize:historyNode];
    }
    
    
    
    NSUInteger iconSize = node.icon ? node.icon.estimatedStorageBytes : 0UL;
        
    
    
    NSUInteger binariesSize = 0;
    for (NSString* filename in node.fields.attachments.allKeys) {
        KeePassAttachmentAbstractionLayer* dbA = node.fields.attachments[filename];
        binariesSize += dbA == nil ? 0 : dbA.estimatedStorageBytes;
    }
    
    NSUInteger textSize = (basicFields + customFields) * 2; 
    
    NSUInteger ret = fixedStructuralSizeGuess + textSize + historySize + iconSize + binariesSize;

    
    
    return ret;
}

- (void)removeOldestHistoryItem:(Node*)node {
    NSArray* sorted = [node.fields.keePassHistory sortedArrayUsingComparator:^NSComparisonResult(Node*  _Nonnull obj1, Node*  _Nonnull obj2) {
        return [obj1.fields.modified compare:obj2.fields.modified];
    }];
    
    if(sorted.count < 2) {
        [node.fields.keePassHistory removeAllObjects];
    }
    else {
        node.fields.keePassHistory = [[sorted subarrayWithRange:NSMakeRange(1, sorted.count - 1)] mutableCopy];
    }
}

@end
