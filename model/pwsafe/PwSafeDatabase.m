#import <Foundation/Foundation.h>
#import "PwSafeDatabase.h"
#import "Utils.h"
#import "PwSafeSerialization.h"
#import <CommonCrypto/CommonHMAC.h>
#import "Record.h"
#import "Constants.h"
#import "StrongboxErrorCodes.h"
#import "StreamUtils.h"

const NSInteger kPwSafeDefaultVersionMajor = 0x03;
const NSInteger kPwSafeDefaultVersionMinor = 0x0D;

@implementation PwSafeDatabase

+ (NSString *)fileExtension {
    return @"psafe3";
}

+ (DatabaseFormat)format {
    return kPasswordSafe;
}

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    return [PwSafeSerialization isValidDatabase:prefix error:error];
}

+ (void)open:(NSData *)data ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
    NSError* error;
    if (![PwSafeDatabase isValidDatabase:data error:&error]) {
        slog(@"Not a valid safe!");
        error = [Utils createNSError:@"This is not a valid Password Safe 3 File (Invalid Format)." errorCode:-1];
        completion(NO, nil,  nil, error);
        return;
    }

    NSMutableArray<Field*> *headerFields;
    NSArray<Record*> *records = [PwSafeDatabase decryptSafe:data
                                         password:ckf.password
                                          headers:&headerFields
                                            error:&error];

    if(!records) {
        completion(NO, nil,  nil, error);
        return;
    }
    
    
    
    Node* rootGroup = [PwSafeDatabase buildModel:records headers:headerFields];
    if(!rootGroup) {
        slog(@"Could not build model from records and headers?!");
        error = [Utils createNSError:@"Could not parse this Password Safe File." errorCode:-1];
        completion(NO, nil, nil, error);
        return;
    }
    
    UnifiedDatabaseMetadata* metadata = [UnifiedDatabaseMetadata withDefaultsForFormat:kPasswordSafe];
    metadata.version = [PwSafeDatabase getVersion:headerFields];
    metadata.kdfIterations = [PwSafeSerialization getKeyStretchIterations:data];

    [PwSafeDatabase syncLastUpdateFieldsFromHeaders:metadata headers:headerFields];
    
    DatabaseModel *ret = [[DatabaseModel alloc] initWithFormat:kPasswordSafe compositeKeyFactors:ckf metadata:metadata root:rootGroup];
    metadata.adaptorTag = headerFields;

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
        completion(NO, nil, nil, stream.streamError);
        return;
    }
    
    [self open:mutableData ckf:ckf completion:completion];
}

+ (void)save:(DatabaseModel *)database
outputStream:(NSOutputStream *)outputStream
      params:(id _Nullable)params
  completion:(SaveCompletionBlock)completion {
    if(!database.ckfs.password) {
        NSError* error = [Utils createNSError:@"Master Password not set." errorCode:-3];
        completion(NO, nil, error);
        return;
    }
    
    [PwSafeDatabase defaultLastUpdateFieldsToNow:database.meta];
    
    
    
    NSMutableData *ret = [[NSMutableData alloc] init];
    
    NSData *K, *L;
    PasswordSafe3Header hdr = [PwSafeSerialization generateNewHeader:(int)database.meta.kdfIterations
                                                      masterPassword:database.ckfs.password
                                                                   K:&K
                                                                   L:&L];
    
    [ret appendBytes:&hdr length:SIZE_OF_PASSWORD_SAFE_3_HEADER];
    
    NSMutableData *toBeEncrypted = [[NSMutableData alloc] init];
    NSMutableData *hmacData = [[NSMutableData alloc] init];
    
    
    
    NSMutableArray<Field*>* headerFields = database.meta.adaptorTag ? (NSMutableArray<Field*>*)database.meta.adaptorTag : [NSMutableArray array];
    
    [PwSafeDatabase addDefaultHeaderFieldsIfNotSet:headerFields];
    [PwSafeDatabase syncEmptyGroupsToHeaders:headerFields rootGroup:database.rootNode];
    [PwSafeDatabase syncLastUpdateFieldsToHeaders:database.meta headers:headerFields];
    
    [toBeEncrypted appendData:[PwSafeDatabase serializeHeaderFields:headerFields]];
    [hmacData appendData:[PwSafeDatabase getHeaderFieldHmacData:headerFields]];
    
    
    
    NSArray<Record*>* records = [PwSafeDatabase getRecordsForSerialization:database.rootNode];
    
    [toBeEncrypted appendData:[PwSafeDatabase serializeRecords:records]];
    [hmacData appendData:[PwSafeDatabase getRecordsHmacData:records]];
    
    
    
    NSData *ct = [PwSafeSerialization encryptCBC:K ptData:toBeEncrypted iv:hdr.iv];
    [ret appendData:ct];
    
    
    
    NSData *eofMarker = [EOF_MARKER dataUsingEncoding:NSUTF8StringEncoding];
    [ret appendData:eofMarker];
    
    
    
    NSData *hmac = [PwSafeSerialization calculateRFC2104Hmac:hmacData key:L];
    [ret appendData:hmac];
    
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




+ (Node*)buildModel:(NSArray<Record*>*)records headers:(NSArray<Field*>*)headers  {
    Node* root = [[Node alloc] initAsRoot:nil];
    
    
    
    NSMutableDictionary<NSArray<NSString*>*, NSMutableArray<Record*>*> *groupedByGroup =
        [[NSMutableDictionary<NSArray<NSString*>*, NSMutableArray<Record*>*> alloc] init];
    
    for (Record *r in records) {
        NSMutableArray<Record*>* recordsForThisGroup = [groupedByGroup objectForKey:r.group.pathComponents];
        
        if(!recordsForThisGroup) {
            recordsForThisGroup = [NSMutableArray<Record*> array];
            [groupedByGroup setObject:recordsForThisGroup forKey:r.group.pathComponents];
        }
     
        [recordsForThisGroup addObject:r];
    }

    NSMutableArray<NSArray<NSString*>*> *allKeys = [[groupedByGroup allKeys] mutableCopy];
    
    NSMutableSet<NSUUID*>* usedIds = NSMutableSet.set;

    for (NSArray<NSString*>* groupComponents in allKeys) {
        Node* group = [self addGroupUsingGroupComponents:root groupComponents:groupComponents];
        
        NSMutableArray<Record*>* recordsForThisGroup = [groupedByGroup objectForKey:groupComponents];

        for(Record* record in recordsForThisGroup) {
            Node* recordNode = [self createNodeFromExistingRecord:record parent:group usedIds:usedIds];
            [group addChild:recordNode keePassGroupTitleRules:YES];
        }
    }
    
    NSSet<Group*> *emptyGroups = [self getEmptyGroupsFromHeaders:headers];
    
    for (Group* emptyGroup in emptyGroups) {
        [self addGroupUsingGroupComponents:root groupComponents:emptyGroup.pathComponents];
    }
    
    return root;
}

+ (Node*)createNodeFromExistingRecord:(Record*)record parent:(Node*)group usedIds:(NSMutableSet<NSUUID*>*)usedIds {
    NodeFields* fields = [[NodeFields alloc] init];
    
    fields.username = record.username;
    fields.password = record.password;
    fields.url = record.url;
    fields.notes = record.notes;
    fields.passwordHistory = record.passwordHistory;
    fields.email = record.email;
        
    fields.expires = record.expires;
    
    [fields setTouchPropertiesWithCreated:record.created accessed:record.accessed modified:record.modified locationChanged:nil usageCount:nil]; 
    
    fields.passwordModified = record.passwordModified;

    NSUUID* uniqueId = record.uuid ? record.uuid : [NSUUID UUID];
    BOOL alreadyUsedId = [usedIds containsObject:uniqueId];
    if ( alreadyUsedId ) {
        slog(@"WARNWARN: Duplicated ID: %@", uniqueId);
        uniqueId = NSUUID.UUID;
    }
    [usedIds addObject:uniqueId];
    
    Node* ret = [[Node alloc] initAsRecord:record.title parent:group fields:fields uuid:uniqueId];
    
    ret.linkedData = record;
    
    return ret;
}

+ (NSSet<Group*>*)getEmptyGroupsFromHeaders:(NSArray<Field*>*)headers {
    NSMutableSet<Group*> *groups = [[NSMutableSet<Group*> alloc] init];
    
    for (Field *field in headers) {
        if (field.dbHeaderFieldType == HDR_EMPTYGROUP) {
            NSString *groupName = field.dataAsString;
            [groups addObject:[[Group alloc] initWithEscapedPathString:groupName]];
        }
    }
    
    return groups;
}

+ (Node*)addGroupUsingGroupComponents:(Node*)root groupComponents:(NSArray<NSString*>*)groupComponents {
    Node* node = root;
    
    for(NSString* component in groupComponents) {
        Node* foo = [node getChildGroupWithTitle:component];
        
        if(!foo) {
            foo = [[Node alloc] initAsGroup:component parent:node keePassGroupTitleRules:NO uuid:nil];
            if(![node addChild:foo keePassGroupTitleRules:NO]) {
                slog(@"Problem adding child group [%@] to node [%@]", component, node.title);
                return nil;
            }
        }
        
        node = foo;
    }
    
    return node;
}

+ (NSArray<Record*> *)decryptSafe:(NSData*)safeData
                         password:(NSString*)password
                          headers:(NSMutableArray<Field*> **)headerFields
                            error:(NSError **)ppError {
    PasswordSafe3Header header = [PwSafeSerialization getHeader:safeData];
    
    NSData *pBar;
    if (![PwSafeSerialization checkPassword:&header password:password pBar:&pBar]) {
        slog(@"Invalid password!");
        
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"The password is incorrect." errorCode:StrongboxErrorCodes.incorrectCredentials];
        }
        
        return nil;
    }
    
    NSData *K;
    NSData *L;
    
    [PwSafeSerialization getKandL:pBar header:header K_p:&K L_p:&L];
    
    NSInteger numBlocks = [PwSafeSerialization getNumberOfBlocks:safeData];
    
    NSData *decData = [PwSafeSerialization decryptBlocks:K
                                            ct:(unsigned char *)&safeData.bytes[SIZE_OF_PASSWORD_SAFE_3_HEADER]
                                            iv:header.iv
                                     numBlocks:numBlocks];
    
    NSMutableArray<Record*> *records = [NSMutableArray array];
    NSData *dataForHmac = [PwSafeSerialization extractDbHeaderAndRecords:decData headerFields_p:headerFields records_p:&records];
    
    NSData *computedHmac = [PwSafeSerialization calculateRFC2104Hmac:dataForHmac key:L];
    
    unsigned char *actualHmac[CC_SHA256_DIGEST_LENGTH];
    [safeData getBytes:actualHmac range:NSMakeRange(safeData.length - CC_SHA256_DIGEST_LENGTH, CC_SHA256_DIGEST_LENGTH)];
    NSData *actHmac = [[NSData alloc] initWithBytes:actualHmac length:CC_SHA256_DIGEST_LENGTH];
    
    if (![actHmac isEqualToData:computedHmac]) {
        slog(@"HMAC is no good! Corrupted Safe!");
        
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"The data is corrupted (HMAC incorrect)." errorCode:-3];
        }
        
        return nil;
    }
    
    

    return records;
}




+ (void)addDefaultHeaderFieldsIfNotSet:(NSMutableArray<Field*>*)headers {
    
    
    if(![self getFirstHeaderFieldOfType:HDR_VERSION headers:headers]) {
        unsigned char versionBytes[2];
        versionBytes[0] = kPwSafeDefaultVersionMinor;
        versionBytes[1] = kPwSafeDefaultVersionMajor;
        NSData *versionData = [[NSData alloc] initWithBytes:&versionBytes length:2];
        Field *version = [[Field alloc] initNewDbHeaderField:HDR_VERSION withData:versionData];
        [headers addObject:version];
    }

    

    if(![self getFirstHeaderFieldOfType:HDR_UUID headers:headers]) {
        NSUUID *unique = [[NSUUID alloc] init];
        unsigned char bytes[16];
        [unique getUUIDBytes:bytes];
        Field *uuid = [[Field alloc] initNewDbHeaderField:HDR_UUID withData:[[NSData alloc] initWithBytes:bytes length:16]];
        [headers addObject:uuid];
    }
}

+ (void)deleteEmptyGroupHeaderFields:(NSMutableArray<Field*>*)headers {
    NSMutableArray<Field*> *fieldsToRemove = [NSMutableArray array];
    
    for (Field *field in headers) {
        if (field.dbHeaderFieldType == HDR_EMPTYGROUP) {
            [fieldsToRemove addObject:field];
        }
    }
    
    for (Field *field in fieldsToRemove) {
        [headers removeObject:field];
    }
}

+ (NSArray<Group*>*)getMinimalEmptyGroupObjectsFromModel:(Node*)rootGroup {
    NSArray<Node*> *emptyGroups = [[rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup && node.children.count == 0;
    }] sortedArrayUsingComparator:finderStyleNodeComparator];
    
    NSMutableArray<Group*>* groups = [NSMutableArray array];
    for(Node* emptyGroup in emptyGroups) {
        NSArray<NSString*>* pathComponents = [emptyGroup getTitleHierarchy];
        Group* group = [[Group alloc] initWithPathComponents:pathComponents];
        [groups addObject:group];
    }
    
    return groups;
}

+ (void)syncEmptyGroupsToHeaders:(NSMutableArray<Field*>*)headers rootGroup:(Node*)rootGroup {
    [self deleteEmptyGroupHeaderFields:headers];
    
    NSArray<Group*>* emptyGroups = [self getMinimalEmptyGroupObjectsFromModel:rootGroup];

    for(Group* group in emptyGroups) {
        Field *emptyGroupField = [[Field alloc] initNewDbHeaderField:HDR_EMPTYGROUP withString:group.escapedPathString];
        [headers addObject:emptyGroupField];
    }
}

+ (NSArray<Record*>* _Nonnull)getRecordsForSerialization:(Node*)rootGroup {
    NSArray<Node*> *recordNodes = [[rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }] sortedArrayUsingComparator:finderStyleNodeComparator];
    
    NSMutableArray<Record*> *records = [NSMutableArray array];
    
    for(Node* recordNode in recordNodes) {
        Record* record = [self createOrUpdateSerializationRecordWithNode:recordNode];
        [records addObject:record];
    }
    
    return records;
}

+ (Record* _Nonnull)createOrUpdateSerializationRecordWithNode:(Node* _Nonnull)recordNode {
    Record *record = recordNode.linkedData ? ( (Record*)recordNode.linkedData) : [[Record alloc] init];
 
    record.uuid = recordNode.uuid; 
    
    record.title = recordNode.title;
    record.username = recordNode.fields.username;
    record.password = recordNode.fields.password;
    record.url = recordNode.fields.url;
    record.notes = recordNode.fields.notes;
    record.email = recordNode.fields.email;
    record.group = [[Group alloc] initWithPathComponents:[recordNode.parent getTitleHierarchy]];
    record.expires = recordNode.fields.expires;
    
    if(!(recordNode.fields.passwordHistory.enabled == NO &&
         recordNode.fields.passwordHistory.entries.count == 0)) {
        record.passwordHistory = recordNode.fields.passwordHistory;
    }
    else {
        record.passwordHistory = nil;
    }
    
    record.accessed = recordNode.fields.accessed;
    record.created = recordNode.fields.created;
    record.modified = recordNode.fields.modified;
    
    return record;
}
    
+ (NSData*)getHeaderFieldHmacData:(NSMutableArray<Field*>*)headers {
    NSMutableData *hmacData = [[NSMutableData alloc] init];
    
    for (Field *dbHeaderField in headers) {
        [hmacData appendData:dbHeaderField.data];
    }
    
    return hmacData;
}

+ (NSData*)serializeHeaderFields:(NSMutableArray<Field*>*)headers {
    NSMutableData *toBeEncrypted = [[NSMutableData alloc] init];
    
    for (Field *dbHeaderField in headers) {
        
        NSData* serializedField = [PwSafeSerialization serializeField:dbHeaderField];
        
        [toBeEncrypted appendData:serializedField];
    }
    
    
    
    Field *hdrEnd = [[Field alloc] initEmptyDbHeaderField:HDR_END];
    NSData *serializedField = [PwSafeSerialization serializeField:hdrEnd];
    [toBeEncrypted appendData:serializedField];
    
    return toBeEncrypted;
}

+ (NSData*)serializeRecords:(NSArray<Record*>*)records {
    NSMutableData *toBeEncrypted = [[NSMutableData alloc] init];
    
    for (Record *record in records) {
        for (Field *field in [record getAllFields]) {
            [toBeEncrypted appendData:[PwSafeSerialization serializeField:field]];
        }
        
        
        
        Field *end = [[Field alloc] initEmptyWithType:FIELD_TYPE_END];
        [toBeEncrypted appendData:[PwSafeSerialization serializeField:end]];
    }
    
    return toBeEncrypted;
}

+ (NSData*)getRecordsHmacData:(NSArray<Record*>*)records {
    NSMutableData *hmacData = [[NSMutableData alloc] init];
    
    for (Record *record in records) {
        for (Field *field in [record getAllFields]) {
            [hmacData appendData:field.data];
        }
    }
    
    return hmacData;
}

+ (void)syncLastUpdateFieldsToHeaders:(UnifiedDatabaseMetadata*)metadata headers:(NSMutableArray<Field*>*)headers {
    [self setHeaderFieldString:HDR_LASTUPDATEAPPLICATION value:metadata.lastUpdateApp headers:headers];
    [self setHeaderFieldString:HDR_LASTUPDATEHOST value:metadata.lastUpdateHost headers:headers];
    [self setHeaderFieldString:HDR_LASTUPDATEUSER value:metadata.lastUpdateUser headers:headers];
    [self setHeaderFieldDate:HDR_LASTUPDATETIME value:metadata.lastUpdateTime headers:headers];
}

+ (void)syncLastUpdateFieldsFromHeaders:(UnifiedDatabaseMetadata*)metadata headers:(NSMutableArray<Field*>*)headers {
    Field *appField = [self getFirstHeaderFieldOfType:HDR_LASTUPDATETIME headers:headers];
    if(appField) {
        metadata.lastUpdateTime = appField.dataAsDate;
    }

    appField = [self getFirstHeaderFieldOfType:HDR_LASTUPDATEHOST headers:headers];
    if(appField) {
        metadata.lastUpdateHost = appField.dataAsString;
    }

    appField = [self getFirstHeaderFieldOfType:HDR_LASTUPDATEUSER headers:headers];
    if(appField) {
        metadata.lastUpdateUser = appField.dataAsString;
    }
    
    appField = [self getFirstHeaderFieldOfType:HDR_LASTUPDATEAPPLICATION headers:headers];
    if(appField) {
        metadata.lastUpdateApp = appField.dataAsString;
    }
}

+ (NSString*)getDiagnosticDumpString:(BOOL)plaintextPasswords headers:(NSMutableArray<Field*>*)headers rootGroup:(Node*)rootGroup {
    [self addDefaultHeaderFieldsIfNotSet:headers];
    [self syncEmptyGroupsToHeaders:headers rootGroup:rootGroup];
    
    NSString* dump = [NSString string];
    
    dump = [dump stringByAppendingString:@"------------------------------- HEADERS -----------------------------------\n"];
    
    for(Field* field in headers) {
        dump = [dump stringByAppendingFormat:@"[%-17s]=[%@]\n", [field.prettyTypeString UTF8String], field.prettyDataString];
    }
 
    dump = [dump stringByAppendingString:@"\n------------------------------- RECORDS -----------------------------------\n"];
    
    NSArray<Record*>* records = [self getRecordsForSerialization:rootGroup];
    
    for(Record* record in records) {
        dump = [dump stringByAppendingFormat:@"RECORD: [%@]\n", record.title];
        dump = [dump stringByAppendingString:@"-------------------------------\n"];
        
        for (Field *field in [record getAllFields]) {
            if(field.type == FIELD_TYPE_PASSWORD && !plaintextPasswords) {
                dump = [dump stringByAppendingFormat:@"   [%@]=[<HIDDEN>]\n", field.prettyTypeString];
            }
            else if(field.type == FIELD_TYPE_NOTES) {                
                NSString * singleLine = [field.prettyDataString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
                dump = [dump stringByAppendingFormat:@"   [%-17s]=[%@]\n", [field.prettyTypeString UTF8String], singleLine];
            }
            else {
                dump = [dump stringByAppendingFormat:@"   [%-17s]=[%@]\n", [field.prettyTypeString UTF8String], field.prettyDataString];
            }
        }

        dump = [dump stringByAppendingString:@"---------------------------------------------------------------------------\n"];
    }
    
    
    dump = [dump stringByAppendingString:@"\n---------------------------------------------------------------------------"];

    return dump;
}

+ (void)defaultLastUpdateFieldsToNow:(UnifiedDatabaseMetadata*)metadata {
    metadata.lastUpdateTime = [[NSDate alloc] init];
    metadata.lastUpdateUser = [Utils getUsername];
    metadata.lastUpdateHost = [Utils hostname];
    metadata.lastUpdateApp =  [Utils getAppName];
}

+ (NSString*)getVersion:(NSMutableArray<Field*>*)headers {
    Field *version = [self getFirstHeaderFieldOfType:HDR_VERSION headers:headers];
    if(!version) {
        return [NSString stringWithFormat:@"%ld.%ld", (long)kPwSafeDefaultVersionMajor, (long)kPwSafeDefaultVersionMinor];
    }
    else {
        return [version prettyDataString];
    }
}



+ (Field*_Nullable) getFirstHeaderFieldOfType:(HeaderFieldType)type headers:(NSMutableArray<Field*>*)headers {
    for (Field *field in headers) {
        if (field.dbHeaderFieldType == type) {
            return field;
        }
    }
    
    return nil;
}

+ (void)setHeaderFieldString:(HeaderFieldType)type value:(NSString*)value headers:(NSMutableArray<Field*>*)headers {
    Field *appField = [self getFirstHeaderFieldOfType:type headers:headers];
    
    if (appField) {
        [appField setDataWithString:value];
    }
    else {
        appField = [[Field alloc] initNewDbHeaderField:type withString:value];
        [headers addObject:appField];
    }
}

+ (void)setHeaderFieldDate:(HeaderFieldType)type value:(NSDate*)value headers:(NSMutableArray<Field*>*)headers {
    Field *appField = [self getFirstHeaderFieldOfType:type headers:headers];
    
    time_t timeT = (time_t)value.timeIntervalSince1970;
    NSData *dataTime = [[NSData alloc] initWithBytes:&timeT length:4];
    
    if (appField) {
        [appField setDataWithData:dataTime];
    }
    else {
        Field *lastUpdateTime = [[Field alloc] initNewDbHeaderField:HDR_LASTUPDATETIME withData:dataTime];
        [headers addObject:lastUpdateTime];
    }
}

@end
