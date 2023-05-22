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

@interface DatabasesManager()

@property (strong, nonatomic) dispatch_queue_t dataQueue;

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

- (NSMutableArray<DatabaseMetadata*>*)deserializeFromUserDefaults:(NSUserDefaults*)defaults {
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

- (NSMutableArray<DatabaseMetadata*>*)deserialize {
    return [self deserializeFromUserDefaults:Settings.sharedInstance.sharedAppGroupDefaults];
}

- (void)serialize:(NSArray<DatabaseMetadata*>*)data {
    [self serializeToUserDefaults:Settings.sharedInstance.sharedAppGroupDefaults data:data];

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabasesListChangedNotification object:nil];
    });
}
    


- (void)add:(DatabaseMetadata *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        NSMutableArray<DatabaseMetadata*>* databases = [self deserialize];
        [databases addObject:safe];
        [self serialize:databases];
    });
}

- (NSArray<DatabaseMetadata *> *)snapshot {
    __block NSArray<DatabaseMetadata *> *result;

    
    
    
    
    
    
    
    if ( dispatch_get_current_queue() == self.dataQueue ) { 
        result = [self deserialize].copy;
    }
    else {
        dispatch_sync(self.dataQueue, ^{ result = [self deserialize].copy; });
    }
    
    return result;
}

- (void)remove:(NSString*_Nonnull)uuid {
    dispatch_barrier_async(self.dataQueue, ^{
        NSMutableArray<DatabaseMetadata*>* databases = [self deserialize];

        NSUInteger index = [databases indexOfObjectPassingTest:^BOOL(DatabaseMetadata * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:uuid];
        }];
        
        if(index != NSNotFound) {
            [databases removeObjectAtIndex:index];
            [self serialize:databases];
        }
        else {
            NSLog(@"WARN: Attempt to remove a safe not found in list... [%@]", uuid);
        }
    });
}

- (void)atomicUpdate:(NSString *)uuid touch:(void (^)(DatabaseMetadata * _Nonnull))touch {
    dispatch_barrier_async(self.dataQueue, ^{  
        NSMutableArray<DatabaseMetadata*>* databases = [self deserialize];

        NSUInteger index = [databases indexOfObjectPassingTest:^BOOL(DatabaseMetadata * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:uuid];
        }];
        
        if(index != NSNotFound) {
            DatabaseMetadata* metadata = databases[index];
            
            if ( touch ) {
                touch ( metadata );
                [self serialize:databases];
            }
        }
        else {
            NSLog(@"WARN: Attempt to update a safe not found in list... [%@]", uuid);
        }
    });
}

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex {
    dispatch_barrier_async(self.dataQueue, ^{
        NSMutableArray<DatabaseMetadata*>* databases = [self deserialize];

        DatabaseMetadata* item = [databases objectAtIndex:sourceIndex];
        
        [databases removeObjectAtIndex:sourceIndex];
        
        [databases insertObject:item atIndex:destinationIndex];
        
        [self serialize:databases];
    });
}

- (DatabaseMetadata *)getDatabaseById:(NSString *)uuid {
    return [self.snapshot firstOrDefault:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return [obj.uuid isEqualToString:uuid];
    }];
}

- (DatabaseMetadata *)getDatabaseByFileUrl:(NSURL *)url {
    
    
    return [self.snapshot firstOrDefault:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return [obj.fileUrl isEqual:url];
    }];
}

- (DatabaseMetadata*)addOrGet:(NSURL *)url {
    DatabaseMetadata *safe = [self getDatabaseByFileUrl:url];
    if(safe) {
        return safe;
    }
    
    NSURL* effectiveFileUrl = url;
    if ( [url.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
        NSURLComponents* components =  [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        components.scheme = kStrongboxFileUrlScheme;
        effectiveFileUrl = components.URL;
    }
    
    NSError* error;
    NSString * fileIdentifier = [BookmarksHelper getBookmarkFromUrl:effectiveFileUrl readOnly:NO error:&error];
    if(!fileIdentifier) {
        NSLog(@"Could not get Bookmark for this database will continue without... [%@]", error);
    }

    StorageProvider provider = storageProviderFromUrl(url);
     
    NSString* nickName = [url.lastPathComponent stringByDeletingPathExtension];
    
    nickName = nickName ? nickName : NSLocalizedString(@"generic_unknown", @"Unknown");
    
    nickName = [self getUniqueNameFromSuggestedName:nickName];
    
    safe = [[DatabaseMetadata alloc] initWithNickName:nickName
                                      storageProvider:provider
                                              fileUrl:url
                                          storageInfo:fileIdentifier];

    [DatabasesManager.sharedInstance add:safe];

    return safe;
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
