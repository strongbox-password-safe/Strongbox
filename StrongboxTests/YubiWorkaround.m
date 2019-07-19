//
//  YubiWorkaround.m
//  StrongboxTests
//
//  Created by Mark on 10/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Kdbx4Database.h"
#import "KeePassDatabase.h"
#import "Utils.h"
#import <CommonCrypto/CommonCrypto.h>
#import "KeePassDatabase.h"

@interface YubiWorkaround : XCTestCase

@end

@implementation YubiWorkaround

- (void)testKdbx4Argon2 {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Google Drive/yubi.kdbx"];
    
    NSError* error;
    
    if(![Kdbx4Database isAValidSafe:safeData error:&error]){
        NSLog(@"Invalid KeePass datase");
        return;
    }
    
    NSData* challenge = [Kdbx4Database getYubikeyChallenge:safeData error:&error];
    
    NSLog(@"Yubikey Challenge: [%@]", challenge);

    NSData* yubikey = [Utils dataFromHexString:@"98884e35602b5a00427807c626f1ae25af10f02b"];

    NSData* HMAC = hmacSha1(challenge, yubikey);
    
    NSLog(@"yubikey: %@", yubikey);
    NSLog(@"HMAC: %@", HMAC);
    
    //BOOL ret = [HMAC writeToFile:@"/Users/mark/generated.key" atomically:YES];
    //NSLog(@"Done: %d", ret);

    CompositeKeyFactors* cpf = [CompositeKeyFactors password:@"a" keyFileDigest:nil yubiKeyResponse:HMAC];
    StrongboxDatabase* db = [[[Kdbx4Database alloc] init] open:safeData compositeKeyFactors:cpf error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@ - %@", db, error);
}

- (void)testKdbx4Aes {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Google Drive/yubi-aes.kdbx"];
    
    NSError* error;
    
    if(![Kdbx4Database isAValidSafe:safeData error:&error]){
        NSLog(@"Invalid KeePass datase");
        return;
    }
    
    NSData* challenge = [Kdbx4Database getYubikeyChallenge:safeData error:&error];
    
    NSLog(@"Yubikey Challenge: [%@]", challenge);
    
    NSData* yubikey = [Utils dataFromHexString:@"98884e35602b5a00427807c626f1ae25af10f02b"];
    
    NSData* HMAC = hmacSha1(challenge, yubikey);
    
    NSLog(@"yubikey: %@", yubikey);
    NSLog(@"HMAC: %@", HMAC);
    
    //BOOL ret = [HMAC writeToFile:@"/Users/mark/generated.key" atomically:YES];
    //NSLog(@"Done: %d", ret);
    
    CompositeKeyFactors* cpf = [CompositeKeyFactors password:@"a" keyFileDigest:nil yubiKeyResponse:HMAC];
    StrongboxDatabase* db = [[[Kdbx4Database alloc] init] open:safeData compositeKeyFactors:cpf error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@ - %@", db, error);
}

- (void)testKdbx31 {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Google Drive/yubi-31.kdbx"];
    
    NSError* error;
    
    if(![KeePassDatabase isAValidSafe:safeData error:&error]){
        NSLog(@"Invalid KeePass datase");
        XCTAssertFalse(YES);
        return;
    }
    
    NSData* challenge = [KeePassDatabase getYubikeyChallenge:safeData error:&error];
    
    NSLog(@"Yubikey Challenge: [%@]", challenge);
    
    NSData* yubikey = [Utils dataFromHexString:@"98884e35602b5a00427807c626f1ae25af10f02b"];
    
    NSData* HMAC = hmacSha1(challenge, yubikey);
    
    NSLog(@"yubikey: %@", yubikey);
    NSLog(@"HMAC: %@", HMAC);
    
    //BOOL ret = [HMAC writeToFile:@"/Users/mark/generated.key" atomically:YES];
    //NSLog(@"Done: %d", ret);
    
    CompositeKeyFactors* cpf = [CompositeKeyFactors password:@"a" keyFileDigest:nil yubiKeyResponse:HMAC];
    StrongboxDatabase* db = [[[KeePassDatabase alloc] init] open:safeData compositeKeyFactors:cpf error:&error];
    
    XCTAssertNotNil(db);
    NSLog(@"%@ - %@", db, error);
}

@end
