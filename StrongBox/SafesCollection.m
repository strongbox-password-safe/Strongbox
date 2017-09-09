//
//  SafesCollection.m
//  StrongBox
//
//  Created by Mark on 22/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafesCollection.h"
#import "SafeMetaData.h"

@interface SafesCollection ()

@property (nonatomic, nonnull) NSMutableArray<SafeMetaData*> *mutableSafes;

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
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSArray *existingSafes = [userDefaults arrayForKey:@"safes"];
        
        self.mutableSafes = [[NSMutableArray alloc] init];
        
        for (NSDictionary *safeDict in existingSafes) {
            SafeMetaData *safe = [SafeMetaData fromDictionary:safeDict];
            
            [self.mutableSafes addObject:safe];
        }
        
        return self;
    }
    else {
        return nil;
    }
}

- (NSArray<SafeMetaData*>*)safes {
    return self.mutableSafes;
}

- (void)removeSafesAt:(NSIndexSet *)index {
    return [self.mutableSafes removeObjectsAtIndexes:index];
}

- (void)removeAt:(NSUInteger)index {
    return [self.mutableSafes removeObjectAtIndex:index];
}

- (NSSet *)getAllNickNamesLowerCase {
    NSMutableSet *set = [[NSMutableSet alloc] initWithCapacity:self.mutableSafes.count];
    
    for (SafeMetaData *safe in self.mutableSafes) {
        [set addObject:(safe.nickName).lowercaseString];
    }
    
    return set;
}

- (void)add:(SafeMetaData *)newSafe {
    if (![self isValidNickName:newSafe.nickName]) {
        NSLog(@"Cannot Save Safe, as existing Safe exists with this nick name, or the name is invalid!");
        return;
    }
    
    [self.mutableSafes addObject:newSafe];
    
    [self save];
}

//////////////////////////////////////////////////////////////////////////////////////////

- (void)save {
    NSMutableArray *sfs = [NSMutableArray arrayWithCapacity:(self.mutableSafes).count ];
    
    for (SafeMetaData *s in self.mutableSafes) {
        [sfs addObject:s.toDictionary];
    }
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:sfs forKey:@"safes"];
    
    [userDefaults synchronize];
}

/////////////////////////////////////////////////////////////////////////////////////////

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
    
    return [sanitized isEqualToString:nickName] && nickName.length > 0 && ![[self getAllNickNamesLowerCase] containsObject:nickName.lowercaseString];
}

- (BOOL)safeWithTouchIdIsAvailable {
    NSArray<SafeMetaData*> *touchIdEnabledSafes = [self.mutableSafes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        SafeMetaData *safe = (SafeMetaData*)evaluatedObject;
        return safe.isTouchIdEnabled && safe.isEnrolledForTouchId;
    }]];
    
    return [touchIdEnabledSafes count] > 0;
}

@end
