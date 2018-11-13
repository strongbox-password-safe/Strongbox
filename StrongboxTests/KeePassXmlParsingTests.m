//
//  KeePassXmlParsingTests.m
//  StrongboxTests
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KeePassXmlParserDelegate.h"
#import "XmlTreeSerializer.h"
#import "KeePassDatabase.h"
#import "CommonTesting.h"

@interface KeePassXmlParsingTests : XCTestCase

@end

@implementation KeePassXmlParsingTests

- (BOOL)isEquivalentXml:(NSString*)xml1 xml2:(NSString*)xml2 {
    XmlTree *xmlTree1 = [[CommonTesting parseKeePassXml:xml1] generateXmlTree];
    XCTAssertNotNil(xmlTree1);
    
    XmlTree *xmlTree2 = [[CommonTesting parseKeePassXml:xml2] generateXmlTree];
    XCTAssertNotNil(xmlTree2);
    
    return [xmlTree1 isXmlEquivalent_UnitTestOnly:xmlTree2];
}

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

    NSLog(@"%@", rootObject.keePassFile.meta.generator.text);
    
    XCTAssert([rootObject.keePassFile.meta.generator.text isEqualToString:@"Strongbox"]);
}

- (void)testVeryBasicSetGeneratorNameAndRegenerateXml {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"initial-experimentation" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    //NSLog(@"%@", parserDelegate.rootElement.keePassFile.meta.generator.name);
    //XCTAssert([parserDelegate.rootElement.keePassFile.meta.generator.name isEqualToString:@"Strongbox"]);
    
    rootObject.keePassFile.meta.generator.text = @"blah";
    
    XmlTree *xmlTree = [rootObject generateXmlTree];
    
    //NSLog(@"%@", xmlTree);
    
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    
    NSLog(@"\n%@", [s serializeTrees:xmlTree.children]);
}

- (void)testParseAndRegenerateAllFiles {
    for(NSString* file in CommonTesting.testXmlFilesAndKeys.allKeys) {
        //NSString* file = @"just-xml-header";
        NSLog(@"Testing: %@", file);
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *path = [bundle pathForResource:file ofType:@"xml"];
        NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
        
        RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
        XCTAssertNotNil(rootObject);
        
        XmlTree *xmlTree = [rootObject generateXmlTree];
        
        XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
        
        [s serializeTrees:xmlTree.children];
    }
}


- (void)testRepresentiveSetGeneratorNameAndRegenerateXmlSaveToDesktop {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"ladder" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    NSLog(@"%@", rootObject.keePassFile.meta.generator.text);
    XCTAssert([rootObject.keePassFile.meta.generator.text isEqualToString:@"MacPass"]);
    
    rootObject.keePassFile.meta.generator.text = @"Strongbox";
    
    // Serialize
    
    XmlTree *xmlTree = [rootObject generateXmlTree];
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    
    NSString *regeneratedXml = [s serializeTrees:xmlTree.children];
    
    NSLog(@"\n%@", regeneratedXml);
    
    [[NSFileManager defaultManager] createFileAtPath:@"/Users/mark/Desktop/regenerated.xml"
                                            contents:[regeneratedXml dataUsingEncoding:NSUTF8StringEncoding]
                                          attributes:nil];
}

- (void)testRegenerateXmlAndVerifyEquivalent {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"ladder" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    XmlTree *xmlTree = [[CommonTesting parseKeePassXml:xml] generateXmlTree];
    XCTAssertNotNil(xmlTree);
    
    // Serialize
    
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    
    NSString *regeneratedXml = [s serializeTrees:xmlTree.children];
    
    //NSLog(@"\n%@", regeneratedXml);
  
    XCTAssertTrue([self isEquivalentXml:xml xml2:regeneratedXml]);
}

- (void)testModifyVerifyNotEquivalent {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"ladder" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject* rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    rootObject.keePassFile.meta.generator.text = @"Strongbox";
    
    // Serialize
    
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    NSString *regeneratedXml = [s serializeTrees:[rootObject generateXmlTree].children];
    
    XCTAssertFalse([self isEquivalentXml:xml xml2:regeneratedXml]);
}

- (void)testSalsa20Decrypt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"ladder" ofType:@"xml"];
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    NSData *key = [[NSData alloc] initWithBase64EncodedString:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ=" options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
    KeePassXmlParserDelegate *parserDelegate = [[KeePassXmlParserDelegate alloc] initV3WithProtectedStreamId:kInnerStreamSalsa20
                                                                                         key:key];
    
    [parser setDelegate:parserDelegate];
    [parser parse];
    
    NSError* err = [parser parserError];
    
    if(err)
    {
        NSLog(@"%@", err);
    }
    
    XCTAssertNil(err);
    
    // Serialize
    
    XmlTree *xmlTree = [parserDelegate.rootElement generateXmlTree];
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    
    NSString *regeneratedXml = [s serializeTrees:xmlTree.children];
    
    NSLog(@"\n%@", regeneratedXml);
}

- (void)testKeepassDbWithBinaryAndCustomProtectedField {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"keypass-database-with-binary"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"ztCAmxaRzv/Q/ws53V4wLACfqfJtDELuEa0lR0lK1UA="];
    XmlTree *xmlTree = [rootObject generateXmlTree];
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    NSString *regeneratedXml = [s serializeTrees:xmlTree.children];
    
    NSLog(@"\n%@", regeneratedXml);
    
    [[NSFileManager defaultManager] createFileAtPath:@"/Users/mark/Desktop/regenerated.xml"
                                            contents:[regeneratedXml dataUsingEncoding:NSUTF8StringEncoding]
                                          attributes:nil];
}

- (void)testSalsa20DecryptAndEncryptAgain {
    for (NSString* filename in CommonTesting.testXmlFilesAndKeys.allKeys)
    {
        NSLog(@"Testing [%@]", filename);
        
        NSString * xml = [CommonTesting getXmlFromBundleFile:filename];
        NSString *b64Key = [CommonTesting.testXmlFilesAndKeys objectForKey:filename];
        
        RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:b64Key];
        XmlTree *xmlTree = [rootObject generateXmlTree];
        
        // Serialize Back Out
        
        XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithProtectedStreamId:kInnerStreamSalsa20 b64ProtectedStreamKey:b64Key prettyPrint:YES];
        
        NSString *regeneratedXml = [s serializeTrees:xmlTree.children];
        
        NSLog(@"\n%@", regeneratedXml);
    }
}

- (void)testLadderGroups {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"ladder"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    XCTAssertNotNil(rootObject);
    
    //NSLog(@"%@", rootObject.keePassFile.root.groups);
    
    Root* root = rootObject.keePassFile.root;
    
    XCTAssertNotNil(root.rootGroup);
    XCTAssertTrue([root.rootGroup.name.text isEqualToString:@"General"]);
    
    NSLog(@"%@", root.rootGroup.uuid.uuid.UUIDString);
    
    XCTAssertTrue([root.rootGroup.uuid.uuid.UUIDString isEqualToString:@"BB2E8130-51B5-46B5-A92E-5F1E9F9CAF35"]);
    
    XCTAssertTrue(root.rootGroup.groups.count == 6);
    
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:0].name.text isEqualToString:@"Windows"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:1].name.text isEqualToString:@"Network"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:2].name.text isEqualToString:@"Internet"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:3].name.text isEqualToString:@"EMail"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:4].name.text isEqualToString:@"Homebanking"]);
    XCTAssertTrue([[root.rootGroup.groups objectAtIndex:5].name.text isEqualToString:@"New Group"]);
    
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
    
    NSLog(@"%@", entry.customFields);
    
    XCTAssertTrue([[entry.customFields objectForKey:@"Blah-Mark"] isEqualToString:@"Blah Value"]);
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
