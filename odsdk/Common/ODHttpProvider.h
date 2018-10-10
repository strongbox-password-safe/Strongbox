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

/**
 Completion handler to be called from ODHttpProvider on download completion.
 */
typedef void (^ODRawDownloadCompletionHandler)(NSURL *location, NSURLResponse *response, NSError *error);

/**
 Completion handler to be called from ODHttpProvider on upload completion.
 */
typedef void (^ODRawUploadCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);

/**
 Completion handler to be called form ODHttpProvider on a data task completion.
 */
typedef void (^ODDataCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);

/**
 The `ODHttpProvider` protocol is meant to inject all network access from ODClient and ODRequests.
 */
@protocol ODHttpProvider <NSObject>


/**
 Creates an NSURLSessionDataTask ready to be resumed.
 @param  request The request that should be sent.
 @param  completionHandler The completion handler to be called on completion. It may be nil.
 @return The NSURLSessionDataTask ready to be resumed.
 */
- (NSURLSessionDataTask *) dataTaskWithRequest:(NSURLRequest *)request
                             completionHandler:(ODDataCompletionHandler)completionHandler;
/**
 Creates an NSURLSessionDataTask ready to be resumed.
 @param  request The request that should be sent.
 @param  progress A reference to an NSProgress object that will be updated when the download completes. It may be nil.
 @param  completionHandler The completion handler to be called on completion. It may be nil.
 @return The NSURLSessionDownloadTask ready to be resumed.
 */
- (NSURLSessionDownloadTask *) downloadTaskWithRequest:(NSURLRequest *)request
                                              progress:(NSProgress * __autoreleasing *)progress
                                     completionHandler:(ODRawDownloadCompletionHandler)completionHandler;
/**
 Creates an NSURLSessionUploadTask ready to be resumed.
 @param  request The request that should be sent.
 @param  fileURL The file to upload.
 @param  progress A reference to an NSProgress to be updated as the upload completes. It may be nil.
 @param  completionHandler The completion handler to be called on completion. It may be nil.
 @return The NSURLSessionDownloadTask ready to be resumed.
 */
- (NSURLSessionUploadTask *) uploadTaskWithRequest:(NSURLRequest *)request
                                          fromFile:(NSURL *)fileURL
                                          progress:(NSProgress * __autoreleasing *)progress
                                 completionHandler:(ODRawUploadCompletionHandler)completionHandler;
/**
 Creates an NSURLSessionUploadTask ready to be resumed.
 @param  request The request to be sent.
 @param  data The data to be uploaded.
 @param  progress A reference to an NSProgress to be updated as the upload completes. It may be nil.
 @param  completionHandler The completion handler to be called on completion. It may be nil.
 @return The NSURLSessionDownloadTask ready to be resumed.
 */
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromData:(NSData *)data
                                         progress:(NSProgress * __autoreleasing *)progress
                                completionHandler:(ODRawUploadCompletionHandler)completionHandler;

@end
