//
//  OtpTests.m
//  StrongboxTests
//
//  Created by Mark on 20/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Node+OtpToken.h"

@interface OtpTests : XCTestCase

@end

@implementation OtpTests

- (void)testPasswordOtpUrl {
    OTPToken* token = [Node getOtpTokenFromRecord:@"otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase" fields:@{} notes:@""];
    
    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testKeeOtpPluginStyle {
    StringValue* stringValue = [StringValue valueWithString:@"key=2GQFLXXUBJQELC&step=31"];
    OTPToken* token = [Node getOtpTokenFromRecord:@"" fields:@{@"otp" : stringValue} notes:@""];

    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testKeePassXc {
    NSDictionary *fields = @{ @"TOTP Seed" : [StringValue valueWithString:@"2gqegflxxubjqeld"], @"TOTP Settings" : [StringValue valueWithString:@"30;6"] };
    
    OTPToken* token = [Node getOtpTokenFromRecord:@"" fields:fields notes:@""];

    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testKeePassXcWithS {
    NSDictionary *fields = @{ @"TOTP Seed" : [StringValue valueWithString:@"2gqegflxxubjqeld"], @"TOTP Settings" : [StringValue valueWithString:@"30;S"] };
    
    OTPToken* token = [Node getOtpTokenFromRecord:@"" fields:fields notes:@""];
    
    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testNotesContainingOtpUrl {
    OTPToken* token = [Node getOtpTokenFromRecord:@""
                                           fields:@{}
                                            notes:@"This are some notes containing an OTP Url like this: otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqexxubjqelc&issuer=Coinbase which is kind of cool"];
    
    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testSetWithOtpUrl {
//    OTPToken* token = [Node getOtpTokenFromRecord:@""
//                                           fields:@{}
//                                            notes:@"This are some notes containing an OTP Url like this: otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase which is kind of cool"];
//
//    XCTAssertNotNil(token);

    Node* node = [[Node alloc] initAsRecord:@"Title" parent:[[Node alloc] initAsRoot:nil]];
    
    BOOL ret = [node setTotpWithString:@"otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase" appendUrlToNotes:YES];
    
    XCTAssertTrue(ret);
    
    NSLog(@"Notes: %@", node.fields.notes);

    NSLog(@"Custom Fields: %@", node.fields.customFields);
}

- (void)testSetWithOtpUrlWithNonDefaults {
    //    OTPToken* token = [Node getOtpTokenFromRecord:@""
    //                                           fields:@{}
    //                                            notes:@"This are some notes containing an OTP Url like this: otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase which is kind of cool"];
    //
    //    XCTAssertNotNil(token);
    
    Node* node = [[Node alloc] initAsRecord:@"Title" parent:[[Node alloc] initAsRoot:nil]];
    
    BOOL ret = [node setTotpWithString:@"otpauth://totp/ACME%20Co:john.doe@email.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA1&digits=8&period=31" appendUrlToNotes:YES];
    
    XCTAssertTrue(ret);
    
    NSLog(@"Notes: %@", node.fields.notes);
    
    NSLog(@"Custom Fields: %@", node.fields.customFields);
}

- (void)testSetWithOtpUrlWithEmpty {
    //    OTPToken* token = [Node getOtpTokenFromRecord:@""
    //                                           fields:@{}
    //                                            notes:@"This are some notes containing an OTP Url like this: otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase which is kind of cool"];
    //
    //    XCTAssertNotNil(token);
    
    Node* node = [[Node alloc] initAsRecord:@"Title" parent:[[Node alloc] initAsRoot:nil]];
    
    BOOL ret = [node setTotpWithString:@"" appendUrlToNotes:YES];
    
    XCTAssertFalse(ret);
    
    NSLog(@"Notes: %@", node.fields.notes);
    
    NSLog(@"Custom Fields: %@", node.fields.customFields);
}

- (void)testSetWithOtpUrlWithNil {
    //    OTPToken* token = [Node getOtpTokenFromRecord:@""
    //                                           fields:@{}
    //                                            notes:@"This are some notes containing an OTP Url like this: otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase which is kind of cool"];
    //
    //    XCTAssertNotNil(token);
    
    Node* node = [[Node alloc] initAsRecord:@"Title" parent:[[Node alloc] initAsRoot:nil]];
    
    BOOL ret = [node setTotpWithString:nil appendUrlToNotes:YES];
    
    XCTAssertFalse(ret);
    
    NSLog(@"Notes: %@", node.fields.notes);
    
    NSLog(@"Custom Fields: %@", node.fields.customFields);
}

- (void)testSetWithOtpUrlWithRubbish {
    //    OTPToken* token = [Node getOtpTokenFromRecord:@""
    //                                           fields:@{}
    //                                            notes:@"This are some notes containing an OTP Url like this: otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2g&issuer=Coinbase which is kind of cool"];
    //
    //    XCTAssertNotNil(token);
    
    Node* node = [[Node alloc] initAsRecord:@"Title" parent:[[Node alloc] initAsRoot:nil]];
    
    BOOL ret = [node setTotpWithString:@"Absolute Garbage GIGO" appendUrlToNotes:YES];
    
    XCTAssertTrue(ret); //Seemd to be fine!
    
    NSLog(@"Notes: %@", node.fields.notes);
    
    NSLog(@"Custom Fields: %@", node.fields.customFields);
}

- (void)testSetWithOtpUrlWithManualBase32String {
    //    OTPToken* token = [Node getOtpTokenFromRecord:@""
    //                                           fields:@{}
    //                                            notes:@"This are some notes containing an OTP Url like this: otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase which is kind of cool"];
    //
    //    XCTAssertNotNil(token);
    
    Node* node = [[Node alloc] initAsRecord:@"Title" parent:[[Node alloc] initAsRoot:nil]];
    
    BOOL ret = [node setTotpWithString:@"2gqegflxxubjqelc" appendUrlToNotes:YES];
    
    XCTAssertTrue(ret); //Seemd to be fine!
    
    NSLog(@"Notes: %@", node.fields.notes);
    
    NSLog(@"Custom Fields: %@", node.fields.customFields);
}

@end
