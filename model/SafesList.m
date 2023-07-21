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

@interface SafesList()

@property (strong, nonatomic) NSMutableArray<SafeMetaData*> *databasesList;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@property (readonly) BOOL changedDatabaseSettingsFlag;
@property ConcurrentMutableSet* editingSet; 

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
        self.editingSet = ConcurrentMutableSet.mutableSet;
        self.databasesList = [self deserialize];
    }
    
    return self;
}

- (BOOL)changedDatabaseSettingsFlag {
#ifndef IS_APP_EXTENSION
    return AppPreferences.sharedInstance.autoFillDidChangeDatabases;
#else
    return AppPreferences.sharedInstance.mainAppDidChangeDatabases;
#endif
}

- (void)setChangedDatabaseSettings {
#ifndef IS_APP_EXTENSION
    AppPreferences.sharedInstance.mainAppDidChangeDatabases = YES;
#else
    AppPreferences.sharedInstance.autoFillDidChangeDatabases = YES;
#endif
}

- (void)clearChangedDatabaseSettings { 
#ifndef IS_APP_EXTENSION
    AppPreferences.sharedInstance.autoFillDidChangeDatabases = NO;
#else
    AppPreferences.sharedInstance.mainAppDidChangeDatabases = NO;
#endif
}

- (void)reloadIfChangedByOtherComponent {
    if ( self.changedDatabaseSettingsFlag ) { 


        [self clearChangedDatabaseSettings];
        self.databasesList = [self deserialize];
    }
    else {

    }
}



- (NSArray<SafeMetaData *> *)snapshot {
    __block NSArray<SafeMetaData *> *result;
    dispatch_sync(self.dataQueue, ^{ result = [NSArray arrayWithArray:self.databasesList]; });
    return result;
}

- (NSMutableArray<SafeMetaData*>*)deserialize {
    NSURL* fileUrl = [StrongboxFilesManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:kDatabasesFilename];
    
    NSError* error;
    __block NSError* readError;
    __block NSData* json = nil;
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    
    [fileCoordinator coordinateReadingItemAtURL:fileUrl
                                        options:kNilOptions
                                          error:&error
                                     byAccessor:^(NSURL * _Nonnull newURL) {
        json = [NSData dataWithContentsOfURL:fileUrl options:kNilOptions error:&readError];
    }];
    
    if (!json || error || readError) {
        if ( readError.code != NSFileReadNoSuchFileError ) {
            NSLog(@"🔴 Error reading file for databases: [%@] - [%@]", error, readError);
        }
        
        return @[].mutableCopy;
    }

    NSArray* jsonDatabases = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&error];

    if (error) {
        NSLog(@"Error getting json dictionaries for databases: [%@]", error);
        return @[].mutableCopy;
    }

    NSMutableArray<SafeMetaData*> *ret = NSMutableArray.array;
    for (NSDictionary* jsonDatabase in jsonDatabases) {
        SafeMetaData* database = [SafeMetaData fromJsonSerializationDictionary:jsonDatabase];
        [ret addObject:database];
    }
    
    return ret;
}

- (void)serialize:(BOOL)listChanged {
    [self serialize:listChanged databaseIdChanged:nil];
}

- (void)serialize:(BOOL)listChanged databaseIdChanged:(NSString*)databaseIdChanged {
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
        NSLog(@"Error getting json for databases: [%@]", error);
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
        NSLog(@"Error writing Databases file: [%@]-[%@]", error, writeError);
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
            NSLog(@"🔴 WARN: Attempt to update a safe not found in list... [%@]", uuid);
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

- (void)add:(SafeMetaData *)safe initialCache:(NSData *)initialCache initialCacheModDate:(NSDate *)initialCacheModDate {
    dispatch_barrier_async(self.dataQueue, ^{
        [self _internalAdd:safe initialCache:initialCache initialCacheModDate:initialCacheModDate];
    });
}

- (NSString*)addWithDuplicateCheck:(SafeMetaData *)safe
                      initialCache:(NSData *)initialCache
               initialCacheModDate:(NSDate *)initialCacheModDate {
    __block NSString* result;

    dispatch_sync(self.dataQueue, ^{
        SafeMetaData* dupe = [self.databasesList firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
            BOOL storage = obj.storageProvider == safe.storageProvider;
            
            NSString* name1 = obj.fileName;
            NSString* name2 = safe.fileName;
            BOOL names = [name1 compare:name2] == NSOrderedSame; 

            NSString* id1 = obj.fileIdentifier;
            NSString* id2 = safe.fileIdentifier;
            BOOL ids = [id1 compare:id2] == NSOrderedSame;  

            return storage && names && ids;
        }];
        
        if( dupe == nil ) {
            [self _internalAdd:safe initialCache:initialCache initialCacheModDate:initialCacheModDate];
            result = nil;
        }
        else {
            NSLog(@"🔴 Found duplicate... Not Adding - [%@]", dupe.uuid);
            result = dupe.uuid;
        }
    });
    
    return result;
}

- (void)_internalAdd:(SafeMetaData *)safe initialCache:(NSData *)initialCache initialCacheModDate:(NSDate *)initialCacheModDate {
    if (initialCache) {
        NSError* error;
        NSURL* url = [WorkingCopyManager.sharedInstance setWorkingCacheWithData:initialCache dateModified:initialCacheModDate database:safe.uuid error:&error];

        safe.lastSyncRemoteModDate = initialCacheModDate; 
        
        if (error || !url) {
            NSLog(@"🔴 ERROR: Error adding database - setWorkingCacheWithData: [%@]", error);
        }
        else {
            NSLog(@"✅ Added Database [%@]", safe.uuid);
            [self.databasesList addObject:safe];
            [self serialize:YES];
        }
    }
    else {
        NSLog(@"✅ Added Database [%@]", safe.uuid);
        [self.databasesList addObject:safe];
        [self serialize:YES];
    }
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
            NSLog(@"WARN: Attempt to remove a safe not found in list... [%@]", uuid);
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

- (void)deleteAll {
    for(SafeMetaData* database in self.snapshot) {
        [database clearKeychainItems];
    }
    
    dispatch_barrier_async(self.dataQueue, ^{
        [self.databasesList removeAllObjects];
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
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet nonBaseCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"±|/\\`~@<>:;£$%^&()=+{}[]!\"|?*"]] componentsJoinedByString:@""];
    
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



- (BOOL)isEditing:(SafeMetaData *)database {
    return [self.editingSet containsObject:database.uuid];
}

- (void)setEditing:(SafeMetaData *)database editing:(BOOL)editing {
    NSLog(@"SafesList::setEditing: %@ => %hhd", database.nickName, editing);
    
    if ( editing ) {
        [self.editingSet addObject:database.uuid];
    }
    else {
        [self.editingSet removeObject:database.uuid];
    }
}

@end
