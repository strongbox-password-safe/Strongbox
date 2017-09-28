//
//  SafesCollection.m
//  StrongBox
//
//  Created by Mark on 22/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafesCollection.h"
#import "SafeMetaData.h"
#import "Utils.h"

@interface SafesCollection ()

@property (nonatomic, nonnull) NSMutableDictionary<NSString*, SafeMetaData*> *theCollection;
@property (nonatomic, nonnull, readonly) NSArray<SafeMetaData*> *snapshot;

@end

@implementation SafesCollection

+ (instancetype)sharedInstance {
    static SafesCollection *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SafesCollection alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        
        self.theCollection = [[NSMutableDictionary alloc] init];
        
        [self load];
        
        return self;
    }
    else {
        return nil;
    }
}

- (NSArray<SafeMetaData *> *)snapshot {
    return self.theCollection.allValues;
}

- (void)removeSafe:(NSString*)safeName {
    [self.theCollection removeObjectForKey:safeName];
    [self save];
}

- (BOOL)internalNoSaveAdd:(SafeMetaData *)safe {
    if ([self.theCollection objectForKey:safe.nickName] || ![self isValidNickName:safe.nickName]) {
        NSLog(@"Cannot Save Safe as [%@], as existing Safe exists with this nick name, or the name is invalid!", safe.nickName);
        NSLog(@"*******************************************************************************************");
        
        for (NSString* foo in self.theCollection.allKeys)
        {
            NSLog(@"%@", foo);
        }
        
        NSLog(@"*******************************************************************************************");
        return NO;
    }
    
    [self.theCollection setObject:safe forKey:safe.nickName];
    
    return YES;
}

- (BOOL)add:(SafeMetaData *)safe {
    BOOL ret = [self internalNoSaveAdd:safe];
    
    [self save];
   
    return ret;
}

- (BOOL)changeNickName:(NSString*)nickName newNickName:(NSString*)newNickName {
    SafeMetaData* metadata = [self.theCollection objectForKey:nickName];
    
    if(![self.theCollection objectForKey:newNickName]) {
        [metadata changeNickName:newNickName];
    
        [self.theCollection setObject:metadata forKey:newNickName];
        [self.theCollection removeObjectForKey:nickName];
        [self save];
        
        return YES;
    }
    
    return NO;
}

//////////////////////////////////////////////////////////////////////////////////////////

- (void)load {
    self.theCollection = [NSMutableDictionary dictionary];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *existingSafes = [userDefaults arrayForKey:@"safes"];
    
    for (NSDictionary *safeDict in existingSafes) {
        SafeMetaData *safe = [SafeMetaData fromDictionary:safeDict];
        
        // TODO: Failure should only ever happen on initial load of 1.12.0 where someone has somehow got 2 identically named safes...
        // virtually impossible
        
        if(![self internalNoSaveAdd:safe]) {
            [safe changeNickName:[[NSUUID UUID] UUIDString]];
            [self internalNoSaveAdd:safe];
        }
    }
}

- (void)save {
    NSMutableArray *sfs = [NSMutableArray arrayWithCapacity:(self.snapshot).count ];
    
    for (SafeMetaData *s in self.theCollection.allValues) {
        [sfs addObject:s.toDictionary];
    }
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:sfs forKey:@"safes"];
    [userDefaults synchronize];
}

/////////////////////////////////////////////////////////////////////////////////////////

- (NSArray<SafeMetaData*>*)sortedSafes {
    return [self.snapshot sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString* str1 = ((SafeMetaData*)obj1).nickName;
        NSString* str2 = ((SafeMetaData*)obj2).nickName;
        
        return [Utils finderStringCompare:str1 string2:str2];
    }];
}

- (NSSet *)getAllNickNamesLowerCase {
    NSMutableSet *set = [[NSMutableSet alloc] initWithCapacity:self.snapshot.count];
    
    for (SafeMetaData *safe in self.snapshot) {
        [set addObject:(safe.nickName).lowercaseString];
    }
    
    return set;
}

- (NSArray<SafeMetaData*>*)getSafesOfProvider:(StorageProvider)storageProvider {
    return [self.snapshot filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        SafeMetaData* item = (SafeMetaData*)evaluatedObject;
        return item.storageProvider == storageProvider;
    }]];
}

+ (NSString *)sanitizeSafeNickName:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet illegalCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet nonBaseCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"±|/\\`~@<>:;£$%^&()=+{}[]!\"|?*"]] componentsJoinedByString:@""];
    
    return trimmed;
}

- (BOOL)isValidNickName:(NSString *)nickName {
    NSString *sanitized = [SafesCollection sanitizeSafeNickName:nickName];
    
    NSSet<NSString*> *nicknamesLowerCase = [self getAllNickNamesLowerCase];

    NSLog(@"*********************************************************************************************************");
    for(NSString *existing in nicknamesLowerCase) {
        NSLog(@"SafesCollection: [%@] checked against [%@] == %d", existing, nickName, [nickName.lowercaseString isEqualToString:existing]);
    }
    NSLog(@"*********************************************************************************************************");

    return [sanitized isEqualToString:nickName] && nickName.length > 0 && ![nicknamesLowerCase containsObject:nickName.lowercaseString];
}

- (BOOL)safeWithTouchIdIsAvailable {
    NSArray<SafeMetaData*> *touchIdEnabledSafes = [self.snapshot filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        SafeMetaData *safe = (SafeMetaData*)evaluatedObject;
        return safe.isTouchIdEnabled && safe.isEnrolledForTouchId;
    }]];
    
    return [touchIdEnabledSafes count] > 0;
}

@end
