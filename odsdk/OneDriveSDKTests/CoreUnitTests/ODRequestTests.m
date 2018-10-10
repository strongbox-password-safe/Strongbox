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
#import "ODURLSessioNDataTask.h"
#import "ODCollectionRequest.h"
#import "ODCollection.h"

@interface ODRequest (Test)

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      body:(NSData *)body
                                   headers:(NSDictionary *)headers;
@end

@interface ODURLSessionDataTask(Test)

@property (strong) void (^completionHandler)(NSDictionary *dictionary, NSError *error);

@end

@interface ODRequestTests : ODTestCase


@end
@implementation ODRequestTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInit{
    ODRequest *request = [[ODRequest alloc] initWithURL:self.testBaseURL client:[[ODClient alloc] init]];
    XCTAssertEqualObjects(request.requestURL, self.testBaseURL);
}

- (void)testRequestInitWithNilURL{
    XCTAssertThrows([[ODRequest alloc] initWithURL:nil client:nil]);
}

- (void)testRequestWithInvalidOptions{
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:self.testBaseURL];
    NSArray *invalidOptions = @[@"foo", @"Bar"];
    XCTAssertThrows([self requestWithURL:self.testBaseURL
                                 options:invalidOptions
                                  method:@"GET"
                                    body:nil
                            extraHeaders:nil
                         expectedRequest:expectedRequest]);
    
}

- (void)testRequestWithHeaderOptions{
    ODHeaderOptions *testHeaders = [[ODHeaderOptions alloc] initWithKey:@"foo" value:@"Bar"];
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:self.testBaseURL];
    
    [expectedRequest setValue:testHeaders.value forHTTPHeaderField:testHeaders.key];
    [self requestWithURL:self.testBaseURL
                 options:@[testHeaders]
                  method:@"GET"
                    body:nil
            extraHeaders:nil
         expectedRequest:expectedRequest];
    
}

- (void)testWithQueryParameters{
    ODQueryParameters *testParams = [[ODQueryParameters alloc] initWithKey:@"foo" value:@"bar"];
    NSURL *expectedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@=%@", [self.testBaseURL absoluteString],testParams.key, testParams.value]];
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:expectedURL];
    [self requestWithURL:self.testBaseURL
                 options:@[testParams]
                  method:@"GET"
                    body:nil
            extraHeaders:nil
         expectedRequest:expectedRequest];
}

- (void)testWithBody{
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:@{@"foo" : @"bar"} options:0 error:nil];
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:self.testBaseURL];
    expectedRequest.HTTPBody = bodyData;
    expectedRequest.HTTPMethod = @"POST";
    [self requestWithURL:self.testBaseURL
                 options:nil
                  method:@"POST"
                    body:bodyData
            extraHeaders:nil
         expectedRequest:expectedRequest];
}

- (void)testWithExtraHeaders{
    NSDictionary *extraHeaders = @{@"foo" : @"Bar" };
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:self.testBaseURL];
    expectedRequest.HTTPMethod = @"GET";
    [expectedRequest setValue:extraHeaders[@"foo"] forHTTPHeaderField:@"foo"];
    [self requestWithURL:self.testBaseURL
                 options:nil
                  method:@"GET"
                    body:nil
            extraHeaders:extraHeaders
         expectedRequest:expectedRequest];
}

- (void)testPutRequestWithAllComponents{
    NSDictionary *extraHeaders = @{@"baz" : @"qux" };
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:@{@"foo" : @"bar"} options:0 error:nil];
    ODQueryParameters *testParams = [[ODQueryParameters alloc] initWithKey:@"foo" value:@"bar"];
    ODHeaderOptions *testHeaders = [[ODHeaderOptions alloc] initWithKey:@"foo" value:@"Bar"];
    NSURL *expectedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@=%@", [self.testBaseURL absoluteString],testParams.key, testParams.value]];
    
    NSMutableURLRequest *expectedRequest = [NSMutableURLRequest requestWithURL:expectedURL];
    expectedRequest.HTTPBody = bodyData;
    expectedRequest.HTTPMethod = @"PUT";
    NSMutableDictionary *allHeaders =  [NSMutableDictionary dictionaryWithDictionary:extraHeaders];
    allHeaders[testHeaders.key] = testHeaders.value;
    expectedRequest.allHTTPHeaderFields = allHeaders;
    [self requestWithURL:self.testBaseURL
                 options:@[testHeaders, testParams]
                  method:@"PUT"
                    body:bodyData
            extraHeaders:extraHeaders
         expectedRequest:expectedRequest];
    
}

- (void)testTaskWithNilRequest{
    ODRequest *testRequest = [self odRequestWith:self.testBaseURL options:nil];
    XCTAssertThrows([testRequest taskWithRequest:nil odObjectWithDictionary:nil completion:nil]);
}

- (void)testTaskWithCompletion{
    NSDictionary *odObject = @{@"foo" : @"bar"};
    NSDictionary *responseObject = @{@"baz" : @"qux"};
    
    ODURLSessionDataTask *testTask = [self taskWithCompletion:^(id response, NSError *error){
        XCTAssertEqual(response, odObject);
        XCTAssertNil(error);
        }parseBlock:^(NSDictionary *response){
            XCTAssertEqual(response, responseObject);
            return odObject;
        }];
    
    testTask.completionHandler(responseObject, nil);
}

- (void)testTaskWithCompletionWithError{
    NSError *responseError = [NSError errorWithDomain:@"testError" code:123 userInfo:@{}];
    ODURLSessionDataTask *testTask = [self taskWithCompletion:^(id response, NSError *error){
        XCTAssertEqual(error, responseError);
        XCTAssertNil(response);
    }parseBlock:^(NSDictionary *response){
        // The parse block shouldn't get called if there was an error
        XCTAssertTrue(NO);
        return @{};
    }];
    testTask.completionHandler(nil, responseError);
}

- (void)testCollectionWithCompletion{
    NSDictionary *firstObject = @{@"foo" : @"Bar" };
    NSDictionary *secondObject = @{@"baz" : @"qux" };
    NSArray *values = @[firstObject, secondObject];
    NSDictionary *responseObject = @{ ODCollectionValueKey : values, ODODataNextContext : @"foo" };
    ODURLSessionDataTask *testCollectionTask = [self collectionTaskWithCompletion:^(ODCollection *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqualObjects(response.value, values);
    }parseBlock:^(NSDictionary *itemResponse){
        XCTAssertTrue([values containsObject:itemResponse]);
        return itemResponse;
    }];
    testCollectionTask.completionHandler(responseObject, nil);
}

- (void)testCollectionWithNilResponse{
    ODURLSessionDataTask *testCollectionTask = [self collectionTaskWithCompletion:^(ODCollection *response, NSError *error){
        XCTAssertNil(response);
    }parseBlock:^(NSDictionary *responseItem){
        // This should never get called if the response was nil
        XCTAssertTrue(NO);
        return responseItem;
    }];
    testCollectionTask.completionHandler(nil, nil);
}

- (void)testCollectionWithInvalidObjects{
    NSArray *objects = @[ @{@"foo" : @"bar"}, @{ @"baz" : @"qux"}];
    NSDictionary *responseObject = @{ ODCollectionValueKey : objects};
    __block NSInteger parseBlockCounter = 0;
    ODURLSessionDataTask *testCollectionTask = [self collectionTaskWithCompletion:^(ODCollection *collection, NSError *error){
        XCTAssertNil(collection);
    }parseBlock:^id (NSDictionary *object){
        parseBlockCounter++;
        if (parseBlockCounter == 2){
            return nil;
        }
        else{
            return object;
        }
    }];
    testCollectionTask.completionHandler(responseObject, nil);
}

- (void)testCollectionWithNonNilError{
    NSError *collectionTaskError = [NSError errorWithDomain:@"testErro" code:123 userInfo:@{}];
    ODURLSessionDataTask *testCollectionTask = [self collectionTaskWithCompletion:^(ODCollection *response, NSError *error){
        XCTAssertEqual(collectionTaskError, error);
    }parseBlock:^ id (NSDictionary *object){
        XCTAssertTrue(NO);
        return nil;
    }];
    testCollectionTask.completionHandler(nil, collectionTaskError);
}

- (ODURLSessionDataTask*)taskWithCompletion:(ODObjectCompletionHandler)completion parseBlock:(ODObjectWithDictionary)parseBlock
{
    ODRequest *testRequest = [self odRequestWith:self.testBaseURL options:nil];
    NSMutableURLRequest *testURLRequest = [self requestWithODURLRequest:testRequest method:@"GET" body:nil extraHeaders:nil expectedRequest:nil];
    ODURLSessionDataTask *testTask = [testRequest taskWithRequest:testURLRequest odObjectWithDictionary:parseBlock completion:completion];
    return testTask;
}

- (ODURLSessionDataTask *)collectionTaskWithCompletion:(ODObjectCompletionHandler)completion parseBlock:(ODObjectWithDictionary)parseBlock
{
    ODCollectionRequest *testRequest = [self collectionRequestWithURL:self.testBaseURL options:nil];
    NSMutableURLRequest *testURLRequest = [self requestWithODURLRequest:testRequest method:@"GET" body:nil extraHeaders:nil expectedRequest:nil];
    ODURLSessionDataTask *testTask = [testRequest collectionTaskWithRequest:testURLRequest odObjectWithDictionary:parseBlock completion:completion];
    return testTask;
    
}

- (ODCollectionRequest *)collectionRequestWithURL:(NSURL *)url
                                            options:(NSArray *)options
{
    return [[ODCollectionRequest alloc] initWithURL:url options:options client:self.mockClient];
}


- (ODRequest *)odRequestWith:(NSURL *)url
                         options:(NSArray *)options
{
    return [[ODRequest alloc] initWithURL:url options:options client:self.mockClient];
}

- (NSMutableURLRequest *)requestWithODURLRequest:(ODRequest *)testRequest
                                            method:(NSString *)method
                                              body:(NSData *)body
                                      extraHeaders:(NSDictionary *)extraHeaders
                                   expectedRequest:(NSURLRequest*)expectedRequest
{
    
    NSMutableURLRequest *request = [testRequest requestWithMethod:method body:body headers:extraHeaders];
    if(expectedRequest){
        [self assertRequest:request isEqual:expectedRequest];
    }
    
    return request; 
}

- (NSMutableURLRequest *)requestWithURL:(NSURL *)url
                                options:(NSArray *)options
                                 method:(NSString *)method
                                   body:(NSData *)body
                           extraHeaders:(NSDictionary *)extraHeaders
                        expectedRequest:(NSURLRequest *)expectedRequest
{
    ODRequest *testRequest = [self odRequestWith:url options:options];
    
    return [self requestWithODURLRequest:testRequest
                             method:method
                               body:body
                       extraHeaders:extraHeaders
                   expectedRequest:expectedRequest];
}

@end
