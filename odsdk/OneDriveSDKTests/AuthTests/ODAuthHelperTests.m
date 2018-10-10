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
#import "ODAuthHelper.h"
#import "ODAuthConstants.h"
#import "ODAccountSession.h"
#import "ODServiceInfo.h"
#import "NSError+OneDriveSDK.h"

@interface ODAuthHelperTests : ODTestCase

@end

@implementation ODAuthHelperTests

- (void)testAccountSessionWithValidResponseNoRefreshToken{
    NSDictionary *responseDictionary = @{OD_AUTH_EXPIRES : @"0",
                                         OD_AUTH_ACCESS_TOKEN : @"foo",
                                         OD_AUTH_USER_ID : @"bar"
                                         };
    id mockServiceInfo = OCMStrictClassMock([ODServiceInfo class]);
    
    ODAccountSession *session = [self accountSessionWithMockResponse:responseDictionary
                                                     mockServiceInfo:mockServiceInfo];
    
    XCTAssertEqualObjects(session.accountId, responseDictionary[OD_AUTH_USER_ID]);
    XCTAssertEqualObjects(session.accessToken, responseDictionary[OD_AUTH_ACCESS_TOKEN]);
    XCTAssertEqual(session.serviceInfo, mockServiceInfo);
    XCTAssertNil(session.refreshToken);
}

- (void)testAccountSessionWithValidResponseAndRefreshToken{
    
    id mockServiceInfo = OCMStrictClassMock([ODServiceInfo class]);
    NSDictionary *responseDictionary = @{OD_AUTH_EXPIRES : @"0",
                                        OD_AUTH_ACCESS_TOKEN : @"foo",
                                             OD_AUTH_USER_ID : @"bar",
                                        OD_AUTH_REFRESH_TOKEN : @"baz"};
    
    ODAccountSession *session = [self accountSessionWithMockResponse:responseDictionary
                                                     mockServiceInfo:mockServiceInfo];
    
    XCTAssertEqualObjects(session.accountId, responseDictionary[OD_AUTH_USER_ID]);
    XCTAssertEqualObjects(session.accessToken, responseDictionary[OD_AUTH_ACCESS_TOKEN]);
    XCTAssertEqualObjects(session.refreshToken, responseDictionary[OD_AUTH_REFRESH_TOKEN]);
    XCTAssertEqual(session.serviceInfo, mockServiceInfo);
}

- (void)testSessionDictionaryWithInvalidResposne
{
    NSHTTPURLResponse *badRequest = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:400 HTTPVersion:@"test" headerFields:nil];
    NSError *error = nil;
    
    NSDictionary *responseDictionary = [ODAuthHelper sessionDictionaryWithResponse:badRequest data:nil error:&error];
    XCTAssertNil(responseDictionary);
    XCTAssertNotNil(error);
    XCTAssertTrue([error isAuthenticationError]);
    XCTAssertEqualObjects(error.userInfo[OD_AUTH_ERROR_KEY], @(400));
}

- (void)testSessionDictionaryWithMalformedResposne
{
    NSHTTPURLResponse *okResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:200 HTTPVersion:@"test" headerFields:nil];
    NSError *error = nil;
    NSData *badData = [@"foo bar baz" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *responseDictionary = [ODAuthHelper sessionDictionaryWithResponse:okResponse data:badData error:&error];
    
    XCTAssertNil(responseDictionary);
    XCTAssertNotNil(error);
    XCTAssertTrue([error isAuthenticationError]);
    XCTAssertEqual(error.code, ODSerializationError);
}

- (void)testSessionDictionaryWithValidResponse
{
    NSHTTPURLResponse *okResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:200 HTTPVersion:@"test" headerFields:nil];
    NSError *error = nil;
    NSDictionary *responseDictionary = @{OD_AUTH_EXPIRES : @"0",
                                         OD_AUTH_ACCESS_TOKEN : @"foo",
                                         OD_AUTH_USER_ID : @"bar",
                                         OD_AUTH_REFRESH_TOKEN : @"baz"
                                         };
    
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseDictionary options:0 error:nil];
    NSDictionary *actualResponse = [ODAuthHelper sessionDictionaryWithResponse:okResponse data:responseData error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(actualResponse, responseDictionary);
    
}


- (void)testRequestWithGetNoParamsNoHeaders
{
    NSURLRequest *request = [ODAuthHelper requestWithMethod:@"GET" URL:self.testBaseURL parameters:nil headers:nil];
    XCTAssertNil(request.allHTTPHeaderFields);
    XCTAssertEqualObjects(request.URL, self.testBaseURL);
}

- (void)testRequestGetParamsNoHeaders
{
    NSDictionary *params = @{@"foo" : @"bar"};
    NSURLRequest *request = [ODAuthHelper requestWithMethod:@"GET" URL:self.testBaseURL parameters:params headers:nil];
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:[self.testBaseURL absoluteString]];
    urlComponents.query = @"foo=bar";
    
    XCTAssertNil(request.allHTTPHeaderFields);
    XCTAssertEqualObjects(urlComponents.URL, request.URL);
}

- (void)testRequestGetParamsHeaders
{
    NSDictionary *params = @{@"foo" : @"bar"};
    NSURLRequest *request = [ODAuthHelper requestWithMethod:@"GET" URL:self.testBaseURL parameters:params headers:params];
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:[self.testBaseURL absoluteString]];
    urlComponents.query = @"foo=bar";
    
    XCTAssertEqualObjects(urlComponents.URL, request.URL);
    XCTAssertEqual([params count], [request.allHTTPHeaderFields count]);
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop){
        XCTAssertEqualObjects(request.allHTTPHeaderFields[key], value);
    }];
}

- (void)testRequestPostNoParamsNoheaders
{
    NSURLRequest *request = [ODAuthHelper requestWithMethod:@"POST" URL:self.testBaseURL parameters:nil headers:nil];
    
    XCTAssertEqualObjects(request.allHTTPHeaderFields, @{});
    XCTAssertNil(request.HTTPBody);
    XCTAssertEqualObjects(request.URL, self.testBaseURL);
}

- (void)testReuqestPostParamsHeaders
{
     NSDictionary *params = @{@"foo" : @"bar"};
    NSURLRequest *request = [ODAuthHelper requestWithMethod:@"POST" URL:self.testBaseURL parameters:params headers:params];
    
    XCTAssertEqualObjects(self.testBaseURL, request.URL);
    XCTAssertEqual([params count], [request.allHTTPHeaderFields count]);
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop){
        XCTAssertEqualObjects(request.allHTTPHeaderFields[key], value);
    }];
    
    NSData *body = [@"foo=bar" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(body, request.HTTPBody);
}

- (void)testEncodeURLParamsNilParams{
    XCTAssertThrows([ODAuthHelper encodeQueryParameters:nil]);
}

- (void)testEncodeURLParamsEmptyParams{
    XCTAssertEqualObjects([ODAuthHelper encodeQueryParameters:@{}], @"");
}

- (void)testEncodeURLParamsValidParams{
    NSString *keyFoo = @"foo";
    NSString *valueBar = @"bar";
    
    NSString *keyBaz = @"baz";
    NSString *valueQux = @"qux";
    NSDictionary *params = @{ keyFoo : valueBar, keyBaz : valueQux };
    NSString *paramString = [NSString stringWithFormat:@"%@=%@&%@=%@", keyFoo, valueBar, keyBaz, valueQux];
    XCTAssertEqualObjects([ODAuthHelper encodeQueryParameters:params], paramString);
}

- (void)testDecodeURLParamsNilURL{
    XCTAssertThrows([ODAuthHelper decodeQueryParameters:nil]);
}

- (void)testDecodeURLParamsNoParams{
    XCTAssertEqualObjects([ODAuthHelper decodeQueryParameters:self.testBaseURL], @{});
}

- (void)testDecodeURLParamsValidParams{
    NSString *keyFoo = @"foo";
    NSString *valueBar = @"bar";
    
    NSString *keyBaz = @"baz";
    NSString *valueQux = @"qux";
    NSURL *testURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@=%@&%@=%@", [self.testBaseURL absoluteString], keyFoo, valueBar, keyBaz, valueQux]];
    NSDictionary *params = @{ keyFoo : valueBar, keyBaz : valueQux };
    XCTAssertEqualObjects([ODAuthHelper decodeQueryParameters:testURL], params);
}

/**
 Calls accountSessionWithResposne:serviceInfo with mocked NSDate and datetimestring
 @param response the mockResponse from the service to pass to the accountSessionWithResponse:serviceInfo: method
 @param mockServiceInfo the mock service info to pass to the accountSessionWithResponse:serviceInfo: method
 @warning Asserts the expiresDate on the session is correct
 */
- (ODAccountSession *)accountSessionWithMockResponse:(NSDictionary *)responseDictionary mockServiceInfo:(ODServiceInfo *)mockServiceInfo
{
    NSDate *expiresDate = [NSDate dateWithTimeIntervalSince1970:0];
    id dateMock = OCMClassMock([NSDate class]);
    NSString *dateTimeString = [NSDateFormatter localizedStringFromDate:expiresDate dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterFullStyle];
    
    OCMStub([dateMock dateWithTimeIntervalSinceNow:0]).andReturn(expiresDate);
    ODAccountSession *session = [ODAuthHelper accountSessionWithResponse:responseDictionary serviceInfo:mockServiceInfo];
    [dateMock stopMocking];
    if (session.expires){
        NSString *expiresDateString = [NSDateFormatter localizedStringFromDate:session.expires dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterFullStyle];
        XCTAssertEqualObjects(dateTimeString, expiresDateString);
    }
    return session;
}



@end
