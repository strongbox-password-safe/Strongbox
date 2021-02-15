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

@interface DatabasesManager()

@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

static NSString* kDatabasesDefaultsKey = @"databases";
static NSString* const kMigratedToNewStore = @"migratedDatabasesToNewStore";

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

    dispatch_sync(self.dataQueue, ^{ result = [self deserialize].copy; });

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

- (void)update:(DatabaseMetadata *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        NSMutableArray<DatabaseMetadata*>* databases = [self deserialize];

        NSUInteger index = [databases indexOfObjectPassingTest:^BOOL(DatabaseMetadata * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:safe.uuid];
        }];
        
        if(index != NSNotFound) {
            [databases replaceObjectAtIndex:index withObject:safe];
            [self serialize:databases];
        }
        else {
            NSLog(@"WARN: Attempt to update a safe not found in list... [%@]", safe);
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

+ (NSString *)sanitizeSafeNickName:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
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

- (BOOL)isValidNickName:(NSString *)nickName {
    NSString *sanitized = [DatabasesManager sanitizeSafeNickName:nickName];
    
    NSSet<NSString*> *nicknamesLowerCase = [self getAllNickNamesLowerCase];
    
    return [sanitized isEqualToString:nickName] && nickName.length > 0 && ![nicknamesLowerCase containsObject:nickName.lowercaseString];
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
    
    NSError* error;
    NSString * fileIdentifier = [BookmarksHelper getBookmarkFromUrl:url readOnly:NO error:&error];
    
    if(!fileIdentifier) {
        NSLog(@"Could not get Bookmark for this database will continue without... [%@]", error);
    }

    safe = [[DatabaseMetadata alloc] initWithNickName:[url.lastPathComponent stringByDeletingPathExtension]
                                      storageProvider:kLocalDevice 
                                              fileUrl:url
                                          storageInfo:fileIdentifier];

    [DatabasesManager.sharedInstance add:safe];

    return safe;
}

@end
