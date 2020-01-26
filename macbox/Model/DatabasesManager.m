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

@interface DatabasesManager()

@property (strong, nonatomic) NSMutableArray<DatabaseMetadata*> *data;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

static NSString* kDatabasesDefaultsKey = @"databases";

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
        _data = [self load];
    }
    
    return self;
}

- (NSMutableArray<DatabaseMetadata*>*)load {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *encodedObject = [defaults objectForKey:kDatabasesDefaultsKey];
    
    if(encodedObject == nil) {
        return [[NSMutableArray<DatabaseMetadata*> alloc] init];
    }
    
    NSArray<DatabaseMetadata*> *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    return [[NSMutableArray<DatabaseMetadata*> alloc]initWithArray:object];
}

- (void)serialize {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:self.data];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:encodedObject forKey:kDatabasesDefaultsKey];
    [defaults synchronize];
}

- (void)add:(DatabaseMetadata *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        [self.data addObject:safe];
        [self serialize];
    });
}

- (void)save {
    dispatch_barrier_async(self.dataQueue, ^{
        [self serialize];
    });
}

- (NSArray<DatabaseMetadata *> *)snapshot {
    __block NSArray<DatabaseMetadata *> *result;
    dispatch_sync(self.dataQueue, ^{ result = [NSArray arrayWithArray:self.data]; });
    return result;
}

- (void)remove:(NSString*_Nonnull)uuid {
    dispatch_barrier_async(self.dataQueue, ^{
        NSUInteger index = [self.data indexOfObjectPassingTest:^BOOL(DatabaseMetadata * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:uuid];
        }];
        
        if(index != NSNotFound) {
            [self.data removeObjectAtIndex:index];
            [self serialize];
        }
        else {
            NSLog(@"WARN: Attempt to remove a safe not found in list... [%@]", uuid);
        }
    });
}

- (void)update:(DatabaseMetadata *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        NSUInteger index = [self.data indexOfObjectPassingTest:^BOOL(DatabaseMetadata * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:safe.uuid];
        }];
        
        if(index != NSNotFound) {
            [self.data replaceObjectAtIndex:index withObject:safe];
            [self serialize];
        }
        else {
            NSLog(@"WARN: Attempt to update a safe not found in list... [%@]", safe);
        }
    });
}

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex {
    dispatch_barrier_async(self.dataQueue, ^{
        DatabaseMetadata* item = [self.data objectAtIndex:sourceIndex];
        
        [self.data removeObjectAtIndex:sourceIndex];
        
        [self.data insertObject:item atIndex:destinationIndex];
        
        [self serialize];
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
    // FUTURE: Check Storage type when impl sftp or webdav
    
    return [self.snapshot firstOrDefault:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return [obj.fileUrl isEqual:url];
    }];
}

- (DatabaseMetadata*)addOrGet:(NSURL *)url {
    DatabaseMetadata *safe = [self getDatabaseByFileUrl:url];
    if(safe) {
//        NSLog(@"Database is already in Databases List... Not Adding");
        return safe;
    }
    
    NSError* error;
    NSString * fileIdentifier = [BookmarksHelper getBookmarkFromUrl:url error:&error];
    if(!fileIdentifier) {
        NSLog(@"getBookmarkFromUrl: [%@]", error);
        return nil;
    }
    
    safe = [[DatabaseMetadata alloc] initWithNickName:[url.lastPathComponent stringByDeletingPathExtension]
                                      storageProvider:kLocalDevice
                                              fileUrl:url
                                          storageInfo:fileIdentifier];
    
    [DatabasesManager.sharedInstance add:safe];
    
    return safe;
}



@end
