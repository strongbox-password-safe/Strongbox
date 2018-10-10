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


@class ODAsyncOperationStatus;

#import "ODURLSessionTask.h"

/**
 An `ODURLSessionTask` to be used for async tasks. These tasks will poll a monitor request in the background.
 As the monitor requests complete they will call the ODAsyncActionCompletionHandler, and only one of the parameters will be non nil at a time.
 */
@interface ODAsyncURLSessionDataTask : ODURLSessionTask

/**
 An NSProgress representing the progress of the async task.
 */
@property NSProgress *progress;

/**
 The Async Action Completion, to be called when the task is completed, has an updated monitor response, or if there was an error.
 */
typedef void(^ODAsyncActionCompletion)(id response, ODAsyncOperationStatus *status, NSError *error);

/**
 Creates an `ODAsyncURLSessionDataTask` with the given requests and client.
 @param request The request to use. Must not be nil.
 @param client The client to make the request. Must not be nil.
 @param completionHandler The completionHandler to be called whenever the task was completed, the status was updated, or there was an error.
 */
- (instancetype)initWithRequest:(NSMutableURLRequest *)request
                         client:(ODClient *)client
                     completion:(ODAsyncActionCompletion)completionHandler;

@end
