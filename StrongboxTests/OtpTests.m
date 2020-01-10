//
//  OtpTests.m
//  StrongboxTests
//
//  Created by Mark on 20/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NodeFields.h"
#import "OTPToken+Serialization.h"
#import "Node.h"

@interface OtpTests : XCTestCase

@end

@implementation OtpTests

- (void)testSteamTotpKeePassXCSteamEncoderOTPAuthUrl {
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"otpauth://totp/Steam:mark@gmail.com?secret=63BEDWCQZKTQWPESARIERL5DTTQFCJTK&issuer=Steam&encoder=steam"
                                                 fields:@{}
                                                  notes:@""];
    
    XCTAssertNotNil(token);
    
    XCTAssertEqual(token.algorithm, OTPAlgorithmSteam);
    XCTAssertEqual(token.digits, 5);
    
    NSLog(@"%@", token.url);
}

- (void)testSteamTotpKeePassXC {
    NSDictionary *fields = @{ @"TOTP Seed" : [StringValue valueWithString:@"63BEDWCQZKTQWPESARIERL5DTTQFCJTK"], @"TOTP Settings" : [StringValue valueWithString:@"30;S"] };
    
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"" fields:fields notes:@""];
    
    XCTAssertNotNil(token);
    
    XCTAssertEqual(token.algorithm, OTPAlgorithmSteam);
    XCTAssertEqual(token.digits, 5);

    NSLog(@"%@", token.url);
}

- (void)testPasswordOtpUrl {
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase" fields:@{} notes:@""];
    
    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testKeeOtpPluginStyle {
    StringValue* stringValue = [StringValue valueWithString:@"key=2GQFLXXUBJQELC&step=31"];
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"" fields:@{@"otp" : stringValue} notes:@""];

    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testKeePassXc {
    NSDictionary *fields = @{ @"TOTP Seed" : [StringValue valueWithString:@"2gqegflxxubjqeld"], @"TOTP Settings" : [StringValue valueWithString:@"30;6"] };
    
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"" fields:fields notes:@""];

    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testKeePassXcWithS {
    NSDictionary *fields = @{ @"TOTP Seed" : [StringValue valueWithString:@"2gqegflxxubjqeld"], @"TOTP Settings" : [StringValue valueWithString:@"30;S"] };
    
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"" fields:fields notes:@""];
    
    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testNotesContainingOtpUrl {
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@""
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
    
    BOOL ret = [node setTotpWithString:@"otpauth://totp/Coinbase:mark.mcguill@gmail.com?secret=2gqegflxxubjqelc&issuer=Coinbase"
                      appendUrlToNotes:YES
                            forceSteam:NO];
    
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
    
    BOOL ret = [node setTotpWithString:@"otpauth://totp/ACME%20Co:john.doe@email.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA1&digits=8&period=31"
                      appendUrlToNotes:YES
                            forceSteam:NO];
    
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
    
    BOOL ret = [node setTotpWithString:@""
                      appendUrlToNotes:YES
                            forceSteam:NO];
    
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
    
    BOOL ret = [node setTotpWithString:nil appendUrlToNotes:YES forceSteam:NO];
    
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
    
    BOOL ret = [node setTotpWithString:@"Absolute Garbage GIGO" appendUrlToNotes:YES forceSteam:NO];
    
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
    
    BOOL ret = [node setTotpWithString:@"2gqegflxxubjqelc" appendUrlToNotes:YES forceSteam:NO];
    
    XCTAssertTrue(ret); //Seemd to be fine!
    
    NSLog(@"Notes: %@", node.fields.notes);
    
    NSLog(@"Custom Fields: %@", node.fields.customFields);
}

- (void)testOtpRaw {
    StringValue* stringValue = [StringValue valueWithString:@"ZOFHRYXNSJDUGHSJ"];
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"" fields:@{@"otp" : stringValue} notes:@""];

    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testOtpRawSpaced {
    StringValue* stringValue = [StringValue valueWithString:@"ZOFH RYXN SJDU GHSJ"];
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"" fields:@{@"otp" : stringValue} notes:@""];

    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testOtpRawLowercase {
    StringValue* stringValue = [StringValue valueWithString:@"zofhryxnsjdughsj"];
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"" fields:@{@"otp" : stringValue} notes:@""];

    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}

- (void)testOtpRawLowercaseSpaced {
    StringValue* stringValue = [StringValue valueWithString:@"zofh ryxn sjdu ghsj"];
    OTPToken* token = [NodeFields getOtpTokenFromRecord:@"" fields:@{@"otp" : stringValue} notes:@""];

    XCTAssertNotNil(token);
    
    NSLog(@"%@", token);
}
@end
