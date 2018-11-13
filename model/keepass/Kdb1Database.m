//
//  Kdb1Database.m
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Kdb1Database.h"
#import "KdbSerialization.h"
#import "NSArray+Extensions.h"
#import "Kdb1DatabaseMetadata.h"
#import "KeePassConstants.h"
#import "Utils.h"

static const BOOL kLogVerbose = NO;

@interface Kdb1Database ()

@property NSArray<KdbEntry*>* existingMetaEntries;

@end

@implementation Kdb1Database

+ (NSString *)fileExtension {
    return @"kdb";
}

- (NSString *)fileExtension {
    return [Kdb1Database fileExtension];
}

- (DatabaseFormat)format {
    return kKeePass1;
}

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [KdbSerialization isAValidSafe:candidate];
}

- (instancetype)initNewWithoutPassword {
    return [self initNewWithPassword:nil];
}

- (void)addKeePassDefaultRootGroup {
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:_rootGroup uuid:nil];
    [_rootGroup addChild:keePassRootGroup];
}

- (instancetype)initNewWithPassword:(NSString *)password {
    if (self = [super init]) {
        _rootGroup = [[Node alloc] initAsRoot:nil childRecordsAllowed:NO];
        
        [self addKeePassDefaultRootGroup];
        
        _attachments = [NSMutableArray array];
        _metadata = [[Kdb1DatabaseMetadata alloc] init];
        
        self.existingMetaEntries = [NSArray array];
        self.masterPassword = password;
        
        return self;
    }
    else {
        return nil;
    }
}

- (instancetype _Nullable)initExistingWithDataAndPassword:(NSData * _Nonnull)data password:(NSString * _Nonnull)password error:(NSError *__autoreleasing  _Nonnull * _Nonnull)ppError {
    if (self = [super init]) {
        KdbSerializationData *serializationData = [KdbSerialization deserialize:data password:password ppError:ppError];
        
        if(serializationData == nil) {
            NSLog(@"Error getting Decrypting KDB binary: [%@]", *ppError);
            return nil;
        }

        if(kLogVerbose) {
            NSLog(@"KdbSerializationData = [%@]", serializationData);
        }

        _attachments = [NSMutableArray array];
        _rootGroup = [self buildStrongboxModel:serializationData];

        if(kLogVerbose) {
            NSLog(@"Attachments: %@", self.attachments);
        }

        // Metadata

        _metadata = [[Kdb1DatabaseMetadata alloc] init];

        self.metadata.version = serializationData.version;
        self.metadata.transformRounds = serializationData.transformRounds;
        self.metadata.flags = serializationData.flags;

        self.existingMetaEntries = serializationData.metaEntries;
        self.masterPassword = password;
    }
    
    return self;
}

- (NSData *)getAsData:(NSError **)error {
    KdbSerializationData *serializationData = [[KdbSerializationData alloc] init];
    
    if(self.rootGroup.childGroups.count == 0) {
        // KDB1 Requires at least one group at the top
        [self addKeePassDefaultRootGroup];
    }
    
    [self nodeModelToGroupsAndEntries:0
                                group:self.rootGroup
                    serializationData:serializationData
                     existingGroupIds:[NSMutableSet<NSNumber*> set]];
    
    serializationData.flags = self.metadata.flags;
    serializationData.version = self.metadata.version;
    serializationData.transformRounds = self.metadata.transformRounds;
    [serializationData.metaEntries addObjectsFromArray:self.existingMetaEntries];
    
    return [KdbSerialization serialize:serializationData password:self.masterPassword ppError:error];
}

-(void)nodeModelToGroupsAndEntries:(int)level
                             group:(Node*)group
                 serializationData:(KdbSerializationData*)serializationData
                  existingGroupIds:(NSMutableSet<NSNumber*>*)existingGroupIds {
    NSArray<Node*>* subGroups = [group childGroups];
    
    for (Node* subGroup in subGroups) {
        KdbGroup* kdbGroup = groupToKdbGroup(subGroup, level, existingGroupIds);
        [serializationData.groups addObject:kdbGroup];

        NSArray<KdbEntry*> *entries = [[subGroup childRecords] map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return [self recordToKdbEntry:obj kdbGroup:kdbGroup];
        }];
        
        [serializationData.entries addObjectsFromArray:entries];

        [self nodeModelToGroupsAndEntries:level + 1 group:subGroup serializationData:serializationData  existingGroupIds:existingGroupIds];
    }
}

KdbGroup* groupToKdbGroup(Node* group, int level,NSMutableSet<NSNumber*> *existingGroupIds) {
    KdbGroup *ret = [[KdbGroup alloc] init];
    
    ret.groupId = newGroupId(existingGroupIds);
    [existingGroupIds addObject:@(ret.groupId)];
    
    ret.name = group.title;
    ret.imageId = group.iconId != nil ? group.iconId : @(48);
    
    if(group.linkedData) {
        KdbGroup* previous = (KdbGroup*)group.linkedData;
        
        ret.creation = previous.creation;
        ret.modification = previous.modification;
        ret.lastAccess = previous.lastAccess;
        ret.expiry = previous.expiry;
        ret.flags = previous.flags;
        ret.imageId = previous.imageId;
    }
    
    ret.level = level;
    return ret;
}

- (KdbEntry*)recordToKdbEntry:(Node*)record kdbGroup:(KdbGroup*)kdbGroup {
    KdbEntry* ret = [[KdbEntry alloc] init];
    
    ret.uuid = record.uuid;
    ret.groupId = kdbGroup.groupId;
    ret.imageId = record.iconId != nil ? record.iconId : @(0);
    ret.title = record.title;
    ret.url = record.fields.url;
    ret.username = record.fields.username;
    ret.password = record.fields.password;
    ret.notes = record.fields.notes;
    ret.creation = record.fields.created;
    ret.modified = record.fields.modified;
    ret.accessed = record.fields.accessed;
    
    if(record.fields.attachments.count) { 
        NodeFileAttachment *theAttachment = record.fields.attachments[0];
        
        ret.binaryFileName = theAttachment.filename;
        ret.binaryData = self.attachments[theAttachment.index].data;
    }
    
    if(record.linkedData) {
        KdbEntry* previous = (KdbEntry*)record.linkedData;
        ret.imageId = previous.imageId;
        ret.expired = previous.expired;
    }
    
    return ret;
}

uint32_t newGroupId(NSSet *existingGroupIds) {
    uint32_t t = 0;
    
    while(true)
    {
        t = getRandomUint32();
        
        if((t == 0) || (t == UINT32_MAX) || ([existingGroupIds containsObject:@(t)])) {
            continue;
        }
        
        return t;
    }
}

void normalizeLevels(NSArray<KdbGroup*> *groups) {
    groups[0].level = 0;
    
    int lastLevel = 0;
    for (KdbGroup *group in groups) {
        if(group.level > lastLevel + 1) {
            group.level = lastLevel + 1;
        }
        
        lastLevel = group.level;
    }
}

- (Node*)buildStrongboxModel:(KdbSerializationData *)serializationData {
    Node* ret = [[Node alloc] initAsRoot:nil childRecordsAllowed:NO];
    
    normalizeLevels(serializationData.groups);
    
    int currentLevel = 0;
    Node* parentNode = ret;
    Node* lastNode = ret;
    
    for (KdbGroup* group in serializationData.groups) {
        if(group.level > currentLevel) {
            parentNode = lastNode;
            currentLevel = group.level;
        }
        else if(group.level < currentLevel) {
            int popCount = currentLevel - group.level;
            while(popCount--) parentNode = parentNode.parent;
            currentLevel = group.level;
        }
        
        Node* node = [[Node alloc] initAsGroup:group.name parent:parentNode uuid:nil];
        node.iconId = group.imageId;
        node.linkedData = group;
        [parentNode addChild:node];
        
        // Add Entries/Records for this group
        
        NSArray<KdbEntry*> *entries = [serializationData.entries filter:^BOOL(KdbEntry * _Nonnull obj) {
            return obj.groupId == group.groupId;
        }];
        
        NSArray<Node*> *childEntries = [entries map:^id (KdbEntry * entry, NSUInteger idx) {
            return [self kdbEntryToRecordNode:entry parent:node];
        }];
        
        for (Node* childEntry in childEntries) {
            [node addChild:childEntry];
        }
        
        lastNode = node;
    }
    
    return ret;
}

- (Node*)kdbEntryToRecordNode:(KdbEntry*)entry parent:(Node*)parent {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:entry.username
                                                          url:entry.url
                                                     password:entry.password
                                                        notes:entry.notes
                                                        email:@""];
    
    fields.created = entry.creation;
    fields.accessed = entry.accessed;
    fields.modified = entry.modified;
    
    if(entry.binaryFileName.length) {
        DatabaseAttachment *dbAttachment = [[DatabaseAttachment alloc] init];
        dbAttachment.data = entry.binaryData;
        dbAttachment.compressed = NO;
        dbAttachment.protectedInMemory = NO;
        [self.attachments addObject:dbAttachment];
        
        NodeFileAttachment *attachment = [[NodeFileAttachment alloc] init];
        attachment.filename = entry.binaryFileName;
        attachment.index = (uint32_t)self.attachments.count - 1;
        
        [fields.attachments addObject:attachment];
    }
    
    Node* ret = [[Node alloc] initAsRecord:entry.title parent:parent fields:fields uuid:entry.uuid];
    ret.linkedData = entry;
    ret.iconId = entry.imageId;
    
    return ret;
}

- (NSString * _Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords {
    return [self description];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"masterPassword = %@, metadata=%@, rootGroup = %@", self.masterPassword, self.metadata, self.rootGroup];
}

@end
