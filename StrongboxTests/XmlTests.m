//
//  XmlTests.m
//  StrongboxTests
//
//  Created by Mark on 20/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"

@interface XmlTests : XCTestCase

@end

@implementation XmlTests

- (void)testEmptyRecycleBinValues {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"empty-recycle-bin-values"];
    XCTAssertNotNil(xml);
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    NSLog(@"Enabled: %@", rootObject.keePassFile.meta.recycleBinEnabled);
    NSLog(@"Group: %@", rootObject.keePassFile.meta.recycleBinGroup);
    NSLog(@"Changed: %@", rootObject.keePassFile.meta.recycleBinChanged);
}

- (void)testCorruptRecycleBinValues {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"corrupt-recycly-bin-values"];
    XCTAssertNotNil(xml);
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    NSLog(@"Enabled: %@", rootObject.keePassFile.meta.recycleBinEnabled);
    NSLog(@"Group: %@", rootObject.keePassFile.meta.recycleBinGroup);
    NSLog(@"Changed: %@", rootObject.keePassFile.meta.recycleBinChanged);
}

@end
