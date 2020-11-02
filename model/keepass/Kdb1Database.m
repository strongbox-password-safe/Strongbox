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
#import "Constants.h"
#import "NSData+Extensions.h"

static const BOOL kLogVerbose = NO;

@interface Kdb1Database ()

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

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    return [KdbSerialization isAValidSafe:prefix error:error];
}

- (void)addKeePassDefaultRootGroup:(Node*)rootGroup {
    NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
    if ([rootGroupName isEqualToString:@"generic_database"]) { // If it's not translated use default...
      rootGroupName = kDefaultRootGroupName;
    }
    Node* keePassRootGroup = [[Node alloc] initAsGroup:rootGroupName parent:rootGroup keePassGroupTitleRules:YES uuid:nil];
    [rootGroup addChild:keePassRootGroup keePassGroupTitleRules:YES];
}

- (StrongboxDatabase *)create:(CompositeKeyFactors *)compositeKeyFactors {
    Node* rootGroup = [[Node alloc] initAsRoot:nil childRecordsAllowed:NO];
    
    [self addKeePassDefaultRootGroup:rootGroup];
    
    Kdb1DatabaseMetadata *metadata = [[Kdb1DatabaseMetadata alloc] init];
    
    StrongboxDatabase *ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup
                                                                 metadata:metadata
                                                      compositeKeyFactors:compositeKeyFactors];
    
    return ret;
}

- (void)open:(NSData *)data
         ckf:(CompositeKeyFactors *)ckf
  completion:(OpenCompletionBlock)completion {
    NSError* error;
    KdbSerializationData *serializationData = [KdbSerialization deserialize:data
                                                                   password:ckf.password
                                                              keyFileDigest:ckf.keyFileDigest
                                                                    ppError:&error];
    
    if(serializationData == nil) {
        NSLog(@"Error getting Decrypting KDB binary: [%@]", error);
        completion(NO, nil, error);
        return;
    }

    if(kLogVerbose) {
        NSLog(@"KdbSerializationData = [%@]", serializationData);
    }

    NSArray<DatabaseAttachment*>* attachments;
    Node* rootGroup = [self buildStrongboxModel:serializationData attachments:&attachments];

    if(kLogVerbose) {
        NSLog(@"Attachments: %@", attachments);
    }

    // Metadata

    Kdb1DatabaseMetadata *metadata = [[Kdb1DatabaseMetadata alloc] init];

    metadata.version = serializationData.version;
    metadata.transformRounds = serializationData.transformRounds;
    metadata.flags = serializationData.flags;

    StrongboxDatabase *ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup
                                                                 metadata:metadata
                                                      compositeKeyFactors:ckf
                                                              attachments:attachments];
    ret.adaptorTag = serializationData.metaEntries;
    
    completion(NO, ret, nil);
}

- (void)read:(NSInputStream *)stream ckf:(CompositeKeyFactors *)ckf xmlDumpStream:(NSOutputStream *)xmlDumpStream sanityCheckInnerStream:(BOOL)sanityCheckInnerStream completion:(OpenCompletionBlock)completion {
    [self read:stream ckf:ckf completion:completion];
}

- (void)read:(NSInputStream *)stream ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
    NSMutableData* mutableData = [NSMutableData dataWithCapacity:kStreamingSerializationChunkSize];
    
    [stream open];
    uint8_t* buf = malloc(kStreamingSerializationChunkSize);
    NSInteger bytesRead;
    
    do {
        bytesRead = [stream read:buf maxLength:kStreamingSerializationChunkSize];
        if (bytesRead > 0) {
            [mutableData appendBytes:buf length:bytesRead];
        }
    } while (bytesRead > 0);
    
    free(buf);
    [stream close];
    
    if (bytesRead < 0) {
        completion(NO, nil, stream.streamError);
        return;
    }
    
    [self open:mutableData ckf:ckf completion:completion];
}

- (void)save:(StrongboxDatabase *)database completion:(SaveCompletionBlock)completion {
    if(!database.compositeKeyFactors.password.length && !database.compositeKeyFactors.keyFileDigest) {
        // KeePass 1 does not allow empty Password
        NSError* error = [Utils createNSError:@"Master Password or Key File not set." errorCode:-3];
        completion(NO, nil, error);
        return;
    }
    
    KdbSerializationData *serializationData = [[KdbSerializationData alloc] init];
    
    if(database.rootGroup.childGroups.count == 0) {
        // KDB1 Requires at least one group at the top
        [self addKeePassDefaultRootGroup:database.rootGroup];
    }
    
    [self nodeModelToGroupsAndEntries:0
                                group:database.rootGroup
                    serializationData:serializationData
                     existingGroupIds:[NSMutableSet<NSNumber*> set]
                          attachments:database.attachments];
    
    Kdb1DatabaseMetadata* metadata = (Kdb1DatabaseMetadata*)database.metadata;
    
    serializationData.flags = metadata.flags;
    serializationData.version = metadata.version;
    serializationData.transformRounds = metadata.transformRounds;
    
    NSMutableArray<KdbEntry*>* metaEntries = (NSMutableArray<KdbEntry*>*)database.adaptorTag;
    if(metaEntries) {
        [serializationData.metaEntries addObjectsFromArray:metaEntries];
    }
    
    NSError* error;
    NSData* ret = [KdbSerialization serialize:serializationData
                              password:database.compositeKeyFactors.password
                         keyFileDigest:database.compositeKeyFactors.keyFileDigest
                               ppError:&error];
    
    completion(NO, ret, error);
}

+ (NSData *_Nullable)getYubikeyChallenge:(nonnull NSData *)candidate error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    return nil;
}

-(void)nodeModelToGroupsAndEntries:(int)level
                             group:(Node*)group
                 serializationData:(KdbSerializationData*)serializationData
                  existingGroupIds:(NSMutableSet<NSNumber*>*)existingGroupIds
                       attachments:(NSArray<DatabaseAttachment*>*)attachments {
    NSArray<Node*>* subGroups = [group childGroups];
    
    for (Node* subGroup in subGroups) {
        KdbGroup* kdbGroup = groupToKdbGroup(subGroup, level, existingGroupIds);
        [serializationData.groups addObject:kdbGroup];

        NSArray<KdbEntry*> *entries = [[subGroup childRecords] map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return [self recordToKdbEntry:obj kdbGroup:kdbGroup attachments:attachments];
        }];
        
        [serializationData.entries addObjectsFromArray:entries];

        [self nodeModelToGroupsAndEntries:level + 1 group:subGroup serializationData:serializationData
                         existingGroupIds:existingGroupIds attachments:attachments];
    }
}

KdbGroup* groupToKdbGroup(Node* group, int level,NSMutableSet<NSNumber*> *existingGroupIds) {
    KdbGroup *ret = [[KdbGroup alloc] init];
    
    ret.groupId = newGroupId(existingGroupIds);
    [existingGroupIds addObject:@(ret.groupId)];
    
    ret.name = group.title;
    ret.imageId = group.iconId != nil ? group.iconId : @(48);

    ret.creation = group.fields.created;
    ret.modification = group.fields.modified;
    ret.lastAccess = group.fields.accessed;

    if(group.linkedData) {
        KdbGroup* previous = (KdbGroup*)group.linkedData;
        
        ret.expiry = previous.expiry;
        ret.flags = previous.flags;
    }
    
    ret.level = level;
    return ret;
}

- (KdbEntry*)recordToKdbEntry:(Node*)record kdbGroup:(KdbGroup*)kdbGroup attachments:(NSArray<DatabaseAttachment*>*)attachments {
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
    ret.expired = record.fields.expires;
    
    if(record.fields.attachments.count) { 
        NodeFileAttachment *theAttachment = record.fields.attachments[0];
        
        ret.binaryFileName = theAttachment.filename;
        
        NSInputStream* inputStream = [attachments[theAttachment.index] getPlainTextInputStream];

        // FUTURE: Stream this write
        NSData* data = [NSData dataWithContentsOfStream:inputStream];

        if (!data) {
            return nil;
        }
        
        ret.binaryData = data;
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

- (Node*)buildStrongboxModel:(KdbSerializationData *)serializationData attachments:(NSArray<DatabaseAttachment*>**)attachments {
    Node* ret = [[Node alloc] initAsRoot:nil childRecordsAllowed:NO];
    NSMutableArray<DatabaseAttachment*> *mutableAttachments = [NSMutableArray array];
    
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
        
        Node* node = [[Node alloc] initAsGroup:group.name parent:parentNode keePassGroupTitleRules:YES uuid:nil];
        node.iconId = group.imageId;
        
        [node.fields setTouchPropertiesWithCreated:group.creation accessed:group.lastAccess modified:group.modification locationChanged:nil usageCount:nil];
        
        node.linkedData = group;
        [parentNode addChild:node keePassGroupTitleRules:YES];
        
        // Add Entries/Records for this group
        
        NSArray<KdbEntry*> *entries = [serializationData.entries filter:^BOOL(KdbEntry * _Nonnull obj) {
            return obj.groupId == group.groupId;
        }];
        
        NSArray<Node*> *childEntries = [entries map:^id (KdbEntry * entry, NSUInteger idx) {
            return [self kdbEntryToRecordNode:entry parent:node attachments:mutableAttachments];
        }];
        
        for (Node* childEntry in childEntries) {
            [node addChild:childEntry keePassGroupTitleRules:YES];
        }
        
        lastNode = node;
    }
    
    *attachments = mutableAttachments;
    return ret;
}

- (Node*)kdbEntryToRecordNode:(KdbEntry*)entry parent:(Node*)parent attachments:(NSMutableArray<DatabaseAttachment*>*)attachments {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:entry.username
                                                          url:entry.url
                                                     password:entry.password
                                                        notes:entry.notes
                                                        email:@""];
    
    [fields setTouchPropertiesWithCreated:entry.creation accessed:entry.accessed modified:entry.modified locationChanged:nil usageCount:nil];

    fields.expires = entry.expired;
    
    if(entry.binaryFileName.length) {
        NSInputStream* str = [NSInputStream inputStreamWithData:entry.binaryData];
        DatabaseAttachment *dbAttachment = [[DatabaseAttachment alloc] initWithStream:str protectedInMemory:NO compressed:NO];
        [attachments addObject:dbAttachment];
        
        NodeFileAttachment *attachment = [[NodeFileAttachment alloc] init];
        attachment.filename = entry.binaryFileName;
        attachment.index = (uint32_t)attachments.count - 1;
        
        [fields.attachments addObject:attachment];
    }
    
    Node* ret = [[Node alloc] initAsRecord:entry.title parent:parent fields:fields uuid:entry.uuid];
    ret.iconId = entry.imageId;
    
    return ret;
}

@end
