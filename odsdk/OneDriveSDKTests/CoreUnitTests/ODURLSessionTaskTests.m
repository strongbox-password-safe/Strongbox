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
#import "ODURLSessionDataTask.h"
#import "ODURLSessionDownloadTask.h"
#import "ODURLSessionUploadTask.h"
#import "ODAsyncURLSessionDataTask.h"
#import "NSError+OneDriveSDK.h"
#import "NSJSONSerialization+ResponseHelper.h"
#import "ODError.h"

/*
 iOS 9 changed NSURLSessionDataTask properties to dynamic, OCMock does not support mocking dynamic properties in 
 the current release (3.1.5) but will in 3.2, for now we will create a mock task ourselves.
 See commit (https://github.com/erikdoe/ocmock/commit/8556be0d744d4a4c770ce73416035885dc6c7871) for changes.
 */
@interface NSURLSessionDataTask(Test)

@property (readonly) NSUInteger taskIdentifier;

@end

@implementation NSURLSessionDataTask (Test)

- (NSUInteger)taskIdentifier
{
    return 0;
}

@end

@interface ODAsyncURLSessionDataTask()

@property NSMutableURLRequest *monitorRequest;

@property (strong) ODAsyncActionCompletion asyncActionCompletion;

- (void)onRequestStarted:(NSURLResponse *)response
                   error:(NSError *)error;

- (void)sendMonitorRequest:(NSMutableURLRequest *)request;

- (void)onMonitorRequestResponse:(NSDictionary *)response
                    httpResponse:(NSHTTPURLResponse *)httpResponse
                           error:(NSError *)error;

@end

@interface ODURLSessionTask()

- (NSURLSessionTask *)taskWithRequest:(NSMutableURLRequest*)request;

@end

@interface ODURLSessionTaskTests : ODTestCase

@property NSMutableURLRequest *mockRequest;

@end

@implementation ODURLSessionTaskTests

- (void)setUp {
    [super setUp];
    self.mockRequest = [[NSMutableURLRequest alloc] initWithURL:self.testBaseURL];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitFailsWithNilClient{
    XCTAssertThrows([[ODURLSessionTask alloc] initWithRequest:[NSMutableURLRequest requestWithURL:self.testBaseURL] client:nil]);
}

- (void)testInitFailsWithNilRequest{
    XCTAssertThrows([[ODURLSessionTask alloc] initWithRequest:nil client:self.mockClient]);
}

- (void)testTaskFailedAuth {
    __block NSError *authError = [NSError errorWithDomain:@"autherror" code:123 userInfo:@{}];
    [self setAuthProvider:self.mockAuthProvider appendHeaderResponseWith:nil error:authError];
    
    __block ODURLSessionDataTask *dataTask = [[ODURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:^(NSDictionary *request, NSError *error){
        XCTAssertEqual(authError, error);
    }];
    XCTAssertEqual(dataTask.state, ODTaskCreated);
    [dataTask execute];
    XCTAssertEqual(dataTask.state, ODTaskAuthFailed);
}

- (void)testTaskDidStart{
    [self setAuthProvider:self.mockAuthProvider appendHeaderResponseWith:self.mockRequest error:nil];
    id mockTask = OCMStrictClassMock([NSURLSessionDataTask class]);
    OCMStub([mockTask taskIdentifier]).andReturn(1);

    __block ODURLSessionDataTask *dataTask = [[ODURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:nil];
    
    ODURLSessionDataTask *mockDataTask = OCMPartialMock(dataTask);
    OCMStub([mockDataTask taskWithRequest:[OCMArg any]])
    .andReturn(mockTask);
    
    
     OCMStub([mockTask resume])
    .andDo(^(NSInvocation *invocation){
    });
    
    [mockDataTask execute];
    XCTAssertEqual(mockDataTask.state, ODTaskExecuting);
    OCMVerify([mockTask resume]);
    OCMVerify([mockDataTask taskWithRequest:[OCMArg any]]);
}

- (void)testDataTaskAuthFailedWithoutCompletion{
    __block NSError *authError = [NSError errorWithDomain:@"authError" code:123 userInfo:@{}];
    [self setAuthProvider:self.mockAuthProvider appendHeaderResponseWith:nil error:authError];
    
    ODURLSessionDataTask *dataTask = [[ODURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient];
    
    XCTAssertNoThrow([dataTask execute]);
}

- (void)testDataTaskCompletionHandlerWithError{
    
    __block NSError *connectionError = [NSError errorWithDomain:@"connectionError" code:123 userInfo:@{}];
    self.mockRequest.HTTPMethod = @"PUT";
    [self setAuthProvider:self.mockAuthProvider appendHeaderResponseWith:self.mockRequest error:nil];
    [self dataTaskCompletionWithRequest:self.mockRequest data:nil response:nil error:connectionError];
    ODURLSessionDataTask *dataTask = [[ODURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:^(NSDictionary *response, NSError *error){
        XCTAssertNil(response);
        XCTAssertEqual(error, connectionError);
    }];
    
    [dataTask taskWithRequest:self.mockRequest];
    // append content type for non GET requests
    XCTAssertNotNil(self.mockRequest.allHTTPHeaderFields[@"Content-Type"]);
    OCMVerify([self.mockSession dataTaskWithRequest:self.mockRequest completionHandler:[OCMArg any]]);
}

- (void)testDataTaskWithNoCompletionHandler{
    [self setAuthProvider:self.mockAuthProvider appendHeaderResponseWith:self.mockRequest error:nil];
    
    OCMStub([self.mockSession dataTaskWithRequest:self.mockRequest completionHandler:[OCMArg any]])
    .andDo(^(NSInvocation *invocation){
        ODDataCompletionHandler completionHandler;
        [invocation getArgument:&completionHandler atIndex:3];
        completionHandler(nil, nil, nil);
    });
    
    ODURLSessionDataTask *dataTask = [[ODURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient];
    
    XCTAssertNoThrow([dataTask execute]);
    OCMVerify([self.mockSession dataTaskWithRequest:self.mockRequest completionHandler:[OCMArg any]]);
}

- (void)testDataTaskCompletionHandlerWithValidResponse{
    NSDictionary *responseBody = @{@"foo" : @"bar" };
    __block NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];
    __block NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:200 HTTPVersion:@"foo" headerFields:nil];
    
    id mockHelper = OCMClassMock([NSJSONSerialization class]);
    OCMStub([mockHelper dictionaryWithResponse:response responseData:responseData error:[OCMArg anyObjectRef]];)
    .andReturn(responseBody);
   
    [self dataTaskCompletionWithRequest:self.mockRequest data:responseData response:response error:nil];
    
    __block ODURLSessionDataTask *dataTask = [[ODURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:^(NSDictionary *responseDict, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(responseBody, responseDict);
    }];
    
    [dataTask taskWithRequest:self.mockRequest];
    XCTAssertEqual(dataTask.state, ODTaskCompleted);
    OCMVerify([mockHelper dictionaryWithResponse:response responseData:responseData error:[OCMArg anyObjectRef]]);
    [mockHelper stopMocking];
}

- (void)testDataTaskCompletionHandlerWith304Response{
    __block NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:304 HTTPVersion:@"foo" headerFields:nil];
    
    
    [self dataTaskCompletionWithRequest:self.mockRequest data:nil response:response error:nil];
    ODURLSessionDataTask *dataTask = [[ODURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:^(NSDictionary *responseDict, NSError *error){
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 304);
        XCTAssertNil(responseDict);
    }];
    
    [dataTask taskWithRequest:self.mockRequest];
    XCTAssertEqual(dataTask.state, ODTaskCompleted);
}

- (void)testDownloadTaskCompletionHandler{
    __block NSURL *fileLocation = [NSURL URLWithString:@"foo/bar/baz"];
    __block NSHTTPURLResponse *validResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:200 HTTPVersion:@"foo" headerFields:@{}];
    __block NSProgress *mockProgress;
    [self mockURLSession:self.mockSession downloadTaskCompletionWithRequest:self.mockRequest progress:mockProgress url:fileLocation response:validResponse error:nil];
    
    ODURLSessionDownloadTask *downloadTask = [[ODURLSessionDownloadTask alloc] initWithRequest:self.mockRequest client:self.mockClient completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(location, fileLocation);
        XCTAssertEqual(validResponse, response);
    }];
    
    
    [downloadTask taskWithRequest:self.mockRequest];
    XCTAssertEqual(downloadTask.state, ODTaskCompleted);
}

- (void)testDownloadTaskFailedWithBadResponse{
    __block NSURL *fileLocation = [NSURL URLWithString:@"foo/bar/baz"];
    __block NSHTTPURLResponse *badRequest = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:400 HTTPVersion:@"test" headerFields:@{}];
    [self mockURLSession:self.mockSession downloadTaskCompletionWithRequest:self.mockRequest progress:nil url:fileLocation response:badRequest error:nil];
    
    ODURLSessionDownloadTask *downloadTask = [[ODURLSessionDownloadTask alloc] initWithRequest:self.mockRequest client:self.mockClient completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error){
        XCTAssertNil(location);
        XCTAssertEqual(error.code, 400);
        XCTAssertEqual(response, badRequest);
    }];
    
    [downloadTask taskWithRequest:self.mockRequest];
    XCTAssertEqual(downloadTask.state, ODTaskCompleted);
}

-(void)testDownloadTaskReceived304
{

    __block NSURL *fileLocation = [NSURL URLWithString:@"foo/bar/baz"];
    __block NSHTTPURLResponse *notModifiedResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:304 HTTPVersion:@"foo" headerFields:@{}];
    
    [self mockURLSession:self.mockSession downloadTaskCompletionWithRequest:self.mockRequest progress:nil url:fileLocation response:notModifiedResponse error:nil];
    ODURLSessionDownloadTask *downloadTask = [[ODURLSessionDownloadTask alloc] initWithRequest:self.mockRequest client:self.mockClient completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertNil(location);
        XCTAssertEqual(response, notModifiedResponse);
    }];
    
    [downloadTask taskWithRequest:self.mockRequest];
    
    XCTAssertEqual(downloadTask.state, ODTaskCompleted);
}

- (void)testUploadTaskWithEmptyData{
    __block NSData *emptyData = [NSJSONSerialization dataWithJSONObject:@{} options:0 error:nil];
    __block NSHTTPURLResponse *createdResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:201 HTTPVersion:@"foo" headerFields:@{}];
    
    [self mockURLSession:self.mockSession uploadTaskCompletionWithRequest:self.mockRequest progress:nil data:emptyData response:createdResponse error:nil];
    ODURLSessionUploadTask *uploadTask = [[ODURLSessionUploadTask alloc] initWithRequest:self.mockRequest fromFile:self.testBaseURL client:self.mockClient completionHandler:^(NSDictionary *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqualObjects(response, @{});
    }];
    [uploadTask taskWithRequest:self.mockRequest];
    
    XCTAssertEqual(uploadTask.state, ODTaskCompleted);
}

- (void)testUploadTaskFailedWith404{
    __block NSHTTPURLResponse *notFound = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:404 HTTPVersion:@"foo" headerFields:nil];
    
    [self mockURLSession:self.mockSession uploadTaskCompletionWithRequest:self.mockRequest progress:nil data:nil response:notFound error:nil];
    
    ODURLSessionUploadTask *uploadTask = [[ODURLSessionUploadTask alloc] initWithRequest:self.mockRequest fromFile:self.testBaseURL client:self.mockClient completionHandler:^(NSDictionary *response, NSError *error){
        XCTAssertEqualObjects(error.domain, ODErrorDomain);
        XCTAssertEqual(error.code, ODNotFound);
    }];
    
    [uploadTask taskWithRequest:self.mockRequest];
    XCTAssertEqual(uploadTask.state, ODTaskCompleted);
}

- (void)testAsyncErrorOnCreation{
    __block NSError *mockError = [NSError errorWithDomain:ODErrorDomain code:ODBadRequest userInfo:@{}];
    
    [self mockURLSession:self.mockSession dataTaskCompletionWithRequest:self.mockRequest data:nil response:nil error:mockError];
    
    ODAsyncURLSessionDataTask *asyncTask = [[ODAsyncURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:^(id response, ODAsyncOperationStatus *status, NSError *error){
        XCTAssertNil(response);
        XCTAssertNil(status);
        XCTAssertEqual(mockError, error);
    }];
    
    [asyncTask taskWithRequest:self.mockRequest];
}

- (void)testAsyncTaskClientErrorOnCreation{
    __block NSHTTPURLResponse *notFound = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:ODNotFound HTTPVersion:@"foO" headerFields:@{}];
    __block NSDictionary *userInfo = @{ @"foo" : @"Bar"};
    __block NSData *responseData = [NSJSONSerialization dataWithJSONObject:userInfo  options:0 error:nil];
    
    [self mockURLSession:self.mockSession dataTaskCompletionWithRequest:self.mockRequest data:responseData response:notFound error:nil];
    ODAsyncURLSessionDataTask *asyncTask = [[ODAsyncURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:^(id response, ODAsyncOperationStatus *status, NSError *error){
        XCTAssertNil(response);
        XCTAssertNil(status);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, ODNotFound);
        XCTAssertNotNil([error clientError]);
        XCTAssertTrue([[error clientError] matches:ODMalformedErrorResponseError]);
    }];
    [asyncTask taskWithRequest:self.mockRequest];
}

- (void)testAsyncTaskServiceUnknownResponse{
    __block NSHTTPURLResponse *notModified = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:ODNotModified HTTPVersion:@"foO" headerFields:@{}];
    
    [self mockURLSession:self.mockSession dataTaskCompletionWithRequest:self.mockRequest data:nil response:notModified error:nil];
    
    ODAsyncURLSessionDataTask *asyncTask = [[ODAsyncURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:^(id response, ODAsyncOperationStatus *status, NSError *error){
        XCTAssertNil(response);
        XCTAssertNil(status);
    //    XCTAssertEqual(error.code, ODUnexpectedResponse);
    }];
    
    [asyncTask taskWithRequest:self.mockRequest];
}

- (void)testAsyncTaskValidAsyncSessionCreated{
    __block NSHTTPURLResponse *accepted = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:ODAccepted HTTPVersion:@"foo" headerFields:@{ @"Location" : [self.testBaseURL absoluteString]}];
    
    
    ODAsyncURLSessionDataTask *asyncTask = [[ODAsyncURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:nil];
    ODAsyncURLSessionDataTask *mockTask = OCMPartialMock(asyncTask);
    OCMStub([mockTask sendMonitorRequest:[OCMArg any]]);
    [mockTask onRequestStarted:accepted error:nil];
    OCMVerify([mockTask sendMonitorRequest:[OCMArg checkWithBlock:^(NSMutableURLRequest *request){
        return [[request.URL absoluteString] isEqualToString:[self.testBaseURL absoluteString]];
    }]]);
}

- (void)testAsyncTaskOnMonitorRequestError{
    ODAsyncURLSessionDataTask *asyncTask = [[ODAsyncURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient];
    __block NSError *unknownError = [NSError errorWithDomain:ODErrorDomain code:ODUnknownError userInfo:@{}];
    
    asyncTask.asyncActionCompletion = ^(NSDictionary *response, ODAsyncOperationStatus *status, NSError *error){
        XCTAssertNil(response);
        XCTAssertNil(status);
        XCTAssertEqual(error, unknownError);
    };
    
    [asyncTask onMonitorRequestResponse:nil httpResponse:nil error:unknownError];
}

- (void)testAsyncTaskValidMonitorUpdate{
    ODAsyncURLSessionDataTask *asyncTask = [[ODAsyncURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:nil];
    ODAsyncOperationStatus *mockStatus = [[ODAsyncOperationStatus alloc] init];
    mockStatus.status = @"foo";
    mockStatus.percentageComplete = 42;
    mockStatus.operation = @"bar";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:ODAccepted HTTPVersion:@"foo" headerFields:nil];
    
    ODAsyncURLSessionDataTask *mockTask = OCMPartialMock(asyncTask);
    mockTask.monitorRequest = self.mockRequest;
    OCMStub([mockTask sendMonitorRequest:[OCMArg any]]);
    
    
    mockTask.asyncActionCompletion = ^(NSDictionary *response, ODAsyncOperationStatus *status, NSError *error){
        XCTAssertNil(response);
        XCTAssertNil(error);
        XCTAssertEqualObjects(status.status, mockStatus.status);
        XCTAssertEqualObjects(status.operation, mockStatus.operation);
        XCTAssertEqual(status.percentageComplete, mockStatus.percentageComplete);
     };
    [mockTask onMonitorRequestResponse:[mockStatus dictionaryFromItem] httpResponse:response error:nil];
    XCTAssertEqual(mockTask.progress.completedUnitCount, mockStatus.percentageComplete);
    OCMVerify([mockTask sendMonitorRequest:self.mockRequest]);
}

- (void)testAsyncTaskValidItemReturned{
    ODItem *mockItem = [[ODItem alloc] init];
    mockItem.name = @"foo";
    mockItem.id = @"bar";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:ODOK HTTPVersion:@"foo" headerFields:nil];
    
    ODAsyncURLSessionDataTask *asyncTask = [[ODAsyncURLSessionDataTask alloc] initWithRequest:self.mockRequest
                                                                                       client:self.mockClient
                                                                                   completion:^(NSDictionary *dictionary, ODAsyncOperationStatus *status, NSError *error){
        XCTAssertNil(status);
        XCTAssertNil(error);
        XCTAssertNotNil(dictionary);
        ODItem *receivedItem = [[ODItem alloc] initWithDictionary:dictionary];
        XCTAssertEqualObjects(receivedItem.id, mockItem.id);
        XCTAssertEqualObjects(receivedItem.name, mockItem.name);
    }];
    [asyncTask onMonitorRequestResponse:[mockItem dictionaryFromItem] httpResponse:response error:nil];
    XCTAssertEqual(asyncTask.progress.completedUnitCount, 100);
    XCTAssertEqual(asyncTask.state, ODTaskCompleted);
}

- (void)testAsyncTaskInvalidResponse{
    ODAsyncURLSessionDataTask *asyncTask = [[ODAsyncURLSessionDataTask alloc] initWithRequest:self.mockRequest client:self.mockClient completion:^(NSDictionary *resposne, ODAsyncOperationStatus *status, NSError *error){
        XCTAssertNotNil(error);
    }];
    
    NSHTTPURLResponse *badResponse = [[NSHTTPURLResponse alloc] initWithURL:self.testBaseURL statusCode:42 HTTPVersion:@"foo" headerFields:@{}];
    [asyncTask onMonitorRequestResponse:nil httpResponse:badResponse error:nil];
}



@end
