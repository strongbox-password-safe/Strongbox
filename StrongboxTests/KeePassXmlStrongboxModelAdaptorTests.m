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
#import "DatabaseAttachment.h"

@interface KeePassXmlStrongboxModelAdaptorTests : XCTestCase

@end

@implementation KeePassXmlStrongboxModelAdaptorTests

-(Node*)getModelFromXmlFile:(NSString*)filename key:(NSString*)key {
    NSString * xml = [CommonTesting getXmlFromBundleFile:filename];
    
    RootXmlDomainObject *rootObject = [CommonTesting parseKeePassXmlSalsa20:xml b64key:key];
    XCTAssertNotNil(rootObject);
    
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    NSError *error;
    
    Node *ret = [adaptor fromXmlModelToStrongboxModel:rootObject error:&error];
    
    XCTAssertNotNil(ret);
    return ret;
}

- (void)testReadMinimal {
    NSString* file = @"minimal";
    NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
    
    Node* strongboxModel = [self getModelFromXmlFile:file key:key];

    XCTAssertNotNil(strongboxModel);
    
    NSLog(@"%@", strongboxModel);
}

- (void)testReadFunky {
    NSString* file = @"funky";
    NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
    
    Node* strongboxModel = [self getModelFromXmlFile:file key:key];
    
    NSLog(@"%@", strongboxModel);
    
    XCTAssertNotNil(strongboxModel);
}

- (void)testReadLadder {
    NSString* file = @"ladder";
    NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
    
    Node* strongboxModel = [self getModelFromXmlFile:file key:key];
    
    //NSLog(@"%@", strongboxModel);
    XCTAssertNotNil(strongboxModel);
    XCTAssertNotNil(strongboxModel.childGroups);
    XCTAssertNotNil([strongboxModel.childGroups objectAtIndex:0]);
    XCTAssertNotNil([[strongboxModel.childGroups objectAtIndex:0].childGroups objectAtIndex:5]);
                     
    Node* newGroupNode = [[strongboxModel.childGroups objectAtIndex:0].childGroups objectAtIndex:5];
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
        Node* strongboxModel = [self getModelFromXmlFile:file key:key];
        
        XCTAssertNotNil(strongboxModel);
        
        NSLog(@"%@", strongboxModel);
        NSLog(@"===================================================================================================================");
    }
}

- (void)testReadLadderSingleEntry {
    NSString* file = @"ladder-single-entry";
    NSString* key = [CommonTesting.testXmlFilesAndKeys objectForKey:file];
    
    Node* strongboxModel = [self getModelFromXmlFile:file key:key];
    
    NSLog(@"%@", strongboxModel);
    
    XCTAssertNotNil(strongboxModel);
    XCTAssertNotNil(strongboxModel.childGroups);
    XCTAssertNotNil([strongboxModel.childGroups objectAtIndex:0]);
    XCTAssertNotNil([[strongboxModel.childGroups objectAtIndex:0].childRecords objectAtIndex:0]);
    
    Node* foo = [[strongboxModel.childGroups objectAtIndex:0].childRecords objectAtIndex:0];
    
    NSLog(@"%@", foo);
    
    XCTAssert([foo.title isEqualToString:@"Entry 1"]);
}

//- (void)testToXmlModelFromNilFails {
//    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
//    
//    NSError *error;
//    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:nil
//                                                         attachments:[NSArray array]
//                                             existingRootXmlDocument:nil
//                                                             context:[XmlProcessingContext standardV3Context]
//                                                               error:&error];
//    
//    XCTAssertNil(ret);
//    
//    NSLog(@"%@", error);
//}

- (void)testToXmlModelFromEmptyFails {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    
    Node* node = [[Node alloc] initAsRoot:nil];
    
    NSError *error;
    
    KeePassDatabaseWideProperties* props = [[KeePassDatabaseWideProperties alloc] init];
    
    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:node
                                                  databaseProperties:props
                                                             context:[XmlProcessingContext standardV3Context]
                                                               error:&error];
    
    XCTAssertNil(ret);
 
    NSLog(@"%@", error);
}

- (void)testToXmlModelFromMostBasicStrongboxModel {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    

    Node* node = [[Node alloc] initAsRoot:nil];
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:node keePassGroupTitleRules:YES uuid:nil];
    [node addChild:keePassRootGroup keePassGroupTitleRules:YES];

    NSError *error;
    KeePassDatabaseWideProperties* props = [[KeePassDatabaseWideProperties alloc] init];

    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:node
                                                  databaseProperties:props
                                                             context:[XmlProcessingContext standardV3Context]
                                                               error:&error];
    
    XCTAssertNotNil(ret);
    XCTAssertNotNil(ret.keePassFile);
    XCTAssertNotNil(ret.keePassFile.meta);
    XCTAssertNotNil(ret.keePassFile.meta.generator);

    XCTAssert([ret.keePassFile.meta.generator isEqualToString:@"Strongbox"]);
    
    XCTAssertNotNil(ret);
    XCTAssertNotNil(ret.keePassFile);
    XCTAssertNotNil(ret.keePassFile.root);
    XCTAssertNotNil(ret.keePassFile.root.rootGroup);
    
    XCTAssert([ret.keePassFile.root.rootGroup.name isEqualToString:kDefaultRootGroupName]);
    
    NSLog(@"%@", ret);
}

- (void)testToXmlModelFromStrongboxModelWithAGroupAndAnEntry {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    
    Node* node = [[Node alloc] initAsRoot:nil];
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:node keePassGroupTitleRules:YES uuid:nil];
    [node addChild:keePassRootGroup keePassGroupTitleRules:YES];
    
    Node* fooGroup = [[Node alloc] initAsGroup:@"Foo-Group" parent:keePassRootGroup keePassGroupTitleRules:YES uuid:nil];
    [keePassRootGroup addChild:fooGroup keePassGroupTitleRules:YES];
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username" url:@"url" password:@"secret" notes:@"" email:@""];
    Node* barEntry = [[Node alloc] initAsRecord:@"Bar-Entry" parent:keePassRootGroup fields:fields uuid:nil];
    [keePassRootGroup addChild:barEntry keePassGroupTitleRules:YES];
    
    NSError *error;
    KeePassDatabaseWideProperties* props = [[KeePassDatabaseWideProperties alloc] init];
    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:node
                                                  databaseProperties:props
                                                             context:[XmlProcessingContext standardV3Context]
                                                               error:&error];
    
    XCTAssertNotNil(ret);
    XCTAssertNotNil(ret.keePassFile);
    XCTAssertNotNil(ret.keePassFile.root);
    XCTAssertNotNil(ret.keePassFile.root.rootGroup);
    
    XCTAssert(ret.keePassFile.root.rootGroup.groups.count == 1);
    XCTAssert(ret.keePassFile.root.rootGroup.entries.count == 1);
    
    XCTAssert([[ret.keePassFile.root.rootGroup.groups objectAtIndex:0].name isEqualToString:@"Foo-Group"]);
    XCTAssert([[ret.keePassFile.root.rootGroup.entries objectAtIndex:0].title isEqualToString:@"Bar-Entry"]);

    NSLog(@"%@", ret);
}

- (void)testToXmlModelWithAttachments {
    XmlStrongBoxModelAdaptor *adaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    
    Node* node = [[Node alloc] initAsRoot:nil];
 
    // Attachments
    
    DatabaseAttachment* databaseAttachment = [[DatabaseAttachment alloc] init];
    
    NSString* text = @"Twas the best of times...";
    databaseAttachment.data = [text dataUsingEncoding:NSUTF8StringEncoding];
    databaseAttachment.protectedInMemory = YES;
    databaseAttachment.compressed = YES;
    
    NodeFileAttachment* nodeAttachment = [[NodeFileAttachment alloc] init];
    nodeAttachment.index = 0;
    nodeAttachment.filename = @"test-attachment.txt";
    
    // Nodes
    
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:node keePassGroupTitleRules:YES uuid:nil];
    [node addChild:keePassRootGroup keePassGroupTitleRules:YES];
    
    NodeFields *fields = [[NodeFields alloc] init];
    [fields.attachments addObject:nodeAttachment];
    
    Node* nodeWithAttachment = [[Node alloc] initAsRecord:@"Attachments" parent:keePassRootGroup fields:fields uuid:nil];
    [keePassRootGroup addChild:nodeWithAttachment keePassGroupTitleRules:YES];
    
    NSError *error;
    KeePassDatabaseWideProperties* props = [[KeePassDatabaseWideProperties alloc] init];
    RootXmlDomainObject *ret = [adaptor toXmlModelFromStrongboxModel:node
                                                  databaseProperties:props
                                                             context:[XmlProcessingContext standardV3Context]
                                                               error:&error];
    
    XCTAssertNotNil(ret);
    XCTAssertNotNil(ret.keePassFile);
    XCTAssertNotNil(ret.keePassFile.meta);
    XCTAssertNotNil(ret.keePassFile.meta.generator);
    
    XCTAssert([ret.keePassFile.meta.generator isEqualToString:@"Strongbox"]);
    
    XCTAssertNotNil(ret);
    XCTAssertNotNil(ret.keePassFile);
    XCTAssertNotNil(ret.keePassFile.root);
    XCTAssertNotNil(ret.keePassFile.root.rootGroup);
    
    XCTAssert([ret.keePassFile.root.rootGroup.name isEqualToString:kDefaultRootGroupName]);
    
    NSLog(@"%@", ret);
}

@end
