//
//  SafesList.m
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SafesList.h"

@interface SafesList()

@property (strong, nonatomic) NSMutableArray<SafeMetaData*> *data;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

static NSString* kSafesList = @"safesList";

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

- (void)add:(SafeMetaData *_Nonnull)safe {
    dispatch_barrier_async(self.dataQueue, ^{
        safe.uuid = [[NSUUID UUID] UUIDString];
        [self.data addObject:safe];
        
        NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:self.data];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:encodedObject forKey:kSafesList];
        [defaults synchronize];
    });
}

- (NSArray<SafeMetaData *> *)snapshot {
    __block NSArray<SafeMetaData *> *result;
    dispatch_sync(self.dataQueue, ^{ result = [NSArray arrayWithArray:self.data]; });
    return result;
}

- (void)remove:(NSString*_Nonnull)uuid {
    dispatch_barrier_async(self.dataQueue, ^{
        NSUInteger index = [self.data indexOfObjectPassingTest:^BOOL(SafeMetaData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:uuid];
        }];
        
        if(index != NSNotFound) {
            [self.data removeObjectAtIndex:index];
        }
        
        NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:self.data];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:encodedObject forKey:kSafesList];
        [defaults synchronize];
    });
}

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex {
    dispatch_barrier_async(self.dataQueue, ^{
        SafeMetaData* item = [self.data objectAtIndex:sourceIndex];
        
        [self.data removeObjectAtIndex:sourceIndex];
        
        [self.data insertObject:item atIndex:destinationIndex];
        
        NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:self.data];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:encodedObject forKey:kSafesList];
        [defaults synchronize];
    });
}

- (NSMutableArray<SafeMetaData*>*)load {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *encodedObject = [defaults objectForKey:kSafesList];
    
    if(encodedObject == nil) {
        return [[NSMutableArray<SafeMetaData*> alloc] init];
    }
    
    NSArray<SafeMetaData*> *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    return [[NSMutableArray<SafeMetaData*> alloc]initWithArray:object];
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
