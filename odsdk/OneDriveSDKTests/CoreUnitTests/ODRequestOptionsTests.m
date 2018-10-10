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
#import "ODQueryParameters.h"
#import "ODHeaderOptions.h"

@interface ODRequestOptionsTests : ODTestCase

@property NSString *firstKey;
@property NSString *firstValue;
@property NSString *secondKey;
@property NSString *secondValue;

@end

@implementation ODRequestOptionsTests

- (void)setUp {
    [super setUp];
    self.firstKey = @"foo";
    self.firstValue = @"bar";
    self.secondKey = @"baz";
    self.secondValue = @"qux";
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testQueryParamString{
    ODQueryParameters *firstParam = [[ODQueryParameters alloc] initWithKey:self.firstKey value:self.firstValue];
    NSMutableString *queryString = [NSMutableString stringWithString:@""];
    [firstParam appendOption:nil queryParams:queryString];
    XCTAssertEqualObjects(queryString, @"?foo=bar");
    
    ODQueryParameters *secondParam = [[ODQueryParameters alloc] initWithKey:self.secondKey value:self.secondValue];
    [secondParam appendOption:nil queryParams:queryString];
    XCTAssertEqualObjects(queryString, @"?foo=bar&baz=qux");
}

- (void)testHeaderOptions{
    ODHeaderOptions *firstHeader = [[ODHeaderOptions alloc] initWithKey:self.firstKey value:self.firstValue];
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    [firstHeader appendOption:headers queryParams:nil];
    
    XCTAssertEqualObjects(headers[self.firstKey], self.firstValue);
}

@end
