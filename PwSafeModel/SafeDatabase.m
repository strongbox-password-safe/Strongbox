//
//  OpenSafe.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeDatabase.h"
#import "SafeTools.h"
#import "Field.h"
#import "Group.h"
#import <CommonCrypto/CommonHMAC.h>

#define kStrongBoxUser @"StrongBox User"

@implementation SafeDatabase {
    NSMutableArray *_records;
    NSMutableArray *_dbHeaderFields;
    int _keyStretchIterations;
}

- (instancetype)initNewWithPassword:(NSString *)masterPassword; {
    if (self = [super init]) {
        _dbHeaderFields = [[NSMutableArray alloc] init];

        // Version

        unsigned char versionBytes[2];
        versionBytes[0] = 0x0B;
        versionBytes[1] = 0x03;
        NSData *versionData = [[NSData alloc] initWithBytes:&versionBytes length:2];
        Field *version = [[Field alloc] initNewDbHeaderField:HDR_VERSION withData:versionData];
        [_dbHeaderFields addObject:version];

        // UUID

        NSUUID *unique = [[NSUUID alloc] init];
        unsigned char bytes[16];
        [unique getUUIDBytes:bytes];
        Field *uuid = [[Field alloc] initNewDbHeaderField:HDR_UUID withData:[[NSData alloc] initWithBytes:bytes length:16]];
        [_dbHeaderFields addObject:uuid];

        [self setLastUpdateTime];
        [self setLastUpdateUser];
        [self setLastUpdateHost];
        [self setLastUpdateApp];


        _records = [[NSMutableArray alloc] init];
        self.masterPassword = masterPassword;
        _keyStretchIterations = DEFAULT_KEYSTRETCH_ITERATIONS;

        return self;
    }
    else {
        return nil;
    }
}

- (instancetype)initExistingWithData:(NSString *)password
                                data:(NSData *)safeData
                               error:(NSError **)ppError {
    if (self = [super init]) {
        PasswordSafe3Header header;
        NSUInteger numBlocks;

        if (![SafeTools isAValidSafe:safeData header:&header numBlocks:&numBlocks]) {
            NSLog(@"Not a valid safe!");

            if (ppError != nil) {
                *ppError = [self createNSError:@"This is not a valid Password Safe (Invalid Format)." errorCode:-1];
            }

            return nil;
        }

        NSData *pBar;

        if (![SafeTools checkPassword:&header password:password pBar:&pBar]) {
            NSLog(@"Invalid password!");

            if (ppError != nil) {
                *ppError = [self createNSError:@"The password is incorrect." errorCode:-2];
            }

            return nil;
        }

        // We need to get K and L now...

        //NSLog(@"%@", pBar);

        NSData *K;
        NSData *L;

        [SafeTools getKandL:pBar header:header K_p:&K L_p:&L];

        //NSLog(@"INIT K: %@", K);
        //NSLog(@"INIT L: %@", L);

        NSMutableData *decData;

        decData = [SafeTools decryptBlocks:K ct:(unsigned char *)&safeData.bytes[SIZE_OF_PASSWORD_SAFE_3_HEADER] iv:header.iv numBlocks:numBlocks];

        //NSLog(@"DEC: %@", decData);

        NSMutableArray *records;
        NSMutableArray *headerFields;

        NSData *dataForHmac = [SafeTools extractDbHeaderAndRecords:decData headerFields_p:&headerFields records_p:&records];
        NSData *computedHmac = [SafeTools calculateRFC2104Hmac:dataForHmac key:L];

        unsigned char *actualHmac[CC_SHA256_DIGEST_LENGTH];
        [safeData getBytes:actualHmac range:NSMakeRange(safeData.length - CC_SHA256_DIGEST_LENGTH, CC_SHA256_DIGEST_LENGTH)];
        NSData *actHmac = [[NSData alloc] initWithBytes:actualHmac length:CC_SHA256_DIGEST_LENGTH];
        //NSLog(@"%@", actHmac);

        if (![actHmac isEqualToData:computedHmac]) {
            NSLog(@"HMAC is no good! Corrupted Safe!");

            if (ppError != nil) {
                *ppError = [self createNSError:@"The data is corrupted (HMAC incorrect)." errorCode:-3];
            }

            return nil;
        }

        //[SafeTools dumpDbHeaderAndRecords:headerFields records:records];

        _dbHeaderFields = headerFields;
        _records = records;
        self.masterPassword = password;
        _keyStretchIterations = [SafeTools littleEndian4BytesToInteger:header.iter];

        return self;
    }
    else {
        return nil;
    }
}

- (NSData *)getAsData {
    [self setLastUpdateTime];
    [self setLastUpdateUser];
    [self setLastUpdateHost];
    [self setLastUpdateApp];

    NSMutableData *ret = [[NSMutableData alloc] init];

    NSData *K, *L;

    //NSLog(@"Key Stretch Iterations: %d", _keyStretchIterations);
    
    PasswordSafe3Header hdr = [SafeTools generateNewHeader:_keyStretchIterations
                                            masterPassword:_masterPassword
                                                         K:&K
                                                         L:&L];
    // Header is done...

    [ret appendBytes:&hdr length:SIZE_OF_PASSWORD_SAFE_3_HEADER];

    // We fill data buffer with all fields to be encrypted

    NSMutableData *toBeEncrypted = [[NSMutableData alloc] init];
    NSMutableData *hmacData = [[NSMutableData alloc] init];

    // DB Header

    NSData *serializedField;

    for (Field *dbHeaderField in _dbHeaderFields) {
        //NSLog(@"SAVE HDR: %@ -> %@", dbHeaderField.prettyTypeString, dbHeaderField.prettyDataString);
        serializedField = [SafeTools serializeField:dbHeaderField];

        [toBeEncrypted appendData:serializedField];
        [hmacData appendData:dbHeaderField.data];
    }

    // Write HDR_END

    Field *hdrEnd = [[Field alloc] initEmptyDbHeaderField:HDR_END];
    serializedField = [SafeTools serializeField:hdrEnd];
    [toBeEncrypted appendData:serializedField];
    [hmacData appendData:hdrEnd.data];

    // DONE DB Header //

    // Now all other records

    for (Record *record in _records) {
        //NSLog(@"Serializing [%@]", record.title);

        // Add required fields if they're not present, UUID, Title and Password

        if ((record.title).length == 0) {
            record.title = @"<Untitled>";
        }

        if ((record.password).length == 0) {
            record.password = @"";
        }

        if ((record.uuid).length == 0) {
            [record generateNewUUID];
        }

        for (Field *field in [record getAllFields]) {
            serializedField = [SafeTools serializeField:field];
            [toBeEncrypted appendData:serializedField];
            [hmacData appendData:field.data];
        }

        // Write RECORD_END

        Field *end = [[Field alloc] initEmptyWithType:FIELD_TYPE_END];
        serializedField = [SafeTools serializeField:end];
        [toBeEncrypted appendData:serializedField];
        [hmacData appendData:end.data];
    }

    // Verify our data is a multiple of the block size

    if (toBeEncrypted.length % TWOFISH_BLOCK_SIZE != 0) {
        NSLog(@"Data to be encrypted is not a multiple of the block size. Actual Length: %lu", (unsigned long)toBeEncrypted.length);
        return nil;
    }

    //NSLog(@"TBE: %@", toBeEncrypted);
    NSData *ct = [SafeTools encryptCBC:K ptData:toBeEncrypted iv:hdr.iv];

    [ret appendData:ct];

    // We write Plaintext EOF marker - must consume a block

    NSData *eofMarker = [EOF_MARKER dataUsingEncoding:NSUTF8StringEncoding];
    [ret appendData:eofMarker];

    // we calculate the hmac with L and the pt (toBeEncrypted) using sha256

    //NSLog(@"SAVE L: %@", L);
    // NSLog(@"SAVE HMACDATA: %@", hmacData);
    NSData *hmac = [SafeTools calculateRFC2104Hmac:hmacData key:L];
    //NSLog(@"SAVE HMAC: %@", hmac);

    [ret appendData:hmac];

    return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)records {
    return _records;
}

- (NSArray *)dbHeaderFields {
    return _dbHeaderFields;
}

- (NSString *)masterPassword {
    return _masterPassword;
}

- (NSArray *)emptyGroups {
    NSMutableSet *groups = [[NSMutableSet alloc] init];

    for (Field *field in _dbHeaderFields) {
        if (field.dbHeaderFieldType == HDR_EMPTYGROUP) {
            NSString *groupName = field.dataAsString;
            [groups addObject:[[Group alloc] init:groupName]];
        }
    }

    return groups.allObjects;
}

- (Group *)addSubgroupWithUIString:(Group *)parent title:(NSString *)title {
    return [self addSubgroupWithDisplayString:parent title:title validate:NO];
}

- (Group *)addSubgroupWithDisplayString:(Group *)parent title:(NSString *)title validate:(BOOL)validate {
    if (!title || title.length < 1) {
        return nil;
    }

    if (!parent) {
        parent = [[Group alloc] init];
    }

    BOOL exists = NO;
    Group *retGroup = [parent createChildGroupWithUITitle:title];

    for (Record *r in _records) {
        if ([r.group isSameGroupAs:retGroup] || [r.group isSubgroupOf:retGroup]) {
            exists = YES;
            break;
        }
    }

    if (!exists && !validate) {
        // Store our new group

        Field *emptyGroupField = [[Field alloc] initNewDbHeaderField:HDR_EMPTYGROUP withString:retGroup.fullPath];
        [_dbHeaderFields addObject:emptyGroupField];
    }

    return retGroup;
}

///////////////////////////////////////////////////////////////////////////////////
// Search Helpers

- (NSArray *)allGroupsContainingRecordsMatchingFilter:(NSString *)filter
                                           deepSearch:(BOOL)deepSearch {
    NSMutableArray *groups = [[NSMutableArray alloc] init];

    for (Record *record in _records) {
        if ([self recordMatchesFilter:record filter:filter deepSearch:deepSearch]) {
            [groups addObject:record.group];
        }
    }

    if (filter.length == 0) {
        for (Group *emptyGroup in [self emptyGroups]) {
            [groups addObject:emptyGroup];
        }
    }

    return groups;
}

- (BOOL)recordMatchesFilter:(Record *)record
                     filter:(NSString *)filter
                 deepSearch:(BOOL)deepSearch {
    if (!deepSearch) {
        return filter.length == 0 || ([record.title rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound);
    }
    else {
        return (filter.length == 0 ||
                ([record.title rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound) ||
                ([record.username rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound) ||
                ([record.password rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound) ||
                ([record.url rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound) ||
                ([record.notes rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound));
    }
}

- (NSArray *)getSubgroupsForGroup:(Group *)parent
                       withFilter:(NSString *)filter
                       deepSearch:(BOOL)deepSearch {
    NSArray *candidateGroups = [self allGroupsContainingRecordsMatchingFilter:filter deepSearch:deepSearch];

    NSMutableSet *subGroupsSet = [[NSMutableSet alloc] init];
    NSMutableArray *actualSubgroups = [[NSMutableArray alloc] init];

    for (Group *group in candidateGroups) {
        if ([group isSubgroupOf:parent]) {
            Group *g = [group getImmediateChildGroupWithParentGroup:parent];

            // Unique

            if (![subGroupsSet containsObject:g.fullPath]) {
                [subGroupsSet addObject:g.fullPath];
                [actualSubgroups addObject:g];
            }
        }
    }

    return actualSubgroups;
}

- (NSArray *)getRecordsForGroup:(Group *)parent
                     withFilter:(NSString *)filter
                     deepSearch:(BOOL)deepSearch {
    if (!parent) {
        parent = [[Group alloc] init];
    }

    NSMutableArray *ret = [[NSMutableArray alloc] init];

    for (Record *record in _records) {
        if ([self recordMatchesFilter:record filter:filter deepSearch:deepSearch] &&
            [record.group.fullPath isEqualToString:parent.fullPath]) {
            [ret addObject:record];
        }
    }

    return ret;
}

///////////////////////////////////////////////////////////////////////////////////

- (NSArray *)getAllRecords {
    return [NSArray arrayWithArray:_records];
}

///////////////////////////////////////////////////////////////////////////////////

- (void)addRecord:(Record *)newRecord {
    [_records addObject:newRecord];

    NSMutableArray *fieldsToDelete = [[NSMutableArray alloc] init];

    for (Field *field in _dbHeaderFields) {
        if (field.dbHeaderFieldType == HDR_EMPTYGROUP) {
            NSString *groupName = field.dataAsString;

            if ([groupName isEqualToString:newRecord.group.fullPath]) {
                [fieldsToDelete addObject:field];
            }
        }
    }

    [_dbHeaderFields removeObjectsInArray:fieldsToDelete];
}

- (void)deleteRecord:(Record *)record {
    [_records removeObject:record];

    // We'd like to keep the empty group around for convenience/display purposes - until user explicitly deletes so we'll put it
    // in the empty groups list in the DB header if it's not there

    BOOL isEmpty = YES;

    for (Record *r in _records) {
        if ([r.group isSameGroupAs:record.group] || [r.group isSubgroupOf:record.group]) {
            isEmpty = NO;
            break;
        }
    }

    BOOL emptyGroupAlreadyExists = NO;

    if (isEmpty) {
        for (Field *field in _dbHeaderFields) {
            if (field.dbHeaderFieldType == HDR_EMPTYGROUP) {
                NSString *groupName = field.dataAsString;

                if ([groupName isEqualToString:record.group.fullPath]) {
                    emptyGroupAlreadyExists = YES; // HOW?!
                    break;
                }
            }
        }
    }

    if (!emptyGroupAlreadyExists) {
        Field *emptyGroupField = [[Field alloc] initNewDbHeaderField:HDR_EMPTYGROUP withString:record.group.fullPath];
        [_dbHeaderFields addObject:emptyGroupField];
    }
}

- (void)deleteGroup:(Group *)group {
    // We need to find all this empty group + empty groups that are a subgroup of this and delete them

    NSMutableArray *fieldsToBeDeleted = [[NSMutableArray alloc] init];

    for (Field *field in _dbHeaderFields) {
        if (field.dbHeaderFieldType == HDR_EMPTYGROUP) {
            NSString *groupName = field.dataAsString;
            Group *g = [[Group alloc] init:groupName];

            if ([g isSameGroupAs:group] || [g isSubgroupOf:group]) {
                [fieldsToBeDeleted addObject:field];
            }
        }
    }

    [_dbHeaderFields removeObjectsInArray:fieldsToBeDeleted];

    // We need to find all records that are part of this group and delete them!

    NSMutableArray *recordsToBeDeleted = [[NSMutableArray alloc] init];

    for (Record *record in _records) {
        if ([record.group isSameGroupAs:group] || [record.group isSubgroupOf:group]) {
            [recordsToBeDeleted addObject:record];
        }
    }

    [_records removeObjectsInArray:recordsToBeDeleted];
}

//////////////////////////////////////////////////////////////////////////////

- (NSString *)lastUpdateApp {
    NSString *ret = @"<Unknown>";

    for (Field *field in _dbHeaderFields) {
        if (field.type == HDR_LASTUPDATEAPPLICATION) {
            ret = field.dataAsString;
            break;
        }
    }

    return ret;
}

- (void)setLastUpdateApp {
    Field *appField = nil;

    for (Field *field in _dbHeaderFields) {
        if (field.type == HDR_LASTUPDATEAPPLICATION) {
            appField = field;
            break;
        }
    }

    if (appField) {
        [appField setDataWithString:[self getAppName]];
    }
    else {
        appField = [[Field alloc] initNewDbHeaderField:HDR_LASTUPDATEAPPLICATION withString:[self getAppName]];
        [_dbHeaderFields addObject:appField];
    }
}

- (NSString *)lastUpdateHost {
    NSString *ret = @"<Unknown>";

    for (Field *field in _dbHeaderFields) {
        if (field.type == HDR_LASTUPDATEHOST) {
            ret = field.dataAsString;
            break;
        }
    }

    return ret;
}

- (void)setLastUpdateHost {
    Field *appField = nil;

    for (Field *field in _dbHeaderFields) {
        if (field.type == HDR_LASTUPDATEHOST) {
            appField = field;
            break;
        }
    }

    NSString *hostName = [SafeDatabase hostname]; //[[NSProcessInfo processInfo] hostName];

    if (appField) {
        [appField setDataWithString:hostName];
    }
    else {
        Field *lastUpdateHost = [[Field alloc] initNewDbHeaderField:HDR_LASTUPDATEHOST withString:hostName];
        [_dbHeaderFields addObject:lastUpdateHost];
    }
}

+ (NSString *)hostname {
    char baseHostName[256];
    int success = gethostname(baseHostName, 255);

    if (success != 0) return nil;

    baseHostName[255] = '\0';

#if !TARGET_IPHONE_SIMULATOR
    return [NSString stringWithFormat:@"%s.local", baseHostName];

#else
    return [NSString stringWithFormat:@"%s", baseHostName];

#endif
}

- (NSString *)lastUpdateUser {
    NSString *ret = @"<Unknown>";

    for (Field *field in _dbHeaderFields) {
        if (field.type == HDR_LASTUPDATEUSER) {
            ret = field.dataAsString;
            break;
        }
    }

    return ret;
}

- (void)setLastUpdateUser {
    Field *appField = nil;

    for (Field *field in _dbHeaderFields) {
        if (field.type == HDR_LASTUPDATEUSER) {
            appField = field;
            break;
        }
    }

    if (appField) {
        [appField setDataWithString:kStrongBoxUser];
    }
    else {
        Field *lastUpdateUser = [[Field alloc] initNewDbHeaderField:HDR_LASTUPDATEUSER withString:kStrongBoxUser];
        [_dbHeaderFields addObject:lastUpdateUser];
    }
}

- (NSDate *)lastUpdateTime {
    NSDate *ret = nil;

    for (Field *field in _dbHeaderFields) {
        if (field.type == HDR_LASTUPDATETIME) {
            ret = field.dataAsDate;
            break;
        }
    }

    return ret;
}

- (void)setLastUpdateTime {
    Field *appField = nil;

    for (Field *field in _dbHeaderFields) {
        if (field.type == HDR_LASTUPDATETIME) {
            appField = field;
            break;
        }
    }

    NSDate *now = [[NSDate alloc] init];
    time_t timeT = (time_t)now.timeIntervalSince1970;
    NSData *dataTime = [[NSData alloc] initWithBytes:&timeT length:4];

    if (appField) {
        [appField setDataWithData:dataTime];
    }
    else {
        Field *lastUpdateTime = [[Field alloc] initNewDbHeaderField:HDR_LASTUPDATETIME withData:dataTime];
        [_dbHeaderFields addObject:lastUpdateTime];
    }
}

+ (BOOL)isAValidSafe:(NSData *)candidate {
    PasswordSafe3Header header;
    NSUInteger numBlocks;

    return [SafeTools isAValidSafe:candidate header:&header numBlocks:&numBlocks];
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)moveGroup:(Group *)src destination:(Group *)destination validate:(BOOL)validate {
    if (destination == nil) {
        destination = [[Group alloc] init];
    }

    if (![src isDirectChildOf:destination] && ![src isSameGroupAs:destination] &&  ![destination isSubgroupOf:src]) {
        // Create this group if it doesn't exist already!

        Group *movedGroup = [self addSubgroupWithDisplayString:destination title:src.suffixDisplayString validate:validate];

        if (movedGroup == nil) {
            return NO;
        }

        // Direct records

        NSArray *records = [self getRecordsForGroup:src withFilter:nil deepSearch:NO];

        for (Record *record in records) {
            if (![self moveRecord:record destination:movedGroup validate:validate]) {
                return NO;
            }
        }

        // Direct subgroubs

        NSArray *subgroups = [self getSubgroupsForGroup:src withFilter:nil deepSearch:NO];

        for (Group *subgroup in subgroups) {
            if (![self moveGroup:subgroup destination:movedGroup validate:validate]) {
                return NO;
            }
        }

        // Delete the src

        if (!validate) {
            [self deleteGroup:src];
        }

        return YES;
    }

    return NO;
}

- (BOOL)moveRecord:(Record *)src destination:(Group *)destination validate:(BOOL)validate {
    if (destination == nil) {
        destination = [[Group alloc] init];
    }

    if ([src.group isSameGroupAs:destination]) {
        return NO;
    }

    if (!validate) {
        src.group = destination;
    }

    return YES;
}

- (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode {
    NSArray *keys = @[NSLocalizedDescriptionKey];
    NSArray *values = @[description];
    NSDictionary *userDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    NSError *error = [[NSError alloc] initWithDomain:@"com.markmcguill.StrongBox.ErrorDomain." code:errorCode userInfo:(userDict)];
    
    return error;
}

- (NSString *)getAppName {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSString *appName = [NSString stringWithFormat:@"%@ v%@", info[@"CFBundleDisplayName"], info[@"CFBundleVersion"]];
    
    return appName;
}

@end
