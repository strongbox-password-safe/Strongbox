//
//  StrongboxDatabase.m
//  
//
//  Created by Mark on 16/11/2018.
//

#import "StrongboxDatabase.h"
#import "AttachmentsRationalizer.h"
#import "NSArray+Extensions.h"

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
    [self rationalizeCustomIcons];
    return [self.mutableCustomIcons copy];
}

- (NSArray<DatabaseAttachment *> *)attachments {
    return [self.mutableAttachments copy];
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
    
    NSArray<Node*>* customIconNodes = [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.customIconUuid != nil;
    }];
    
    NSMutableDictionary<NSUUID*, NSData*>* fresh = [NSMutableDictionary dictionaryWithCapacity:customIconNodes.count];
    for (Node* node in customIconNodes) {
        NSUUID* key = node.customIconUuid;
        if(self.mutableCustomIcons[key]) {
            fresh[key] = self.mutableCustomIcons[key];
        }
        else {
            NSLog(@"Removed bad Custom Icon reference [%@]-[%@]", node, key);
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
