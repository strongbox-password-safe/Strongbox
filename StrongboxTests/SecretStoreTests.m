//
//  MacCredStoreTestd.m
//  MB1Tests
//
//  Created by Mark on 13/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SecretStore.h"

@interface SecretStoreTests : XCTestCase

@end

// MMcG: Fails on iOS 13 Simulator - which seems to be due to an Apple BUG. Real devices and iOS < 13.0 work fine... sigh

@implementation SecretStoreTests

static NSString* const kTestUuid = @"46C9B1FF-BC4A-BC4B-BB26-0C6291BAD20A";
static NSString* const kTestPassword = @"password";

- (void)testSetAndGetWithNeverExpires {
    BOOL ret = [SecretStore.sharedInstance setSecureString:kTestPassword forIdentifier:kTestUuid];
    
    XCTAssertTrue(ret);

    NSString* pw = [SecretStore.sharedInstance getSecureString:kTestUuid];

    if(!pw) {
        NSLog(@"Error: pw = nil");
    }
    
    XCTAssertTrue([pw isEqualToString:kTestPassword]);
}

- (void)testStoreDictionaryObjectGraphWithVariousTypes {
    NSString *identifier = @"Unit-Test-Dictionary";
    
    NSDictionary *set = @{ @"A Key" : @"A Value",
                           @"Foo" : @(YES),
                           @"A number" : @(2412)
    };
    
    BOOL ret = [SecretStore.sharedInstance setSecureObject:set forIdentifier:identifier];

    XCTAssertTrue(ret);
    
    NSDictionary *got = [SecretStore.sharedInstance getSecureObject:identifier];

    XCTAssertEqualObjects(set, got);
}

- (void)testExpiresAtExpiryInThePast {
    NSString *identifier = @"Unit-Test-Dictionary";
    
    NSDictionary *set = @{ @"A Key" : @"A Value",
                           @"Foo" : @(YES),
                           @"A number" : @(2412)
    };
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate* dateInThePast = [cal dateByAddingUnit:NSCalendarUnitDay value:-9 toDate:[NSDate date] options:0];

    BOOL ret = [SecretStore.sharedInstance setSecureObject:set forIdentifier:identifier expiresAt:dateInThePast];

    XCTAssertTrue(ret);
    
    NSDictionary *got = [SecretStore.sharedInstance getSecureObject:identifier];

    XCTAssertNil(got);
}

- (void)testExpiresAtExpiryInFuture {
    NSString *identifier = @"Unit-Test-Dictionary";
    
    NSDictionary *set = @{ @"A Key" : @"A Value",
                           @"Foo" : @(YES),
                           @"A number" : @(2412)
    };
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate* expiry = [cal dateByAddingUnit:NSCalendarUnitDay value:+9 toDate:[NSDate date] options:0];

    BOOL ret = [SecretStore.sharedInstance setSecureObject:set forIdentifier:identifier expiresAt:expiry];

    XCTAssertTrue(ret);
    
    NSDictionary *got = [SecretStore.sharedInstance getSecureObject:identifier];

    XCTAssertEqualObjects(set, got);
}

- (void)testEphemeralStore {
    NSString *identifier = @"Unit-Test-Dictionary";
    
    NSDictionary *set = @{ @"A Key" : @"A Value",
                           @"Foo" : @(YES),
                           @"A number" : @(2412)
    };
    
    BOOL ret = [SecretStore.sharedInstance setSecureEphemeralObject:set forIdentifer:identifier];

    XCTAssertTrue(ret);
    
    NSDictionary *got = [SecretStore.sharedInstance getSecureObject:identifier];

    XCTAssertEqualObjects(set, got);
}

@end
