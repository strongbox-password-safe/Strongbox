//
//  StrongboxTests.m
//  StrongboxTests
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KeePassDatabase.h"
#import "XmlStrongboxNodeModelAdaptor.h"
#import "KdbxSerialization.h"
#import "CommonTesting.h"
#import "XmlTreeSerializer.h"

@interface KeePassXmlStrongboxNodeModelAdaptorTests : XCTestCase

@end        

@implementation KeePassXmlStrongboxNodeModelAdaptorTests

-(Node*)getModelFromXmlFile:(NSString*)filename b64Key:(NSString*)b64Key {
    NSString * xml = [CommonTesting getXmlFromBundleFile:filename];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:b64Key];
    XCTAssertNotNil(rootObject);
    XCTAssertNotNil(rootObject.keePassFile);
    XCTAssertNotNil(rootObject.keePassFile.root);
    XCTAssertNotNil(rootObject.keePassFile.root.rootGroup);

    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    NSError *error;
    Node* ret = [adaptor toModel:rootObject.keePassFile.root.rootGroup error:&error];
    
    XCTAssertNotNil(ret);
    return ret;
}

- (void)test_single_entry_ladder_inner_Salsa20 {
    Node * ret = [self getModelFromXmlFile:@"password-ladder" b64Key:@"JvrWpyQom2y63klo6iNBsIIjnt/dRKV2rbu7VRaX+cw="]; //: b64key:@];
    
    Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);
    
    NSLog(@"%@", singleEntry);
}


- (void)test_two_entries_ladder_inner_Salsa20 {
    Node * ret = [self getModelFromXmlFile:@"password-two-entries-ladder" b64Key:@"N0gYzFpyRtD8VC/FjMTUN/ehg8tDYydOMWcLWe3rdJI="];

    Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);

    Node* secondEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:1];
    XCTAssert([secondEntry.fields.password isEqualToString:@"ladder"]);

    //Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    //XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);
    //NSLog(@"%@", singleEntry);
}

- (void)test_three_entries_ladder_inner_Salsa20 {
    Node * ret = [self getModelFromXmlFile:@"password-three-entries-ladder" b64Key:@"2+0LT4H8KD86L76Umi+eu2T0AM0Dr7/d+oFbFTlLgxk="];
    
    Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);
    
    Node* secondEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:1];
    XCTAssert([secondEntry.fields.password isEqualToString:@"ladder"]);
    
    //Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    //XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);
    //NSLog(@"%@", singleEntry);
}


- (void)test_five_entries_ladder_inner_Salsa20 {
    Node * ret = [self getModelFromXmlFile:@"password-five-entries-ladder" b64Key:@"VId5gvqpc1umKBTk16bND/3VGKotVVOTygiw6nGTBYI="];
    
    Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);
    
    Node* secondEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:1];
    XCTAssert([secondEntry.fields.password isEqualToString:@"ladder"]);
    
    //Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    //XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);
    //NSLog(@"%@", singleEntry);
}

- (void)test_ladder_inner_Salsa20 {
    Node * ret = [self getModelFromXmlFile:@"ladder" b64Key:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ="];

    Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);
    
    Node* secondEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:1];
    XCTAssert([secondEntry.fields.password isEqualToString:@"ladde"]);
    
    //Node* singleEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    //XCTAssert([singleEntry.fields.password isEqualToString:@"ladder"]);
    //NSLog(@"%@", singleEntry);
}

- (void)testEntryProperties {
    Node * ret = [self getModelFromXmlFile:@"ladder" b64Key:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ="];
    XCTAssertNotNil(ret);
    
    Node* firstEntry = [[[ret.children objectAtIndex:0].children objectAtIndex:4].children objectAtIndex:0];
    NSLog(@"%@", firstEntry);
    
    XCTAssert([firstEntry.title isEqualToString:@"Entry 1"]);
    XCTAssert([firstEntry.fields.username isEqualToString:@""]);
    XCTAssert([firstEntry.fields.password isEqualToString:@"ladder"]);
    XCTAssert([firstEntry.fields.url isEqualToString:@""]);
    XCTAssert([firstEntry.fields.notes isEqualToString:@""]);
}

- (void)broken_testSingleEntryToFromModelAndCompareXml {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"ladder-single-entry"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ="];
    
    // Xml Model to Strongbox Model...
    
    KeePassGroup *origRootGroup = rootObject.keePassFile.root.rootGroup;
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    NSError *error;
    Node* strongboxModel = [adaptor toModel:origRootGroup error:&error];
    
    // Strongbox Model to Xml Model
    
    adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup* regeneratedRootGroup = [adaptor fromModel:strongboxModel context:[XmlProcessingContext standardV3Context] error:&error];
    
    // Compare Original and Regenerated
    
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    NSString *originalXml = [s serializeTree:[origRootGroup generateXmlTree]];
    NSLog(@"%@", originalXml);
    
    NSLog(@"============================================================================================================================");
    
    s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    NSString* regeneratedXml = [s serializeTree:[regeneratedRootGroup generateXmlTree]];
    NSLog(@"%@", regeneratedXml);
    
    XCTAssertTrue([[origRootGroup generateXmlTree] isXmlEquivalent_UnitTestOnly:[regeneratedRootGroup generateXmlTree]]);
}

- (void)broken_testToFromModelAndCompareXml {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"ladder"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ="];

    // Xml Model to Strongbox Model...
    
    KeePassGroup *origRootGroup = rootObject.keePassFile.root.rootGroup;
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    NSError *error;
    Node* strongboxModel = [adaptor toModel:origRootGroup error:&error];
    
    // Strongbox Model to Xml Model
    
    adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup* regeneratedRootGroup = [adaptor fromModel:strongboxModel context:[XmlProcessingContext standardV3Context] error:&error];

    // Compare Original and Regenerated

    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    NSString *originalXml = [s serializeTree:[origRootGroup generateXmlTree]];
    NSLog(@"%@", originalXml);

    NSLog(@"============================================================================================================================");
    
    s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    NSString* regeneratedXml = [s serializeTree:[regeneratedRootGroup generateXmlTree]];
    NSLog(@"%@", regeneratedXml);
    
    XCTAssertTrue([[origRootGroup generateXmlTree] isXmlEquivalent_UnitTestOnly:[regeneratedRootGroup generateXmlTree]]);
}

- (void)broken_testToFromModelAndCompareXmlCustomIcon {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"custom-icon"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXml:xml];
    
    // Xml Model to Strongbox Model...
    
    KeePassGroup *origRootGroup = rootObject.keePassFile.root.rootGroup;
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    NSError *error;
    Node* strongboxModel = [adaptor toModel:origRootGroup error:&error];
    
    // Strongbox Model to Xml Model
    
    adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup* regeneratedRootGroup = [adaptor fromModel:strongboxModel context:[XmlProcessingContext standardV3Context] error:&error];
    
    // Compare Original and Regenerated
    
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    NSString *originalXml = [s serializeTree:[origRootGroup generateXmlTree]];
    NSLog(@"%@", originalXml);
    
    NSLog(@"============================================================================================================================");
    
    s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    NSString* regeneratedXml = [s serializeTree:[regeneratedRootGroup generateXmlTree]];
    NSLog(@"%@", regeneratedXml);
    
    XCTAssertTrue([[origRootGroup generateXmlTree] isXmlEquivalent_UnitTestOnly:[regeneratedRootGroup generateXmlTree]]);
}

- (void)broken_testToFromModelAndCompareXmlLarge {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"keypass-database-with-binary"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"ztCAmxaRzv/Q/ws53V4wLACfqfJtDELuEa0lR0lK1UA="];
    
    DatabaseAttachment *fakeAttachment = [[DatabaseAttachment alloc] init];
    fakeAttachment.data = [NSData data];
    
    // Xml Model to Strongbox Model...
    
    KeePassGroup *origRootGroup = rootObject.keePassFile.root.rootGroup;
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    NSError *error;
    Node* strongboxModel = [adaptor toModel:origRootGroup error:&error];
    
    NSLog(@"%@", strongboxModel);
    
    // Strongbox Model to Xml Model
    
    adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup* regeneratedRootGroup = [adaptor fromModel:strongboxModel context:[XmlProcessingContext standardV3Context] error:&error];
    
    // Compare Original and Regenerated
    
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    NSString *originalXml = [s serializeTree:[origRootGroup generateXmlTree]];
    
    [[NSFileManager defaultManager] createFileAtPath:@"/Users/mark/Desktop/orig.xml" contents:[originalXml dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    //NSLog(@"%@", originalXml);
    

    NSLog(@"============================================================================================================================");
    
    s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    NSString* regeneratedXml = [s serializeTree:[regeneratedRootGroup generateXmlTree]];
    //NSLog(@"%@", regeneratedXml);
    [[NSFileManager defaultManager] createFileAtPath:@"/Users/mark/Desktop/regen.xml" contents:[regeneratedXml dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

    XCTAssertTrue([[origRootGroup generateXmlTree] isXmlEquivalent_UnitTestOnly:[regeneratedRootGroup generateXmlTree]]);
}


- (void)testSingleEntryModifyPasswordCompareXml {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"ladder-single-entry"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ="];
    
    // Xml Model to Strongbox Model...
    
    KeePassGroup *origRootGroup = rootObject.keePassFile.root.rootGroup;
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    NSError *error;
    Node* strongboxModel = [adaptor toModel:origRootGroup error:&error];
    
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    NSString *originalXml = [s serializeTree:[origRootGroup generateXmlTree]];
    NSLog(@"%@", originalXml);

    Node* e = [[strongboxModel.children objectAtIndex:0].children objectAtIndex:0];
    e.title = @"Changed!";
    // Strongbox Model to Xml Model
    
    adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup* regeneratedRootGroup = [adaptor fromModel:strongboxModel context:[XmlProcessingContext standardV3Context] error:&error];
    
    // Compare Original and Regenerated
    
    NSLog(@"============================================================================================================================");
    
    s = [[XmlTreeSerializer alloc] initWithPrettyPrint:YES];
    NSString* regeneratedXml = [s serializeTree:[regeneratedRootGroup generateXmlTree]];
    NSLog(@"%@", regeneratedXml);
    
    XCTAssertFalse([[origRootGroup generateXmlTree] isXmlEquivalent_UnitTestOnly:[regeneratedRootGroup generateXmlTree]]);
}

- (void)testSingleEntryModifyWithApostrophe {
    NSString * xml = [CommonTesting getXmlFromBundleFile:@"ladder-single-entry"];
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ="];
    
    // Xml Model to Strongbox Model...
    
    KeePassGroup *origRootGroup = rootObject.keePassFile.root.rootGroup;
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    NSError *error;
    Node* strongboxModel = [adaptor toModel:origRootGroup error:&error];
    
    XmlTreeSerializer *s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    NSString *originalXml = [s serializeTree:[origRootGroup generateXmlTree]];
    NSLog(@"%@", originalXml);
    
    Node* e = [[strongboxModel.children objectAtIndex:0].children objectAtIndex:0];
    e.title = @"Mark's New Title";
    // Strongbox Model to Xml Model
    
    adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup* regeneratedRootGroup = [adaptor fromModel:strongboxModel context:[XmlProcessingContext standardV3Context] error:&error];
    
    // Compare Original and Regenerated
    
    NSLog(@"============================================================================================================================");
    
    s = [[XmlTreeSerializer alloc] initWithPrettyPrint:NO];
    NSString* regeneratedXml = [s serializeTree:[regeneratedRootGroup generateXmlTree]];
    NSLog(@"%@", regeneratedXml);
    
    XCTAssertFalse([[origRootGroup generateXmlTree] isXmlEquivalent_UnitTestOnly:[regeneratedRootGroup generateXmlTree]]);
}

@end
