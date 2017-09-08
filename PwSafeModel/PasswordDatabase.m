//
//  PasswordDatabase.m
//
//
//  Created by Mark on 01/09/2015.
//
//

#import <Foundation/Foundation.h>
#import "PasswordDatabase.h"
#import "Utils.h"
#import "SafeTools.h"
#import <CommonCrypto/CommonHMAC.h>

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface PasswordDatabase ()

@property (nonatomic, strong) NSMutableArray<Field*> *dbHeaderFields;

@end

@implementation PasswordDatabase

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [SafeTools isAValidSafe:candidate];
}

- (instancetype)initNewWithoutPassword {
    return [self initNewWithPassword:nil];
}

- (instancetype)initNewWithPassword:(NSString *)password {
    if (self = [super init]) {
        _dbHeaderFields = [[NSMutableArray alloc] init];

        self.keyStretchIterations = DEFAULT_KEYSTRETCH_ITERATIONS;
        self.masterPassword = password;
        
        _rootGroup = [[Node alloc] initAsRoot];
        return self;
    }
    else {
        return nil;
    }
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                                          error:(NSError **)ppError {
    if (self = [super init]) {
        if (![SafeTools isAValidSafe:safeData]) {
            NSLog(@"Not a valid safe!");
            
            if (ppError != nil) {
                *ppError = [Utils createNSError:@"This is not a valid Password Safe (Invalid Format)." errorCode:-1];
            }
            
            return nil;
        }

        NSMutableArray<Field*> *headerFields;
        NSArray<Record*> *records = [self decryptSafe:safeData
                                             password:password
                                              headers:&headerFields
                                                error:ppError];

        if(!records) {
            return nil;
        }
        
        // Headers
        
        _dbHeaderFields = headerFields;
        self.masterPassword = password;
        self.keyStretchIterations = [SafeTools getKeyStretchIterations:safeData];
        [self syncLastUpdateFieldsFromHeaders];
        
        // Records and Groups
        
        _rootGroup = [self buildModel:records headers:headerFields];
        
        if(!self.rootGroup) {
            NSLog(@"Could not build model from records and headers?!");
            
            if (ppError != nil) {
                *ppError = [Utils createNSError:@"Could not parse this safe." errorCode:-1];
            }
            
            return nil;
        }
        
        return self;
    }
    else {
        return nil;
    }
}

///////////////////////////////////////////////////////////////////////////////
// Deserialization

- (Node*)buildModel:(NSArray<Record*>*)records headers:(NSArray<Field*>*)headers  {
    Node* root = [[Node alloc] initAsRoot];
    
    // Group Records into by their group
    
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
    
    for (NSArray<NSString*>* groupComponents in allKeys) {
        Node* group = [self addGroupUsingGroupComponents:root groupComponents:groupComponents];
        
        NSMutableArray<Record*>* recordsForThisGroup = [groupedByGroup objectForKey:groupComponents];

        for(Record* record in recordsForThisGroup) {
            Node* recordNode = [[Node alloc] initWithExistingPasswordSafe3Record:record parent:group];
            [group addChild:recordNode];
        }
    }
    
    NSSet<Group*> *emptyGroups = [self getEmptyGroupsFromHeaders:headers];
    
    for (Group* emptyGroup in emptyGroups) {
        [self addGroupUsingGroupComponents:root groupComponents:emptyGroup.pathComponents];
    }
    
    return root;
}

- (NSSet<Group*>*)getEmptyGroupsFromHeaders:(NSArray<Field*>*)headers {
    NSMutableSet<Group*> *groups = [[NSMutableSet<Group*> alloc] init];
    
    for (Field *field in headers) {
        if (field.dbHeaderFieldType == HDR_EMPTYGROUP) {
            NSString *groupName = field.dataAsString;
            [groups addObject:[[Group alloc] initWithEscapedPathString:groupName]];
        }
    }
    
    return groups;
}

- (Node*)addGroupUsingGroupComponents:(Node*)root groupComponents:(NSArray<NSString*>*)groupComponents {
    Node* node = root;
    
    for(NSString* component in groupComponents) {
        Node* foo = [node getChildGroupWithTitle:component];
        
        if(!foo) {
            foo = [[Node alloc] initAsGroup:component parent:node];
            if(![node addChild:foo]) {
                NSLog(@"Problem adding child group [%@] to node [%@]", component, node.title);
                return nil;
            }
        }
        
        node = foo;
    }
    
    return node;
}

- (NSArray<Record*> *)decryptSafe:(NSData*)safeData
                         password:(NSString*)password
                          headers:(NSMutableArray<Field*> **)headerFields
                            error:(NSError **)ppError {
    
    PasswordSafe3Header header = [SafeTools getHeader:safeData];
    
    NSData *pBar;
    if (![SafeTools checkPassword:&header password:password pBar:&pBar]) {
        NSLog(@"Invalid password!");
        
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"The password is incorrect." errorCode:-2];
        }
        
        return nil;
    }
    
    NSData *K;
    NSData *L;
    
    [SafeTools getKandL:pBar header:header K_p:&K L_p:&L];
    
    NSInteger numBlocks = [SafeTools getNumberOfBlocks:safeData];
    
    NSData *decData = [SafeTools decryptBlocks:K
                                            ct:(unsigned char *)&safeData.bytes[SIZE_OF_PASSWORD_SAFE_3_HEADER]
                                            iv:header.iv
                                     numBlocks:numBlocks];
    
    NSMutableArray<Record*> *records = [NSMutableArray array];
    NSData *dataForHmac = [SafeTools extractDbHeaderAndRecords:decData headerFields_p:headerFields records_p:&records];
    
    NSData *computedHmac = [SafeTools calculateRFC2104Hmac:dataForHmac key:L];
    
    unsigned char *actualHmac[CC_SHA256_DIGEST_LENGTH];
    [safeData getBytes:actualHmac range:NSMakeRange(safeData.length - CC_SHA256_DIGEST_LENGTH, CC_SHA256_DIGEST_LENGTH)];
    NSData *actHmac = [[NSData alloc] initWithBytes:actualHmac length:CC_SHA256_DIGEST_LENGTH];
    
    if (![actHmac isEqualToData:computedHmac]) {
        NSLog(@"HMAC is no good! Corrupted Safe!");
        
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"The data is corrupted (HMAC incorrect)." errorCode:-3];
        }
        
        return nil;
    }
    
    //[SafeTools dumpDbHeaderAndRecords:headerFields records:records];

    return records;
}

///////////////////////////////////////////////////////////////////////////////
// Serialization

- (void)addDefaultHeaderFieldsIfNotSet {
    // Version
    
    if(![self getFirstHeaderFieldOfType:HDR_VERSION]) {
        unsigned char versionBytes[2];
        versionBytes[0] = 0x0B;
        versionBytes[1] = 0x03;
        NSData *versionData = [[NSData alloc] initWithBytes:&versionBytes length:2];
        Field *version = [[Field alloc] initNewDbHeaderField:HDR_VERSION withData:versionData];
        [_dbHeaderFields addObject:version];
    }

    // UUID

    if(![self getFirstHeaderFieldOfType:HDR_UUID]) {
        NSUUID *unique = [[NSUUID alloc] init];
        unsigned char bytes[16];
        [unique getUUIDBytes:bytes];
        Field *uuid = [[Field alloc] initNewDbHeaderField:HDR_UUID withData:[[NSData alloc] initWithBytes:bytes length:16]];
        [_dbHeaderFields addObject:uuid];
    }
}

- (void)deleteEmptyGroupHeaderFields {
    NSMutableArray<Field*> *fieldsToRemove = [NSMutableArray array];
    
    for (Field *field in _dbHeaderFields) {
        if (field.dbHeaderFieldType == HDR_EMPTYGROUP) {
            [fieldsToRemove addObject:field];
        }
    }
    
    for (Field *field in fieldsToRemove) {
        [_dbHeaderFields removeObject:field];
    }
}

- (NSArray<Group*>*)getMinimalEmptyGroupObjectsFromModel {
    NSArray<Node*> *emptyGroups = [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup && node.children.count == 0;
    }];
    
    NSMutableArray<Group*>* groups = [NSMutableArray array];
    for(Node* emptyGroup in emptyGroups) {
        NSArray<NSString*>* pathComponents = [emptyGroup getTitleHierarchy];
        Group* group = [[Group alloc] initWithPathComponents:pathComponents];
        [groups addObject:group];
    }
    
    return groups;
}

- (void)syncEmptyGroupsToHeaders {
    [self deleteEmptyGroupHeaderFields];
    
    NSArray<Group*>* emptyGroups = [self getMinimalEmptyGroupObjectsFromModel];

    for(Group* group in emptyGroups) {
        Field *emptyGroupField = [[Field alloc] initNewDbHeaderField:HDR_EMPTYGROUP withString:group.escapedPathString];
        [_dbHeaderFields addObject:emptyGroupField];
    }
}

- (NSArray<Record*>* _Nonnull)getRecordsForSerialization {
    NSArray<Node*> *recordNodes = [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }];
    
    NSMutableArray<Record*> *records = [NSMutableArray array];
    
    for(Node* recordNode in recordNodes) {
        Record* record = [self createOrUpdateSerializationRecordWithNode:recordNode];
        [records addObject:record];
    }
    
    return records;
}

- (Record* _Nonnull)createOrUpdateSerializationRecordWithNode:(Node* _Nonnull)recordNode {
    Record *record = recordNode.originalLinkedRecord ? recordNode.originalLinkedRecord : [[Record alloc] init];
 
    record.title = recordNode.title;
    record.username = recordNode.fields.username;
    record.password = recordNode.fields.password;
    record.url = recordNode.fields.url;
    record.notes = recordNode.fields.notes;
    record.group = [[Group alloc] initWithPathComponents:[recordNode.parent getTitleHierarchy]];
    
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
    
- (NSData*)getHeaderFieldHmacData {
    NSMutableData *hmacData = [[NSMutableData alloc] init];
    
    for (Field *dbHeaderField in _dbHeaderFields) {
        [hmacData appendData:dbHeaderField.data];
    }
    
    return hmacData;
}

- (NSData*)serializeHeaderFields {
    NSMutableData *toBeEncrypted = [[NSMutableData alloc] init];
    
    for (Field *dbHeaderField in _dbHeaderFields) {
        //NSLog(@"SAVE HDR: %@ -> %@", dbHeaderField.prettyTypeString, dbHeaderField.prettyDataString);
        NSData* serializedField = [SafeTools serializeField:dbHeaderField];
        
        [toBeEncrypted appendData:serializedField];
    }
    
    // Write HDR_END
    
    Field *hdrEnd = [[Field alloc] initEmptyDbHeaderField:HDR_END];
    NSData *serializedField = [SafeTools serializeField:hdrEnd];
    [toBeEncrypted appendData:serializedField];
    
    return toBeEncrypted;
}

- (NSData*)serializeRecords:(NSArray<Record*>*)records {
    NSMutableData *toBeEncrypted = [[NSMutableData alloc] init];
    
    for (Record *record in records) {
        for (Field *field in [record getAllFields]) {
            [toBeEncrypted appendData:[SafeTools serializeField:field]];
        }
        
        // Write RECORD_END
        
        Field *end = [[Field alloc] initEmptyWithType:FIELD_TYPE_END];
        [toBeEncrypted appendData:[SafeTools serializeField:end]];
    }
    
    return toBeEncrypted;
}

- (NSData*)getRecordsHmacData:(NSArray<Record*>*)records {
    NSMutableData *hmacData = [[NSMutableData alloc] init];
    
    for (Record *record in records) {
        for (Field *field in [record getAllFields]) {
            [hmacData appendData:field.data];
        }
    }
    
    return hmacData;
}

- (void)defaultLastUpdateFieldsToNow {
    self.lastUpdateTime = [[NSDate alloc] init];
    self.lastUpdateUser = [Utils getUsername];
    self.lastUpdateHost = [Utils hostname];
    self.lastUpdateApp =  [Utils getAppName];
}

- (void)syncLastUpdateFieldsToHeaders {
    [self setHeaderFieldString:HDR_LASTUPDATEAPPLICATION value:self.lastUpdateApp];
    [self setHeaderFieldString:HDR_LASTUPDATEHOST value:self.lastUpdateHost];
    [self setHeaderFieldString:HDR_LASTUPDATEUSER value:self.lastUpdateUser];
    [self setHeaderFieldDate:HDR_LASTUPDATETIME value:self.lastUpdateTime];
}

- (void)syncLastUpdateFieldsFromHeaders {
    Field *appField = [self getFirstHeaderFieldOfType:HDR_LASTUPDATETIME];
    if(appField) {
        self.lastUpdateTime = appField.dataAsDate;
    }

    appField = [self getFirstHeaderFieldOfType:HDR_LASTUPDATEHOST];
    if(appField) {
        self.lastUpdateHost = appField.dataAsString;
    }

    appField = [self getFirstHeaderFieldOfType:HDR_LASTUPDATEUSER];
    if(appField) {
        self.lastUpdateUser = appField.dataAsString;
    }
    
    appField = [self getFirstHeaderFieldOfType:HDR_LASTUPDATEAPPLICATION];
    if(appField) {
        self.lastUpdateApp = appField.dataAsString;
    }
}

- (NSData *)getAsData:(NSError**)error {
    if(!self.masterPassword) {
        if(error) {
            *error = [Utils createNSError:@"Master Password not set." errorCode:-3];
        }
        
        return nil;
    }

    // File Header
    
    NSMutableData *ret = [[NSMutableData alloc] init];
    
    NSData *K, *L;
    PasswordSafe3Header hdr = [SafeTools generateNewHeader:(int)self.keyStretchIterations
                                            masterPassword:self.masterPassword
                                                         K:&K
                                                         L:&L];
  
    [ret appendBytes:&hdr length:SIZE_OF_PASSWORD_SAFE_3_HEADER];
    
    NSMutableData *toBeEncrypted = [[NSMutableData alloc] init];
    NSMutableData *hmacData = [[NSMutableData alloc] init];
    
    // Headers

    [self addDefaultHeaderFieldsIfNotSet];
    [self syncEmptyGroupsToHeaders];
    [self syncLastUpdateFieldsToHeaders];
    
    [toBeEncrypted appendData:[self serializeHeaderFields]];
    [hmacData appendData:[self getHeaderFieldHmacData]];
    
    // Records

    NSArray<Record*>* records = [self getRecordsForSerialization];
    
    [toBeEncrypted appendData:[self serializeRecords:records]];
    [hmacData appendData:[self getRecordsHmacData:records]];

    // Encrypt
    
    NSData *ct = [SafeTools encryptCBC:K ptData:toBeEncrypted iv:hdr.iv];
    [ret appendData:ct];
    
    // EOF marker
    
    NSData *eofMarker = [EOF_MARKER dataUsingEncoding:NSUTF8StringEncoding];
    [ret appendData:eofMarker];
    
    // HMAC
    
    NSData *hmac = [SafeTools calculateRFC2104Hmac:hmacData key:L];
    [ret appendData:hmac];
    
    return ret;
}

- (NSString*)getDiagnosticDumpString:(BOOL)plaintextPasswords {
    [self addDefaultHeaderFieldsIfNotSet];
    [self syncEmptyGroupsToHeaders];
    
    NSString* dump = [NSString string];
    
    dump = [dump stringByAppendingString:@"------------------------------- HEADERS -----------------------------------\n"];
    
    for(Field* field in _dbHeaderFields) {
        dump = [dump stringByAppendingFormat:@"[%-17s]=[%@]\n", [field.prettyTypeString UTF8String], field.prettyDataString];
    }
 
    dump = [dump stringByAppendingString:@"\n------------------------------- RECORDS -----------------------------------\n"];
    
    NSArray<Record*>* records = [self getRecordsForSerialization];
    
    for(Record* record in records) {
        dump = [dump stringByAppendingFormat:@"RECORD: [%@]\n", record.title];
        dump = [dump stringByAppendingString:@"-------------------------------\n"];
        
        for (Field *field in [record getAllFields]) {
            if(field.type == FIELD_TYPE_PASSWORD && !plaintextPasswords) {
                dump = [dump stringByAppendingFormat:@"   [%@]=[<HIDDEN>]\n", field.prettyTypeString];
            }
            else if(field.type == FIELD_TYPE_NOTES) {
                NSString *singleLine = [field.prettyDataString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
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

////////////////////////////////////////////////////////////////////////////////////////////
// Convenience

- (NSArray<Node*>*)getAllRecords {
    return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }];
}

- (NSSet<NSString*> *)usernameSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];

    for (Node *recordNode in [self getAllRecords]) {
        [bag addObject:recordNode.fields.username];
    }

    return bag;
}

- (NSSet<NSString*> *)passwordSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];

    for (Node *record in [self getAllRecords]) {
        [bag addObject:record.fields.password];
    }

    return bag;
}

- (NSString *)mostPopularUsername {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];

    for (Node *record in [self getAllRecords]) {
        if(record.fields.username.length) {
            [bag addObject:record.fields.username];
        }
    }
    
    return [self mostFrequentInCountedSet:bag];
}

- (NSString *)mostPopularPassword {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];

    for (Node *record in [self getAllRecords]) {
        [bag addObject:record.fields.password];
    }

    return [self mostFrequentInCountedSet:bag];
}

- (NSString*)mostFrequentInCountedSet:(NSCountedSet<NSString*>*)bag {
    NSString *mostOccurring = @"";
    NSUInteger highest = 0;

    for (NSString *s in bag) {
        if ([bag countForObject:s] > highest) {
            highest = [bag countForObject:s];
            mostOccurring = s;
        }
    }

    return mostOccurring;
}

/////////////////////////////////////////////////////////////////////////////////////////////

-(Field*_Nullable) getFirstHeaderFieldOfType:(HeaderFieldType)type {
    for (Field *field in _dbHeaderFields) {
        if (field.dbHeaderFieldType == type) {
            return field;
        }
    }
    
    return nil;
}

- (void)setHeaderFieldString:(HeaderFieldType)type value:(NSString*)value {
    Field *appField = [self getFirstHeaderFieldOfType:type];
    
    if (appField) {
        [appField setDataWithString:value];
    }
    else {
        appField = [[Field alloc] initNewDbHeaderField:type withString:value];
        [_dbHeaderFields addObject:appField];
    }
}

- (void)setHeaderFieldDate:(HeaderFieldType)type value:(NSDate*)value {
    Field *appField = [self getFirstHeaderFieldOfType:type];
    
    time_t timeT = (time_t)value.timeIntervalSince1970;
    NSData *dataTime = [[NSData alloc] initWithBytes:&timeT length:4];
    
    if (appField) {
        [appField setDataWithData:dataTime];
    }
    else {
        Field *lastUpdateTime = [[Field alloc] initNewDbHeaderField:HDR_LASTUPDATETIME withData:dataTime];
        [_dbHeaderFields addObject:lastUpdateTime];
    }
}

@end
