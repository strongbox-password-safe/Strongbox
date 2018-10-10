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
#import "ODError.h"

@interface ODErrorTests : ODTestCase

@property NSDictionary *errorDictionary;

@end

@implementation ODErrorTests

- (void)setUp {
    [super setUp];
    self.errorDictionary =  @{ @"code" : ODAccessDeniedError,
                               @"message" : @"Foo Bar",
                                @"innererror" :
                                @{
                                       @"code" : ODGeneralExceptionError
                                 }
                                    
                             };
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testErrorWithDictionary {
    // This is an example of a functional test case.
    ODError *error = [ODError errorWithDictionary:self.errorDictionary];
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.code, ODAccessDeniedError);
    XCTAssertEqualObjects(error.innerError.code, ODGeneralExceptionError);
    XCTAssertNil(error.innerError.innerError);
}

- (void)testErrorMatches{
    ODError *error = [ODError errorWithDictionary:self.errorDictionary];
    XCTAssertTrue([error matches:ODGeneralExceptionError]);
    XCTAssertTrue([error matches:ODAccessDeniedError]);
    XCTAssertFalse([error matches:ODNotSupportedError]);
}

- (void)testMalformedError{
    ODError *error = [ODError errorWithDictionary:@{@"foo" : @"bar"}];
    XCTAssertTrue([error matches:ODMalformedErrorResponseError]);
}

@end
