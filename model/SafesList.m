//
//  SafesList.m
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SafesList.h"
#import "IOsUtils.h"
#import "SharedAppAndAutoFillSettings.h"

@interface SafesList()

@property (strong, nonatomic) NSMutableArray<SafeMetaData*> *data;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

static NSString* const kSafesList = @"safesList";
NSString* _Nonnull const kDatabasesListChangedNotification = @"DatabasesListChanged";

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
        _dataQueue = dispatch_queue_create("SafesList", DISPATCH_QUEUE_CONCURRENT);
        _data = [self load];
    }
    
    return self;
}

static NSUserDefaults* getSharedAppGroupDefaults() {
    return SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
}

- (NSArray<SafeMetaData *> *)snapshot {
    __block NSArray<SafeMetaData *> *result;
    dispatch_sync(self.dataQueue, ^{ result = [NSArray arrayWithArray:self.data]; });
    return result;
}

- (NSMutableArray<SafeMetaData*>*)load {
    NSUserDefaults * defaults = getSharedAppGroupDefaults();
    NSData *encodedObject = [defaults objectForKey:kSafesList];
    
    if(encodedObject == nil) {
        return [[NSMutableArray<SafeMetaData*> alloc] init];
    }
    
    NSArray<SafeMetaData*> *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    return [[NSMutableArray<SafeMetaData*> alloc]initWithArray:object];
}

- (void)serialize {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:self.data];
    NSUserDefaults * defaults = getSharedAppGroupDefaults();
    [defaults setObject:encodedObject forKey:kSafesList];
    [defaults synchronize];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabasesListChangedNotification object:nil];
    });
}

- (void)save {
    dispatch_barrier_async(self.dataQueue, ^{
        [self serialize];
    });
}

- (void)update:(SafeMetaData *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        NSUInteger index = [self.data indexOfObjectPassingTest:^BOOL(SafeMetaData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
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

#ifndef IS_APP_EXTENSION

- (void)add:(SafeMetaData *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        [self.data addObject:safe];
        
        [self serialize];
    });
}

- (void)addWithDuplicateCheck:(SafeMetaData *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        NSArray* duplicates = [self.data filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            SafeMetaData* item = (SafeMetaData*)evaluatedObject;
            return (item.storageProvider == safe.storageProvider &&
                    [item.fileName isEqualToString:safe.fileName] &&
                    [item.fileIdentifier isEqualToString:safe.fileIdentifier]);
        }]];
        
        NSLog(@"Found %lu duplicates...", (unsigned long)duplicates.count);
        
        if([duplicates count] == 0) {
            [self.data addObject:safe];
            
            [self serialize];
        }
    });
}

- (void)remove:(NSString*_Nonnull)uuid {
    dispatch_barrier_async(self.dataQueue, ^{
        NSUInteger index = [self.data indexOfObjectPassingTest:^BOOL(SafeMetaData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
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

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex {
    dispatch_barrier_async(self.dataQueue, ^{
        SafeMetaData* item = [self.data objectAtIndex:sourceIndex];
        
        [self.data removeObjectAtIndex:sourceIndex];
        
        [self.data insertObject:item atIndex:destinationIndex];
        
        [self serialize];
    });
}

- (void)deleteAll {
    for(SafeMetaData* database in self.snapshot) {
        [database clearKeychainItems];
    }
    
    dispatch_barrier_async(self.dataQueue, ^{
        [self.data removeAllObjects];
        [self serialize];
    });
}

- (NSString*)getUniqueNameFromSuggestedName:(NSString*)suggested {
    suggested = [SafesList sanitizeSafeNickName:suggested];

    NSString *suggestion = suggested;
    
    int attempt = 2;
    while(![self isValidNickName:suggestion] && attempt < 100) {
        suggestion = [NSString stringWithFormat:@"%@ %d", suggested, attempt++];
    }
    
    return [self isValidNickName:suggestion] ? suggestion : nil;
}

#endif

- (NSString*)getSuggestedDatabaseNameUsingDeviceName {
    NSString* name = [IOsUtils nameFromDeviceName];
    name = [SafesList sanitizeSafeNickName:name];

    NSString *suggestion = name.length ?
    [NSString stringWithFormat:
        NSLocalizedString(@"casg_suggested_database_name_users_database_fmt", @"%@'s Database"), name] :
        NSLocalizedString(@"casg_suggested_database_name_default", @"My Database");
   
    int attempt = 2;
    while(![self isValidNickName:suggestion] && attempt < 100) {
        suggestion = [NSString stringWithFormat:
                      NSLocalizedString(@"casg_suggested_database_name_users_database_number_suffix_fmt", @"%@'s Database %d"), name, attempt++];
    }
    
    return [self isValidNickName:suggestion] ? suggestion : nil;
}

+ (NSString *)sanitizeSafeNickName:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet illegalCharacterSet]] componentsJoinedByString:@""];
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

- (BOOL)isValidNickName:(NSString *)nickName {
    NSString *sanitized = [SafesList sanitizeSafeNickName:nickName];
    
    NSSet<NSString*> *nicknamesLowerCase = [self getAllNickNamesLowerCase];
    
    return [sanitized isEqualToString:nickName] && nickName.length > 0 && ![nicknamesLowerCase containsObject:nickName.lowercaseString];
}

- (NSArray<SafeMetaData*>*)getSafesOfProvider:(StorageProvider)storageProvider {
    return [self.snapshot filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        SafeMetaData* item = (SafeMetaData*)evaluatedObject;
        return item.storageProvider == storageProvider;
    }]];
}

@end
