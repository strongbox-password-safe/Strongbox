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
#import "ODPersonalAuthProvider.h"
#import "ODAuthHelper.h"
#import "NSJSONSerialization+ResponseHelper.h"
#import "ODAuthProvider+Protected.h"
#import "ODAccountStoreProtocol.h"
#import "ODAccountSession.h"
#import "ODServiceInfo.h"

@interface ODPersonalAuthProvider()


- (void)refreshSession:(ODAccountSession *)session withCompletion:(void (^)(ODAccountSession *updatedSession, NSError *error))completion;

- (ODAccountSession *) accountSessionWithData:(NSData *)data response:(NSHTTPURLResponse *)resposne error:(NSError * __autoreleasing *)error;

@end

@interface ODPersonalAuthProviderTests : ODTestCase

@property id <ODAccountStore> mockStore;

@end

@implementation ODPersonalAuthProviderTests

- (void)setUp {
    [super setUp];
    self.mockStore = OCMProtocolMock(@protocol(ODAccountStore));
}
- (void)testRefreshSessionSuccess
{
    id mockData = OCMStrictClassMock([NSData class]);
    id mockresponse = OCMStrictClassMock([NSHTTPURLResponse class]);
    NSDictionary *resposneDictionary = @{};
    NSError *error = nil;
   
    id mockUpdatedSession = OCMStrictClassMock([ODAccountSession class]);
    OCMStub([mockUpdatedSession refreshToken]).andReturn(@"foo");
    [self refreshSessionWithUpatedSession:mockUpdatedSession refreshData:mockData urlResponse:mockresponse error:error responseDictionary:resposneDictionary completion:^(ODAccountSession *session, NSError *error){
        XCTAssertEqual(session, mockUpdatedSession);
        XCTAssertNil(error);
    }];
}

- (void)testRefreshSessionNetworkError
{
    NSError *networkError = [NSError errorWithDomain:@"test" code:42 userInfo:@{}];
    id mockUpdatedSession = OCMStrictClassMock([ODAccountSession class]);
    OCMStub([mockUpdatedSession refreshToken]).andReturn(@"foo");
    
    [self refreshSessionWithUpatedSession:mockUpdatedSession refreshData:nil urlResponse:nil error:networkError responseDictionary:nil completion:^(ODAccountSession *session, NSError *error){
        XCTAssertNil(session);
        XCTAssertEqual(error, networkError);
    }];
}

- (void)testRefreshSessionMalformedResponse
{
    NSDictionary *resposne = nil;
    id mockUpdatedSession = OCMStrictClassMock([ODAccountSession class]);
    OCMStub([mockUpdatedSession refreshToken]).andReturn(@"foo");
    
    [self refreshSessionWithUpatedSession:mockUpdatedSession refreshData:nil urlResponse:nil error:nil responseDictionary:resposne completion:^(ODAccountSession *session, NSError *error){
        XCTAssertNil(session);
    }];
}

- (void)testGetTokenWithCodeRefreshSuccess
{
    id mockSession = OCMStrictClassMock([ODAccountSession class]);
    OCMExpect([mockSession refreshToken]);
    
    OCMExpect([self.mockStore storeCurrentAccount:mockSession]);
    
    [self getTokenWithCode:@"foo" responseSession:mockSession responseError:nil completion:^(NSError *error){
        XCTAssertNil(error);
        OCMVerify(mockSession);
        OCMVerify(self.mockStore);
    }];
}

-(void)testGetTokenWithCodeError
{
    NSError *responseError = [NSError errorWithDomain:@"test" code:42 userInfo:@{}];
    [self getTokenWithCode:@"foo" responseSession:nil responseError:responseError completion:^(NSError *error){
        XCTAssertEqual(error, responseError);
    }];
}

- (void)getTokenWithCode:(NSString *)code
         responseSession:(ODAccountSession *)session
           responseError:(NSError *)error
              completion:(AuthCompletion)completion
{
    id mockTask = OCMStrictClassMock([NSURLSessionDataTask class]);
    OCMExpect([mockTask resume]);
    
    id mockRequest = OCMStrictClassMock([NSURLRequest class]);
    
    id mockServiceInfo = OCMStrictClassMock([ODServiceInfo class]);
    OCMStub([mockServiceInfo appId]).andReturn(@"bar");
    OCMStub([mockServiceInfo tokenURL]).andReturn(@"https://tokenurl.com");
    OCMStub([mockServiceInfo redirectURL]).andReturn(@"https://redirectURL.com");
    
    id mockProvider = OCMPartialMock([[ODPersonalAuthProvider alloc] initWithServiceInfo:mockServiceInfo httpProvider:self.mockSession accountStore:self.mockStore logger:nil]);
    OCMStub([mockProvider accountSessionWithData:[OCMArg any] response:[OCMArg any] error:[OCMArg anyObjectRef]]).andReturn(session);
    
    [self dataTaskCompletionWithRequest:mockRequest data:nil response:nil error:error];
    
    [mockProvider getTokenWithCode:code completion:completion];
    
    OCMVerify(mockTask);
}

- (void)refreshSessionWithUpatedSession:(ODAccountSession *)session
                            refreshData:(NSData *)data
                            urlResponse:(NSHTTPURLResponse *)urlResponse
                                  error:(NSError *)error
                     responseDictionary:(NSDictionary *)resposneDictionary
                             completion:(void (^)(ODAccountSession *session, NSError *error))completionHandler
{
    id mockTask = OCMStrictClassMock([NSURLSessionDataTask class]);
    OCMExpect([mockTask resume]);
    
    id mockRequest = OCMStrictClassMock([NSURLRequest class]);
    
    id mockServiceInfo = OCMStrictClassMock([ODServiceInfo class]);
    OCMStub([mockServiceInfo appId]).andReturn(@"bar");
    OCMStub([mockServiceInfo tokenURL]).andReturn(@"https://tokenurl.com");
    
    id mockAuthHelper = OCMStrictClassMock([ODAuthHelper class]);
    OCMStub([mockAuthHelper sessionDictionaryWithResponse:[OCMArg any] data:[OCMArg any] error:[OCMArg anyObjectRef]]).andReturn(resposneDictionary);
    OCMStub([mockAuthHelper accountSessionWithResponse:resposneDictionary serviceInfo:mockServiceInfo]).andReturn(session);
    
    
    [self dataTaskCompletionWithRequest:mockRequest data:data response:urlResponse error:error];
    
    ODPersonalAuthProvider *authProvider = [[ODPersonalAuthProvider alloc] initWithServiceInfo:mockServiceInfo httpProvider:self.mockSession accountStore:self.mockStore logger:nil];
    
    [authProvider refreshSession:session withCompletion:completionHandler];
    
    OCMVerify(mockTask);
    [mockAuthHelper stopMocking];
}

@end
