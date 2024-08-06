//
//  SafesList.m
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SafesList.h"
#import "IOsUtils.h"
#import "AppPreferences.h"
#import "StrongboxiOSFilesManager.h"
#import "NSArray+Extensions.h"
#import "WorkingCopyManager.h"
#import "ConcurrentMutableSet.h"
#import "DatabaseNuker.h"
#import "Utils.h"

@interface SafesList()

@property (strong, nonatomic) NSMutableArray<SafeMetaData*> *databasesList;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@property (readonly) BOOL lastChangeByOtherComponent;

@end

static NSString* const kDatabasesFilename = @"databases.json";

NSString* _Nonnull const kDatabasesListChangedNotification = @"DatabasesListChanged";
NSString* _Nonnull const kDatabaseUpdatedNotification = @"kDatabaseUpdatedNotification";

@implementation SafesList

+ (instancetype)sharedInstance {
    static SafesList *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SafesList alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.dataQueue = dispatch_queue_create("SafesList", DISPATCH_QUEUE_CONCURRENT);
        
        NSMutableArray<SafeMetaData*>* deserialized;
        NSError* error;
        
        if ( [self deserialize2:&deserialized error:&error] ) {
            self.databasesList = [deserialized mutableCopy];
        }
        else {
            self.databasesList = @[].mutableCopy;
        }
        
        if ( self.lastChangeByOtherComponent ) { 
            [self clearChangedDatabaseSettings];
        }
    }
    
    return self;
}

- (BOOL)lastChangeByOtherComponent {
#ifndef IS_APP_EXTENSION
    return AppPreferences.sharedInstance.autoFillDidChangeDatabases;
#else
    return AppPreferences.sharedInstance.mainAppDidChangeDatabases;
#endif
}

- (void)setChangedDatabaseSettings {
#ifndef IS_APP_EXTENSION
    AppPreferences.sharedInstance.mainAppDidChangeDatabases = YES;
    AppPreferences.sharedInstance.autoFillDidChangeDatabases = NO;
#else
    AppPreferences.sharedInstance.autoFillDidChangeDatabases = YES;
    AppPreferences.sharedInstance.mainAppDidChangeDatabases = NO;
#endif
}

- (void)clearChangedDatabaseSettings { 
#ifndef IS_APP_EXTENSION
    AppPreferences.sharedInstance.autoFillDidChangeDatabases = NO;
#else
    AppPreferences.sharedInstance.mainAppDidChangeDatabases = NO;
#endif
}

- (BOOL)reloadIfChangedByOtherComponent {
    if ( self.lastChangeByOtherComponent ) {
#ifndef IS_APP_EXTENSION
        slog(@"🟢 reloadIfChangedByAutoFillOrMainApp: Databases List CHANGED by AutoFill Extension...");
#else
        slog(@"🟢 reloadIfChangedByAutoFillOrMainApp: Databases List CHANGED by main Strongbox App...");
#endif
        [self clearChangedDatabaseSettings];
        
        NSMutableArray<SafeMetaData*>* deserialized;
        NSError* error;
        
        if ( [self deserialize2:&deserialized error:&error] ) {
            self.databasesList = [deserialized mutableCopy];
            return YES;
        }
        else {
            slog(@"🔴 reloadIfChangedByOtherComponent => Error deserializing: [%@]", error);
            return NO;
        }
    }
    else {
        
        return NO;
    }
}



- (NSArray<SafeMetaData *> *)snapshot {
    __block NSArray<SafeMetaData *> *result;
    dispatch_sync(self.dataQueue, ^{ result = [NSArray arrayWithArray:self.databasesList]; });
    return result;
}

- (BOOL)deserialize2:(NSMutableArray<SafeMetaData*>**)databases
               error:(NSError**)error {
    NSURL* fileUrl = [StrongboxFilesManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:kDatabasesFilename];
    
    NSError* coorderror;
    __block NSError* readError;
    __block NSData* json = nil;
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    
    [fileCoordinator coordinateReadingItemAtURL:fileUrl
                                        options:kNilOptions
                                          error:&coorderror
                                     byAccessor:^(NSURL * _Nonnull newURL) {
        json = [NSData dataWithContentsOfURL:fileUrl options:kNilOptions error:&readError];
    }];
    
    if (!json || coorderror || readError) {
        if ( readError.code != NSFileReadNoSuchFileError ) {
            slog(@"🔴 Error reading file for databases: [%@] - [%@]", coorderror, readError);
            AppPreferences.sharedInstance.databasesSerializationError = [NSString stringWithFormat:@"Read Error: [%@]", *error];
            
            
            
            NSException *e = [NSException exceptionWithName:@"DatabasesJSON Read Exception" reason:@"Could not read databases.json" userInfo:nil];
            @throw e;
            return NO;
        }
        else {
            *error = readError ? readError : coorderror;
            AppPreferences.sharedInstance.databasesSerializationError = [NSString stringWithFormat:@"Read Error: [%@]", *error];
            return NO;
        }
    }
    
    NSArray* jsonDatabases = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&coorderror];
    
    if (coorderror) {
        slog(@"Error getting json dictionaries for databases: [%@]", coorderror);
        *error = coorderror;
        AppPreferences.sharedInstance.databasesSerializationError = [NSString stringWithFormat:@"JSON Error: [%@]", *error];
        
        
        
        NSException *e = [NSException exceptionWithName:@"DatabasesJSON Read Exception" reason:@"Error getting json dictionaries for databases" userInfo:nil];
        @throw e;
        return NO;
    }
    
    NSMutableArray<SafeMetaData*> *ret = NSMutableArray.array;
    
    for (NSDictionary* jsonDatabase in jsonDatabases) {
        SafeMetaData* database = [SafeMetaData fromJsonSerializationDictionary:jsonDatabase];
        [ret addObject:database];
    }
    
    *databases = ret;
    
    return YES;
}

- (void)serialize:(BOOL)listChanged {
    [self serialize:listChanged databaseIdChanged:nil];
}

- (void)serialize:(BOOL)listChanged databaseIdChanged:(NSString*)databaseIdChanged {
    
    
    if ( self.lastChangeByOtherComponent ) {
        slog(@"🔴 🔴 🔴 🔴 WARNWARN - Serialize called but changed by other component flag set! 🔴 🔴 🔴 🔴 ");
    }
    
    NSMutableArray<NSDictionary*>* jsonDatabases = NSMutableArray.array;
    
    for (SafeMetaData* database in self.databasesList) {
        NSDictionary* jsonDict = [database getJsonSerializationDictionary];
        [jsonDatabases addObject:jsonDict];
    }
    
    NSError* error;
    NSUInteger options = NSJSONWritingPrettyPrinted;
    options |= NSJSONWritingSortedKeys;
    
    NSData* json = [NSJSONSerialization dataWithJSONObject:jsonDatabases options:options error:&error];
    
    if (error) {
        slog(@"Error getting json for databases: [%@]", error);
        return;
    }
    
    NSURL* fileUrl = [StrongboxFilesManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:kDatabasesFilename];
    
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    __block NSError *writeError = nil;
    __block BOOL success = NO;
    [fileCoordinator coordinateWritingItemAtURL:fileUrl
                                        options:0
                                          error:&error
                                     byAccessor:^(NSURL *newURL) {
        success = [json writeToURL:newURL options:NSDataWritingAtomic error:&writeError];
    }];
    
    if (!success || error || writeError) {
        slog(@"Error writing Databases file: [%@]-[%@]", error, writeError);
        return;
    }
    
    [self setChangedDatabaseSettings];
    
    if (listChanged) {
        [self notifyDatabasesListChanged];
    }
    else if (databaseIdChanged) {
        [self notifyDatabaseChanged:databaseIdChanged];
    }
}

- (void)notifyDatabasesListChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabasesListChangedNotification object:nil];
    });
}

- (void)notifyDatabaseChanged:(NSString*)databaseIdChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseUpdatedNotification object:databaseIdChanged];
    });
}

- (void)atomicUpdate:(NSString *)uuid touch:(void (^)(SafeMetaData * _Nonnull))touch {
    dispatch_barrier_async(self.dataQueue, ^{
        NSUInteger index = [self.databasesList indexOfObjectPassingTest:^BOOL(SafeMetaData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:uuid];
        }];
        
        if(index != NSNotFound) {
            SafeMetaData* metadata = self.databasesList[index];
            
            if ( touch ) {
                touch ( metadata );
                [self serialize:NO databaseIdChanged:uuid];
            }
        }
        else {
            slog(@"🔴 WARN: Attempt to update a safe not found in list... [%@]", uuid);
        }
    });
}

- (SafeMetaData *)getById:(NSString*)uuid {
    return [self.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
        return [obj.uuid isEqualToString:uuid];
    }];
}

- (SafeMetaData *_Nullable)getDatabaseById:(NSString*)uuid {
    return [SafesList.sharedInstance getById:uuid];
}








- (BOOL)add:(SafeMetaData *)safe
      error:(NSError *__autoreleasing  _Nullable *)error {
    return [self add:safe initialCache:nil initialCacheModDate:nil error:error];
}

- (BOOL)add:(SafeMetaData *)safe
initialCache:(NSData *)initialCache
initialCacheModDate:(NSDate *)initialCacheModDate
      error:(NSError *__autoreleasing  _Nullable *)error {
    return [self addWithMaybeDuplicateCheck:safe
                          checkForDuplicate:NO
                               initialCache:initialCache
                        initialCacheModDate:initialCacheModDate
                              duplicateUuid:nil
                                      error:error];
}

- (BOOL)addWithDuplicateCheck:(SafeMetaData *)safe
                 initialCache:(NSData *)initialCache
          initialCacheModDate:(NSDate *)initialCacheModDate
                        error:(NSError**)error {
    return [self addWithDuplicateCheck:safe
                          initialCache:initialCache
                   initialCacheModDate:initialCacheModDate
                         duplicateUuid:nil
                                 error:error];
}

- (BOOL)addWithDuplicateCheck:(SafeMetaData *)safe
                 initialCache:(NSData *)initialCache
          initialCacheModDate:(NSDate *)initialCacheModDate
                duplicateUuid:(NSString **)duplicateUuid
                        error:(NSError**)error {
    return [self addWithMaybeDuplicateCheck:safe
                          checkForDuplicate:YES
                               initialCache:initialCache
                        initialCacheModDate:initialCacheModDate
                              duplicateUuid:duplicateUuid
                                      error:error];
}

- (BOOL)addWithMaybeDuplicateCheck:(SafeMetaData *)safe
                 checkForDuplicate:(BOOL)checkForDuplicate
                      initialCache:(NSData *)initialCache
               initialCacheModDate:(NSDate *)initialCacheModDate
                     duplicateUuid:(NSString **)duplicateUuid
                             error:(NSError**)error {
    __block NSString* duplicateResult = nil;
    __block BOOL addedDatabase = NO;
    __block NSError* blockError = nil;
    
    dispatch_sync(self.dataQueue, ^{
        SafeMetaData* dupe = nil;
        
        if ( checkForDuplicate ) {
            dupe = [self.databasesList firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
                return [self databasesAreDuplicates:safe other:obj];
            }];
        }
        
        if( dupe == nil ) {
            addedDatabase = [self _internalAdd:safe initialCache:initialCache initialCacheModDate:initialCacheModDate error:&blockError];
        }
        else {
            slog(@"🔴 Found duplicate... Not Adding - [%@]", dupe.uuid);
            duplicateResult = dupe.uuid;
        }
    });
    
    if ( duplicateUuid ) {
        *duplicateUuid = duplicateResult;
        if ( error ) {
            *error = [Utils createNSError:@"Duplicate Database Found. Cannot Add." errorCode:-1];
        }
    }
    else {
        if ( error ) {
            *error = blockError;
        }
    }
    
    return addedDatabase;
}

- (BOOL)databasesAreDuplicates:(SafeMetaData*)safe other:(SafeMetaData*)obj {
    if ( obj.storageProvider != safe.storageProvider ) {
        return NO;
    }
    
    NSString* name1 = obj.fileName;
    NSString* name2 = safe.fileName;
    BOOL names = [name1 compare:name2] == NSOrderedSame; 
    if ( !names ) {
        return NO;
    }
    
    if ( safe.storageProvider != kiCloud ) { 
        NSString* id1 = obj.fileIdentifier;
        NSString* id2 = safe.fileIdentifier;
        
        return [id1 compare:id2] == NSOrderedSame;  
    }
    else {
        return YES;
    }
    
    return NO;
}

- (BOOL)_internalAdd:(SafeMetaData *)safe initialCache:(NSData *)initialCache initialCacheModDate:(NSDate *)initialCacheModDate error:(NSError**)error {
    if (initialCache) {
        NSError* setWorkingCacheError;
        NSURL* url = [WorkingCopyManager.sharedInstance setWorkingCacheWithData:initialCache dateModified:initialCacheModDate database:safe.uuid error:&setWorkingCacheError];
        
        if ( !url ) {
            slog(@"🔴 ERROR: Error adding database - setWorkingCacheWithData: [%@]", setWorkingCacheError);
            
            if ( error ) {
                *error = setWorkingCacheError ? setWorkingCacheError : [Utils createNSError:@"Unknown Error Adding Database!" errorCode:-1];
            }
            
            return NO;
        }
        
        safe.lastSyncRemoteModDate = initialCacheModDate; 
    }
    
    slog(@"✅ Added Database [%@]", safe.uuid);
    [self.databasesList addObject:safe];
    [self serialize:YES];
    
    return YES;
}

- (void)remove:(NSString*_Nonnull)uuid {
    dispatch_barrier_async(self.dataQueue, ^{
        NSUInteger index = [self.databasesList indexOfObjectPassingTest:^BOOL(SafeMetaData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:uuid];
        }];
        
        if(index != NSNotFound) {
            [self.databasesList removeObjectAtIndex:index];
            [self serialize:YES];
        }
        else {
            slog(@"WARN: Attempt to remove a safe not found in list... [%@]", uuid);
        }
    });
}

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex {
    dispatch_barrier_async(self.dataQueue, ^{
        SafeMetaData* item = [self.databasesList objectAtIndex:sourceIndex];
        
        [self.databasesList removeObjectAtIndex:sourceIndex];
        
        [self.databasesList insertObject:item atIndex:destinationIndex];
        
        [self serialize:YES];
    });
}

- (NSString*)getUniqueNameFromSuggestedName:(NSString*)suggested {
    suggested = [SafesList trimDatabaseNickName:suggested];

    return [self getSuggestedNewDatabaseNameWithPrefix:suggested];
}

- (NSString*)getSuggestedNewDatabaseName {
    return [self getSuggestedNewDatabaseNameWithPrefix:NSLocalizedString(@"casg_suggested_database_name_default", @"My Database")];
}

- (NSString*)getSuggestedNewDatabaseNameWithPrefix:(NSString*)prefix {
    NSString *suggestion = prefix;
   
    int attempt = 2;
    while(![self isUnique:suggestion] && attempt < 1000) {
        suggestion = [NSString stringWithFormat:@"%@ %@", prefix, @(attempt++)];
    }
    
    return [self isUnique:suggestion] ? suggestion : [NSUUID UUID].UUIDString;
}

- (NSArray<SafeMetaData*>*)getSafesOfProvider:(StorageProvider)storageProvider {
    return [self.snapshot filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        SafeMetaData* item = (SafeMetaData*)evaluatedObject;
        return item.storageProvider == storageProvider;
    }]];
}

+ (NSString *)trimDatabaseNickName:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet illegalCharacterSet]] componentsJoinedByString:@""];

    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"±|/\\`~@<>:;£$%^()=+{}[]!\"|?*"]] componentsJoinedByString:@""];
    
    return trimmed;
}

- (NSSet *)getAllNickNamesLowerCase {
    NSMutableSet *set = [[NSMutableSet alloc] initWithCapacity:self.snapshot.count];
    
    for (SafeMetaData *safe in self.snapshot) {
        [set addObject:(safe.nickName).lowercaseString];
    }
    
    return set;
}

- (BOOL)isValid:(NSString *)nickName {
    NSString *sanitized = [SafesList trimDatabaseNickName:nickName];
    
    return [sanitized compare:nickName] == NSOrderedSame && nickName.length > 0;
}

- (BOOL)isUnique:(NSString *)nickName {
    NSSet<NSString*> *nicknamesLowerCase = [self getAllNickNamesLowerCase];
    
    return ![nicknamesLowerCase containsObject:nickName.lowercaseString];
}

@end
