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

@interface ODTestCase(){
    NSDictionary *_cannedItem;
}

@end

@implementation ODTestCase


- (void)setUp{
    [super setUp];
    
    self.mockSession = OCMProtocolMock(@protocol(ODHttpProvider));
    self.mockAuthProvider = OCMProtocolMock(@protocol(ODAuthProvider));
    self.mockClient = OCMPartialMock([[ODClient alloc] initWithURL:[self.testBaseURL absoluteString] httpProvider:self.mockSession authProvider:self.mockAuthProvider]);
    self.testBaseURL = [NSURL URLWithString:@"https://foo.com/bar/baz"]; 
}

- (void) setAuthProvider:(id <ODAuthProvider> )mockAuthProvider
appendHeaderResponseWith:(NSMutableURLRequest *)request
                   error:(NSError *)error
{
   OCMStub([mockAuthProvider appendAuthHeaders:[OCMArg any] completion:[OCMArg any]])
    .andDo(^(NSInvocation *invocation){
          void (^completionHandler)(NSMutableURLRequest *request, NSError *error);
        [invocation getArgument:&completionHandler atIndex:3];
        completionHandler(request, error);
    });
}

- (void)appendHeaderResponseWith:(NSMutableURLRequest *)request
                           error:(NSError *)error
{
    [self setAuthProvider:self.mockAuthProvider appendHeaderResponseWith:request error:error];
}

-(OCMStubRecorder *) dataTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                   data:(NSData *)data
               response:(NSHTTPURLResponse *)response
                  error:(NSError *)error
{
    return [self dataTaskCompletionWithRequest:mockRequest data:data response:response error:error dataTask:nil];
}

- (OCMStubRecorder *) dataTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                               data:(NSData *)data
                                           response:(NSHTTPURLResponse *)response
                                              error:(NSError *)error
                                           dataTask:(NSURLSessionDataTask *)task
{
    return [self mockURLSession:self.mockSession dataTaskCompletionWithRequest:mockRequest data:data response:response error:error dataTask:task];
}

- (OCMStubRecorder *) mockURLSession:( id <ODHttpProvider> )mockSession
dataTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                   data:(NSData *)data
               response:(NSHTTPURLResponse *)response
                  error:(NSError *)error
{
    return [self mockURLSession:mockSession dataTaskCompletionWithRequest:mockRequest data:data response:response error:error dataTask:nil];
}

- (OCMStubRecorder *)mockURLSession:(id<ODHttpProvider>)mockSession
      dataTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                               data:(NSData *)data
                           response:(NSHTTPURLResponse *)response
                              error:(NSError *)error
                           dataTask:(NSURLSessionDataTask *)task
{
    OCMStubRecorder *sessionStub = OCMStub([mockSession dataTaskWithRequest:mockRequest completionHandler:[OCMArg any]])
        .andDo(^(NSInvocation *invocation){
            ODDataCompletionHandler completionHandler;
             [invocation getArgument:&completionHandler atIndex:3];
             completionHandler(data, response, error);
    });
    return [self sessionStub:sessionStub returnsTask:task];
}

- (OCMStubRecorder *) mockURLSession:(id <ODHttpProvider> )mockSession
downloadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
               progress:(NSProgress *)progress
                    url:(NSURL *)location
               response:(NSHTTPURLResponse *)response
                  error:(NSError *)error
{
    return [self mockURLSession:mockSession downloadTaskCompletionWithRequest:mockRequest progress:progress url:location response:response error:error downloadTask:nil];
}

- (OCMStubRecorder *)downloadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                 progress:(NSProgress *)progress
                                      url:(NSURL *)location
                                 response:(NSHTTPURLResponse *)response
                                    error:(NSError *)error
{
    return [self downloadTaskCompletionWithRequest:mockRequest progress:progress url:location response:response error:error downloadTask:nil];
}

- (OCMStubRecorder *)downloadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                              progress:(NSProgress *)progress
                                                   url:(NSURL *)location
                                              response:(NSHTTPURLResponse *)response
                                                 error:(NSError *)error
                                          downloadTask:(NSURLSessionDownloadTask *)task
{
    return [self mockURLSession:self.mockSession downloadTaskCompletionWithRequest:mockRequest progress:progress url:location response:response error:error downloadTask:task];
}


- (OCMStubRecorder *)mockURLSession:(id<ODHttpProvider>)session
  downloadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                           progress:(NSProgress *)progress
                                url:(NSURL *)location
                           response:(NSHTTPURLResponse *)response
                              error:(NSError *)error
                       downloadTask:(NSURLSessionDownloadTask *)task
{
    OCMStubRecorder *sessionStub = OCMStub([session downloadTaskWithRequest:mockRequest progress:[OCMArg anyObjectRef] completionHandler:[OCMArg any]])
    .andDo(^(NSInvocation *invocation){
        ODRawDownloadCompletionHandler completionHandler;
        NSProgress * __autoreleasing *taskProgress;
        [invocation getArgument:&taskProgress atIndex:3];
        if (progress){
            *taskProgress = progress;
        }
        [invocation getArgument:&completionHandler atIndex:4];
        completionHandler(location, response, error);
    });
    
    return [self sessionStub:sessionStub returnsTask:task];
}


- (OCMStubRecorder *) mockURLSession:(id <ODHttpProvider> )mockSession
uploadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
               progress:(NSProgress *)progress
                   data:(NSData *)data
               response:(NSHTTPURLResponse *)response
                  error:(NSError *)error
{
    return [self mockURLSession:mockSession uploadTaskCompletionWithRequest:mockRequest progress:progress data:data response:response error:error uploadTask:nil];
}

- (OCMStubRecorder *)uploadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                            progress:(NSProgress *)progress
                                                data:(NSData *)data
                                            response:(NSHTTPURLResponse *)response
                                               error:(NSError *)error
{
    return [self mockURLSession:self.mockSession uploadTaskCompletionWithRequest:mockRequest progress:progress data:data response:response error:error uploadTask:nil];
}

- (OCMStubRecorder *)uploadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                            progress:(NSProgress *)progress
                                                data:(NSData *)data
                                            response:(NSHTTPURLResponse *)response
                                               error:(NSError *)error
                                          uploadTask:(NSURLSessionUploadTask *)uploadTask
{
    return [self mockURLSession:self.mockSession uploadTaskCompletionWithRequest:mockRequest progress:progress data:data response:response error:error uploadTask:uploadTask];
}

- (OCMStubRecorder *) mockURLSession:(id <ODHttpProvider> )mockSession
     uploadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                            progress:(NSProgress *)progress
                                data:(NSData *)data
                            response:(NSHTTPURLResponse *)response
                               error:(NSError *)error
                          uploadTask:(NSURLSessionUploadTask *)task
{
   OCMStubRecorder *sessionStub = OCMStub([mockSession uploadTaskWithRequest:mockRequest fromFile:[OCMArg any] progress:[OCMArg anyObjectRef] completionHandler:[OCMArg any]])
    .andDo(^(NSInvocation *invocation){
        ODRawUploadCompletionHandler completionHandler;
        [invocation getArgument:&completionHandler atIndex:5];
        completionHandler(data, response, error);
    });
    return [self sessionStub:sessionStub returnsTask:task];
}
- (OCMStubRecorder *)sessionStub:(OCMStubRecorder *)sessionStub returnsTask:(NSURLSessionTask *)task
{
    if (task){
        return sessionStub.andReturn(task);
    }
    return sessionStub;
}

- (void)assertRequest:(NSURLRequest *)request isEqual:(NSURLRequest *)expectedRequest
{
    XCTAssertEqualObjects(request.URL, expectedRequest.URL);
    XCTAssertEqualObjects(request.HTTPMethod, expectedRequest.HTTPMethod);
    XCTAssertEqualObjects(request.HTTPBody, expectedRequest.HTTPBody);
    // all requests that were made have the SDK version on them
    XCTAssertEqual([request.allHTTPHeaderFields count], [expectedRequest.allHTTPHeaderFields count]);
    [expectedRequest.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop){
        XCTAssertEqualObjects(request.allHTTPHeaderFields[key], value);
    }];
}

- (NSDictionary *)cannedItem
{
    if (!_cannedItem){
        __block id class = [self class];
        static NSDictionary *cannedItem = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *cannedItemPath = [[NSBundle bundleForClass:class] pathForResource:@"CannedItem" ofType:@"json"];
            NSData *cannedItemData = [NSData dataWithContentsOfFile:cannedItemPath];
            cannedItem = [NSJSONSerialization JSONObjectWithData:cannedItemData options:0 error:nil];
        });
        _cannedItem = cannedItem;
    }
    return _cannedItem;
}

@end
