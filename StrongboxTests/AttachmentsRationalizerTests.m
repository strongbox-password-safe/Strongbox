//
//  AttachmentsRationalizerTests.m
//  StrongboxTests
//
//  Created by Mark on 04/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XmlStrongBoxModelAdaptor.h"
#import "KeePassConstants.h"
#import "AttachmentsRationalizer.h"

@interface AttachmentsRationalizerTests : XCTestCase

@end

@implementation AttachmentsRationalizerTests

static NSArray *getDbAttachments(int n) {
    NSString* text1 = @"Twas the best of times...";
    DatabaseAttachment* db1 = [[DatabaseAttachment alloc] initWithData:[text1 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];

    NSString* text2 = @"Twas the blurst of times...";
    DatabaseAttachment* db2 = [[DatabaseAttachment alloc] initWithData:[text2 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];

    NSString* text3 = @"Year 501...";
    DatabaseAttachment* db3 = [[DatabaseAttachment alloc] initWithData:[text3 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];
    
    NSArray* dbAttachments = @[db1, db2, db3];
    
    return [dbAttachments subarrayWithRange:NSMakeRange(0, n)];;
}

- (void)testToXmlModelAttachments_NoChangesRequired_Single {
    NSArray * dbAttachments = getDbAttachments(1);
    Node* root = [[Node alloc] initAsRoot:nil];
    Node* node = getSampleNode(root);
    
    NodeFileAttachment* nodeAttachment = [[NodeFileAttachment alloc] init];
    nodeAttachment.index = 0;
    nodeAttachment.filename = @"test-attachment.txt";
    
    [node.fields.attachments addObject:nodeAttachment];
    
    NSArray* ret = [AttachmentsRationalizer rationalizeAttachments:dbAttachments root:root];
    
    NSLog(@"New List: %@", ret);
    NSLog(@"Tree: %@", node);

    XCTAssert(ret.count == 1);
}

- (void)testToXmlModelAttachments_Unused {
    NSArray * dbAttachments = getDbAttachments(1);
    Node* root = [[Node alloc] initAsRoot:nil];
    Node* node = getSampleNode(root);
    
    // Rationalize
    NSArray* ret = [AttachmentsRationalizer rationalizeAttachments:dbAttachments root:root];
    
    NSLog(@"New List: %@", ret);
    NSLog(@"Tree: %@", node);
    
    XCTAssert(ret.count == 0);
}

- (void)testToXmlModelAttachments_SingleNode_MultipleAttachments_ButOneUnused_NoNeedToAdjustReferences {
    NSArray * dbAttachments = getDbAttachments(2);
    
    Node* root = [[Node alloc] initAsRoot:nil];
    Node* node = getSampleNode(root);
    
    NodeFileAttachment* na1 = [[NodeFileAttachment alloc] init];
    na1.index = 0;
    na1.filename = @"test-attachment.txt";
    
    NodeFileAttachment* na2 = [[NodeFileAttachment alloc] init];
    na2.index = 0;
    na2.filename = @"attachment2.txt";

    [node.fields.attachments addObject:na1];
    [node.fields.attachments addObject:na2];
    
    // Rationalize
    NSArray* ret = [AttachmentsRationalizer rationalizeAttachments:dbAttachments root:root];
    
    NSLog(@"New List: %@", ret);
    NSLog(@"%@", node.fields.attachments);
    
    XCTAssert(ret.count == 1);
    XCTAssert([node.fields.attachments objectAtIndex:0].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:1].index == 0);
}

- (void)testToXmlModelAttachments_MultipleNodes_MultipleAttachments_NoneUnused {
    NSArray * dbAttachments = getDbAttachments(2);
    
    Node* root = [[Node alloc] initAsRoot:nil];
    NSArray<Node*> *nodes = getSampleNodes(root);
    
    NodeFileAttachment* na1 = [[NodeFileAttachment alloc] init];
    na1.index = 0;
    na1.filename = @"test-attachment.txt";
    
    NodeFileAttachment* na2 = [[NodeFileAttachment alloc] init];
    na2.index = 0;
    na2.filename = @"attachment2.txt";
    
    [nodes[0].fields.attachments addObject:na1];
    [nodes[0].fields.attachments addObject:na2];
    
    NodeFileAttachment* na3 = [[NodeFileAttachment alloc] init];
    na3.index = 0;
    na3.filename = @"test-attachment.txt";
    
    NodeFileAttachment* na4 = [[NodeFileAttachment alloc] init];
    na4.index = 1;
    na4.filename = @"attachment2.txt";
    
    [nodes[1].fields.attachments addObject:na3];
    [nodes[1].fields.attachments addObject:na4];
    
    // Rationalize
    NSArray* ret = [AttachmentsRationalizer rationalizeAttachments:dbAttachments root:root];
    
    NSLog(@"New List: %@", ret);
    NSLog(@"%@", nodes[0].fields.attachments);
    NSLog(@"%@", nodes[1].fields.attachments);

    XCTAssert(ret.count == 2);
    XCTAssert(nodes[0].fields.attachments[0].index == 0);
    XCTAssert(nodes[0].fields.attachments[1].index == 0);
    XCTAssert(nodes[1].fields.attachments[0].index == 0);
    XCTAssert(nodes[1].fields.attachments[1].index == 1);
}

- (void)testToXmlModelAttachments_SingleNode_MultipleAttachments_ButOneUnused_AdjustReferences {
    NSArray * dbAttachments = getDbAttachments(3);
    
    Node* root = [[Node alloc] initAsRoot:nil];
    Node* node = getSampleNode(root);
    
    NodeFileAttachment* na1 = [[NodeFileAttachment alloc] init];
    na1.index = 1;
    na1.filename = @"test-attachment.txt";
    
    NodeFileAttachment* na2 = [[NodeFileAttachment alloc] init];
    na2.index = 1;
    na2.filename = @"attachment2.txt";

    NodeFileAttachment* na3 = [[NodeFileAttachment alloc] init];
    na3.index = 2;
    na3.filename = @"attachment3.txt";
    
    [node.fields.attachments addObject:na1];
    [node.fields.attachments addObject:na2];
    [node.fields.attachments addObject:na3];

    NSLog(@"Before: %@", dbAttachments);
    NSLog(@"%@", node.fields.attachments);
    
    // Rationalize
    NSArray* ret = [AttachmentsRationalizer rationalizeAttachments:dbAttachments root:root];
    
    NSLog(@"After: %@", ret);
    NSLog(@"%@", node.fields.attachments);
    
    XCTAssert(ret.count == 2);
    XCTAssert([node.fields.attachments objectAtIndex:0].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:1].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:2].index == 1);
}

- (void)testToXmlModelAttachments_DuplicateAttachments {
    NSString* text1 = @"Twas the best of times...";
    DatabaseAttachment* db1 = [[DatabaseAttachment alloc] initWithData:[text1 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];

    NSString* text2 = @"Twas the blurst of times...";
    DatabaseAttachment* db2 = [[DatabaseAttachment alloc] initWithData:[text2 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];

    NSString* text3 = @"Twas the best of times...";
    DatabaseAttachment* db3 = [[DatabaseAttachment alloc] initWithData:[text3 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];
    
    NSArray* dbAttachments = @[db1, db2, db3]; // duplicate
    
    Node* root = [[Node alloc] initAsRoot:nil];
    Node* node = getSampleNode(root);
    
    NodeFileAttachment* na1 = [[NodeFileAttachment alloc] init];
    na1.index = 0;
    na1.filename = @"test-attachment.txt";
    
    NodeFileAttachment* na2 = [[NodeFileAttachment alloc] init];
    na2.index = 1;
    na2.filename = @"attachment2.txt";
    
    NodeFileAttachment* na3 = [[NodeFileAttachment alloc] init];
    na3.index = 2;
    na3.filename = @"attachment3.txt";
    
    [node.fields.attachments addObject:na1];
    [node.fields.attachments addObject:na2];
    [node.fields.attachments addObject:na3];
    
    NSLog(@"Before: %@", dbAttachments);
    NSLog(@"%@", node.fields.attachments);
    
    // Rationalize
    NSArray* ret = [AttachmentsRationalizer rationalizeAttachments:dbAttachments root:root];
    
    NSLog(@"After: %@", ret);
    NSLog(@"%@", node.fields.attachments);
    
    XCTAssert(ret.count == 2);
    XCTAssert([node.fields.attachments objectAtIndex:0].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:1].index == 1);
    XCTAssert([node.fields.attachments objectAtIndex:2].index == 0);
}

- (void)testToXmlModelAttachments_MultipleDuplicateAttachments {
    NSString* text1 = @"Twas the best of times...";
    DatabaseAttachment* db1 = [[DatabaseAttachment alloc] initWithData:[text1 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];

    NSString* text2 = @"Twas the blurst of times...";
    DatabaseAttachment* db2 = [[DatabaseAttachment alloc] initWithData:[text2 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];
    
    NSArray* dbAttachments = @[db1, db1, db1, db2]; // duplicate
    
    Node* root = [[Node alloc] initAsRoot:nil];
    Node* node = getSampleNode(root);
    
    NodeFileAttachment* na1 = [[NodeFileAttachment alloc] init];
    na1.index = 0;
    na1.filename = @"test-attachment.txt";
    
    NodeFileAttachment* na2 = [[NodeFileAttachment alloc] init];
    na2.index = 1;
    na2.filename = @"attachment2.txt";
    
    NodeFileAttachment* na3 = [[NodeFileAttachment alloc] init];
    na3.index = 2;
    na3.filename = @"attachment3.txt";
    
    NodeFileAttachment* na4 = [[NodeFileAttachment alloc] init];
    na4.index = 3;
    na4.filename = @"attachment4.txt";
    
    [node.fields.attachments addObject:na1];
    [node.fields.attachments addObject:na2];
    [node.fields.attachments addObject:na3];
    [node.fields.attachments addObject:na4];

    NSLog(@"Before: %@", dbAttachments);
    NSLog(@"%@", node.fields.attachments);
    
    // Rationalize
    NSArray* ret = [AttachmentsRationalizer rationalizeAttachments:dbAttachments root:root];
    
    NSLog(@"After: %@", ret);
    NSLog(@"%@", node.fields.attachments);
    
    XCTAssert(ret.count == 2);
    XCTAssert([node.fields.attachments objectAtIndex:0].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:1].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:2].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:3].index == 1);
}

- (void)testToXmlModelAttachments_MultipleDuplicateAttachmentsInterleaved {
    NSString* text1 = @"Twas the best of times...";
    DatabaseAttachment* db1 = [[DatabaseAttachment alloc] initWithData:[text1 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];

    NSString* text2 = @"Twas the blurst of times...";
    DatabaseAttachment* db2 = [[DatabaseAttachment alloc] initWithData:[text2 dataUsingEncoding:NSUTF8StringEncoding] compressed:YES protectedInMemory:YES];
    
    NSArray* dbAttachments = @[db1, db1, db1, db2, db1]; // duplicate
    
    Node* root = [[Node alloc] initAsRoot:nil];
    Node* node = getSampleNode(root);
    
    NodeFileAttachment* na1 = [[NodeFileAttachment alloc] init];
    na1.index = 0;
    na1.filename = @"test-attachment.txt";
    
    NodeFileAttachment* na2 = [[NodeFileAttachment alloc] init];
    na2.index = 1;
    na2.filename = @"attachment2.txt";
    
    NodeFileAttachment* na3 = [[NodeFileAttachment alloc] init];
    na3.index = 2;
    na3.filename = @"attachment3.txt";
    
    NodeFileAttachment* na4 = [[NodeFileAttachment alloc] init];
    na4.index = 3;
    na4.filename = @"attachment4.txt";

    NodeFileAttachment* na5 = [[NodeFileAttachment alloc] init];
    na5.index = 2;
    na5.filename = @"attachment5.txt";
    
    NodeFileAttachment* na6 = [[NodeFileAttachment alloc] init];
    na6.index = 4;
    na6.filename = @"attachment6.txt";
    
    [node.fields.attachments addObject:na1];
    [node.fields.attachments addObject:na2];
    [node.fields.attachments addObject:na3];
    [node.fields.attachments addObject:na4];
    [node.fields.attachments addObject:na5];
    [node.fields.attachments addObject:na6];
    
    NSLog(@"Before: %@", dbAttachments);
    NSLog(@"%@", node.fields.attachments);
    
    // Rationalize
    NSArray* ret = [AttachmentsRationalizer rationalizeAttachments:dbAttachments root:root];
    
    NSLog(@"After: %@", ret);
    NSLog(@"%@", node.fields.attachments);
    
    XCTAssert(ret.count == 2);
    XCTAssert([node.fields.attachments objectAtIndex:0].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:1].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:2].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:3].index == 1);
    XCTAssert([node.fields.attachments objectAtIndex:4].index == 0);
    XCTAssert([node.fields.attachments objectAtIndex:5].index == 0);
}

static Node* getSampleNode(Node* root) {
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:root keePassGroupTitleRules:YES uuid:nil];
    [root addChild:keePassRootGroup keePassGroupTitleRules:YES];
    
    NodeFields *fields = [[NodeFields alloc] init];
    Node* nodeWithAttachments = [[Node alloc] initAsRecord:@"Attachments" parent:keePassRootGroup fields:fields uuid:nil];
    [keePassRootGroup addChild:nodeWithAttachments keePassGroupTitleRules:YES];
    
    return nodeWithAttachments;
}

static NSArray<Node*>* getSampleNodes(Node* root) {
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:root keePassGroupTitleRules:YES uuid:nil];
    [root addChild:keePassRootGroup keePassGroupTitleRules:YES];
    
    Node* node1 = [[Node alloc] initAsRecord:@"Attachment-1" parent:keePassRootGroup fields:[[NodeFields alloc] init] uuid:nil];
    [keePassRootGroup addChild:node1 keePassGroupTitleRules:YES];
    
    Node* node2 = [[Node alloc] initAsRecord:@"Attachment-2" parent:keePassRootGroup fields:[[NodeFields alloc] init] uuid:nil];
    [keePassRootGroup addChild:node2 keePassGroupTitleRules:YES];
    
    return @[node1, node2];
}

@end
