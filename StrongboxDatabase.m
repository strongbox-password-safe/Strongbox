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

@interface StrongboxDatabase ()

@property (nonatomic, readonly) NSMutableArray<DatabaseAttachment*> *mutableAttachments;
@property (nonatomic) NSMutableDictionary<NSUUID*, NSData*>* mutableCustomIcons;

@end

@implementation StrongboxDatabase

- (instancetype)initWithMetadata:(id<AbstractDatabaseMetadata>)metadata
                  masterPassword:(NSString *)masterPassword
                   keyFileDigest:(NSData*)keyFileDigest {
    return [self initWithRootGroup:[Node rootGroup] metadata:metadata masterPassword:masterPassword keyFileDigest:nil];
}

- (instancetype)initWithRootGroup:(Node *)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
                   masterPassword:(NSString *)masterPassword
                    keyFileDigest:(NSData*)keyFileDigest {
    return [self initWithRootGroup:rootGroup metadata:metadata masterPassword:masterPassword keyFileDigest:keyFileDigest attachments:[NSArray array]];
}

- (instancetype)initWithRootGroup:(Node *)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
                   masterPassword:(NSString *)masterPassword
                    keyFileDigest:(NSData*)keyFileDigest
                      attachments:(NSArray<DatabaseAttachment *> *)attachments {
    return [self initWithRootGroup:rootGroup metadata:metadata masterPassword:masterPassword keyFileDigest:keyFileDigest attachments:attachments customIcons:[NSDictionary dictionary]];
}

- (instancetype)initWithRootGroup:(Node *)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
                   masterPassword:(NSString *)masterPassword
                    keyFileDigest:(NSData*)keyFileDigest
                      attachments:(NSArray<DatabaseAttachment *> *)attachments
                      customIcons:(NSDictionary<NSUUID *,NSData *> *)customIcons {
    self = [super init];
    
    if (self) {
        _rootGroup = rootGroup;
        _metadata = metadata;
        _masterPassword = masterPassword;
        _keyFileDigest = keyFileDigest;
        _mutableAttachments = [[AttachmentsRationalizer rationalizeAttachments:attachments root:rootGroup] mutableCopy];
        
        self.mutableCustomIcons = [customIcons mutableCopy];
        [self rationalizeCustomIcons];
    }
    
    return self;
}

- (NSDictionary<NSUUID *,NSData *> *)customIcons {
    [self rationalizeCustomIcons]; // TODO: Perf
    return [self.mutableCustomIcons copy];
}

- (NSArray<DatabaseAttachment *> *)attachments {
    return [self.mutableAttachments copy];
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

- (void)trimKeePassHistory:(NSInteger)maxItems maxSize:(NSInteger)maxSize {
    for(Node* record in self.rootGroup.allChildRecords) {
        [self trimNodeKeePassHistory:record maxItems:maxItems maxSize:maxSize];
    }
}

- (BOOL)trimNodeKeePassHistory:(Node*)node maxItems:(NSInteger)maxItems maxSize:(NSInteger)maxSize {
    bool trimmed = false;
    
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
        customFields += key.length + node.fields.customFields[key].length;
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

- (void)removeNodeAttachment:(Node *)node atIndex:(NSUInteger)atIndex {
    if(atIndex < 0 || atIndex >= node.fields.attachments.count) {
        NSLog(@"WARN: removeNodeAttachment [OUT OF BOUNDS]");
        return;
    }
    
    [node.fields.attachments removeObjectAtIndex:atIndex];
    _mutableAttachments = [[AttachmentsRationalizer rationalizeAttachments:_mutableAttachments root:self.rootGroup] mutableCopy];
}

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment *)attachment {
    DatabaseAttachment* dbAttachment = [[DatabaseAttachment alloc] init];
    dbAttachment.data = attachment.data;
    [_mutableAttachments addObject:dbAttachment];
    
    NodeFileAttachment* nodeAttachment = [[NodeFileAttachment alloc] init];
    nodeAttachment.filename = attachment.filename;
    nodeAttachment.index = (uint32_t)_mutableAttachments.count - 1;
    [node.fields.attachments addObject:nodeAttachment];
    
    _mutableAttachments = [[AttachmentsRationalizer rationalizeAttachments:_mutableAttachments root:self.rootGroup] mutableCopy];
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

    _mutableAttachments = [[AttachmentsRationalizer rationalizeAttachments:_mutableAttachments root:self.rootGroup] mutableCopy];
}

- (void)setNodeCustomIcon:(Node*)node data:(NSData*)data {
    if(data == nil) {
        node.customIconUuid = nil;
    }
    else {
        NSUUID *uuid = [NSUUID UUID];
        node.customIconUuid = uuid;
        self.mutableCustomIcons[uuid] = data;
    }
    
    [self rationalizeCustomIcons];
}

- (void)rationalizeCustomIcons {
    //NSLog(@"Before Rationalization: [%@]", self.mutableCustomIcons.allKeys);
    
    NSArray<Node*>* currentCustomIconNodes = [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.customIconUuid != nil;
    }];
    
    NSArray<Node*>* allNodesWithHistoryAndCustomIcons = [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
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

    NSMutableDictionary<NSUUID*, NSData*>* fresh = [NSMutableDictionary dictionaryWithCapacity:customIconNodes.count];
    for (Node* node in customIconNodes) {
        NSUUID* key = node.customIconUuid;
        if(self.mutableCustomIcons[key]) {
            fresh[key] = self.mutableCustomIcons[key];
        }
        else {
            NSLog(@"Removed bad Custom Icon reference [%@]-[%@]", node.title, key);
            node.customIconUuid = nil;
        }
    }
    
    //NSLog(@"Rationalized: [%@]", fresh.allKeys);
    
    self.mutableCustomIcons = fresh;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"masterPassword = %@, metadata=%@, rootGroup = %@", self.masterPassword, self.metadata, self.rootGroup];
}

@end
