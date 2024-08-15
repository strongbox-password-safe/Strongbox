//
//  Kdb1Database.m
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Kdb1Database.h"
#import "KdbSerialization.h"
#import "NSArray+Extensions.h"
#import "KeePassConstants.h"
#import "Utils.h"
#import "Constants.h"
#import "NSData+Extensions.h"
#import "StreamUtils.h"

static const BOOL kLogVerbose = NO;

@interface Kdb1Database ()

@end

@implementation Kdb1Database

+ (NSString *)fileExtension {
    return @"kdb";
}

+ (DatabaseFormat)format {
    return kKeePass1;
}

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    return [KdbSerialization isAValidSafe:prefix error:error];
}

+ (void)open:(NSData *)data
         ckf:(CompositeKeyFactors *)ckf
  completion:(OpenCompletionBlock)completion {
    NSError* error;
    KdbSerializationData *serializationData = [KdbSerialization deserialize:data
                                                                   password:ckf.password
                                                              keyFileDigest:ckf.keyFileDigest
                                                                    ppError:&error];
    
    if(serializationData == nil) {
        slog(@"Error getting Decrypting KDB binary: [%@]", error);
        completion(NO, nil, nil, error);
        return;
    }

    if(kLogVerbose) {
        slog(@"KdbSerializationData = [%@]", serializationData);
    }

    NSArray<KeePassAttachmentAbstractionLayer*>* attachments;
    Node* rootGroup = [Kdb1Database buildStrongboxModel:serializationData attachments:&attachments];

    if(kLogVerbose) {
        slog(@"Attachments: %@", attachments);
    }

    

    UnifiedDatabaseMetadata *metadata = [UnifiedDatabaseMetadata withDefaultsForFormat:kKeePass1];

    metadata.versionInt = serializationData.version;
    metadata.kdfIterations = serializationData.transformRounds;
    metadata.flags = serializationData.flags;

    DatabaseModel *ret = [[DatabaseModel alloc] initWithFormat:kKeePass1 compositeKeyFactors:ckf metadata:metadata root:rootGroup];
    
    ret.meta.adaptorTag = serializationData.metaEntries;
    
    completion(NO, ret, nil, nil);
}

+ (void)read:(NSInputStream *)stream ckf:(CompositeKeyFactors *)ckf xmlDumpStream:(NSOutputStream *)xmlDumpStream sanityCheckInnerStream:(BOOL)sanityCheckInnerStream completion:(OpenCompletionBlock)completion {
    [self read:stream ckf:ckf completion:completion];
}

+ (void)read:(NSInputStream *)stream ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
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
        completion(NO, nil,  nil, stream.streamError);
        return;
    }
    
    [self open:mutableData ckf:ckf completion:completion];
}

+ (void)save:(DatabaseModel *)database outputStream:(NSOutputStream *)outputStream params:(id _Nullable)params completion:(SaveCompletionBlock)completion {
    if(!database.ckfs.password.length && !database.ckfs.keyFileDigest) {
        
        NSError* error = [Utils createNSError:@"Master Password or Key File not set." errorCode:-3];
        completion(NO, nil, error);
        return;
    }
    
    KdbSerializationData *serializationData = [[KdbSerializationData alloc] init];
    
    if(database.rootNode.childGroups.count == 0) {
        
        [Kdb1Database addKeePassDefaultRootGroup:database.rootNode];
    }
    
    if ( ! [Kdb1Database nodeModelToGroupsAndEntries:0
                                               group:database.rootNode
                                   serializationData:serializationData
                                    existingGroupIds:[NSMutableSet<NSNumber*> set]] ) {
        slog(@"WARNWARN: Could not convert to KDB.");
        NSError* error = [Utils createNSError:@"Could not convert to KDB." errorCode:-3];
        completion(NO, nil, error);
        return;
    }
        
    serializationData.flags = database.meta.flags;
    serializationData.version = database.meta.versionInt;
    serializationData.transformRounds = (uint32_t)database.meta.kdfIterations;
    
    NSMutableArray<KdbEntry*>* metaEntries = (NSMutableArray<KdbEntry*>*)database.meta.adaptorTag;
    if(metaEntries) {
        [serializationData.metaEntries addObjectsFromArray:metaEntries];
    }
    
    NSError* error;
    NSData* ret = [KdbSerialization serialize:serializationData
                              password:database.ckfs.password
                         keyFileDigest:database.ckfs.keyFileDigest
                               ppError:&error];
    
    if(!ret) {
        slog(@"Could not serialize Document to KDB");
        completion(NO, nil, error);
        return;
    }
    
    NSInputStream* inputStream = [NSInputStream inputStreamWithData:ret];
    [inputStream open];
    BOOL success = [StreamUtils pipeFromStream:inputStream to:outputStream openAndCloseStreams:NO];
    [inputStream close];
    
    if ( !success ) {
        completion(NO, nil, [Utils createNSError:@"Could not pipe data to stream!" errorCode:-1]);
    }
    else {
        completion(NO, nil, nil);
    }
}

+ (void)addKeePassDefaultRootGroup:(Node*)rootGroup {
    NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
    if ([rootGroupName isEqualToString:@"generic_database"]) { 
      rootGroupName = kDefaultRootGroupName;
    }
    Node* keePassRootGroup = [[Node alloc] initAsGroup:rootGroupName parent:rootGroup keePassGroupTitleRules:YES uuid:nil];
    [rootGroup addChild:keePassRootGroup keePassGroupTitleRules:YES];
}

+ (BOOL)nodeModelToGroupsAndEntries:(int)level
                             group:(Node*)group
                 serializationData:(KdbSerializationData*)serializationData
                  existingGroupIds:(NSMutableSet<NSNumber*>*)existingGroupIds {
    NSArray<Node*>* subGroups = [group childGroups];
    
    for (Node* subGroup in subGroups) {
        KdbGroup* kdbGroup = groupToKdbGroup(subGroup, level, existingGroupIds);
        [serializationData.groups addObject:kdbGroup];

        NSMutableArray<KdbEntry*>* entries = NSMutableArray.array;
        for ( Node* obj in subGroup.childRecords ) {
            KdbEntry* entry = [Kdb1Database recordToKdbEntry:obj kdbGroup:kdbGroup];
            if ( !entry ) {
                slog(@"WARNWARN: Could not get KDBEntry for Node.");
                return NO;
            }
            [entries addObject:entry];
        }
        
        [serializationData.entries addObjectsFromArray:entries];

        if ( ![self nodeModelToGroupsAndEntries:level + 1
                                          group:subGroup
                              serializationData:serializationData
                               existingGroupIds:existingGroupIds] ) {
            return NO;
        }
    }
    
    return YES;
}

KdbGroup* groupToKdbGroup(Node* group, int level,NSMutableSet<NSNumber*> *existingGroupIds) {
    KdbGroup *ret = [[KdbGroup alloc] init];
    
    ret.groupId = newGroupId(existingGroupIds);
    [existingGroupIds addObject:@(ret.groupId)];
    
    ret.name = group.title;
    
    ret.imageId = group.icon != nil ? @(group.icon.preset) : @(48);

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

+ (KdbEntry*)recordToKdbEntry:(Node*)record kdbGroup:(KdbGroup*)kdbGroup {
    KdbEntry* ret = [[KdbEntry alloc] init];
    
    ret.uuid = record.uuid;
    ret.groupId = kdbGroup.groupId;
    ret.imageId = record.icon != nil ? @(record.icon.preset) : @(0);
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
        NSString* filename = record.fields.attachments.allKeys.firstObject;
        KeePassAttachmentAbstractionLayer *theAttachment = record.fields.attachments[filename];
        
        ret.binaryFileName = filename;
        
        
        NSData* data = theAttachment.nonPerformantFullData;
        
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

+ (Node*)buildStrongboxModel:(KdbSerializationData *)serializationData attachments:(NSArray<KeePassAttachmentAbstractionLayer*>**)attachments {
    Node* ret = [[Node alloc] initAsRoot:nil childRecordsAllowed:NO];
    NSMutableArray<KeePassAttachmentAbstractionLayer*> *mutableAttachments = [NSMutableArray array];
    
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
        
        if (group.imageId != nil) {
            node.icon = [NodeIcon withPreset:group.imageId.integerValue];
        }
        
        [node.fields setTouchPropertiesWithCreated:group.creation accessed:group.lastAccess modified:group.modification locationChanged:nil usageCount:nil];
        
        node.linkedData = group;
        [parentNode addChild:node keePassGroupTitleRules:YES];
        
        
        
        NSArray<KdbEntry*> *entries = [serializationData.entries filter:^BOOL(KdbEntry * _Nonnull obj) {
            return obj.groupId == group.groupId;
        }];
        
        NSArray<Node*> *childEntries = [entries map:^id (KdbEntry * entry, NSUInteger idx) {
            return [Kdb1Database kdbEntryToRecordNode:entry parent:node attachments:mutableAttachments];
        }];
        
        for (Node* childEntry in childEntries) {
            [node addChild:childEntry keePassGroupTitleRules:YES];
        }
        
        lastNode = node;
    }
    
    *attachments = mutableAttachments;
    return ret;
}

+ (Node*)kdbEntryToRecordNode:(KdbEntry*)entry parent:(Node*)parent attachments:(NSMutableArray<KeePassAttachmentAbstractionLayer*>*)attachments {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:entry.username
                                                          url:entry.url
                                                     password:entry.password
                                                        notes:entry.notes
                                                        email:@""];
    
    [fields setTouchPropertiesWithCreated:entry.creation accessed:entry.accessed modified:entry.modified locationChanged:nil usageCount:nil];

    fields.expires = entry.expired;
    
    if(entry.binaryFileName.length) {
        NSInputStream* str = [NSInputStream inputStreamWithData:entry.binaryData];
        
        KeePassAttachmentAbstractionLayer *dbAttachment = [[KeePassAttachmentAbstractionLayer alloc] initWithStream:str
                                                                               length:entry.binaryData.length
                                                                    protectedInMemory:NO
                                                                           compressed:NO];
        [attachments addObject:dbAttachment];
        fields.attachments[entry.binaryFileName] = dbAttachment;
    }
    
    Node* ret = [[Node alloc] initAsRecord:entry.title parent:parent fields:fields uuid:entry.uuid];
    
    if (entry.imageId != nil) {
        ret.icon = [NodeIcon withPreset:entry.imageId.integerValue];
    }
    
    return ret;
}

@end
