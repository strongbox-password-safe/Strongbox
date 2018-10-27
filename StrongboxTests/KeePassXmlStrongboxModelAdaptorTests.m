//
//  KeePassXmlStrongboxModelAdaptorTests.m
//  StrongboxTests
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>
#import "CommonTesting.h"
#import "Node.h"
#import "XmlStrongBoxModelAdaptor.h"
#import "KeePassConstants.h"

@interface KeePassXmlStrongboxModelAdaptorTests : XCTestCase

@end

@implementation KeePassXmlStrongboxModelAdaptorTests

-(KeepassMetaDataAndNodeModel*)getModelFromXmlFile:(NSString*)filename key:(NSString*)key {
    NSString * xml = [CommonTesting getXmlFromBundleFile:filename];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:key];
    XCTAssertNotNil(rootObject);
    
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    NSError *error;
    
    KeepassMetaDataAndNodeModel *ret = [adaptor fromXmlModelToStrongboxModel:rootObject error:&error];
    
    XCTAssertNotNil(ret);
    return ret;
}

- (void)testReadNil {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    NSError *error;
    KeepassMetaDataAndNodeModel *ret = [adaptor fromXmlModelToStrongboxModel:nil error:&error];
    
    XCTAssertNotNil(ret);
    NSLog(@"%@", ret);
}

- (void)testReadMinimal {
    NSString* file = @"minimal";
    NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
    
    KeepassMetaDataAndNodeModel* strongboxModel = [self getModelFromXmlFile:file key:key];

    XCTAssertNotNil(strongboxModel);
    
    NSLog(@"%@", strongboxModel);
}

- (void)testReadFunky {
    NSString* file = @"funky";
    NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
    
    KeepassMetaDataAndNodeModel* strongboxModel = [self getModelFromXmlFile:file key:key];
    
    NSLog(@"%@", strongboxModel);
    
    XCTAssertNotNil(strongboxModel);
}

- (void)testReadLadder {
    NSString* file = @"ladder";
    NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
    
    KeepassMetaDataAndNodeModel* strongboxModel = [self getModelFromXmlFile:file key:key];
    
    //NSLog(@"%@", strongboxModel);
    
    XCTAssertNotNil(strongboxModel);
    XCTAssertNotNil(strongboxModel.rootNode);
    XCTAssertNotNil(strongboxModel.rootNode.childGroups);
    XCTAssertNotNil([strongboxModel.rootNode.childGroups objectAtIndex:0]);
    XCTAssertNotNil([[strongboxModel.rootNode.childGroups objectAtIndex:0].childGroups objectAtIndex:4]);
                     
    Node* newGroupNode = [[strongboxModel.rootNode.childGroups objectAtIndex:0].childGroups objectAtIndex:4];
    Node* entry1 = [newGroupNode.childRecords objectAtIndex:0];
    
    NSLog(@"%@", entry1);
    
    XCTAssert([entry1.title isEqualToString:@"Entry 1"]);
    XCTAssert([entry1.fields.password isEqualToString:@"ladder"]);
}

- (void)testReadAllTestFiles {
    for (NSString* file in CommonTesting.testXmlFilesAndKeys.allKeys) {
        NSLog(@"===================================================================================================================");
        NSLog(@"=========================================== Testing %@ ====================================================", file);

        NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
        KeepassMetaDataAndNodeModel* strongboxModel = [self getModelFromXmlFile:file key:key];
        
        XCTAssertNotNil(strongboxModel);
        
        NSLog(@"%@", strongboxModel);
        NSLog(@"===================================================================================================================");
    }
}

- (void)testReadLadderSingleEntry {
    NSString* file = @"ladder-single-entry";
    NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
    
    KeepassMetaDataAndNodeModel* strongboxModel = [self getModelFromXmlFile:file key:key];
    
    NSLog(@"%@", strongboxModel);
    
    XCTAssertNotNil(strongboxModel);
    XCTAssertNotNil(strongboxModel.rootNode);
    XCTAssertNotNil(strongboxModel.rootNode.childGroups);
    XCTAssertNotNil([strongboxModel.rootNode.childGroups objectAtIndex:0]);
    XCTAssertNotNil([[strongboxModel.rootNode.childGroups objectAtIndex:0].childRecords objectAtIndex:0]);
    
    Node* foo = [[strongboxModel.rootNode.childGroups objectAtIndex:0].childRecords objectAtIndex:0];
    
    NSLog(@"%@", foo);
    
    XCTAssert([foo.title isEqualToString:@"Entry 1"]);
}

- (void)testToXmlModelFromNilFails {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    
    NSError *error;
    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:nil existingRootXmlDocument:nil error:&error];
    
    XCTAssertNil(ret);
    
    NSLog(@"%@", error);
}

- (void)testToXmlModelFromEmptyFails {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    
    KeePassDatabaseMetadata *metadata = [[KeePassDatabaseMetadata alloc] init];
    Node* node = [[Node alloc] initAsRoot:nil];
    
    KeepassMetaDataAndNodeModel *foo = [[KeepassMetaDataAndNodeModel alloc] initWithMetadata:metadata nodeModel:node];
   
    NSError *error;
    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:foo existingRootXmlDocument:nil error:&error];
    
    XCTAssertNil(ret);
 
    NSLog(@"%@", error);
}

- (void)testToXmlModelFromMostBasicStrongboxModel {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    
    KeePassDatabaseMetadata *metadata = [[KeePassDatabaseMetadata alloc] init];

    Node* node = [[Node alloc] initAsRoot:nil];
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:node uuid:nil];
    [node addChild:keePassRootGroup];

    KeepassMetaDataAndNodeModel *foo = [[KeepassMetaDataAndNodeModel alloc] initWithMetadata:metadata nodeModel:node];
    
    NSError *error;
    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:foo existingRootXmlDocument:nil error:&error];
    
    XCTAssertNotNil(ret);
    XCTAssertNotNil(ret.keePassFile);
    XCTAssertNotNil(ret.keePassFile.meta);
    XCTAssertNotNil(ret.keePassFile.meta.generator);

    XCTAssert([ret.keePassFile.meta.generator.text isEqualToString:@"Strongbox"]);
    
    XCTAssertNotNil(ret);
    XCTAssertNotNil(ret.keePassFile);
    XCTAssertNotNil(ret.keePassFile.root);
    XCTAssertNotNil(ret.keePassFile.root.rootGroup);
    
    XCTAssert([ret.keePassFile.root.rootGroup.name.text isEqualToString:kDefaultRootGroupName]);
    
    NSLog(@"%@", ret);
}

- (void)testToXmlModelFromStrongboxModelWithAGroupAndAnEntry {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    
    KeePassDatabaseMetadata *metadata = [[KeePassDatabaseMetadata alloc] init];
    
    Node* node = [[Node alloc] initAsRoot:nil];
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:node uuid:nil];
    [node addChild:keePassRootGroup];
    
    Node* fooGroup = [[Node alloc] initAsGroup:@"Foo-Group" parent:keePassRootGroup uuid:nil];
    [keePassRootGroup addChild:fooGroup];
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username" url:@"url" password:@"secret" notes:@"" email:@""];
    Node* barEntry = [[Node alloc] initAsRecord:@"Bar-Entry" parent:keePassRootGroup fields:fields uuid:nil];
    [keePassRootGroup addChild:barEntry];
    
    KeepassMetaDataAndNodeModel *foo = [[KeepassMetaDataAndNodeModel alloc] initWithMetadata:metadata nodeModel:node];
    
    NSError *error;
    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:foo existingRootXmlDocument:nil error:&error];
    
    XCTAssertNotNil(ret);
    XCTAssertNotNil(ret.keePassFile);
    XCTAssertNotNil(ret.keePassFile.root);
    XCTAssertNotNil(ret.keePassFile.root.rootGroup);
    
    XCTAssert(ret.keePassFile.root.rootGroup.groups.count == 1);
    XCTAssert(ret.keePassFile.root.rootGroup.entries.count == 1);
    
    XCTAssert([[ret.keePassFile.root.rootGroup.groups objectAtIndex:0].name.text isEqualToString:@"Foo-Group"]);
    XCTAssert([[ret.keePassFile.root.rootGroup.entries objectAtIndex:0].title isEqualToString:@"Bar-Entry"]);

    NSLog(@"%@", ret);
}

@end
