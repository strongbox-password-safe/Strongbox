//
//  StrongboxDatabase.m
//  
//
//  Created by Mark on 16/11/2018.
//

#import "StrongboxDatabase.h"
#import "AttachmentsRationalizer.h"
#import "NSArray+Extensions.h"
#import "KeePassDatabaseMetadata.h"
#import "KeePass4DatabaseMetadata.h"
#import "KeePassConstants.h"
#import "CustomIconsRationalizer.h"

static NSString* const kKeePass1BackupGroupName = @"Backup";

@interface StrongboxDatabase ()

@property (nonatomic, readonly) NSMutableArray<DatabaseAttachment*> *mutableAttachments;
@property (nonatomic, readonly) NSMutableDictionary<NSUUID*, NSDate*> *mutableDeletedObjects;
@property (nonatomic) NSMutableDictionary<NSUUID*, NSData*>* mutableCustomIcons;

@end

@implementation StrongboxDatabase

- (instancetype)initWithMetadata:(id<AbstractDatabaseMetadata>)metadata
             compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors {
    return [self initWithRootGroup:[Node rootGroup]
                          metadata:metadata
               compositeKeyFactors:compositeKeyFactors];
}

- (instancetype)initWithRootGroup:(Node*)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors {
    return [self initWithRootGroup:rootGroup
                          metadata:metadata
               compositeKeyFactors:compositeKeyFactors
                       attachments:[NSArray array]];
}

- (instancetype)initWithRootGroup:(Node*)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
                      attachments:(NSArray<DatabaseAttachment*>*)attachments {
    return [self initWithRootGroup:rootGroup
                          metadata:metadata
               compositeKeyFactors:compositeKeyFactors
                       attachments:attachments
                       customIcons:[NSDictionary dictionary]];
}

- (instancetype)initWithRootGroup:(Node*)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
                      attachments:(NSArray<DatabaseAttachment*>*)attachments
                      customIcons:(NSDictionary<NSUUID*, NSData*>*)customIcons {
    return [self initWithRootGroup:rootGroup
                          metadata:metadata
               compositeKeyFactors:compositeKeyFactors
                       attachments:attachments
                       customIcons:[NSDictionary dictionary]
                    deletedObjects:@{}];
}

- (instancetype)initWithRootGroup:(Node *)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      attachments:(NSArray<DatabaseAttachment *> *)attachments
                      customIcons:(NSDictionary<NSUUID *,NSData *> *)customIcons
                   deletedObjects:(NSDictionary<NSUUID *,NSDate *> *)deletedObjects {
    self = [super init];
    
    if (self) {
        _rootGroup = rootGroup;
        _metadata = metadata;
        _compositeKeyFactors = compositeKeyFactors;
        _mutableAttachments = [[AttachmentsRationalizer rationalizeAttachments:attachments root:rootGroup] mutableCopy];
        
        self.mutableCustomIcons = [customIcons mutableCopy];
        [self rationalizeCustomIcons];
        
        _mutableDeletedObjects = deletedObjects.mutableCopy;
        
        //NSLog(@"Got Deleted Objects: [%@]", deletedObjects);
    }
    
    return self;
}

- (Node*)findById:(NSUUID*)uuid {
    return [self.rootGroup findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
        return [node.uuid isEqual:uuid];
    }];
}

- (void)rationalizeAttachments {
    _mutableAttachments = [[AttachmentsRationalizer rationalizeAttachments:_mutableAttachments root:self.rootGroup] mutableCopy];
}

- (void)performPreSerializationTidy {
    [self rationalizeAttachments];
    [self rationalizeCustomIcons];
    [self trimKeePassHistory];
}

- (void)trimKeePassHistory {
    if([self.metadata isKindOfClass:[KeePassDatabaseMetadata class]]) {
        KeePassDatabaseMetadata* metadata = (KeePassDatabaseMetadata*)self.metadata;
        [self trimKeePassHistory:metadata.historyMaxItems maxSize:metadata.historyMaxSize];
    }
    else if([self.metadata isKindOfClass:[KeePass4DatabaseMetadata class]]) {
        KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)self.metadata;
        [self trimKeePassHistory:metadata.historyMaxItems maxSize:metadata.historyMaxSize];
    }
}

- (void)trimKeePassHistory:(NSNumber*)maxItems maxSize:(NSNumber*)maxSize {
    for(Node* record in self.rootGroup.allChildRecords) {
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
    // Try to get a decent estimate of size but really this is not very precise...
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
    
    // History
    
    NSUInteger historySize = 0;
    for (Node* historyNode in node.fields.keePassHistory) {
        historySize += [self getEstimatedSize:historyNode];
    }
    
    // Custom Icon
    
    NSUInteger iconSize = 0;
    if(node.customIconUuid) {
        NSData* data = self.mutableCustomIcons[node.customIconUuid];
        iconSize = data == nil ? 0 : data.length;
    }
    
    // Binary
    
    NSUInteger binariesSize = 0;
    for (NodeFileAttachment* attachments in node.fields.attachments) {
        DatabaseAttachment* dbA = self.mutableAttachments[attachments.index];
        binariesSize += dbA == nil ? 0 : dbA.estimatedStorageBytes;
    }
    
    NSUInteger textSize = (basicFields + customFields) * 2; // Unicode in memory probably?
    
    NSUInteger ret = fixedStructuralSizeGuess + textSize + historySize + iconSize + binariesSize;

    //NSLog(@"Estimated Size: %@ -> [%lu]", node, (unsigned long)ret);
    
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Attachments

- (NSArray<DatabaseAttachment *> *)attachments {
    return [self.mutableAttachments copy];
}

- (void)removeNodeAttachment:(Node *)node atIndex:(NSUInteger)atIndex {
    if(atIndex < 0 || atIndex >= node.fields.attachments.count) {
        NSLog(@"WARN: removeNodeAttachment [OUT OF BOUNDS]");
        return;
    }
    
    [node.fields.attachments removeObjectAtIndex:atIndex];
    [self rationalizeAttachments];
}

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment *)attachment {
    [self addNodeAttachment:node attachment:attachment rationalize:YES];
}

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment *)attachment rationalize:(BOOL)rationalize {
    [_mutableAttachments addObject:attachment.dbAttachment];
    
    NodeFileAttachment* nodeAttachment = [[NodeFileAttachment alloc] init];
    nodeAttachment.filename = attachment.filename;
    nodeAttachment.index = (uint32_t)_mutableAttachments.count - 1;
    [node.fields.attachments addObject:nodeAttachment];

    if(rationalize) {
        [self rationalizeAttachments];
    }
}

- (NSSet<Node*>*)getMinimalNodeSet:(const NSArray<Node*>*)nodes {
    // Filter out children that are already included because the group is included,
    // so we're not copying/moving/deleting twice
    
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Deletions

- (NSDictionary<NSUUID *,NSDate *> *)deletedObjects {
    return self.mutableDeletedObjects.copy;
}

- (BOOL)canRecycle:(Node *)item {
    BOOL willRecycle = self.recycleBinEnabled;
    
    if(self.recycleBinEnabled && self.recycleBinNode) {
        if([self.recycleBinNode contains:item] || self.recycleBinNode == item) {
            willRecycle = NO;
        }
    }

    return willRecycle;
}

- (void)deleteAllGroupItems:(Node*)group deletionDate:(NSDate*)deletionDate {
    for (Node* entry in group.childRecords) {
        [group removeChild:entry];
        self.mutableDeletedObjects[entry.uuid] = deletionDate;
    }

    for (Node* subgroup in group.childGroups) {
        [self deleteAllGroupItems:subgroup deletionDate:deletionDate];
        self.mutableDeletedObjects[subgroup.uuid] = deletionDate;
    }
}

- (NSArray<NodeHierarchyReconstructionData*>*)getHierarchyCloneForReconstruction:(const NSArray<Node*>*)items {
    return [items map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        NodeHierarchyReconstructionData* recon = [[NodeHierarchyReconstructionData alloc] init];
        
        recon.index = [obj.parent.children indexOfObject:obj];
        recon.clonedNode = [obj clone:YES];
        
        return recon;
    }];
}

- (void)reconstruct:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    for (NodeHierarchyReconstructionData* recon in undoData) {
        Node* parent = recon.clonedNode.parent;
        
        if (!parent) {
            continue; // Should never happen
        }
        
        [parent addChild:recon.clonedNode keePassGroupTitleRules:YES];
        
        NSUInteger currentIndex = parent.children.count - 1;
        if (currentIndex != recon.index) {
            [parent moveChild:currentIndex to:recon.index];
        }
    }
}

- (void)unDelete:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    [self reconstruct:undoData];
    
    for (NodeHierarchyReconstructionData* recon in undoData) {
        // Remove all children and self from deleted Objects
        NSArray<NSUUID*>* childIds = [recon.clonedNode.allChildren map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }];
        
        [self.mutableDeletedObjects removeObjectForKey:recon.clonedNode.uuid];
        [self.mutableDeletedObjects removeObjectsForKeys:childIds];
    }
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
    
    for (Node* item in minimalNodeSet) {
        if (item.parent == nil || ![item.parent contains:item]) { // Very very strange if this ever happens we're in trouble
            NSLog(@"WARNWARN: Attempt to delete item with no parent");
            return;
        }

        if (item.isGroup) {
            [self deleteAllGroupItems:item deletionDate:now];
        }

        [item.parent removeChild:item];
        self.mutableDeletedObjects[item.uuid] = now;
    }
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    return [self recycleItems:items undoData:nil];
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>**)undoData {
    if (!self.recycleBinEnabled) {
        NSLog(@"WARNWARN: Attempt to recycle item when recycle bin disabled!");
        return NO;
    }
    
    if(self.recycleBinNode == nil) {     // UUID is NIL/Non Existent or Zero? - Create
        [self createNewRecycleBinNode];
    }
    
    NSDate* now = NSDate.date;
    NSSet<Node*> *minimalNodeSet = [self getMinimalNodeSet:items];

    BOOL ret = [self moveItems:minimalNodeSet.allObjects destination:self.recycleBinNode keePassGroupTitleRules:YES date:now undoData:undoData];
    
    if (ret) {
        for (Node* item in minimalNodeSet) { // Confirmed correct - touch should only be done on minimal node set - 22-May-2020
            [item touchAt:now]; // NB: accessed/usage count recursively (weirdly I think but following KeePass original)
        }
    }

    return ret;
}

- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    [self undoMove:undoData];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Moves

- (BOOL)validateMoveItems:(const NSArray<Node*>*)items destination:(Node*)destination keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    NSArray<Node*>* minimalItems = [self getMinimalNodeSet:items].allObjects;
    
    BOOL invalid = [minimalItems anyMatch:^BOOL(Node * _Nonnull obj) {
        return obj.parent == nil || ![obj validateChangeParent:destination keePassGroupTitleRules:keePassGroupTitleRules];
    }];
    
    return !invalid;
}

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    return [self moveItems:items destination:destination keePassGroupTitleRules:keePassGroupTitleRules date:NSDate.date undoData:nil];
}

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination keePassGroupTitleRules:(BOOL)keePassGroupTitleRules undoData:(NSArray<NodeHierarchyReconstructionData*>**)undoData {
    return [self moveItems:items destination:destination keePassGroupTitleRules:keePassGroupTitleRules date:NSDate.date undoData:undoData];
}

- (BOOL)moveItems:(const NSArray<Node *> *_Nonnull)items
      destination:(Node*_Nonnull)destination
keePassGroupTitleRules:(BOOL)keePassGroupTitleRules
             date:(NSDate*_Nonnull)date
         undoData:(NSArray<NodeHierarchyReconstructionData*>**)undoData {
    NSArray<Node*>* minimalItems = [self getMinimalNodeSet:items].allObjects;
    
    BOOL invalid = [minimalItems anyMatch:^BOOL(Node * _Nonnull obj) {
        return obj.parent == nil || ![obj validateChangeParent:destination keePassGroupTitleRules:keePassGroupTitleRules];
    }];
    
    if (invalid) {
        return NO;
    }
    
    if (undoData) {
        *undoData = [self getHierarchyCloneForReconstruction:items];
    }

    // Attempt the move now - this could break despite the above check because someone tries to
    // insert a group with the same name as one we've already inserted for example
    
    BOOL rollback = NO;
    
    NSMutableArray<Node*> *rollbackTo = NSMutableArray.array;
    for(Node* itemToMove in minimalItems) {
        [rollbackTo addObject:itemToMove.parent];
        
        if(![itemToMove changeParent:destination keePassGroupTitleRules:keePassGroupTitleRules]) {
            rollback = YES;
            NSLog(@"Error Changing Parents. [%@]", itemToMove);
            break;
        }
    }
    
    if (rollback) {
        int i = 0;
        for (Node* previousParent in rollbackTo) {
            [minimalItems[i++] changeParent:previousParent keePassGroupTitleRules:keePassGroupTitleRules];
        }
    }
    else {
        for(Node* itemToMove in minimalItems) { // Confirmed correct - touch should only be done on minimal node set - 22-May-2020
            [itemToMove touchLocationChanged:date]; // NB: Only LocationChanged (Date Mod/Accessed not changed) nor parents in keeping with KeePass original
        }
    }
    
    return !rollback;
}

- (void)undoMove:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    // Find the items that were moved based on the undo data and delete them completely from the hierarchy
    // then reconstruct the hierarcjy based on the undo data and clones in there. This completely reverses
    // the move (including Location Changed and all touch properties.
    
    for (NodeHierarchyReconstructionData* reconItem in undoData) {
        Node* originalMovedItem = [self findById:reconItem.clonedNode.uuid];
    
        if (originalMovedItem) {
            [originalMovedItem.parent removeChild:originalMovedItem];
        }
        else {
            // Should never happen but WARN
            NSLog(@"WARNWARN: Could not find original moved item! [%@]", reconItem);
        }
    }
    
    // Now rebuild with the undo clone...
    
    [self reconstruct:undoData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Add

- (BOOL)validateAddChild:(Node *)item destination:(Node *)destination keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    return [destination validateAddChild:item keePassGroupTitleRules:keePassGroupTitleRules];
}

- (BOOL)addChild:(Node *)item destination:(Node *)destination keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if( ![destination validateAddChild:item keePassGroupTitleRules:keePassGroupTitleRules]) {
        return NO;
    }

    return [destination addChild:item keePassGroupTitleRules:keePassGroupTitleRules];
}

- (void)unAddChild:(Node *)item {
    [item.parent removeChild:item];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Custom Icons

- (NSDictionary<NSUUID *,NSData *> *)customIcons {
    return [self.mutableCustomIcons copy];
}

- (void)setNodeAttachments:(Node*)node attachments:(NSArray<UiAttachment*>*)attachments {
    [node.fields.attachments removeAllObjects];
    
    for (UiAttachment* attachment in attachments) {
        [_mutableAttachments addObject:attachment.dbAttachment];
        
        NodeFileAttachment *nodeAttachment = [[NodeFileAttachment alloc] init];
        nodeAttachment.filename = attachment.filename;
        nodeAttachment.index = (uint32_t)_mutableAttachments.count - 1;
        
        [node.fields.attachments addObject:nodeAttachment];
    }

    [self rationalizeAttachments];
}

- (void)setNodeCustomIcon:(Node*)node data:(NSData*)data rationalize:(BOOL)rationalize {
    if(data == nil) {
        node.customIconUuid = nil;
    }
    else {
        NSUUID *uuid = [NSUUID UUID];
        node.customIconUuid = uuid;
        self.mutableCustomIcons[uuid] = data;
    }
    
    if(rationalize) {
        [self rationalizeCustomIcons];
    }
}

- (void)setNodeCustomIconUuid:(Node *)node uuid:(NSUUID*)uuid rationalize:(BOOL)rationalize {
    node.customIconUuid = uuid;
    
    if(rationalize) {
        [self rationalizeCustomIcons];
    }
}

- (void)rationalizeCustomIcons {
    self.mutableCustomIcons = [CustomIconsRationalizer rationalize:self.customIcons root:self.rootGroup];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Recycle Bin (KeePass 2) -

- (void)setRecycleBinEnabled:(BOOL)recycleBinEnabled {
    if ( [self.metadata isKindOfClass:[KeePassDatabaseMetadata class]] ) {
        KeePassDatabaseMetadata* metadata = (KeePassDatabaseMetadata*)self.metadata;
        metadata.recycleBinEnabled = recycleBinEnabled;
    }
    else if ( [self.metadata isKindOfClass:[KeePass4DatabaseMetadata class]] ) {
        KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)self.metadata;
        metadata.recycleBinEnabled = recycleBinEnabled;
    }
}

- (BOOL)recycleBinEnabled {
    // TODO: Move the adaptor specific metadata checks into the adaptors, shouldn't be here at all
    
    if([self.metadata isKindOfClass:[KeePassDatabaseMetadata class]]) {
        KeePassDatabaseMetadata* metadata = (KeePassDatabaseMetadata*)self.metadata;
        return metadata.recycleBinEnabled;
    }
    else if([self.metadata isKindOfClass:[KeePass4DatabaseMetadata class]]) {
        KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)self.metadata;
        return metadata.recycleBinEnabled;
    }
    else {
        return NO;
    }
}

- (NSUUID *)recycleBinNodeUuid {
    if([self.metadata isKindOfClass:[KeePassDatabaseMetadata class]]) {
        KeePassDatabaseMetadata* metadata = (KeePassDatabaseMetadata*)self.metadata;
        return metadata.recycleBinGroup;
    }
    else if([self.metadata isKindOfClass:[KeePass4DatabaseMetadata class]]) {
        KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)self.metadata;
        return metadata.recycleBinGroup;
    }
    else {
        return nil;
    }
}

- (void)setRecycleBinNodeUuid:(NSUUID *)recycleBinNode {
    if([self.metadata isKindOfClass:[KeePassDatabaseMetadata class]]) {
        KeePassDatabaseMetadata* metadata = (KeePassDatabaseMetadata*)self.metadata;
        metadata.recycleBinGroup = recycleBinNode;
    }
    else if([self.metadata isKindOfClass:[KeePass4DatabaseMetadata class]]) {
        KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)self.metadata;
        metadata.recycleBinGroup = recycleBinNode;
    }
}

- (NSDate *)recycleBinChanged {
    if([self.metadata isKindOfClass:[KeePassDatabaseMetadata class]]) {
        KeePassDatabaseMetadata* metadata = (KeePassDatabaseMetadata*)self.metadata;
        return metadata.recycleBinChanged;
    }
    else if([self.metadata isKindOfClass:[KeePass4DatabaseMetadata class]]) {
        KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)self.metadata;
        return metadata.recycleBinChanged;
    }
    else {
        return nil;
    }
}

- (void)setRecycleBinChanged:(NSDate *)recycleBinChanged {
    if([self.metadata isKindOfClass:[KeePassDatabaseMetadata class]]) {
        KeePassDatabaseMetadata* metadata = (KeePassDatabaseMetadata*)self.metadata;
        metadata.recycleBinChanged = recycleBinChanged;
    }
    else if([self.metadata isKindOfClass:[KeePass4DatabaseMetadata class]]) {
        KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)self.metadata;
        metadata.recycleBinChanged = recycleBinChanged;
    }
}

- (Node *)recycleBinNode {
    if(self.recycleBinNodeUuid) {
        return [self.rootGroup findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
            return [node.uuid isEqual:self.recycleBinNodeUuid];
        }];
    }
    else {
        return nil;
    }
}

- (Node*)keePass1BackupNode {
    return [self.rootGroup findFirstChild:NO predicate:^BOOL(Node * _Nonnull node) {
        return [node.title isEqualToString:kKeePass1BackupGroupName];
    }];
}

- (void)createNewRecycleBinNode {
    // KeePass funky root/non-root group! - Slight abstractioon leak here... this will only work for KeePass

    Node* effectiveRoot;
    if(self.rootGroup.children.count > 0) {
        effectiveRoot = [self.rootGroup.children objectAtIndex:0];
    }
    else {
        effectiveRoot = self.rootGroup; // This should never be able to happen but for safety
    }

    Node* recycleBin = [[Node alloc] initAsGroup:@"Recycle Bin" parent:effectiveRoot keePassGroupTitleRules:YES uuid:nil];
    recycleBin.iconId = @(43);
    [effectiveRoot addChild:recycleBin keePassGroupTitleRules:YES];
    
    self.recycleBinNodeUuid = recycleBin.uuid;
    self.recycleBinChanged = [NSDate date];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//

-(NSString *)description {
    return [NSString stringWithFormat:@"masterPassword = %@, metadata=%@, rootGroup = %@",
            self.compositeKeyFactors.password, self.metadata, self.rootGroup];
}

@end
