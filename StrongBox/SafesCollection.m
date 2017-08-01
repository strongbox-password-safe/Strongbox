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
@property NSMutableArray *safes;
@end

@implementation SafesCollection

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSArray *existingSafes = [userDefaults arrayForKey:@"safes"];
        
        self.safes = [[NSMutableArray alloc] init];
        
        for (NSDictionary *safeDict in existingSafes) {
            SafeMetaData *safe = [SafeMetaData fromDictionary:safeDict];
            
            [self.safes addObject:safe];
        }
        
        return self;
    }
    else {
        return nil;
    }
}

- (NSUInteger)count {
    return self.safes.count;
}

- (SafeMetaData *)get:(NSUInteger)index {
    return (self.safes)[index];
}

- (void)removeSafesAt:(NSIndexSet *)index {
    return [self.safes removeObjectsAtIndexes:index];
}

- (void)removeAt:(NSUInteger)index {
    return [self.safes removeObjectAtIndex:index];
}

- (NSSet *)getAllNickNamesLowerCase {
    NSMutableSet *set = [[NSMutableSet alloc] initWithCapacity:self.safes.count];
    
    for (SafeMetaData *safe in self.safes) {
        [set addObject:(safe.nickName).lowercaseString];
    }
    
    return set;
}

- (void)add:(SafeMetaData *)newSafe {
    if (![self isValidNickName:newSafe.nickName]) {
        NSLog(@"Cannot Save Safe, as existing Safe exists with this nick name, or the name is invalid!");
        return;
    }
    
    [self.safes addObject:newSafe];
    
    [self save];
}

//////////////////////////////////////////////////////////////////////////////////////////

- (void)save {
    NSMutableArray *sfs = [NSMutableArray arrayWithCapacity:(self.safes).count ];
    
    for (SafeMetaData *s in self.safes) {
        [sfs addObject:s.toDictionary];
    }
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:sfs forKey:@"safes"];
    
    [userDefaults synchronize];
}

/////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)sanitizeSafeNickName:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet illegalCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet nonBaseCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"±|/\\`~@<>:;£$%^&()=+{}[]!\"|?*"]] componentsJoinedByString:@""];
    
    return trimmed;
}

- (BOOL)isValidNickName:(NSString *)nickName {
    NSString *sanitized = [self sanitizeSafeNickName:nickName];
    
    return [sanitized isEqualToString:nickName] &&
    nickName.length > 0 &&
    ![[self getAllNickNamesLowerCase] containsObject:nickName.lowercaseString];
}

@end
