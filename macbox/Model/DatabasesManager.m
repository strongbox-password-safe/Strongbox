//
//  SafesList.m
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "DatabasesManager.h"
#import "BookmarksHelper.h"
#import "NSArray+Extensions.h"
#import "Settings.h"
#import "MacUrlSchemes.h"
#import "MutableOrderedDictionary.h"

@interface DatabasesManager()

@property (strong, nonatomic) dispatch_queue_t dataQueue;

@property MutableOrderedDictionary<NSString*, DatabaseMetadata*>* backingDatabases;
@property (readonly) MutableOrderedDictionary<NSString*, DatabaseMetadata*>* databases;

@end

static NSString* const kDatabasesDefaultsKey = @"databases";

NSString* const kDatabasesListChangedNotification = @"databasesListChangedNotification";

@implementation DatabasesManager

+ (instancetype)sharedInstance {
    static DatabasesManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DatabasesManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _dataQueue = dispatch_queue_create("SafesList", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}



- (NSArray<DatabaseMetadata*>*)deserializeFromUserDefaults:(NSUserDefaults*)defaults {


    NSData *encodedObject = [defaults objectForKey:kDatabasesDefaultsKey];
    
    if(encodedObject == nil) {
        return [[NSMutableArray<DatabaseMetadata*> alloc] init];
    }
    
    NSArray<DatabaseMetadata*> *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    



    return [[NSMutableArray<DatabaseMetadata*> alloc] initWithArray:object];
}

- (void)serializeToUserDefaults:(NSUserDefaults*)defaults data:(NSArray<DatabaseMetadata*>*)data {

    
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:data];
    [defaults setObject:encodedObject forKey:kDatabasesDefaultsKey];
    [defaults synchronize];
    


}

- (void)serialize {

    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(actualSerialize) object:nil];
        [self performSelector:@selector(actualSerialize) withObject:nil afterDelay:0.1f];
    });
}

- (void)actualSerialize {
    [self serializeToUserDefaults:Settings.sharedInstance.sharedAppGroupDefaults data:self.databases.allValues];

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabasesListChangedNotification object:nil];
    });
}

- (void)forceSerialize {
    dispatch_barrier_sync(self.dataQueue, ^{
        [self actualSerialize];
    });
}

- (void)forceReload {
    dispatch_barrier_sync(self.dataQueue, ^{
        [self load];
    });
}

- (void)load {
    NSArray<DatabaseMetadata*>* dbs = [self deserializeFromUserDefaults:Settings.sharedInstance.sharedAppGroupDefaults];
    
    MutableOrderedDictionary<NSString*, DatabaseMetadata*>* swap = [[MutableOrderedDictionary alloc] init];
    for (DatabaseMetadata* db in dbs) {
        [swap addKey:db.uuid andValue:db];
    }
    
    self.backingDatabases = swap;
}

- (MutableOrderedDictionary<NSString *,DatabaseMetadata *> *)databases {
    
    
    
    
    
    

    if ( dispatch_get_current_queue() == self.dataQueue ) { 
        return [self getOrLoadDatabases];
    }
    else {
        __block MutableOrderedDictionary<NSString *,DatabaseMetadata *> *result;
        
        dispatch_sync(self.dataQueue, ^{
            result = [self getOrLoadDatabases];
        });
        
        return result;
    }
}

- (MutableOrderedDictionary<NSString *,DatabaseMetadata *> *)getOrLoadDatabases {
    if ( !self.backingDatabases ) {
        [self load];
    }
    
    return self.backingDatabases;
}



- (NSArray<DatabaseMetadata *> *)snapshot {
    return self.databases.allValues;
}



- (void)add:(DatabaseMetadata *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        [self.databases addKey:safe.uuid andValue:safe];
        [self serialize];
    });
}

- (void)remove:(NSString*_Nonnull)uuid {
    dispatch_barrier_async(self.dataQueue, ^{
        [self.databases remove:uuid];
        [self serialize];
    });
}

- (void)atomicUpdate:(NSString *)uuid touch:(void (^)(DatabaseMetadata * _Nonnull))touch {
    dispatch_barrier_async(self.dataQueue, ^{
        DatabaseMetadata* metadata = self.databases[uuid];
        
        if ( metadata ) {
            if ( touch ) {
                touch ( metadata );
                [self serialize];
            }
        }
        else {
            slog(@"WARN: Attempt to update a safe not found in list... [%@]", uuid);
        }
    });
}

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex {
    dispatch_barrier_async(self.dataQueue, ^{
        DatabaseMetadata* item = [self.databases removeObjectAtIndex:sourceIndex];
        [self.databases insertKey:item.uuid withValue:item atIndex:destinationIndex];
        
        [self serialize];
    });
}



- (DatabaseMetadata *)getDatabaseById:(NSString *)uuid {
    return self.databases[uuid];
}

- (DatabaseMetadata *)getDatabaseByFileUrl:(NSURL *)url {
    
    
    return [self.snapshot firstOrDefault:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return [obj.fileUrl isEqual:url];
    }];
}

- (DatabaseMetadata*)addOrGet:(NSURL *)maybeManagedUrl {
    DatabaseMetadata *safe = [self getDatabaseByFileUrl:maybeManagedUrl];
    if(safe) {
        return safe;
    }
    
    NSURL* effectiveFileUrl = fileUrlFromManagedUrl(maybeManagedUrl);
    
    NSError* error;
    NSString * fileIdentifier = [BookmarksHelper getBookmarkFromUrl:effectiveFileUrl readOnly:NO error:&error];
    if(!fileIdentifier) {
        slog(@"Could not get Bookmark for this database will continue without... [%@]", error);
    }

    StorageProvider provider = storageProviderFromUrl(maybeManagedUrl);
     
    NSString* nickName = [maybeManagedUrl.lastPathComponent stringByDeletingPathExtension];
    
    nickName = nickName ? nickName : NSLocalizedString(@"generic_unknown", @"Unknown");
    
    nickName = [self getUniqueNameFromSuggestedName:nickName];
    
    safe = [[DatabaseMetadata alloc] initWithNickName:nickName
                                      storageProvider:provider
                                              fileUrl:maybeManagedUrl
                                          storageInfo:fileIdentifier];

    [DatabasesManager.sharedInstance add:safe];

    return safe;
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
    
    for (DatabaseMetadata *safe in self.snapshot) {
        [set addObject:(safe.nickName).lowercaseString];
    }
    
    return set;
}

- (BOOL)isValid:(NSString *)nickName {
    NSString *sanitized = [DatabasesManager trimDatabaseNickName:nickName];
    
    return [sanitized compare:nickName] == NSOrderedSame && nickName.length > 0;
}

- (BOOL)isUnique:(NSString *)nickName {
    NSSet<NSString*> *nicknamesLowerCase = [self getAllNickNamesLowerCase];
    
    return ![nicknamesLowerCase containsObject:nickName.lowercaseString];
}

- (NSString*)getUniqueNameFromSuggestedName:(NSString*)suggested {
    suggested = [DatabasesManager trimDatabaseNickName:suggested];
    
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

@end
