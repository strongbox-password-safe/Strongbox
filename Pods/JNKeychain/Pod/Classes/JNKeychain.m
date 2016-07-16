//
//  JNKeychain.m
//
//  Created by Jeremias Nunez on 5/10/13.
//  Copyright (c) 2013 Jeremias Nunez. All rights reserved.
//
//  jeremias.np@gmail.com

#define CHECK_OSSTATUS_ERROR(x) (x == noErr) ? YES : NO

#import "JNKeychain.h"

@interface JNKeychain ()

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)key forAccessGroup:(NSString *)group;

@end

@implementation JNKeychain

#pragma mark - Private

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)key forAccessGroup:(NSString *)group
{
    // see http://developer.apple.com/library/ios/#DOCUMENTATION/Security/Reference/keychainservices/Reference/reference.html
    
    NSMutableDictionary *keychainQuery = [NSMutableDictionary dictionaryWithDictionary:
                                          @{(__bridge id)kSecClass            : (__bridge id)kSecClassGenericPassword,
                                            (__bridge id)kSecAttrService      : key,
                                            (__bridge id)kSecAttrAccount      : key,
                                            (__bridge id)kSecAttrAccessible   : (__bridge id)kSecAttrAccessibleAfterFirstUnlock
                                            }];
    
    if (group != nil) {
        [keychainQuery setObject:[self getFullAppleIdentifier:group] forKey:(__bridge id)kSecAttrAccessGroup];
    }
    
    return keychainQuery;
}

/**
 Construct full Apple ID: <Bundle Seed ID> . <Bundle  Identifier>
 @return Apple full identifier
 */
+ (NSString *)getFullAppleIdentifier:(NSString *)bundleIdentifier
{
    NSString *bundleSeedIdentifier = [self getBundleSeedIdentifier];
    if (bundleSeedIdentifier != nil && [bundleIdentifier rangeOfString:bundleSeedIdentifier].location == NSNotFound) {
        bundleIdentifier = [NSString stringWithFormat:@"%@.%@", bundleSeedIdentifier, bundleIdentifier];
    }
    return bundleIdentifier;
}

#pragma mark - Public

+ (BOOL)saveValue:(id)value forKey:(NSString*)key forAccessGroup:(NSString *)group
{
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key forAccessGroup:group];
    // delete any previous value with this key (we could use SecItemUpdate but its unnecesarily more complicated)
    [self deleteValueForKey:key forAccessGroup:group];
    
    [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:value] forKey:(__bridge id)kSecValueData];
    
    OSStatus result = SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);
    
    return CHECK_OSSTATUS_ERROR(result);
}

+ (BOOL)saveValue:(id)value forKey:(NSString*)key
{
    return [self saveValue:value forKey:key forAccessGroup:nil];
}

#pragma mark -

+ (BOOL)deleteValueForKey:(NSString *)key forAccessGroup:(NSString *)group
{
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key forAccessGroup:group];
    
    OSStatus result = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    
    return CHECK_OSSTATUS_ERROR(result);
}

+ (BOOL)deleteValueForKey:(NSString *)key
{
    return [self deleteValueForKey:key forAccessGroup:nil];
}

#pragma mark -

+ (id)loadValueForKey:(NSString*)key forAccessGroup:(NSString *)group
{
    id value = nil;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key forAccessGroup:group];
    CFDataRef keyData = NULL;
    
    [keychainQuery setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [keychainQuery setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData) == noErr) {
        @try {
            value = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)keyData];
        }
        @catch (NSException *e) {
            NSLog(@"Unarchive of %@ failed: %@", key, e);
            value = nil;
        }
        @finally {}
    }
    
    if (keyData) {
        CFRelease(keyData);
    }
    
    return value;
}

+ (id)loadValueForKey:(NSString *)key
{
    return [self loadValueForKey:key forAccessGroup:nil];
}

#pragma mark -

+ (NSString *)getBundleSeedIdentifier
{
    static __strong NSString *bundleSeedIdentifier = nil;
    
    if (bundleSeedIdentifier == nil) {
        @synchronized(self) {
            if (bundleSeedIdentifier == nil) {
                NSString *_bundleSeedIdentifier = nil;
                NSDictionary *query = @{
                                        (__bridge id)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
                                        (__bridge id)kSecAttrAccount: @"bundleSeedID",
                                        (__bridge id)kSecAttrService: @"",
                                        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue
                                        };
                CFDictionaryRef result = nil;
                OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
                if (status == errSecItemNotFound) {
                    status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
                }
                if (status == errSecSuccess) {
                    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
                    NSArray *components = [accessGroup componentsSeparatedByString:@"."];
                    _bundleSeedIdentifier = [[components objectEnumerator] nextObject];
                    CFRelease(result);
                }
                if (_bundleSeedIdentifier != nil) {
                    bundleSeedIdentifier = [_bundleSeedIdentifier copy];
                }
            }
        }
    }
    
    return bundleSeedIdentifier;
}

@end