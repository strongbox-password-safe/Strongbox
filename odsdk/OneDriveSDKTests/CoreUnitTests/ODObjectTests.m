//  Copyright 2015 Microsoft Corporation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


#import "ODTestCase.h"
#import "ODModels.h"
#import "NSDate+ODSerialization.h"

@interface ODObjectTests : ODTestCase
@end

@implementation ODObjectTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testNilDictionary{
    XCTAssertNil([[ODObject alloc] initWithDictionary:nil]);
}

- (void)testItemFromDictionary{
    ODItem *testItem = [[ODItem alloc] initWithDictionary:self.cannedItem];
    
    XCTAssertEqualObjects(testItem.id, self.cannedItem[@"id"]);
    XCTAssertNotNil(testItem.fileSystemInfo);
    XCTAssertNotNil(testItem.fileSystemInfo.createdDateTime);
    XCTAssertNil(testItem.folder);
}

- (void)testItemFromDictionaryToJson{
    ODItem *testItem = [[ODItem alloc] initWithDictionary:self.cannedItem];
    NSError *error;
    NSData *jsonBlob = [NSJSONSerialization dataWithJSONObject:[testItem dictionaryFromItem] options:0 error:&error];
    XCTAssertNotNil(jsonBlob);
    XCTAssertNil(error);
}

- (void)testFolder{
    NSString *itemId = @"12345";
    NSDictionary *folder = @{ @"childCount" : @"42"};
    ODItem *testItem = [[ODItem alloc] initWithDictionary:@{@"id" : itemId, @"folder" : folder}];
    
    XCTAssertEqualObjects(testItem.id, itemId);
    XCTAssertNotNil(testItem.folder);
    XCTAssertEqual(testItem.folder.childCount, 42);
}

- (void)testItemChildren{
    NSString *childId = @"12345";
    NSDictionary *childItem = @{ @"id" : childId};
    NSString *itemId = @"123456";
    ODItem *testItem = [[ODItem alloc] initWithDictionary:@{ @"id" : itemId, @"children" : @[childItem]}];
    
    XCTAssertEqualObjects(testItem.id, itemId);
    XCTAssertNotNil(testItem.children);
    XCTAssertEqualObjects([testItem children:0].id, childId);
}

- (void)testItemInvalidChildren{
    NSString *itemId = @"123456";
    ODItem *testItem = [[ODItem alloc] initWithDictionary:@{ @"id" : itemId, @"children" : @"foo"}];
    
    XCTAssertEqualObjects(testItem.id, itemId);
    XCTAssertNil(testItem.children);
}

- (void)testEmptyDictionary{
    ODItem *testItem = [[ODItem alloc] initWithDictionary:@{}];
    
    XCTAssertNil(testItem.id);
}

- (void)testItemToDictionary{
    ODItem *testItem = [[ODItem alloc] init];
    testItem.id = @"1234";
    ODFolder *folder = [[ODFolder alloc] init];
    folder.childCount = 42;
    testItem.folder = folder;
    testItem.parentReference = [[ODItemReference alloc] init];
    testItem.parentReference.id = @"foo";
    
    NSDictionary *itemDictionary = [testItem dictionaryFromItem];
    XCTAssertEqualObjects(itemDictionary[@"id"], testItem.id);
    XCTAssertEqual([itemDictionary[@"folder"][@"childCount"] integerValue], folder.childCount);
    XCTAssertEqual(itemDictionary[@"parentReference"][@"id"],@"foo");
}

- (void)testItemToData{
    NSString *parentPath = @"foo/bar/baz";
    ODItem *testItem = [[ODItem alloc] initWithDictionary:self.cannedItem];
    testItem.parentReference.path = parentPath;
    NSDictionary *updatedDictionary = [testItem dictionaryFromItem];
    NSData *data = [NSJSONSerialization dataWithJSONObject:updatedDictionary options:0 error:nil];
    NSDictionary *dictionaryFromData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    ODItem *serializedItem = [[ODItem alloc] initWithDictionary:dictionaryFromData];
    XCTAssertEqualObjects(serializedItem.parentReference.path, parentPath);
}

- (void)testDateString{
    NSDictionary *itemDictionary = @{ @"fileSystemInfo" : @{
                                              @"createdDateTime" : @"1991-07-01T08:42:42.422Z",
                                                        }
                                      };
    ODItem *testItem = [[ODItem alloc] initWithDictionary:itemDictionary];
    NSDate *createdTime = testItem.fileSystemInfo.createdDateTime;
    XCTAssertNotNil(createdTime);
}

- (void)testSetDate{
    NSDate *date = [NSDate od_dateFromString:@"1951-09-22T09:42:42Z"];
    
    ODItem *testItem = [[ODItem alloc] init];
    testItem.fileSystemInfo = [[ODFileSystemInfo alloc] init];
    testItem.fileSystemInfo.createdDateTime = date;
    
    XCTAssertNotNil(testItem.fileSystemInfo.createdDateTime);
    XCTAssertNotNil([testItem.fileSystemInfo.createdDateTime od_toString]);
}

- (void)testSerializeSetDate{
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:0];
    ODItem *testItem = [[ODItem alloc] init];
    testItem.fileSystemInfo = [[ODFileSystemInfo alloc] init];
    testItem.fileSystemInfo.createdDateTime = [now copy];
    
    NSDictionary *itemDictionary = [testItem dictionaryFromItem];
    XCTAssertNotNil(itemDictionary[@"fileSystemInfo"][@"createdDateTime"]);
}

- (void)testJsonSerializationItemWithChangedDate{
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:42];
    ODItem *cannedItem = [[ODItem alloc] initWithDictionary:self.cannedItem];
    cannedItem.fileSystemInfo.createdDateTime = now;
    NSError *error = nil;
    NSData *jsonBlob = [NSJSONSerialization dataWithJSONObject:[cannedItem dictionaryFromItem] options:0 error:&error];
    XCTAssertNotNil(jsonBlob);
    XCTAssertNil(error);
   
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonBlob options:0 error:nil];
    ODItem *serializedItem = [[ODItem alloc] initWithDictionary:jsonDictionary];
    
    XCTAssertEqualObjects(serializedItem.fileSystemInfo.createdDateTime, now);
}


@end
