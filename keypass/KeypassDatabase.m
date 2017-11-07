#import <Foundation/Foundation.h>
#import "KeypassDatabase.h"
#import "Utils.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation KeypassDatabase

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return NO;
}

- (instancetype)initNewWithoutPassword {
    return [self initNewWithPassword:nil];
}

- (instancetype)initNewWithPassword:(NSString *)password {
    if (self = [super init]) {
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
        if (![KeypassDatabase isAValidSafe:safeData]) {
            NSLog(@"Not a valid safe!");
            
            if (ppError != nil) {
                *ppError = [Utils createNSError:@"This is not a valid Keypass File (Invalid Format)." errorCode:-1];
            }
            
            return nil;
        }

//        NSMutableArray<Field*> *headerFields;
//        NSArray<Record*> *records = [self decryptSafe:safeData
//                                             password:password
//                                              headers:&headerFields
//                                                error:ppError];
//
//        if(!records) {
//            return nil;
//        }
//
//        // Headers
//
//        _dbHeaderFields = headerFields;
//        self.masterPassword = password;
//        self.keyStretchIterations = [SafeTools getKeyStretchIterations:safeData];
//        [self syncLastUpdateFieldsFromHeaders];
//
//        // Records and Groups
//
//        _rootGroup = [self buildModel:records headers:headerFields];
//
//        if(!self.rootGroup) {
//            NSLog(@"Could not build model from records and headers?!");
//
//            if (ppError != nil) {
//                *ppError = [Utils createNSError:@"Could not parse this safe." errorCode:-1];
//            }
//
//            return nil;
//        }
        
        return self;
    }
    else {
        return nil;
    }
}

///////////////////////////////////////////////////////////////////////////////
// Deserialization

- (Node*)buildModel:(NSArray*)records headers:(NSArray*)headers  {
    Node* root = [[Node alloc] initAsRoot];
    
//    // Group Records by their group
//
//    NSMutableDictionary<NSArray<NSString*>*, NSMutableArray<Record*>*> *groupedByGroup =
//        [[NSMutableDictionary<NSArray<NSString*>*, NSMutableArray<Record*>*> alloc] init];
//
//    for (Record *r in records) {
//        NSMutableArray<Record*>* recordsForThisGroup = [groupedByGroup objectForKey:r.group.pathComponents];
//
//        if(!recordsForThisGroup) {
//            recordsForThisGroup = [NSMutableArray<Record*> array];
//            [groupedByGroup setObject:recordsForThisGroup forKey:r.group.pathComponents];
//        }
//
//        [recordsForThisGroup addObject:r];
//    }
//
//    NSMutableArray<NSArray<NSString*>*> *allKeys = [[groupedByGroup allKeys] mutableCopy];
//
//    for (NSArray<NSString*>* groupComponents in allKeys) {
//        Node* group = [self addGroupUsingGroupComponents:root groupComponents:groupComponents];
//
//        NSMutableArray<Record*>* recordsForThisGroup = [groupedByGroup objectForKey:groupComponents];
//
//        for(Record* record in recordsForThisGroup) {
//            Node* recordNode = [[Node alloc] initWithExistingPasswordSafe3Record:record parent:group];
//            [group addChild:recordNode];
//        }
//    }
//
//    NSSet<Group*> *emptyGroups = [self getEmptyGroupsFromHeaders:headers];
//
//    for (Group* emptyGroup in emptyGroups) {
//        [self addGroupUsingGroupComponents:root groupComponents:emptyGroup.pathComponents];
//    }
    
    return root;
}

- (NSArray*)decryptSafe:(NSData*)safeData
                         password:(NSString*)password
                          headers:(NSMutableArray **)headerFields
                            error:(NSError **)ppError {
    return nil;
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
    
    return ret;
}

- (NSString*)getDiagnosticDumpString:(BOOL)plaintextPasswords {
    NSString* dump = [NSString string];
//
//    dump = [dump stringByAppendingString:@"------------------------------- HEADERS -----------------------------------\n"];
//
//    for(Field* field in _dbHeaderFields) {
//        dump = [dump stringByAppendingFormat:@"[%-17s]=[%@]\n", [field.prettyTypeString UTF8String], field.prettyDataString];
//    }
//
//    dump = [dump stringByAppendingString:@"\n------------------------------- RECORDS -----------------------------------\n"];
//
//    NSArray<Record*>* records = [self getRecordsForSerialization];
//
//    for(Record* record in records) {
//        dump = [dump stringByAppendingFormat:@"RECORD: [%@]\n", record.title];
//        dump = [dump stringByAppendingString:@"-------------------------------\n"];
//
//        for (Field *field in [record getAllFields]) {
//            if(field.type == FIELD_TYPE_PASSWORD && !plaintextPasswords) {
//                dump = [dump stringByAppendingFormat:@"   [%@]=[<HIDDEN>]\n", field.prettyTypeString];
//            }
//            else if(field.type == FIELD_TYPE_NOTES) {
//                NSString * singleLine = [field.prettyDataString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
//                dump = [dump stringByAppendingFormat:@"   [%-17s]=[%@]\n", [field.prettyTypeString UTF8String], singleLine];
//            }
//            else {
//                dump = [dump stringByAppendingFormat:@"   [%-17s]=[%@]\n", [field.prettyTypeString UTF8String], field.prettyDataString];
//            }
//        }
//
//        dump = [dump stringByAppendingString:@"---------------------------------------------------------------------------\n"];
//    }
//
//
//    dump = [dump stringByAppendingString:@"\n---------------------------------------------------------------------------"];

    return dump;
}

@end
