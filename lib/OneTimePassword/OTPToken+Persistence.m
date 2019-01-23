//
//  OTPToken+Persistence.m
//  Authenticator
//
//  Copyright (c) 2013 Matt Rubin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "OTPToken+Persistence.h"
#import "OTPToken+Serialization.h"
@import ObjectiveC.runtime;


static NSString *const kOTPService = @"me.mattrubin.authenticator.token";


@interface OTPToken ()

@property (nonatomic, strong) NSData *keychainItemRef;

@end


@implementation OTPToken (Persistence)

+ (instancetype)tokenWithKeychainItemRef:(NSData *)keychainItemRef
{
    OTPToken *token = nil;
    NSDictionary *result = [self keychainItemForPersistentRef:keychainItemRef];
    if (result) {
        token = [self tokenWithKeychainDictionary:result];
    }
    return token;
}

+ (NSArray *)allTokensInKeychain
{
    NSArray *keychainItems = [self allKeychainItems];
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSDictionary *keychainDict in keychainItems) {
        OTPToken *token = [self tokenWithKeychainDictionary:keychainDict];
        if (token)
            [tokens addObject:token];
    }
    return tokens;
}

+ (instancetype)tokenWithKeychainDictionary:(NSDictionary *)keychainDictionary
{
    NSData *urlData = keychainDictionary[(__bridge id)kSecAttrGeneric];
    NSData *secretData = keychainDictionary[(__bridge id)kSecValueData];
    NSString *urlString = [[NSString alloc] initWithData:urlData
                                                encoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:urlString];
    OTPToken *token = [self tokenWithURL:url secret:secretData];
    token.keychainItemRef = keychainDictionary[(__bridge id)(kSecValuePersistentRef)];
    return token;
}


#pragma mark -

- (NSData *)keychainItemRef
{
    return objc_getAssociatedObject(self, @selector(keychainItemRef));
}

- (void)setKeychainItemRef:(NSData *)keychainItemRef
{
    objc_setAssociatedObject(self, @selector(keychainItemRef), keychainItemRef, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isInKeychain
{
    return !!self.keychainItemRef;
}

- (BOOL)saveToKeychain
{
    NSData *urlData = [self.url.absoluteString dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableDictionary *attributes = [@{(__bridge id)kSecAttrGeneric: urlData} mutableCopy];

    if (self.isInKeychain) {
        return [OTPToken updateKeychainItemForPersistentRef:self.keychainItemRef
                                             withAttributes:attributes];
    } else {
        attributes[(__bridge id)kSecValueData] = self.secret;
        attributes[(__bridge id)kSecAttrService] = kOTPService;

        NSData *persistentRef = [OTPToken addKeychainItemWithAttributes:attributes];

        self.keychainItemRef = persistentRef;
        return !!persistentRef;
    }
}

- (BOOL)removeFromKeychain
{
    if (!self.isInKeychain) return NO;

    BOOL success = [OTPToken deleteKeychainItemForPersistentRef:self.keychainItemRef];

    if (success) {
        [self setKeychainItemRef:nil];
    }
    return success;
}


#pragma mark - Keychain Items

+ (NSDictionary *)keychainItemForPersistentRef:(NSData *)persistentRef
{
    if (!persistentRef) return nil;

    NSDictionary *queryDict = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecValuePersistentRef: persistentRef,
                                (__bridge id)kSecReturnPersistentRef: (id)kCFBooleanTrue,
                                (__bridge id)kSecReturnAttributes: (id)kCFBooleanTrue,
                                (__bridge id)kSecReturnData: (id)kCFBooleanTrue
                                };

    CFTypeRef result = NULL;
    OSStatus resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)(queryDict),
                                              &result);

    return (resultCode == errSecSuccess) ? (__bridge NSDictionary *)(result) : nil;
}

+ (NSArray *)allKeychainItems
{
    NSDictionary *queryDict = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
                                (__bridge id)kSecReturnPersistentRef: (id)kCFBooleanTrue,
                                (__bridge id)kSecReturnAttributes: (id)kCFBooleanTrue,
                                (__bridge id)kSecReturnData: (id)kCFBooleanTrue
                                };

    CFTypeRef result = NULL;
    OSStatus resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)(queryDict),
                                              &result);

    return (resultCode == errSecSuccess) ? (__bridge NSArray *)(result) : nil;
}

+ (NSData *)addKeychainItemWithAttributes:(NSDictionary *)attributes
{
    NSMutableDictionary *mutableAttributes = [attributes mutableCopy];
    mutableAttributes[(__bridge __strong id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    mutableAttributes[(__bridge __strong id)kSecReturnPersistentRef] = (__bridge id)kCFBooleanTrue;
    // Set a random string for the account name.
    // We never query by or display this value, but the keychain requires it to be unique.
    if (!mutableAttributes[(__bridge __strong id)kSecAttrAccount])
        mutableAttributes[(__bridge __strong id)kSecAttrAccount] = [[NSUUID UUID] UUIDString];

    CFTypeRef result = NULL;
    OSStatus resultCode = SecItemAdd((__bridge CFDictionaryRef)(mutableAttributes),
                                     &result);

    return (resultCode == errSecSuccess) ? (__bridge NSData *)(result) : nil;
}

+ (BOOL)updateKeychainItemForPersistentRef:(NSData *)persistentRef withAttributes:(NSDictionary *)attributesToUpdate
{
    NSDictionary *queryDict = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecValuePersistentRef: persistentRef,
                                };

    OSStatus resultCode = SecItemUpdate((__bridge CFDictionaryRef)(queryDict),
                                        (__bridge CFDictionaryRef)(attributesToUpdate));

    return (resultCode == errSecSuccess);
}

+ (BOOL)deleteKeychainItemForPersistentRef:(NSData *)persistentRef
{
    NSDictionary *queryDict = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecValuePersistentRef: persistentRef,
                                };

    OSStatus resultCode = SecItemDelete((__bridge CFDictionaryRef)(queryDict));

    return (resultCode == errSecSuccess);
}

@end
