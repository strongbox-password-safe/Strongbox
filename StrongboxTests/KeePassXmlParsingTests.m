//
//  KeePassXmlParsingTests.m
//  StrongboxTests
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XmlSerializer.h"
#import "KeePassDatabase.h"
#import "CommonTesting.h"

@interface KeePassXmlParsingTests : XCTestCase

@end

@implementation KeePassXmlParsingTests

- (void)testMinimalRequiredXml {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"minimal" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    NSLog(@"%@", rootObject);
}

- (void)testGetGeneratorName {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"initial-experimentation" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);

    NSLog(@"%@", rootObject.keePassFile.meta.generator);
    
    XCTAssert([rootObject.keePassFile.meta.generator isEqualToString:@"Strongbox"]);
}

- (void)testVeryBasicSetGeneratorNameAndRegenerateXml {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"initial-experimentation" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    rootObject.keePassFile.meta.generator = @"blah";
    
    NSString* xml2 = getXml(rootObject, NO);
    NSLog(@"%@\n=========================\n%@", xml, xml2);
    XCTAssertFalse(compareOriginalAndRegeneratedXml(xml, xml2));
}

- (void)broken_testParseAndRegenerateAllFiles {
    for(NSString* file in CommonTesting.testXmlFilesAndKeys.allKeys) {
        //NSString* file = @"just-xml-header";
        NSLog(@"Testing: %@", file);
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *path = [bundle pathForResource:file ofType:@"xml"];
        NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
        
        RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
        XCTAssertNotNil(rootObject);

        NSString* xml2 = getXml(rootObject, NO);
        NSLog(@"%@\n=========================\n%@", xml, xml2);
        XCTAssertTrue(compareOriginalAndRegeneratedXml(xml, xml2));
    }
}

- (void)testRepresentiveSetGeneratorNameAndRegenerateXmlSaveToDesktop {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"ladder" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    NSLog(@"%@", rootObject.keePassFile.meta.generator);
    XCTAssert([rootObject.keePassFile.meta.generator isEqualToString:@"MacPass"]);
    
    rootObject.keePassFile.meta.generator = @"Strongbox";
    
    // Serialize
    
    NSString *regeneratedXml = getXml(rootObject, NO);
    NSLog(@"\n%@", regeneratedXml);
    
    [[NSFileManager defaultManager] createFileAtPath:@"/Users/mark/Desktop/regenerated.xml"
                                            contents:[regeneratedXml dataUsingEncoding:NSUTF8StringEncoding]
                                          attributes:nil];
}

- (void)tstRegenerateXmlAndVerifyEquivalent {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"ladder" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];

    RootXmlDomainObject* blah = [CommonTesting parseKeePassXml:xml];
    NSString *regeneratedXml = getXml(blah, NO);

    XCTAssertTrue(compareOriginalAndRegeneratedXml(xml,regeneratedXml));
}

- (void)testModifyVerifyNotEquivalent {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"ladder" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject* rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    rootObject.keePassFile.meta.generator = @"Strongbox";
    
    // Serialize
    
    NSString *regeneratedXml = getXml(rootObject, NO);
    XCTAssertFalse(compareOriginalAndRegeneratedXml(xml, regeneratedXml));
}

- (void)testSalsa20Decrypt {
    NSString* xml = [CommonTesting getXmlFromBundleFile:@"ladder"];
    NSData* key = [[NSData alloc] initWithBase64EncodedString:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ=" options:kNilOptions];
    
    RootXmlDomainObject* xmlObject = [CommonTesting parseKeePassXmlSalsa20:xml key:key];
    
    XCTAssertNotNil(xmlObject);
    
    // Serialize
    
    NSString *regeneratedXml = getXml2(xmlObject, NO, kInnerStreamSalsa20, key);
    NSLog(@"\n%@", regeneratedXml);

    //XCTAssertTrue(compareOriginalAndRegeneratedXml(xml, regeneratedXml));
}

- (void)broken_testKeepassDbWithBinaryAndCustomProtectedField {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"keypass-database-with-binary"];

    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"ztCAmxaRzv/Q/ws53V4wLACfqfJtDELuEa0lR0lK1UA="];

    NSString *regeneratedXml = getXml(rootObject, NO);
    
    NSLog(@"%@\n======================================================================================\n%@", xml, regeneratedXml);
   
    XCTAssertTrue(compareOriginalAndRegeneratedXml(xml, regeneratedXml));
    
    [[NSFileManager defaultManager] createFileAtPath:@"/Users/mark/Desktop/regenerated.xml"
                                            contents:[regeneratedXml dataUsingEncoding:NSUTF8StringEncoding]
                                          attributes:nil];
}

- (void)broken_testSalsa20DecryptAndEncryptAgain {
    for (NSString* filename in CommonTesting.testXmlFilesAndKeys.allKeys)
    {
        NSLog(@"Testing [%@]", filename);
        
        NSString * xml = [CommonTesting getXmlFromBundleFile:filename];
        NSString *b64Key = [CommonTesting.testXmlFilesAndKeys objectForKey:filename];
        
        RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:b64Key];

        NSString *regeneratedXml = getXml(rootObject, NO);
        XCTAssertTrue(compareOriginalAndRegeneratedXml(xml, regeneratedXml));
    }
}

- (void)testLadderGroups {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"ladder"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    //NSLog(@"%@", rootObject.keePassFile.root.groups);
    
    Root* root = rootObject.keePassFile.root;
    
    XCTAssertNotNil(root.rootGroup);
    XCTAssertTrue([root.rootGroup.name isEqualToString:@"General"]);
    
    NSLog(@"%@", root.rootGroup.uuid.UUIDString);
    
    XCTAssertTrue([root.rootGroup.uuid.UUIDString isEqualToString:@"BB2E8130-51B5-46B5-A92E-5F1E9F9CAF35"]);
    
    XCTAssertTrue(root.rootGroup.groups.count == 6);
    
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:0].name isEqualToString:@"Windows"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:1].name isEqualToString:@"Network"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:2].name isEqualToString:@"Internet"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:3].name isEqualToString:@"EMail"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:4].name isEqualToString:@"Homebanking"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:5].name isEqualToString:@"New Group"]);
    
    NSLog(@"%@", root.rootGroup.groups);
}

- (void)testLadderEntries {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"ladder"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ="];
    XCTAssertNotNil(rootObject);
        
    Root* root = rootObject.keePassFile.root;
    NSArray* entries = [root.rootGroup.groups objectAtIndex:5].entries;

    NSLog(@"%@", entries);
}

- (void)testViewCustomFields {
    NSString *xml = [CommonTesting getXmlFromBundleFile:@"keypass-database-with-binary"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"ztCAmxaRzv/Q/ws53V4wLACfqfJtDELuEa0lR0lK1UA="];
    XCTAssertNotNil(rootObject);
    
    Root* root = rootObject.keePassFile.root;

    Entry* entry = [root.rootGroup.entries objectAtIndex:1];
    
    NSLog(@"%@", entry.customStrings);
    
    XCTAssertTrue([[entry.customStrings objectForKey:@"Blah-Mark"].value isEqualToString:@"Blah Value"]);
}

- (void)testViewCustomIcon {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"custom-icon"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    Root* root = rootObject.keePassFile.root;
    //NSArray* entries = [root.rootGroup.groups objectAtIndex:5].entries;
    
    NSLog(@"%@", root.rootGroup);

}

@end
