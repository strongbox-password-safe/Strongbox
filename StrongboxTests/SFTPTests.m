//
//  SFTPTests.m
//  StrongboxTests
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFTPStorageProvider.h"

@interface SFTPTests : XCTestCase

@end

@implementation SFTPTests

- (SFTPStorageProvider*)getSftp {
    NSError* error;
    NSData* pk = [NSData dataWithContentsOfFile:@"/Users/mark/.ssh/unit-test-deleteme" options:kNilOptions error:&error];
    
    XCTAssert(pk);
    if(!pk) {
        NSLog(@"ERROR: %@", error);
        return nil;
    }
    
    NSString* privKey = [[NSString alloc] initWithData:pk encoding:NSUTF8StringEncoding];
    
    SFTPSessionConfiguration* config = [[SFTPSessionConfiguration alloc] init];
    
    config.host = @"strongboxsafe.com";
    config.authenticationMode = kPrivateKey;
    config.username = @"mark";
    config.password = @"";
    config.privateKey = privKey;
    config.publicKey = nil;
    
    SFTPStorageProvider.sharedInstance.unitTestingSessionConfiguration = config;
    
    return SFTPStorageProvider.sharedInstance;
}

- (void)testList {
    [[self getSftp] list:@"/home/mark" viewController:nil completion:^(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error) {
         NSLog(@"Done: %@ [Error: %@]", items, error);
    }];
}

- (void)testCreate {
    [[self getSftp] create:@"test" extension:@"txt" data:[@"Hello" dataUsingEncoding:NSUTF8StringEncoding] parentFolder:@"/home/mark/" viewController:nil completion:^(SafeMetaData *metadata, NSError *error) {
        NSLog(@"%@ [Error: %@]", metadata, error);
    }];
}

-(void)testUpdate {
    [[self getSftp] create:@"test" extension:@"txt" data:[@"Hello" dataUsingEncoding:NSUTF8StringEncoding] parentFolder:@"/home/mark/" viewController:nil completion:^(SafeMetaData *metadata, NSError *error) {
        NSLog(@"%@ [Error: %@]", metadata, error);
    
        XCTAssertNil(error);
        
        [[self getSftp] update:metadata data:[@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding]  completion:^(NSError *error) {
            NSLog(@"Done. Error = [%@]", error);
        }];
    }];
}

- (void)testRead {
    [[self getSftp] create:@"test" extension:@"txt" data:[@"Hello" dataUsingEncoding:NSUTF8StringEncoding] parentFolder:@"/home/mark/" viewController:nil completion:^(SafeMetaData *metadata, NSError *error) {
        NSLog(@"%@ [Error: %@]", metadata, error);
        
        XCTAssertNil(error);
        [[self getSftp] read:metadata viewController:nil completion:^(NSData *data, NSError *error) {
            NSLog(@"Got Data: %@ [Error: %@]", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], error);
        }];
    }];
}

@end
