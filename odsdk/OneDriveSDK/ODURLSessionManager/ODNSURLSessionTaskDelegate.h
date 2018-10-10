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


#import <Foundation/Foundation.h>

typedef void(^ODURLSessionTaskCompletion)(id responseObject, NSURLResponse *response, NSError *error);

/**
 *  'ODURLSessionTaskDelegate' the delegate object for a given NSURLSessionTask
 */
@interface ODURLSessionTaskDelegate : NSObject

/**
 Creates an instance of an ODURLSessionTaskDelegate
 @param  progress an object reference to a progress
 @param  completion a completion handler to be called when the task completes
 */
- (instancetype)initWithProgressRef:(NSProgress * __autoreleasing *)progress
                        completion:(ODURLSessionTaskCompletion)completion;

/**
 Updates the progress object with the given bytes
 @param  sentBytes the number of bytes that have been sent currently, must not be nil.
 @param  expectedBytes the total number of bytes that are expected to be sent, must not be nil.
 */
- (void)updateProgressWithBytesSent:(int64_t)sentBytes expectedBytes:(int64_t)expectedBytes;

/**
 This method should be called when the NSURLSessionData task received any data
 @param  data the data that was received
 */
- (void)didReceiveData:(NSData *)data;

/**
 This method should be called when the task is completed
 @param  task the task that was completed
 @param  error any error that occurred during the task
 */
- (void)task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error;

/**
 This method should be called when the download task is completed
 @param task the task that was completed
 @param downloadLocation the location of the file that was downloaded
 */
- (void)task:(NSURLSessionTask *)task didCompleteDownload:(NSURL *)downloadLocation;

@end
