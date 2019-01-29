//
//  DavKitTests.m
//  StrongboxTests
//
//  Created by Mark on 10/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WebDAVStorageProvider.h"
#import "WebDAVProviderData.h"

@interface DavKitTests : XCTestCase

@property BOOL done;

@end

@implementation DavKitTests

static WebDAVStorageProvider* getSession() {
    WebDAVSessionConfiguration* config = [[WebDAVSessionConfiguration alloc] init];
    //config.host = [NSURL URLWithString:@"https://demo.nextcloud.com/admin/remote.php/webdav"]; //
    config.host = [NSURL URLWithString:@"https://192.168.20.185:8080"];
    config.username = @"admin";
    config.password = @"admin";
    config.allowUntrustedCertificate = YES;
    
    WebDAVStorageProvider.sharedInstance.unitTestSessionConfiguration = config;
    
    return WebDAVStorageProvider.sharedInstance;
}

- (void)testList {
    WebDAVStorageProvider* provider = getSession();

    [provider list:nil viewController:nil completion:^(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error) {
        //NSLog(@"%@ - %@", items, error);
        for(StorageBrowserItem* sbi in items) {
            NSLog(@"[%@]", sbi.providerData);
        }
        self.done = YES;
    }];
    
    [self waitUntilDone];
}

- (void)testCreate {
    WebDAVStorageProvider* provider = getSession();
    
    [provider create:@"Hello"
           extension:@"txt"
                data:[@"This is a test" dataUsingEncoding:NSUTF8StringEncoding]
        parentFolder:nil
      viewController:nil
          completion:^(SafeMetaData *metadata, NSError *error) {
        NSLog(@"%@ - %@", metadata, error);
        self.done = YES;
    }];
    
    [self waitUntilDone];
}

- (void)testUpdate {
    WebDAVStorageProvider* provider = getSession();
    
    [provider create:@"Hello"
           extension:@"txt"
                data:[@"This is a test" dataUsingEncoding:NSUTF8StringEncoding]
        parentFolder:nil
      viewController:nil
          completion:^(SafeMetaData *metadata, NSError *error) {
        [provider update:metadata data:[@"Another test...." dataUsingEncoding:NSUTF8StringEncoding] completion:^(NSError *error) {
            NSLog(@"Update: %@", error);
            self.done = YES;
        }];
    }];
    
    [self waitUntilDone];
}

- (void)testRead {
    WebDAVStorageProvider* provider = getSession();
    
    [provider create:@"Hello"
           extension:@"txt"
                data:[@"This is a test" dataUsingEncoding:NSUTF8StringEncoding]
        parentFolder:nil
      viewController:nil
          completion:^(SafeMetaData *metadata, NSError *error) {
              XCTAssertNil(error);
              XCTAssertNotNil(metadata);
              
              if(metadata) {
                  [provider read:metadata viewController:nil completion:^(NSData *data, NSError *error) {
                      NSLog(@"Read: %@ - Error: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], error);
                      self.done = YES;
                  }];
              }
          }];
    
    [self waitUntilDone];
}

- (void)testReadFromNextCloud {
    WebDAVStorageProvider* provider = getSession();
    
    WebDAVProviderData *pd = [[WebDAVProviderData alloc] init];
    pd.href = @"https://demo.nextcloud.com/admin/remote.php/webdav/Nextcloud%20Manual.pdf";
    pd.sessionConfiguration = provider.unitTestSessionConfiguration;
    
    [provider readWithProviderData:pd viewController:nil completion:^(NSData *data, NSError *error) {
        NSLog(@"Read: %lu bytes - Error: %@",(unsigned long)data.length, error);
        self.done = YES;
    }];
    
    [self waitUntilDone];
}

- (void)testReadFromNextCloudRelative {
    WebDAVStorageProvider* provider = getSession();
    
    WebDAVProviderData *pd = [[WebDAVProviderData alloc] init];
    pd.href = @"Nextcloud Manual.pdf";
    pd.sessionConfiguration = provider.unitTestSessionConfiguration;
    
    [provider readWithProviderData:pd viewController:nil completion:^(NSData *data, NSError *error) {
        NSLog(@"Read: %lu bytes - Error: %@",(unsigned long)data.length, error);
        self.done = YES;
    }];
    
    [self waitUntilDone];
}


- (void)waitUntilDone {
    while(!self.done) {
        //[[NSRunLoop currentRunLoop] runUntilDate:[[NSDate date] dateByAddingTimeInterval:4]]; // 4 seconds
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

@end
