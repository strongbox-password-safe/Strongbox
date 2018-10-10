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
#import "NSJSONSerialization+ResponseHelper.h"
#import "ODError.h"
#import "NSError+OneDriveSDK.h"

@interface NSJSONSerializationTests : ODTestCase

@property NSHTTPURLResponse *testResponse;

@end

@implementation NSJSONSerializationTests

- (void)setUp {
    [super setUp];
    self.testResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:200 HTTPVersion:@"foo" headerFields:nil];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testBuildResponseWithNilHttpResponse{
    XCTAssertThrows([NSJSONSerialization dictionaryWithResponse:nil responseData:nil error:nil]);
}

- (void)testBuildResponseWithNilData{
    NSDictionary *response = [NSJSONSerialization dictionaryWithResponse:self.testResponse responseData:nil error:nil];
    XCTAssertNil(response);
}

- (void)testBuildResponseWithBadData{
    NSData *badData = [NSData dataWithBytes:@"foo {{{" length:7];
    NSError *error = nil;
    NSDictionary *response = [NSJSONSerialization dictionaryWithResponse:self.testResponse responseData:badData error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testBuildResponseWithValidResponse{
    NSString *key = @"key";
    NSDictionary *responseDictionary = @{ key : @"value" };
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseDictionary options:0 error:nil];
    NSError *error = nil;
    NSDictionary *response = [NSJSONSerialization dictionaryWithResponse:self.testResponse responseData:responseData error:&error];
    XCTAssertEqualObjects(response[key], responseDictionary[key]);
}

- (void)testBuildResponseWithValidResponseNilError{
    NSString *key = @"key";
    NSDictionary *responseDictionary = @{ key : @"value" };
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseDictionary options:0 error:nil];
    NSDictionary *response = [NSJSONSerialization dictionaryWithResponse:self.testResponse responseData:responseData error:nil];
    XCTAssertEqualObjects(response[key], responseDictionary[key]);
}

- (void)testBuildResponseWithError{
    NSHTTPURLResponse *errorResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:ODBadRequest HTTPVersion:@"foo" headerFields:nil];
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:@{ @"error" : @{ @"code" : ODInvalidRequestError, @"message" : @"foo bar baz"} } options:0 error:nil];
    NSError *error = nil;
    NSDictionary *response = [NSJSONSerialization dictionaryWithResponse:errorResponse responseData:responseData error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertTrue([error isClientError]);
    XCTAssertNotNil([error clientError]);
}


- (void)testErrorFromResponseNilResponse{
    XCTAssertThrows([NSJSONSerialization errorFromResponse:nil responseObject:nil]);
}

- (void)testErrorFromResponseNilObject{
    NSHTTPURLResponse *errorResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:ODBadRequest HTTPVersion:@"foo" headerFields:nil];
    NSError *error = [NSJSONSerialization errorFromResponse:errorResponse responseObject:@{}];
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, ODErrorDomain);
    XCTAssertEqual(error.code, ODBadRequest);
}

- (void)testNoErrorFromValidResponse{
    XCTAssertNil([NSJSONSerialization errorFromResponse:self.testResponse responseObject:@{}]);
}


@end
