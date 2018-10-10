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


@class ODClient;

#import <Foundation/Foundation.h>
#import "ODHttpProvider.h"

/**
 States for the ODURLSessionTask.
 */
typedef NS_ENUM(NSInteger, ODURLSessionTaskState){
    ODTaskCreated = 0,
    ODTaskCanceled,
    ODTaskAuthenticating,
    ODTaskAuthFailed,
    ODTaskExecuting,
    ODTaskCompleted
};

/**
 The Upload Completion Handler to be called when an upload is completed.
 */
typedef void (^ODUploadCompletionHandler)(NSDictionary *response, NSError *error);

/**
 The download completion handler to be called when a download is completed.
 */
typedef ODRawDownloadCompletionHandler ODDownloadCompletionHandler;


@interface ODURLSessionTask : NSObject

/**
 The NSURLSessionTask that is created and used to make the actual request.
 This may be nil until the inner task is actually created.
 */
@property (readonly) NSURLSessionTask *innerTask;

/**
 The client that sends the request.
 */
@property (strong) ODClient *client;

/**
 The state of the task.
 @see ODURLSessionTaskState
 */
@property (readonly) ODURLSessionTaskState state;

/**
 Creates an `ODURLSessionTask` with the given requests and client.
 @param request The request to use. Must not be nil.
 @param client The client to make the request. Must not be nil.
 */
- (instancetype)initWithRequest:(NSMutableURLRequest *)request client:(ODClient *)client;

/**
 Executes the task.
 @warning The task may send an extra request to reauthenticate the session if the auth token has expired.
 */
- (void)execute;

/**
 Cancels the task.
 */
- (void)cancel;

@end
