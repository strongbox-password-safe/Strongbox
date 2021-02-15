//
//  CredentialsStore.m
//  Strongbox
//
//  Created by Mark on 13/01/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//
// Reference Reading... Very helpful
//
// https://darthnull.org/security/2018/05/31/secure-enclave-ecies/
// https://gist.github.com/dschuetz/2ff54d738041fc888613f925a7708a06
// https://medium.com/@alx.gridnev/ios-keychain-using-secure-enclave-stored-keys-8f7c81227f4
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/storing_keys_in_the_keychain?language=objc
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/using_keys_for_encryption?language=objc

#import "SecretStore.h"



static NSString* const kKeyApplicationLabel = @"Strongbox-Credential-Store-Key";
static NSString* const kEncryptedBlobServiceName = @"Strongbox-Credential-Store";
static NSString* const kWrappedObjectObjectKey = @"theObject";
static NSString* const kWrappedObjectExpiryKey = @"expiry";
static NSString* const kWrappedObjectExpiryModeKey = @"expiryMode";

@interface SecretStore ()

@property BOOL _secureEnclaveAvailable;
@property NSMutableDictionary<NSString*, id> *ephemeralObjectStore;

@end

@implementation SecretStore

+ (instancetype)sharedInstance {
    static SecretStore *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SecretStore alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self._secureEnclaveAvailable = [SecretStore isSecureEnclaveAvailable];
        self.ephemeralObjectStore = @{}.mutableCopy;
    }
    
    return self;
}




- (BOOL)setSecureObject:(id)object forIdentifier:(NSString *)identifier {
    return [self setSecureObject:object forIdentifier:identifier expiryMode:kNeverExpires expiresAt:nil];
}

- (BOOL)setSecureEphemeralObject:(id)object forIdentifer:(NSString*)identifier {
    return [self setSecureObject:object forIdentifier:identifier expiryMode:kExpiresOnAppExitStoreSecretInMemoryOnly expiresAt:nil];
}

- (BOOL)setSecureObject:(id)object forIdentifier:(NSString *)identifier expiresAt:(NSDate *)expiresAt {
    if(expiresAt == nil) {
        return NO;
    }
    
    return [self setSecureObject:object forIdentifier:identifier expiryMode:kExpiresAtTime expiresAt:expiresAt];
}

- (BOOL)setSecureObject:(id)object forIdentifier:(NSString *)identifier expiryMode:(SecretExpiryMode)expiryMode expiresAt:(NSDate *)expiresAt {
    if ([SecretStore isUnsupportedOS]) {
        NSLog(@"SecretStore: Cannot set secure object - Unsupported OS...");
        return NO;
    }

    [self deleteSecureItem:identifier]; 

    if(object == nil) { 
        return YES;
    }
    
#if TARGET_OS_IPHONE
    if (@available(ios 10.0, *)) {
        return [self wrapSerializeAndEncryptObject:object forIdentifier:identifier expiryMode:expiryMode expiresAt:expiresAt];
    }
    else {
        return [self wrapAndSerializeObject:object forIdentifier:identifier expiryMode:expiryMode expiresAt:expiresAt];
    }
#else
    return [self wrapSerializeAndEncryptObject:object forIdentifier:identifier expiryMode:expiryMode expiresAt:expiresAt];
#endif
}

- (BOOL)wrapAndSerializeObject:(id)object forIdentifier:(NSString *)identifier expiryMode:(SecretExpiryMode)expiryMode expiresAt:(NSDate *)expiresAt {
    NSDictionary* wrapper = [self wrapObject:object expiryMode:expiryMode expiry:expiresAt identifier:identifier];
    NSData* clearData = [NSKeyedArchiver archivedDataWithRootObject:wrapper];

    if(![self storeKeychainBlob:identifier encrypted:clearData]) {
        NSLog(@"Error storing encrypted blob in Keychain...");
        return NO;
    }
    
    return YES;
}

- (BOOL)wrapSerializeAndEncryptObject:(id)object forIdentifier:(NSString *)identifier expiryMode:(SecretExpiryMode)expiryMode expiresAt:(NSDate *)expiresAt {
    SecAccessControlRef access = [SecretStore createAccessControl:self.secureEnclaveAvailable];
    if(!access) {
        return NO;
    }
    
    NSDictionary *attributes = [SecretStore createKeyPairAttributes:identifier accessControl:access requestSecureEnclaveStorage:self.secureEnclaveAvailable];
    
    
    
    CFErrorRef cfError = nil;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &cfError);
    if (!privateKey) {
        if (access)     { CFRelease(access);     }
        
        NSLog(@"Error creating AccessControl: [%@]", (__bridge NSError *)cfError);
        return NO;
    }

    
    
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (!publicKey) {
        if (privateKey) { CFRelease(privateKey); }
        if (access)     { CFRelease(access);     }

        NSLog(@"Error getting match public key....");
        return NO;
    }

    SecKeyAlgorithm algorithm = [SecretStore algorithm];
    if(!SecKeyIsAlgorithmSupported(publicKey, kSecKeyOperationTypeEncrypt, algorithm)) {
        if (privateKey) { CFRelease(privateKey); }
        if (publicKey)  { CFRelease(publicKey);  }
        if (access)     { CFRelease(access);     }

        NSLog(@"Error algorithm is not support....");
        return NO;
    }

    NSDictionary* wrapper = [self wrapObject:object expiryMode:expiryMode expiry:expiresAt identifier:identifier];
    NSData* clearData = [NSKeyedArchiver archivedDataWithRootObject:wrapper];

    CFDataRef cipherText = SecKeyCreateEncryptedData(publicKey, algorithm, (CFDataRef)clearData, &cfError);
    if(!cipherText) {
        if (privateKey) { CFRelease(privateKey); }
        if (publicKey)  { CFRelease(publicKey);  }
        if (access)     { CFRelease(access);     }

        NSLog(@"Error encrypting.... [%@]", (__bridge NSError *)cfError);
        return NO;
    }
        
    if(![self storeKeychainBlob:identifier encrypted:(__bridge NSData*)cipherText]) {
        if (privateKey) { CFRelease(privateKey); }
        if (publicKey)  { CFRelease(publicKey);  }
        if (access)     { CFRelease(access);     }
        if (cipherText) { CFRelease(cipherText); }

        NSLog(@"Error storing encrypted blob in Keychain...");
        return NO;
    }
    
    if (privateKey) { CFRelease(privateKey); }
    if (publicKey)  { CFRelease(publicKey);  }
    if (access)     { CFRelease(access);     }
    if (cipherText) { CFRelease(cipherText); }

    return YES;
}

- (id)getSecureObject:(NSString *)identifier {
    return [self getSecureObject:identifier expired:nil];
}

- (id)getSecureObject:(NSString *)identifier expired:(BOOL*)expired {
    if ([SecretStore isUnsupportedOS]) {
        NSLog(@"Unsupported OS...");
        return nil;
    }

    NSDictionary* wrapped = [self getWrappedObject:identifier];
    if(wrapped == nil) {

        return nil;
    }

    NSNumber* expiryModeNumber = wrapped[kWrappedObjectExpiryModeKey];

    SecretExpiryMode expiryMode = expiryModeNumber.integerValue;
    if(expiryMode == kExpiresOnAppExitStoreSecretInMemoryOnly) {
        id object = self.ephemeralObjectStore[identifier];
        
        if(object == nil) {
            NSLog(@"Ephemeral Entry was present but expired... Cleaning up from secure store...");

            if(expired) {
                *expired = YES;
            }
            
            [self deleteSecureItem:identifier];
            
            return nil;
        }
        
        return object;
    }
    else if(expiryMode == kExpiresAtTime) {
        NSDate* expiry = wrapped[kWrappedObjectExpiryKey];
        
        if([self entryIsExpired:expiry]) {
            NSLog(@"Entry is present but expired [%@]... Cleaning up from secure store...", expiry);

            if(expired) {
                *expired = YES;
            }
            
            [self deleteSecureItem:identifier];
            
            return nil;
        }
        else {
            return wrapped[kWrappedObjectObjectKey];
        }
    }
    else {
        return wrapped[kWrappedObjectObjectKey];
    }
}
    
- (BOOL)setSecureString:(NSString *)string forIdentifier:(NSString *)identifier {
    return [self setSecureObject:string forIdentifier:identifier];
}

- (NSString *)getSecureString:(NSString *)identifier {
    return [self getSecureObject:identifier];
}

- (void)deleteSecureItem:(NSString *)identifier {
    if ([SecretStore isUnsupportedOS]) {
        NSLog(@"Unsupported OS...");
        return;
    }

    [self deleteKeychainBlob:identifier];
    [self.ephemeralObjectStore removeObjectForKey:identifier];
    
    NSDictionary* query = [SecretStore getPrivateKeyQuery:identifier];
    SecItemDelete((__bridge CFDictionaryRef)query);
}



- (SecretExpiryMode)getSecureObjectExpiryMode:(NSString *)identifier {
    if ([SecretStore isUnsupportedOS]) {
        NSLog(@"Unsupported OS...");
        return kUnknown;
    }

    NSDictionary* wrapped = [self getWrappedObject:identifier];
    if(wrapped == nil) {
        return kUnknown;
    }

    NSNumber* expiryModeNumber = wrapped[kWrappedObjectExpiryModeKey];
    return (SecretExpiryMode)expiryModeNumber.integerValue;
}

- (NSDate *)getSecureObjectExpiryDate:(NSString *)identifier {
    if ([SecretStore isUnsupportedOS]) {
        NSLog(@"Unsupported OS...");
        return nil;
    }

    NSDictionary* wrapped = [self getWrappedObject:identifier];
    if(wrapped == nil) {
        return nil;
    }

    NSNumber* expiryModeNumber = wrapped[kWrappedObjectExpiryModeKey];
    SecretExpiryMode mode = expiryModeNumber.integerValue;

    if(mode == kExpiresAtTime) {
        return wrapped[kWrappedObjectExpiryKey];
    }
    
    return nil;
}



+ (CFStringRef)accessibility {
    return kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
}

+ (CFStringRef)keyType {
#if TARGET_OS_IPHONE
    if (@available(iOS 10.0, *)) {
        return kSecAttrKeyTypeECSECPrimeRandom;
    }
    else {
        return kSecAttrKeyTypeEC;
    }
#else
    if (@available(macOS 10.12, *)) {
        return kSecAttrKeyTypeECSECPrimeRandom;
    }
    else {
        return kSecAttrKeyTypeEC;
    }
#endif
}

+ (SecKeyAlgorithm)algorithm {
#if TARGET_OS_IPHONE
    if (@available(iOS 11.0, *)) {
        return kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM;
    }
    else {
        return kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM;
    }
#else
    if (@available(macOS 10.13, *)) {
        return kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM;
    }
    else {
        return kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM;
    }
#endif
}

- (BOOL)secureEnclaveAvailable {
    return self._secureEnclaveAvailable;
}

+ (BOOL)isUnsupportedOS {
#if TARGET_OS_OSX
    if (@available(macOS 10.12, *)) { } else {
        NSLog(@"Mac OSX < 10.12 is not supported by the Strongbox Secret Store");
        return YES;
    }
#endif
    
    return NO;
}

+ (BOOL)isSecureEnclaveAvailable {
    if (TARGET_OS_SIMULATOR != 0) { 
        NSLog(@"Secure Enclave not available on Simulator");
        return NO;
    }

    if ([SecretStore isUnsupportedOS]) {
        NSLog(@"Unsupported OS...");
        return NO;
    }

    if (@available(iOS 10.0, *)) { } else {
        NSLog(@"Secure Enclave unavailable on iOS < 10.0");
        return NO;
    }
    
    

    SecAccessControlRef accessControl = [SecretStore createAccessControl:YES];
    if(!accessControl) {
        return NO;
    }
    
    NSString* identifier = NSUUID.UUID.UUIDString;
    
    NSDictionary* attributes = [SecretStore createKeyPairAttributes:identifier accessControl:accessControl requestSecureEnclaveStorage:YES];
    
    

    CFErrorRef cfError = nil;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &cfError);
    BOOL available = privateKey != nil;

    if(privateKey) {
        NSDictionary* query = [SecretStore getPrivateKeyQuery:identifier];
        SecItemDelete((__bridge CFDictionaryRef)query);
        CFRelease(privateKey);
    }
    CFRelease(accessControl);

    if(!available) {
        NSLog(@"WARNWARN: SECURE ENCLAVE NOT AVAILABLE");
    }
    else {
        NSLog(@"OK. Secure Enclave available on device.");
    }
    
    return available;
}

+ (SecAccessControlRef)createAccessControl:(BOOL)requestSecureEnclaveStorage {
    CFErrorRef cfError = nil;

    SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                 [SecretStore accessibility],
                                                                 requestSecureEnclaveStorage ? kSecAccessControlPrivateKeyUsage : 0L,
                                                                 &cfError);
    
    if(!access) {
        NSLog(@"Error creating AccessControl: [%@]", (__bridge NSError *)cfError);
        return nil;
    }
    
    return access;
}

+ (NSDictionary*)createKeyPairAttributes:(NSString*)identifier
                           accessControl:(SecAccessControlRef)accessControl
             requestSecureEnclaveStorage:(BOOL)requestSecureEnclaveStorage {
    NSDictionary* attributes =
        @{ (id)kSecAttrKeyType:             (id)[SecretStore keyType],
           (id)kSecAttrKeySizeInBits:       @256,
           (id)kSecAttrEffectiveKeySize :   @256,
           (id)kSecAttrApplicationLabel :   kKeyApplicationLabel,
           (id)kSecAttrTokenID:             (id)kSecAttrTokenIDSecureEnclave,
           (id)kSecPrivateKeyAttrs:
             @{ (id)kSecAttrIsPermanent:    @YES,
                (id)kSecAttrApplicationTag: [identifier dataUsingEncoding:NSUTF8StringEncoding],
                (id)kSecAttrAccessControl:  (__bridge id)accessControl,
              },
         };

    if(!requestSecureEnclaveStorage) {
        NSMutableDictionary* foo = attributes.mutableCopy;
        [foo removeObjectForKey:(id)kSecAttrTokenID];
        attributes = foo.copy;
    }

    return attributes;
}

+ (NSDictionary*)getPrivateKeyQuery:(NSString*)identifier {
    return   @{ (id)kSecClass :                 (id)kSecClassKey,
                (id)kSecAttrKeyType :           (id)[SecretStore keyType],
                (id)kSecAttrKeySizeInBits:      @256,
                (id)kSecAttrEffectiveKeySize :  @256,
                (id)kSecAttrApplicationLabel :  kKeyApplicationLabel,
                (id)kSecAttrApplicationTag :    [identifier dataUsingEncoding:NSUTF8StringEncoding],
                (id)kSecReturnRef :             @YES
    };
}

- (NSDictionary*)decryptWrappedObject:(NSData*)encrypted privateKey:(SecKeyRef)privateKey {
    CFErrorRef cfError = nil;
    SecKeyAlgorithm algorithm = [SecretStore algorithm];
    CFDataRef pt = SecKeyCreateDecryptedData(privateKey, algorithm, (CFDataRef)encrypted, &cfError);
    
    if(!pt) {
        NSLog(@"Could not decrypt...");
        return nil;
    }
    
    NSDictionary *wrapped = nil;
    @try {
        wrapped = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)pt];
    }
    @catch (NSException *e) {
        NSLog(@"Error Ubarchiving: %@", e);
    }
    @finally {}
    
    if (pt) {
        CFRelease(pt);
    }
    
    return wrapped;
}

- (id)getWrappedObject:(NSString *)identifier {
    NSData* keychainBlob = [self getKeychainBlob:identifier];
    if(!keychainBlob) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{ 

            [self deleteSecureItem:identifier];
        });
        return nil;
    }
    
#if TARGET_OS_IPHONE
    if (@available(ios 10.0, *)) {
        return [self decryptAndDeserializeKeychainBlob:keychainBlob identifier:identifier];
    }
    else {
        return [self deserializeKeychainBlob:keychainBlob identifier:identifier];
    }
#else
    return [self decryptAndDeserializeKeychainBlob:keychainBlob identifier:identifier];
#endif
}

- (id)decryptAndDeserializeKeychainBlob:(NSData*)encrypted identifier:(NSString *)identifier {
    NSDictionary* query = [SecretStore getPrivateKeyQuery:identifier];
    
    CFTypeRef pk;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &pk);

    if(status != errSecSuccess) {
       
       return nil;
    }

    SecKeyAlgorithm algorithm = [SecretStore algorithm];
    SecKeyRef privateKey = (SecKeyRef)pk;
    if(!SecKeyIsAlgorithmSupported(privateKey, kSecKeyOperationTypeDecrypt, algorithm)) {
       NSLog(@"Error algorithm is not available....");
       return nil;
    }
    
    NSDictionary * wrapped = [self decryptWrappedObject:encrypted privateKey:privateKey];
    
    if (privateKey) {
        CFRelease(privateKey);
    }
    
    if(!wrapped) {
        NSLog(@"Could not unwrap secure item. Cleaning it up.");
        [self deleteSecureItem:identifier];
        return nil;
    }
    
    return wrapped;
}

- (id)deserializeKeychainBlob:(NSData*)plaintext identifier:(NSString *)identifier {
    NSDictionary *wrapped = nil;
    @try {
        wrapped = [NSKeyedUnarchiver unarchiveObjectWithData:plaintext];
    }
    @catch (NSException *e) {
        NSLog(@"Error Ubarchiving: %@", e);
    }
    @finally {}

    if(!wrapped) {
        NSLog(@"Could not unwrap secure item. Cleaning it up.");
        [self deleteSecureItem:identifier];
        return nil;
    }
    
    return wrapped;
}




- (NSDictionary*)wrapObject:(id)object expiryMode:(SecretExpiryMode)expiryMode expiry:(NSDate*_Nullable)expiry identifier:(NSString*)identifier {
    NSMutableDictionary *wrapped = @{
        kWrappedObjectExpiryModeKey : @(expiryMode)
    }.mutableCopy;
    
    if(expiryMode == kExpiresAtTime) {
        wrapped[kWrappedObjectExpiryKey] = expiry;
    }

    if(expiryMode != kExpiresOnAppExitStoreSecretInMemoryOnly) {
        wrapped[kWrappedObjectObjectKey] = object;
    }
    else {
        self.ephemeralObjectStore[identifier] = object;
    }
    
    return wrapped;
}

- (BOOL)storeKeychainBlob:(NSString*)identifier encrypted:(NSData*)encrypted {
    NSDictionary* searchQuery = [self getBlobQuery:identifier];
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)searchQuery, nil);
    
    if (status == errSecSuccess) {
        NSMutableDictionary* query = [[NSMutableDictionary alloc]init];
        
        [query setObject:encrypted forKey:(__bridge id)kSecValueData];
        [query setObject:(__bridge id)[SecretStore accessibility] forKey:(__bridge id)kSecAttrAccessible];
        
        status = SecItemUpdate((__bridge CFDictionaryRef)(searchQuery), (__bridge CFDictionaryRef)(query));
    }
    else if(status == errSecItemNotFound) {
        NSMutableDictionary* query = [self getBlobQuery:identifier];
        
        [query setObject:encrypted forKey:(__bridge id)kSecValueData];
        [query setObject:(__bridge id)[SecretStore accessibility] forKey:(__bridge id)kSecAttrAccessible];

        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    
    if (status != errSecSuccess) {
        NSLog(@"Error storing encrypted blob: %d", (int)status);
    }
 
    return (status == errSecSuccess);
}

- (NSData*)getKeychainBlob:(NSString*)identifier {

        
    NSMutableDictionary *query = [self getBlobQuery:identifier];
    
    [query setObject:@YES forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);




    
    if (status != errSecSuccess) {
        return nil;
    }

    return (__bridge_transfer NSData *)result;
}

- (void)deleteKeychainBlob:(NSString*)identifier {
    NSMutableDictionary *query = [self getBlobQuery:identifier];
    SecItemDelete((__bridge CFDictionaryRef)query);
}

- (NSMutableDictionary*)getBlobQuery:(NSString*)identifier {
    NSString* blobId = [NSString stringWithFormat:@"strongbox-credential-store-encrypted-blob-%@", identifier];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [dictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [dictionary setObject:kEncryptedBlobServiceName forKey:(__bridge id)kSecAttrService];
    [dictionary setObject:blobId forKey:(__bridge id)kSecAttrAccount];
    [dictionary setObject:@NO forKey:(__bridge id)(kSecAttrSynchronizable)]; 
    
#if TARGET_OS_OSX
    if (@available(macOS 10.15, *)) {
        [dictionary setObject:@YES forKey:(__bridge id)(kSecUseDataProtectionKeychain)];
    }
#endif
    
    return dictionary;
}

- (BOOL)entryIsExpired:(NSDate*)expiry {
    return ([expiry timeIntervalSinceNow] < 0);
}

@end
