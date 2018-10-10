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
#import "ODServiceInfo+Protected.h"
#import "ODAADServiceInfo.h"
#import "ODMSAServiceInfo.h"

@interface ODServiceInfoTests : ODTestCase

@property NSCoder *mockDecoder;

@end

@implementation ODServiceInfoTests

- (void)setUp {
    [super setUp];
    self.mockDecoder = OCMClassMock([NSCoder class]);
    OCMStub([self.mockDecoder decodeObjectForKey:@"apiEndpiint"]).andReturn(nil);
    OCMStub([self.mockDecoder decodeObjectForKey:@"resourceId"]).andReturn(OD_MICROSOFT_ACCOUNT_ENDPOINT);
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

/**
 Make sure the migrations from resourceId to apiEndpoint works
 */
- (void)testAADInitFromCoder{
    ODAADServiceInfo *serviceInfo = [[ODAADServiceInfo alloc] initWithCoder:self.mockDecoder];
    XCTAssertNotNil(serviceInfo.apiEndpoint);
    XCTAssertTrue([serviceInfo.apiEndpoint containsString:OD_ACTIVE_DIRECTORY_URL_SUFFIX]);
}

- (void)testMSAInitFromCoder{
    ODMSAServiceInfo *serviceInfo = [[ODMSAServiceInfo alloc] initWithCoder:self.mockDecoder];
    XCTAssertNotNil(serviceInfo.apiEndpoint);
    XCTAssertEqualObjects(serviceInfo.apiEndpoint, serviceInfo.resourceId);
}

@end
