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
#import "ConcurrentMutableDictionary.h"
#import "Utils.h"



static NSString* const kKeyApplicationLabel = @"Strongbox-Credential-Store-Key";
static NSString* const kEncryptedBlobServiceName = @"Strongbox-Credential-Store";
static NSString* const kWrappedObjectObjectKey = @"theObject";
static NSString* const kWrappedObjectExpiryKey = @"expiry";
static NSString* const kWrappedObjectExpiryModeKey = @"expiryMode";
static NSString* const kAccountPrefix = @"strongbox-credential-store-encrypted-blob-";

@interface SecretStore ()

@property BOOL _secureEnclaveAvailable;
@property ConcurrentMutableDictionary<NSString*, id> *ephemeralObjectStore;

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
        self.ephemeralObjectStore = ConcurrentMutableDictionary.mutableDictionary;
    }
    
    return self;
}




- (id)getSecureObject:(NSString *)identifier {
    return [self getSecureObject:identifier error:nil];
}

- (NSString *)getSecureString:(NSString *)identifier {
    return [self getSecureObject:identifier error:nil];
}

- (NSString *)getSecureString:(NSString *)identifier error:(NSError**)error {
    return [self getSecureObject:identifier error:error];
}

- (id)getSecureObject:(NSString *)identifier error:(NSError**)error {
    return [self getSecureObject:identifier expired:nil error:error];
}

- (id)getSecureObject:(NSString *)identifier expired:(BOOL*)expired {
    return [self getSecureObject:identifier expired:expired error:nil];
}

- (id)getSecureObject:(NSString *)identifier expired:(BOOL*)expired error:(NSError**)error {
    

    if(expired) {
        *expired = NO;
    }
    
    NSDictionary* wrapped = [self getWrappedObject:identifier error:error];
    if(wrapped == nil) {
        if ( error ) {
             slog(@"🔴 Could not get wrapped object. [%@]. Error = [%@]", identifier, *error);
        }
        
        return nil;
    }

    NSNumber* expiryModeNumber = wrapped[kWrappedObjectExpiryModeKey];

    SecretExpiryMode expiryMode = expiryModeNumber.integerValue;
    if ( expiryMode == kExpiresOnAppExitStoreSecretInMemoryOnly ) {
        id object = self.ephemeralObjectStore[identifier];
        
        if(object == nil) {
            slog(@"Ephemeral Entry was present but expired... Cleaning up from secure store...");

            if(expired) {
                *expired = YES;
            }
            
            [self deleteSecureItem:identifier];
            
            return nil;
        }
        
        return [self decryptAndDeserializeData:object identifier:identifier];
    }
    else if(expiryMode == kExpiresAtTime) {
        NSDate* expiry = wrapped[kWrappedObjectExpiryKey];
        
        if ( [self entryIsExpired:expiry] ) {
            slog(@"entryIsExpired [%@]... Cleaning up from secure store...", expiry);

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
    

    [self deleteSecureItem:identifier]; 

    if(object == nil) { 
        return YES;
    }
    
    return [self wrapSerializeAndEncryptObject:object forIdentifier:identifier expiryMode:expiryMode expiresAt:expiresAt];
}

- (BOOL)wrapAndSerializeObject:(id)object forIdentifier:(NSString *)identifier expiryMode:(SecretExpiryMode)expiryMode expiresAt:(NSDate *)expiresAt {
    NSDictionary* wrapper = [self wrapObject:object expiryMode:expiryMode expiry:expiresAt identifier:identifier];
    NSData* clearData = [NSKeyedArchiver archivedDataWithRootObject:wrapper];

    if(![self storeKeychainBlob:identifier encrypted:clearData]) {
        slog(@"Error storing encrypted blob in Keychain...");
        return NO;
    }
    
    return YES;
}

- (BOOL)wrapSerializeAndEncryptObject:(id)object
                        forIdentifier:(NSString *)identifier
                           expiryMode:(SecretExpiryMode)expiryMode
                            expiresAt:(NSDate *)expiresAt {
    SecAccessControlRef access = [SecretStore createAccessControl:self.secureEnclaveAvailable];
    if(!access) {
        return NO;
    }
    
    NSDictionary *attributes = [SecretStore createKeyPairAttributes:identifier
                                                      accessControl:access
                                        requestSecureEnclaveStorage:self.secureEnclaveAvailable];
    
    
    
    CFErrorRef cfError = nil;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &cfError);
    if (!privateKey) {
        if (access)     { CFRelease(access);     }
        
        slog(@"Error creating AccessControl: [%@]", (__bridge NSError *)cfError);
        return NO;
    }

    
    
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if ( !publicKey ) {
        if (privateKey) { CFRelease(privateKey); }
        if (access)     { CFRelease(access);     }

        slog(@"Error getting match public key....");
        return NO;
    }

    SecKeyAlgorithm algorithm = [SecretStore algorithm];
    if( !SecKeyIsAlgorithmSupported(publicKey, kSecKeyOperationTypeEncrypt, algorithm) ) {
        if (privateKey) { CFRelease(privateKey); }
        if (publicKey)  { CFRelease(publicKey);  }
        if (access)     { CFRelease(access);     }

        slog(@"Error algorithm is not support....");
        return NO;
    }

    NSDictionary* wrapper = [self wrapObject:object expiryMode:expiryMode expiry:expiresAt identifier:identifier];
    NSData* clearData = [NSKeyedArchiver archivedDataWithRootObject:wrapper];

    CFDataRef cipherText = SecKeyCreateEncryptedData(publicKey, algorithm, (CFDataRef)clearData, &cfError);
    if(!cipherText) {
        if (privateKey) { CFRelease(privateKey); }
        if (publicKey)  { CFRelease(publicKey);  }
        if (access)     { CFRelease(access);     }

        slog(@"Error encrypting.... [%@]", (__bridge NSError *)cfError);
        return NO;
    }
        
    if(![self storeKeychainBlob:identifier encrypted:(__bridge NSData*)cipherText]) {
        if (privateKey) { CFRelease(privateKey); }
        if (publicKey)  { CFRelease(publicKey);  }
        if (access)     { CFRelease(access);     }
        if (cipherText) { CFRelease(cipherText); }

        slog(@"Error storing encrypted blob in Keychain...");
        return NO;
    }
    
    

    if ( expiryMode == kExpiresOnAppExitStoreSecretInMemoryOnly ) {
        NSData* clearDataObject = [NSKeyedArchiver archivedDataWithRootObject:object];
        CFDataRef cipherTextMemOnly = SecKeyCreateEncryptedData(publicKey, algorithm, (CFDataRef)clearDataObject, &cfError);
        if(!cipherTextMemOnly) {
            if (privateKey) { CFRelease(privateKey); }
            if (publicKey)  { CFRelease(publicKey);  }
            if (access)     { CFRelease(access);     }
            if (cipherText) { CFRelease(cipherText); }

            slog(@"Error encrypting memory only object... [%@]", (__bridge NSError *)cfError);
            return NO;
        }


        self.ephemeralObjectStore[identifier] = (__bridge NSData *)cipherTextMemOnly;
    }

    
    if (privateKey) { CFRelease(privateKey); }
    if (publicKey)  { CFRelease(publicKey);  }
    if (access)     { CFRelease(access);     }
    if (cipherText) { CFRelease(cipherText); }

    return YES;
}



- (void)factoryReset {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [dictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [dictionary setObject:kEncryptedBlobServiceName forKey:(__bridge id)kSecAttrService];
    [dictionary setObject:(__bridge id)kSecMatchLimitAll forKey:(__bridge id)kSecMatchLimit];
    [dictionary setObject:@YES forKey:(__bridge id)kSecReturnAttributes];
    [dictionary setObject:@NO forKey:(__bridge id)(kSecAttrSynchronizable)]; 
    
#if TARGET_OS_OSX
    [dictionary setObject:@YES forKey:(__bridge id)(kSecUseDataProtectionKeychain)];
#endif
    
    CFArrayRef result = nil;
    OSStatus ret = SecItemCopyMatching((__bridge CFDictionaryRef)dictionary, (CFTypeRef*)&result);
    if ( ret == errSecSuccess ) {
        NSArray<NSDictionary *>* array = (__bridge NSArray*)result;
        
        for ( NSDictionary* dict in array ) {
            NSString* identifier = dict[(__bridge id)kSecAttrAccount];
            
            if ( [identifier hasPrefix:kAccountPrefix] ) {
                identifier = [identifier substringFromIndex:kAccountPrefix.length];
                [self deleteSecureItem:identifier];
            }
        }
    }
}

- (void)deleteSecureItem:(NSString *)identifier {
    [self deleteKeychainBlob:identifier];
    [self.ephemeralObjectStore removeObjectForKey:identifier];
    
    NSDictionary* query = [SecretStore getPrivateKeyQuery:identifier limit1Match:NO];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if ( status != errSecSuccess && status != errSecItemNotFound ) {
        slog(@"Error Deleting Private Key: [%d]", (int)status);
    }
}



- (SecretExpiryMode)getSecureObjectExpiryMode:(NSString *)identifier {
    NSError* error;
    NSDictionary* wrapped = [self getWrappedObject:identifier error:&error];
    if(wrapped == nil) {
        return kUnknown;
    }

    NSNumber* expiryModeNumber = wrapped[kWrappedObjectExpiryModeKey];
    return (SecretExpiryMode)expiryModeNumber.integerValue;
}

- (NSDate *)getSecureObjectExpiryDate:(NSString *)identifier {
    NSError* error;
    NSDictionary* wrapped = [self getWrappedObject:identifier error:&error];
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
    return kSecAttrKeyTypeECSECPrimeRandom;
}

+ (SecKeyAlgorithm)algorithm {
    return kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM;
}

- (BOOL)secureEnclaveAvailable {
    return self._secureEnclaveAvailable;
}

+ (BOOL)isSecureEnclaveAvailable {
    if (TARGET_OS_SIMULATOR != 0) { 

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

    if ( privateKey ) {
        NSDictionary* query = [SecretStore getPrivateKeyQuery:identifier limit1Match:NO];
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        if ( status != errSecSuccess ) {
            slog(@"Error Deleting Private Key: [%d]", (int)status);
        }
        CFRelease(privateKey);
    }
    CFRelease(accessControl);

    if(!available) {
        slog(@"WARNWARN: SECURE ENCLAVE NOT AVAILABLE");
    }
    else {

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
        slog(@"Error creating AccessControl: [%@]", (__bridge NSError *)cfError);
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

    if ( !requestSecureEnclaveStorage ) {
        NSMutableDictionary* foo = attributes.mutableCopy;
        [foo removeObjectForKey:(id)kSecAttrTokenID];
        attributes = foo.copy;
    }

    return attributes;
}



+ (NSDictionary*)getPrivateKeyQuery:(NSString*)identifier limit1Match:(BOOL)limit1Match {
    NSMutableDictionary* ret = [NSMutableDictionary dictionaryWithDictionary:@{
        (id)kSecClass :                 (id)kSecClassKey,
        (id)kSecAttrKeyType :           (id)[SecretStore keyType],
        (id)kSecAttrKeySizeInBits:      @256,
        (id)kSecAttrEffectiveKeySize :  @256,
        (id)kSecAttrApplicationLabel :  kKeyApplicationLabel,
        (id)kSecAttrApplicationTag :    [identifier dataUsingEncoding:NSUTF8StringEncoding],
        (id)kSecReturnRef :             @YES
    }];
    
    if ( limit1Match ) {
        ret[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    }
    
    return ret;
}

- (NSDictionary*)getWrappedObject:(NSString *)identifier error:(NSError**)error {
    BOOL itemNotFound;

    NSData* keychainBlob = [self getKeychainBlob:identifier itemNotFound:&itemNotFound error:error];
    
    if ( !keychainBlob ) {
        if ( itemNotFound ) {
            return nil;
        }
        else {
            if ( error ) {
                slog(@"🔴 Could not get encrypted blob but it appears to be present [%@] - Error = [%@]", identifier, *error);
            }
            else {
                slog(@"🔴 Could not get encrypted blob but it appears to be present [%@]", identifier);
            }
            
            return nil;
        }
    }
    
    return [self decryptAndDeserializeData:keychainBlob identifier:identifier];
}

- (id)decryptAndDeserializeData:(NSData*)encrypted identifier:(NSString *)identifier {


    NSDictionary* query = [SecretStore getPrivateKeyQuery:identifier limit1Match:YES];

    CFTypeRef pk;
    

    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &pk);


    if( status != errSecSuccess ) {
        slog(@"Error getting key.... status = [%d]", (int)status);
        return nil;
    }








    SecKeyAlgorithm algorithm = [SecretStore algorithm];
    SecKeyRef privateKey = (SecKeyRef)pk;
    if(!SecKeyIsAlgorithmSupported(privateKey, kSecKeyOperationTypeDecrypt, algorithm)) {
       slog(@"Error algorithm is not available....");
       return nil;
    }
    
    id wrapped = [self decryptWrappedObject:encrypted privateKey:privateKey];
    
    if ( privateKey ) {
        CFRelease(privateKey);
    }
    
    if ( !wrapped ) {
        slog(@"Could not unwrap secure item. Cleaning it up.");
        [self deleteSecureItem:identifier];
        return nil;
    }
    

    




    return wrapped;
}

- (NSDictionary*)deserializeKeychainBlob:(NSData*)plaintext identifier:(NSString *)identifier {
    NSDictionary *wrapped = nil;
    @try {
        wrapped = [NSKeyedUnarchiver unarchiveObjectWithData:plaintext];
    }
    @catch (NSException *e) {
        slog(@"Error Ubarchiving: %@", e);
    }
    @finally {}

    if(!wrapped) {
        slog(@"Could not unwrap secure item. Cleaning it up.");
        [self deleteSecureItem:identifier];
        return nil;
    }
    
    return wrapped;
}

- (id)decryptWrappedObject:(NSData*)encrypted privateKey:(SecKeyRef)privateKey {
    CFErrorRef cfError = nil;
    SecKeyAlgorithm algorithm = [SecretStore algorithm];
    CFDataRef pt = SecKeyCreateDecryptedData(privateKey, algorithm, (CFDataRef)encrypted, &cfError);
    
    if(!pt) {
        slog(@"Could not decrypt...");
        return nil;
    }
    
    id wrapped = nil;
    @try {
        wrapped = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)pt];
    }
    @catch (NSException *e) {
        slog(@"Error Unarchiving: %@", e);
    }
    @finally {}
    
    if ( pt ) {
        CFRelease(pt);
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
        slog(@"Error storing encrypted blob: %d", (int)status);
    }
 
    return (status == errSecSuccess);
}

- (NSData*)getKeychainBlob:(NSString*)identifier itemNotFound:(BOOL*)itemNotFound error:(NSError**)error {
    NSTimeInterval startDecryptTime = NSDate.timeIntervalSinceReferenceDate;
        
    NSMutableDictionary *query = [self getBlobQuery:identifier];
    
    [query setObject:@YES forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    CFTypeRef result = NULL;
    

    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    
    double perf = NSDate.timeIntervalSinceReferenceDate - startDecryptTime;
    if ( perf > 0.5f ) {
        slog(@"====================================== PERF ======================================");
        slog(@"getKeychainBlob (query2) [%@] [%f] seconds", identifier, perf);
        slog(@"====================================== PERF ======================================");
    }
    
    if ( status == errSecSuccess ) {
        *itemNotFound = NO;
        return (__bridge_transfer NSData *)result;
    }
    else if (status == errSecItemNotFound) {
        *itemNotFound = YES;
        



        
        return nil;
    }
    else {
        *itemNotFound = NO;
        slog(@"getKeychainBlob: Could not get: %d", (int)status);
        
        if ( error ) {
            *error = [Utils createNSError:[NSString stringWithFormat:@"Could not getKeychainBlob - Error = [%d]", (int)status] errorCode:status];
        }

        return nil;
    }
}

- (void)deleteKeychainBlob:(NSString*)identifier {
    NSMutableDictionary *query = [self getBlobQuery:identifier];
    

    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if ( status != errSecSuccess && status != errSecItemNotFound ) {
        slog(@"Error Deleting Keychain Blob: [%d]", (int)status);
    }
        

}

- (NSMutableDictionary*)getBlobQuery:(NSString*)identifier {
    NSString* blobId = [NSString stringWithFormat:@"%@%@", kAccountPrefix, identifier];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [dictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [dictionary setObject:kEncryptedBlobServiceName forKey:(__bridge id)kSecAttrService];
    [dictionary setObject:blobId forKey:(__bridge id)kSecAttrAccount];
    [dictionary setObject:@NO forKey:(__bridge id)(kSecAttrSynchronizable)]; 
    
#if TARGET_OS_OSX
    [dictionary setObject:@YES forKey:(__bridge id)(kSecUseDataProtectionKeychain)];
#endif
    
    return dictionary;
}

- (BOOL)entryIsExpired:(NSDate*)expiry {
    return ([expiry timeIntervalSinceNow] < 0);
}


























































































@end
