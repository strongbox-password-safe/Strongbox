//
//  StrongboxDatabase.m
//  
//
//  Created by Mark on 16/11/2018.
//

#import "StrongboxDatabase.h"
#import "AttachmentsRationalizer.h"

@interface StrongboxDatabase ()

@property (nonatomic, readonly) NSMutableArray<DatabaseAttachment*> *mutableAttachments;

@end

@implementation StrongboxDatabase

- (instancetype)initWithMetadata:(id<AbstractDatabaseMetadata>)metadata masterPassword:(NSString *)masterPassword {
    return [self initWithRootGroup:[Node rootGroup] metadata:metadata masterPassword:masterPassword];
}

- (instancetype)initWithRootGroup:(Node *)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
                   masterPassword:(NSString *)masterPassword {
    return [self initWithRootGroup:rootGroup metadata:metadata masterPassword:masterPassword attachments:[NSArray array]];
}

- (instancetype)initWithRootGroup:(Node *)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
                   masterPassword:(NSString *)masterPassword
                      attachments:(NSArray<DatabaseAttachment *> *)attachments {
    return [self initWithRootGroup:rootGroup metadata:metadata masterPassword:masterPassword attachments:attachments customIcons:[NSDictionary dictionary]];
}

- (instancetype)initWithRootGroup:(Node *)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
                   masterPassword:(NSString *)masterPassword
                      attachments:(NSArray<DatabaseAttachment *> *)attachments
                      customIcons:(NSDictionary<NSUUID *,NSData *> *)customIcons {
    self = [super init];
    
    if (self) {
        _rootGroup = rootGroup;
        _metadata = metadata;
        _masterPassword = masterPassword;
        _mutableAttachments = [[AttachmentsRationalizer rationalizeAttachments:attachments root:rootGroup] mutableCopy];
        _customIcons = [customIcons mutableCopy];
    }
    
    return self;
}

- (NSArray<DatabaseAttachment *> *)attachments {
    return [NSArray arrayWithArray:_mutableAttachments];
}

- (void)removeNodeAttachment:(Node *)node atIndex:(NSUInteger)atIndex {
    if(atIndex < 0 || atIndex >= _mutableAttachments.count) {
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

-(NSString *)description {
    return [NSString stringWithFormat:@"masterPassword = %@, metadata=%@, rootGroup = %@", self.masterPassword, self.metadata, self.rootGroup];
}

@end
