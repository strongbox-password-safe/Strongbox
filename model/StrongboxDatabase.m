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
@property (nonatomic, readonly) NSMutableArray<DeletedItem*> *mutableDeletedObjects;
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
                    deletedObjects:@[]];
}

- (instancetype)initWithRootGroup:(Node *)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      attachments:(NSArray<DatabaseAttachment *> *)attachments
                      customIcons:(NSDictionary<NSUUID *,NSData *> *)customIcons
                   deletedObjects:(NSArray<DeletedItem *> *)deletedObjects {
    self = [super init];
    
    if (self) {
        _rootGroup = rootGroup;
        _metadata = metadata;
        _compositeKeyFactors = compositeKeyFactors;
        _mutableAttachments = [[AttachmentsRationalizer rationalizeAttachments:attachments root:rootGroup] mutableCopy];
        
        self.mutableCustomIcons = [customIcons mutableCopy];
        [self rationalizeCustomIcons];
        
        _mutableDeletedObjects = deletedObjects.mutableCopy;
        
        NSLog(@"Got Deleted Objects: [%@]", deletedObjects);
    }
    
    return self;
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
        binariesSize += dbA == nil ? 0 : dbA.data.length;
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
    DatabaseAttachment* dbAttachment = [[DatabaseAttachment alloc] init];
    dbAttachment.data = attachment.data;
    [_mutableAttachments addObject:dbAttachment];
    
    NodeFileAttachment* nodeAttachment = [[NodeFileAttachment alloc] init];
    nodeAttachment.filename = attachment.filename;
    nodeAttachment.index = (uint32_t)_mutableAttachments.count - 1;
    [node.fields.attachments addObject:nodeAttachment];

    if(rationalize) {
        [self rationalizeAttachments];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Deletions

- (NSArray<DeletedItem *> *)deletedObjects {
    return [self.mutableDeletedObjects copy];
}

- (void)deleteItem:(Node *)item {
    if (item.parent == nil || ![item.parent contains:item]) { // Very very strange if this ever happens we're in trouble
        NSLog(@"WARNWARN: Attempt to delete item with no parent");
        return;
    }

    NSDate* now = NSDate.date;
    
    if (item.isGroup) {
        [self deleteAllGroupItems:item deletionDate:now];
    }

    [item.parent removeChild:item];
    [self.mutableDeletedObjects addObject:[DeletedItem uuid:item.uuid date:now]];
}

- (void)deleteAllGroupItems:(Node*)group deletionDate:(NSDate*)deletionDate {
    for (Node* entry in group.childRecords) {
        [group removeChild:entry];
        [self.mutableDeletedObjects addObject:[DeletedItem uuid:entry.uuid date:deletionDate]];
    }

    for (Node* subgroup in group.childGroups) {
        [self deleteAllGroupItems:subgroup deletionDate:deletionDate];
        [self.mutableDeletedObjects addObject:[DeletedItem uuid:subgroup.uuid date:deletionDate]];
    }
}

//- (BOOL)unDeleteItemAndRemoveFromDeletedObjects:(Node *)item parent:(Node *)parent {
//    // TODO:
//    // Need to find parent and re-add item
//    // Also need to remove from Deleted Objects
//
//    return NO;
//}

- (BOOL)recycleItem:(Node *)item {
    if (!self.recycleBinEnabled) {
        NSLog(@"WARNWARN: Attempt to recycle item when recycle bin disabled!");
        return NO;
    }
    
    if(self.recycleBinNode == nil) {     // UUID is NIL/Non Existent or Zero? - Create
        [self createNewRecycleBinNode];
    }
    
    BOOL ret = [item changeParent:self.recycleBinNode keePassGroupTitleRules:YES];
    
    if (ret) {
        [item touch]; // NB: LocationChanged not set but accessed/usage count recursively (weirdly I think)
    }

    return ret;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Moves

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    BOOL invalid = [items anyMatch:^BOOL(Node * _Nonnull obj) {
        return obj.parent == nil || ![obj validateChangeParent:destination keePassGroupTitleRules:keePassGroupTitleRules];
    }];
    
    if (invalid) {
        return NO;
    }
    
    // Attempt the move now - this could break despite the above check because someone tries to insert a group with the same name as one we've already inserted for example
    
    BOOL rollback = NO;
    
    NSMutableArray<Node*> *rollbackTo = NSMutableArray.array;
    for(Node* itemToMove in items) {
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
            [items[i++] changeParent:previousParent keePassGroupTitleRules:keePassGroupTitleRules];
        }
    }
    else {
        for(Node* itemToMove in items) {
            [itemToMove touchLocationChanged]; // NB: Only LocationChanged (Date Mod/Accessed not changed) nor parents
        }
    }
    
    return !rollback;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Custom Icons

- (NSDictionary<NSUUID *,NSData *> *)customIcons {
    return [self.mutableCustomIcons copy];
}

- (void)setNodeAttachments:(Node*)node attachments:(NSArray<UiAttachment*>*)attachments {
    [node.fields.attachments removeAllObjects];
    
    for (UiAttachment* attachment in attachments) {
        DatabaseAttachment* dbAttachment = [[DatabaseAttachment alloc] init];
        dbAttachment.data = attachment.data;
        
        [_mutableAttachments addObject:dbAttachment];
        
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

- (void)rationalizeCustomIcons {
    self.mutableCustomIcons = [CustomIconsRationalizer rationalize:self.customIcons root:self.rootGroup];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Recycle Bin (KeePass 2) -

- (void)setRecycleBinEnabled:(BOOL)recycleBinEnabled {
    if([self.metadata isKindOfClass:[KeePassDatabaseMetadata class]]) {
        KeePassDatabaseMetadata* metadata = (KeePassDatabaseMetadata*)self.metadata;
        metadata.recycleBinEnabled = recycleBinEnabled;
    }
    else if([self.metadata isKindOfClass:[KeePass4DatabaseMetadata class]]) {
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
