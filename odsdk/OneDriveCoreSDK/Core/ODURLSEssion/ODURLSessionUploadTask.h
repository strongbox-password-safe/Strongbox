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


#import "ODURLSessionProgressTask.h"
/**
 An `ODURLSessionTask` to upload content. 
 @see ODURLSessionTask
 */
@interface ODURLSessionUploadTask : ODURLSessionProgressTask

/**
 Creates an UploadSessionTask.
 @param request The request to be made.
 @param fileURL The URL to the local file to be uploaded.
 @param client The client that will make the request.
 @param completionHandler The completion to be called on completion.
 @warning Request, fileURL, and client must not be nil.
 */
- (instancetype) initWithRequest:(NSMutableURLRequest *)request
                        fromFile:(NSURL *)fileURL
                          client:(ODClient *)client
               completionHandler:(ODUploadCompletionHandler)completionHandler;

/**
 Creats an UploadSessionTask.
 @param request The request to be made.
 @param data The data to be uploaded.
 @param client The client that will make the request.
 @param completionHandler The completion to be called on completion.
 @warning Request, data, and client must not be nil.
 */
- (instancetype)initWithRequest:(NSMutableURLRequest *)request
                           data:(NSData *)data
                         client:(ODClient *)client
              completionHandler:(ODUploadCompletionHandler)completionHandler;
@end
