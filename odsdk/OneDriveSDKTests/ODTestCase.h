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


#import <XCTest/XCTest.h>
#import "ODClient.h"
#import "ODHttpProvider.h"
#import "ODAuthProvider.h"
#import "ODConstants.h"
#import "OCMock.h"

@interface ODTestCase : XCTestCase

@property NSURL *testBaseURL;

@property ODClient *mockClient;

@property (readonly, nonatomic) NSDictionary *cannedItem;

@property id <ODHttpProvider> mockSession;

@property id <ODAuthProvider> mockAuthProvider;

/**
 * Sets the mock auth manager to call the appendAuthHeaders completion 
 *  handler with the given request and error
 *  @param mockAuthManager, the mock auth manager to set
 *  @param request, the request to pass back in the completion handler
 *  @param error, the error to pass back in the completion handler
 *  @warning mockAuthManager must not be nil
 */
- (void) setAuthProvider:(id <ODAuthProvider> )mockAuthManager
appendHeaderResponseWith:(NSMutableURLRequest *)request
                   error:(NSError *)error;

/**
 * Sets the mock ODHttpProvider to call the  dataTaskWithCompletionHandler 
 *  completion handler with the given data, response, and error
 *  @param mockSession the mock session to stub out
 *  @param data the data to be passed into the completion handler
 *  @param response, the response to be passed into the completion handler
 *  @param error the error to be passed into the completion handler
 *  @warning mockSession must not be nil
 */
- (OCMStubRecorder *) mockURLSession:( id <ODHttpProvider> )mockSession
dataTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                   data:(NSData *)data
               response:(NSHTTPURLResponse *)response
                  error:(NSError *)error;

- (OCMStubRecorder *) mockURLSession:( id <ODHttpProvider> )mockSession
       dataTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                data:(NSData *)data
                            response:(NSHTTPURLResponse *)response
                               error:(NSError *)error
                            dataTask:(NSURLSessionDataTask *)task;
/**
 * Sets the mockSession to call the dataTaskWithCompletionHandler
 * with the given, data , response, and error
 * @see mockURLSession: dataTaskCompletionWithRequest: data:response:error
 */
-(OCMStubRecorder *) dataTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                              data:(NSData *)data
                                          response:(NSHTTPURLResponse *)response
                                             error:(NSError *)error;

-(OCMStubRecorder *) dataTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                              data:(NSData *)data
                                          response:(NSHTTPURLResponse *)response
                                             error:(NSError *)error
                                          dataTask:(NSURLSessionDataTask *)task;

- (OCMStubRecorder *)downloadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                              progress:(NSProgress *)progress
                                                   url:(NSURL *)location
                                              response:(NSHTTPURLResponse *)response
                                                 error:(NSError *)error;

- (OCMStubRecorder *)downloadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                              progress:(NSProgress *)progress
                                                   url:(NSURL *)location
                                              response:(NSHTTPURLResponse *)response
                                                 error:(NSError *)error
                                          downloadTask:(NSURLSessionDownloadTask *)task;

- (OCMStubRecorder *) mockURLSession:(id <ODHttpProvider> )mockSession
   downloadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                            progress:(NSProgress *)progress
                                 url:(NSURL *)location
                            response:(NSHTTPURLResponse *)response
                               error:(NSError *)error
                        downloadTask:(NSURLSessionDownloadTask *)task;

- (OCMStubRecorder *) mockURLSession:(id <ODHttpProvider> )mockSession
   downloadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                            progress:(NSProgress *)progress
                                 url:(NSURL *)location
                            response:(NSHTTPURLResponse *)response
                               error:(NSError *)error;

- (OCMStubRecorder *) uploadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                             progress:(NSProgress *)progress
                                                 data:(NSData *)data
                                             response:(NSHTTPURLResponse *)response
                                                error:(NSError *)error;

- (OCMStubRecorder *) uploadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                                             progress:(NSProgress *)progress
                                                 data:(NSData *)data
                                             response:(NSHTTPURLResponse *)response
                                                error:(NSError *)error
                                           uploadTask:(NSURLSessionUploadTask *)task;

- (OCMStubRecorder *) mockURLSession:(id <ODHttpProvider> )mockSession
     uploadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                            progress:(NSProgress *)progress
                                data:(NSData *)data
                            response:(NSHTTPURLResponse *)response
                               error:(NSError *)error;

- (OCMStubRecorder *) mockURLSession:(id <ODHttpProvider> )mockSession
     uploadTaskCompletionWithRequest:(NSMutableURLRequest *)mockRequest
                            progress:(NSProgress *)progress
                                data:(NSData *)data
                            response:(NSHTTPURLResponse *)response
                               error:(NSError *)error
                          uploadTask:(NSURLSessionUploadTask *)task;

/**
 * Asserts the given request matches the expected request
 * @param requests, the received requests
 * @param the expected request
 * @warning this method Asserts and will throw if the requests are different
 */
- (void)assertRequest:(NSURLRequest *)request isEqual:(NSURLRequest *)expectedRequests;

@end
