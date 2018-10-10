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
#import "ODItemRequest.h"

@interface ODItemRequest (Test)

- (NSMutableURLRequest *)delete;

- (NSMutableURLRequest *)get;

- (NSMutableURLRequest *)update:(ODItem *)item;

@end

@interface ODItemRequestTests : ODTestCase

@property ODItemRequest *itemRequest;

@property NSURL *itemURL;

@property NSString *itemId;

@end

@implementation ODItemRequestTests

- (void)setUp {
    [super setUp];
    self.itemId = @"12345";
    self.itemURL = [self itemURLWithBase:self.testBaseURL item:self.itemId];
    self.itemRequest = [[ODItemRequest alloc] initWithURL:self.itemURL client:self.mockClient];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDeleteItem{
    NSMutableURLRequest *testRequest = [self.itemRequest delete];
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:self.itemURL];
    expectedRequest.HTTPMethod = @"DELETE";
    [self assertRequest:testRequest isEqual:expectedRequest];
}

- (void)testGetItem{
    NSMutableURLRequest *testRequest = [self.itemRequest get];
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:self.itemURL];
    expectedRequest.HTTPMethod = @"GET";
    [self assertRequest:testRequest isEqual:expectedRequest];
}

- (void)testUpdateItem{
    ODItem *updateItem = [[ODItem alloc] init];
    ODItemReference *parentReference = [[ODItemReference alloc] init];
    parentReference.id = @"parentId";
    updateItem.parentReference = parentReference;
    NSMutableURLRequest *testRequest = [self.itemRequest update:updateItem];
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:self.itemURL];
    expectedRequest.HTTPMethod = @"PATCH";
    expectedRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"parentReference" : @{ @"id" : @"parentId"}} options:0 error:nil];
    [self assertRequest:testRequest isEqual:expectedRequest];
}

- (NSURL *)itemURLWithBase:(NSURL *)baseURL item:(NSString *)item
{
    NSURL *itemURL = [baseURL URLByAppendingPathComponent:@"items"];
    return [itemURL URLByAppendingPathComponent:item];
}

@end
